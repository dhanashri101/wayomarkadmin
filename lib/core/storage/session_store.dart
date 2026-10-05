import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  SessionStore._();

  static final SessionStore instance = SessionStore._();
  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'wayomark_admin_access_token';
  static const _refreshKey = 'wayomark_admin_refresh_token';

  Future<void> save({required String accessToken, String? refreshToken}) async {
    await _storage.write(key: _accessKey, value: accessToken);
    if (refreshToken != null && refreshToken.trim().isNotEmpty) {
      await _storage.write(key: _refreshKey, value: refreshToken);
    } else {
      await _storage.delete(key: _refreshKey);
    }
  }

  Future<({String? accessToken, String? refreshToken})> read() async {
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    return (accessToken: access, refreshToken: refresh);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
