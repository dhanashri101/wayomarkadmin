import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Production API client for the Wayomark release backend.
///
/// Production Wayomark API.
///
/// The Postman collection uses AES-256-GCM for JSON request/response payloads.
class WayomarkApiException implements Exception {
  final int statusCode;
  final String message;
  final String? url;
  final String? traceId;
  final String? responseBody;
  final dynamic decodedResponse;

  const WayomarkApiException(
    this.statusCode,
    this.message, {
    this.url,
    this.traceId,
    this.responseBody,
    this.decodedResponse,
  });

  String get details {
    final parts = <String>[
      'Status: $statusCode',
      if (url != null) 'URL: $url',
      if (traceId != null) 'Trace ID: $traceId',
      'Message: $message',
      if (decodedResponse != null) 'Decoded response: ${_pretty(decodedResponse)}',
      if (responseBody != null && responseBody!.trim().isNotEmpty)
        'Raw response: ${responseBody!.trim()}',
    ];
    return parts.join('\n');
  }

  static String _pretty(dynamic value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  @override
  String toString() => 'WayomarkApiException($statusCode): $message\n$details';
}

class WayomarkApi {
  WayomarkApi._();

  static final WayomarkApi instance = WayomarkApi._();

  static const String baseUrl = 'https://wayomark.com/service/api';
  static const String _aesKeyBase64 =
      'C0DjnVBjI9aE25qC0UXZzoKV17szIzCWQ/7CZDc5HD8=';

  String? _accessToken;
  String? _refreshToken;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get isAuthenticated => _accessToken?.isNotEmpty ?? false;

  void setAccessToken(String? token) {
    _accessToken = token?.trim().isEmpty == true ? null : token?.trim();
  }

  void setSession({String? accessToken, String? refreshToken}) {
    setAccessToken(accessToken);
    _refreshToken = refreshToken?.trim().isEmpty == true
        ? null
        : refreshToken?.trim();
  }

  void clearSession() {
    _accessToken = null;
    _refreshToken = null;
  }

  final AesGcm _aes = AesGcm.with256bits();

  Future<Uint8List> _keyBytes() async => base64Decode(_aesKeyBase64);

  Future<String> _encryptPayload(Map<String, dynamic> payload) async {
    final key = SecretKey(await _keyBytes());
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: key,
    );

    // Backend/Postman format: 12-byte nonce + ciphertext + 16-byte tag.
    final combined = <int>[
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ];
    return base64Encode(combined);
  }

  Future<dynamic> _decryptPayload(String encoded) async {
    final bytes = base64Decode(encoded);
    if (bytes.length < 12 + 16) {
      throw const FormatException('Invalid encrypted payload');
    }

    final nonce = bytes.sublist(0, 12);
    final mac = bytes.sublist(bytes.length - 16);
    final cipherText = bytes.sublist(12, bytes.length - 16);

    final box = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(mac),
    );

