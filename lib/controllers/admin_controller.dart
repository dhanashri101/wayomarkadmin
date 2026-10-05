import 'package:flutter/foundation.dart';

import '../core/network/wayomark_api.dart';
import '../core/storage/session_store.dart';
import '../core/utils/api_data.dart';

class AdminController extends ChangeNotifier {
  final WayomarkApi api = WayomarkApi.instance;
  final SessionStore store = SessionStore.instance;

  bool booting = true;
  bool authenticated = false;
  bool loading = false;
  String? error;
  int selectedIndex = 0;

  dynamic dashboardRaw;
  List<Map<String, dynamic>> users = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> assessments = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> consultations = <Map<String, dynamic>>[];

  Future<void> bootstrap() async {
    booting = true;
    error = null;
    notifyListeners();

    try {
      final saved = await store.read();
      if (saved.accessToken == null || saved.accessToken!.trim().isEmpty) {
        authenticated = false;
        return;
      }

      api.setSession(
        accessToken: saved.accessToken,
        refreshToken: saved.refreshToken,
      );

      // Admin dashboard doubles as permission validation. A normal customer
      // token should be rejected by the backend here.
      dashboardRaw = await api.adminDashboard();
      authenticated = true;
      await _prefetchLists();
    } catch (_) {
      await _clearSession();
      authenticated = false;
    } finally {
      booting = false;
      notifyListeners();
    }
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await api.login(identifier: identifier, password: password);

      // Verify that the authenticated account is actually allowed to use the
      // admin API before we persist the session.
      dashboardRaw = await api.adminDashboard();

      final token = api.accessToken;
      if (token == null || token.isEmpty) {
        throw const WayomarkApiException(
          200,
          'Login succeeded but no access token was returned.',
        );
      }

      await store.save(
        accessToken: token,
        refreshToken: api.refreshToken,
      );
      authenticated = true;
      await _prefetchLists();
    } on WayomarkApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        error = 'This account is not authorized for the Wayomark Admin app.';
      } else {
        error = e.message;
      }
      await _clearSession();
      authenticated = false;
    } catch (e) {
      error = 'Unable to sign in: $e';
      await _clearSession();
      authenticated = false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    loading = true;
    notifyListeners();
    try {
      await api.logout();
    } catch (_) {
      // Local logout must still complete if the server is temporarily down.
    } finally {
      await _clearSession();
      authenticated = false;
      selectedIndex = 0;
      dashboardRaw = null;
      users = <Map<String, dynamic>>[];
      assessments = <Map<String, dynamic>>[];
      consultations = <Map<String, dynamic>>[];
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _clearSession() async {
    api.clearSession();
    await store.clear();
  }

  void select(int index) {
    selectedIndex = index;
    error = null;
    notifyListeners();
  }

  Future<void> refreshCurrent() async {
    switch (selectedIndex) {
      case 0:
        await loadDashboard();
        break;
      case 1:
        await loadUsers();
        break;
      case 2:
        await loadAssessments();
        break;
      case 3:
        await loadConsultations();
        break;
      default:
        await _prefetchLists();
    }
  }

  Future<void> _prefetchLists() async {
    await Future.wait([
      loadUsers(silent: true),
      loadAssessments(silent: true),
      loadConsultations(silent: true),
    ]);
  }

  Future<void> loadDashboard({bool silent = false}) async {
    await _run(
      silent: silent,
      action: () async => dashboardRaw = await api.adminDashboard(),
    );
  }

  Future<void> loadUsers({bool silent = false}) async {
    await _run(
      silent: silent,
      action: () async {
        final response = await api.adminUsers();
        users = ApiData.list(response);
      },
    );
  }

  Future<void> loadAssessments({bool silent = false}) async {
    await _run(
      silent: silent,
      action: () async {
        final response = await api.adminAssessments();
        assessments = ApiData.list(response);
      },
    );
  }

  Future<void> loadConsultations({bool silent = false}) async {
    await _run(
      silent: silent,
      action: () async {
        final response = await api.adminConsultations();
        consultations = ApiData.list(response);
      },
    );
  }

  Future<void> sendNotification({
    required List<int> userIds,
    required String title,
    required String body,
    String type = 'ADMIN',
  }) async {
    if (userIds.isEmpty) {
      throw const WayomarkApiException(400, 'Select at least one user.');
    }
    await api.adminSendNotification(
      userIds: userIds,
      title: title,
      body: body,
      type: type,
    );
  }

  Future<void> createBankOffer({
    required String bankName,
    required double roi,
    required double emi,
    required double loanAmount,
    required int tenureMonths,
  }) async {
    await api.adminCreateBankOffer(
      bankName: bankName,
      roi: roi,
      emi: emi,
      loanAmount: loanAmount,
      tenureMonths: tenureMonths,
    );
  }

  Future<void> _run({
    required Future<void> Function() action,
    bool silent = false,
  }) async {
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }

    try {
      await action();
    } on WayomarkApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _clearSession();
        authenticated = false;
      }
      error = e.message;
    } catch (e) {
      error = e.toString();
    } finally {
      if (!silent) loading = false;
      notifyListeners();
    }
  }
}