    final key = SecretKey(await _keyBytes());
    final clear = await _aes.decrypt(box, secretKey: key);
    return jsonDecode(utf8.decode(clear));
  }

  Future<dynamic> _decodeResponse(String body) async {
    if (body.trim().isEmpty) return <String, dynamic>{};

    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return body;
    }

    // Encrypted API responses are wrapped as {"data":"base64..."}.
    if (decoded is Map && decoded['data'] is String) {
      try {
        return await _decryptPayload(decoded['data'] as String);
      } catch (_) {
        // A normal API response can also legitimately have a string `data`.
        return decoded;
      }
    }

    return decoded;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  dynamic _unwrap(dynamic value) {
    if (value is Map) {
      final map = _asMap(value);
      if (map['data'] is Map || map['data'] is List) return map['data'];
      return map;
    }
    return value;
  }

  int? _extractId(dynamic value) {
    final unwrapped = _unwrap(value);
    final map = _asMap(unwrapped);
    for (final key in const ['id', 'assessmentId', 'assessment_id']) {
      final raw = map[key];
      if (raw is num) return raw.toInt();
      final parsed = int.tryParse('$raw');
      if (parsed != null) return parsed;
    }
    return null;
  }

  String _newTraceId() {
    final random = Random.secure();
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final bytes = List<int>.generate(8, (_) => random.nextInt(256));
    final suffix = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$time-$suffix';
  }

  Future<dynamic> _sendJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool encrypted = false,
    bool authenticated = false,
  }) async {
    if (authenticated && !isAuthenticated) {
      throw WayomarkApiException(
        401,
        'Authentication required. Please sign in again.',
        url: '$baseUrl$path',
      );
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    client.idleTimeout = const Duration(seconds: 30);

    final url = '$baseUrl$path';
    final traceId = _newTraceId();

    try {
      final request = await client.openUrl(method, Uri.parse(url));
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set('X-Trace-Id', traceId);

      if (authenticated && (_accessToken?.isNotEmpty ?? false)) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $_accessToken',
        );
      }

      if (encrypted) {
        request.headers.set('X-Wayomark-Encrypted', 'true');
      }

      if (body != null) {
        final payload = encrypted
            ? <String, dynamic>{'data': await _encryptPayload(body)}
            : body;
        request.write(jsonEncode(payload));
      }

      // Never log Authorization or encrypted request data. The trace ID is
      // safe to expose and lets the backend logs be matched to this request.
      print('[Wayomark API] $method $url | trace=$traceId | encrypted=$encrypted');

      final response = await request.close();
      final responseBody = await utf8.decodeStream(response);
      final decoded = await _decodeResponse(responseBody);

      print('[Wayomark API] response ${response.statusCode} $url | trace=$traceId');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401 || response.statusCode == 403) {
          clearSession();
        }
        final map = _asMap(decoded);
        final message =
            map['message']?.toString() ??
            map['error']?.toString() ??
            map['detail']?.toString() ??
            (responseBody.trim().isEmpty
                ? 'HTTP ${response.statusCode}'
                : responseBody.trim());
        throw WayomarkApiException(
          response.statusCode,
          message,
          url: url,
          traceId: traceId,
          responseBody: responseBody,
          decodedResponse: decoded,
        );
      }

      return decoded;
    } on WayomarkApiException {
      rethrow;
    } on TimeoutException catch (e) {
      throw WayomarkApiException(
        408,
        'The server took too long to respond: ${e.message ?? 'timeout'}',
        url: url,
        traceId: traceId,
      );
    } on SocketException catch (e) {
      throw WayomarkApiException(
        0,
        'Network error: ${e.message}',
        url: url,
        traceId: traceId,
      );
    } on HandshakeException catch (e) {
      throw WayomarkApiException(
        0,
        'TLS/SSL handshake failed: $e',
        url: url,
        traceId: traceId,
      );
    } catch (e) {
      throw WayomarkApiException(
        0,
        'Request failed: $e',
        url: url,
        traceId: traceId,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<dynamic> get(
    String path, {
    bool authenticated = true,
  }) => _sendJson(
        'GET',
        path,
        authenticated: authenticated,
      );

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool encrypted = false,
    bool authenticated = true,
  }) => _sendJson(
        'POST',
        path,
        body: body,
        encrypted: encrypted,
        authenticated: authenticated,
      );

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    bool encrypted = false,
    bool authenticated = true,
  }) => _sendJson(
        'PUT',
        path,
        body: body,
        encrypted: encrypted,
        authenticated: authenticated,
      );

  Map<String, dynamic> _sessionMap(dynamic response) {
    final direct = _asMap(_unwrap(response));
    if (direct.isNotEmpty) return direct;
    return _asMap(response);
  }

  Map<String, dynamic> _captureSession(dynamic response) {
    final map = _sessionMap(response);
    final nested = _asMap(map['data']);
    final token = map['accessToken'] ??
        map['access_token'] ??
        map['token'] ??
        nested['accessToken'] ??
        nested['access_token'] ??
        nested['token'];
    final refresh = map['refreshToken'] ??
        map['refresh_token'] ??
        nested['refreshToken'] ??
        nested['refresh_token'];

    if (token == null || token.toString().trim().isEmpty) {
      throw const WayomarkApiException(
        200,
        'Authentication succeeded but the server did not return an access token.',
      );
    }

    setSession(
      accessToken: token.toString(),
      refreshToken: refresh?.toString(),
    );
    return map;
  }

  // -------------------------------------------------------------------------
  // Authentication
  // -------------------------------------------------------------------------

  /// Backend-supported development/test OTP. The app still calls the real
  /// verification endpoint and never creates a fake local session.
  static const String dummyOtp = '123456';

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    final response = await post(
      '/v1/auth/register',
      body: {
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'password': password,
      },
      encrypted: true,
      authenticated: false,
    );
    return _asMap(_unwrap(response));
  }

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final response = await post(
      '/v1/auth/login',
      body: {
        'identifier': identifier.trim(),
        'password': password,
      },
      encrypted: true,
      authenticated: false,
    );
    return _captureSession(response);
  }

  Future<void> requestOtp(String phone) async {
    await post(
      '/v1/auth/otp/request',
      body: {
        'destination': phone,
        'purpose': 'LOGIN',
      },
      encrypted: true,
      authenticated: false,
    );
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await post(
      '/v1/auth/otp/verify',
      body: {
        'destination': phone,
        'otp': otp,
        'purpose': 'LOGIN',
      },
      encrypted: true,
      authenticated: false,
    );
    return _captureSession(response);
  }

  Future<void> logout() async {
    try {
      if (isAuthenticated) {
        await post('/v1/auth/logout');
      }
    } finally {
      clearSession();
    }
  }

  // -------------------------------------------------------------------------
  // App APIs
  // -------------------------------------------------------------------------

  Future<dynamic> dashboard() => get('/v1/dashboard');
  Future<dynamic> profile() => get('/v1/profile');
  Future<dynamic> assessments() => get('/v1/assessments');
  Future<dynamic> offers() => get('/v1/offers');
  Future<dynamic> reports() => get('/v1/reports');
  Future<dynamic> documents() => get('/v1/documents');
  Future<dynamic> notifications() => get('/v1/notifications');
  Future<dynamic> consultations() => get('/v1/consultations');
  Future<dynamic> experts() => get('/v1/experts');
  Future<dynamic> settings() => get('/v1/settings');
  Future<dynamic> supportTickets() => get('/v1/support/tickets');

  Future<dynamic> updateProfile({
    required String fullName,
    String? email,
    String? residencePincode,
  }) => put(
        '/v1/profile',
        body: {
          'fullName': fullName,
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
          if (residencePincode != null && residencePincode.trim().isNotEmpty)
            'residencePincode': residencePincode.trim(),
        },
        encrypted: true,
      );

  Future<dynamic> registerDeviceToken({
    required String token,
    required String platform,
  }) => post(
        '/v1/devices',
        body: {
          'token': token,
          'platform': platform,
        },
        encrypted: true,
      );

  Future<int> createAssessment({required String reasonCode}) async {
    final response = await post(
      '/v1/assessments',
      body: {'reasonCode': reasonCode},
      encrypted: true,
    );
    final id = _extractId(response);
    if (id == null) {
      throw const WayomarkApiException(200, 'Assessment ID was not returned by the server.');
    }
    return id;
  }

  Future<dynamic> updateAssessmentStep({
    required int assessmentId,
    required int step,
    required String reasonCode,
  }) => put(
        '/v1/assessments/$assessmentId/step',
        body: {
          'step': step,
          'reasonCode': reasonCode,
        },
        encrypted: true,
      );

  Future<dynamic> saveLoanProfile({
    required int assessmentId,
    required double currentEmi,
    required double currentOutstanding,
    required int remainingTenureMonths,
    required double availableOutstanding,
    required double currentRoi,
  }) => post(
        '/v1/assessments/$assessmentId/loan',
        body: {
          'currentEmi': currentEmi,
          'currentOutstanding': currentOutstanding,
          'remainingTenureMonths': remainingTenureMonths,
          'availableOutstanding': availableOutstanding,
          'currentRoi': currentRoi,
        },
        encrypted: true,
      );

  Future<dynamic> analysis(int assessmentId) => get('/v1/analysis/$assessmentId');
  Future<dynamic> comparison(int assessmentId) => get('/v1/comparison/$assessmentId');
  Future<dynamic> recommendations(int assessmentId) => get('/v1/recommendations/$assessmentId');
  Future<dynamic> generateRecommendations(int assessmentId) => post('/v1/recommendations/$assessmentId/generate');

  Future<dynamic> createReport({
    required int assessmentId,
    required String title,
    required String reportType,
    required String fileUrl,
  }) => post(
        '/v1/reports',
        body: {
          'assessmentId': assessmentId,
          'title': title,
          'reportType': reportType,
          'fileUrl': fileUrl,
        },
        encrypted: true,
      );

  Future<dynamic> createDocumentMetadata({
    required String documentType,
    required String fileName,
    required String fileUrl,
  }) => post(
        '/v1/documents',
        body: {
          'documentType': documentType,
          'fileName': fileName,
          'fileUrl': fileUrl,
        },
        encrypted: true,
      );

  Future<dynamic> markNotificationRead(int notificationId) => put(
        '/v1/notifications/$notificationId/read',
      );

  Future<dynamic> bookConsultation({
    required int expertId,
    required String scheduledAt,
    required String channel,
    String notes = '',
  }) => post(
        '/v1/consultations',
        body: {
          'expertId': expertId,
          'scheduledAt': scheduledAt,
          'channel': channel,
          'notes': notes,
        },
        encrypted: true,
      );

  Future<dynamic> cancelConsultation(int consultationId) => put(
        '/v1/consultations/$consultationId/cancel',
      );

  Future<dynamic> updateSettings({
    required bool pushEnabled,
    required bool emailEnabled,
    required bool smsEnabled,
  }) => put(
        '/v1/settings',
        body: {
          'pushEnabled': pushEnabled,
          'emailEnabled': emailEnabled,
          'smsEnabled': smsEnabled,
        },
        encrypted: true,
      );

  Future<dynamic> createSupportTicket({
    required String subject,
    required String description,
  }) => post(
        '/v1/support/tickets',
        body: {
          'subject': subject,
          'description': description,
        },
        encrypted: true,
      );

  Future<dynamic> createReferral(String contact) => post(
        '/v1/referrals',
        body: {'contact': contact},
        encrypted: true,
      );

  // -------------------------------------------------------------------------
  // Admin APIs from the supplied Postman collection. These methods are kept
  // in the same client so an admin build can reuse the exact API contract.
  // -------------------------------------------------------------------------

  Future<dynamic> adminDashboard() => get('/v1/admin/dashboard');
  Future<dynamic> adminUsers() => get('/v1/admin/users');
  Future<dynamic> adminAssessments() => get('/v1/admin/assessments');
  Future<dynamic> adminConsultations() => get('/v1/admin/consultations');

  Future<dynamic> adminSendNotification({
    required List<int> userIds,
    required String title,
    required String body,
    String type = 'ADMIN',
  }) => post(
        '/v1/admin/notifications',
        body: {
          'userIds': userIds,
          'title': title.trim(),
          'body': body.trim(),
          'type': type,
        },
        encrypted: true,
      );

  Future<dynamic> adminCreateBankOffer({
    required String bankName,
    required double roi,
    required double emi,
    required double loanAmount,
    required int tenureMonths,
  }) => post(
        '/v1/admin/bank-offers',
        body: {
          'bankName': bankName.trim(),
          'roi': roi,
          'emi': emi,
          'loanAmount': loanAmount,
          'tenureMonths': tenureMonths,
        },
        encrypted: true,
      );

  // -------------------------------------------------------------------------
  // Multipart document upload. This endpoint is NOT encrypted in Postman.
  // -------------------------------------------------------------------------

  Future<dynamic> uploadDocument({
    required String filePath,
    required String documentType,
  }) async {
    if (!isAuthenticated) {
      throw const WayomarkApiException(
        401,
        'Authentication required. Please sign in again.',
      );
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw const WayomarkApiException(0, 'Selected file no longer exists.');
    }

    final bytes = await file.readAsBytes();
    final fileName = file.uri.pathSegments.isEmpty
        ? 'document'
        : file.uri.pathSegments.last;

    final boundary = '----Wayomark${DateTime.now().microsecondsSinceEpoch}';
    final traceId = _newTraceId();
    final uploadUrl = '$baseUrl/v1/documents/upload';
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);
    client.idleTimeout = const Duration(minutes: 2);

    try {
      final request = await client.postUrl(
        Uri.parse(uploadUrl),
      );
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set('X-Trace-Id', traceId);
      if (_accessToken?.isNotEmpty ?? false) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $_accessToken',
        );
      }

      final buffer = BytesBuilder(copy: false);
      void addString(String value) => buffer.add(utf8.encode(value));

      addString('--$boundary\r\n');
      addString('Content-Disposition: form-data; name="documentType"\r\n\r\n');
      addString('$documentType\r\n');
      addString('--$boundary\r\n');
      addString('Content-Disposition: form-data; name="file"; filename="${_safeFileName(fileName)}"\r\n');
      addString('Content-Type: ${_contentType(fileName)}\r\n\r\n');
      buffer.add(bytes);
      addString('\r\n--$boundary--\r\n');

      request.add(buffer.takeBytes());
      final response = await request.close();
      final responseBody = await utf8.decodeStream(response);
      final decoded = await _decodeResponse(responseBody);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401 || response.statusCode == 403) {
          clearSession();
        }
        final map = _asMap(decoded);
        throw WayomarkApiException(
          response.statusCode,
          map['message']?.toString() ?? map['error']?.toString() ?? responseBody,
          url: uploadUrl,
          traceId: traceId,
          responseBody: responseBody,
          decodedResponse: decoded,
        );
      }

      return decoded;
    } on WayomarkApiException {
      rethrow;
    } on TimeoutException {
      throw const WayomarkApiException(408, 'Upload timed out. Please try again.');
    } on SocketException catch (e) {
      throw WayomarkApiException(0, 'Upload network error: ${e.message}');
    } catch (e) {
      throw WayomarkApiException(0, 'Upload failed: $e');
    } finally {
      client.close(force: true);
    }
  }

  String _safeFileName(String value) => value.replaceAll(RegExp(r'[\\/\r\n"]'), '_');

  String _contentType(String name) {
    switch (name.toLowerCase().split('.').last) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }
}
