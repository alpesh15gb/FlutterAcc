import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_client.dart';

enum SessionStage { loading, signedOut, twoFactor, companySelection, signedIn }

class Membership {
  Membership(
      {required this.tenantId, required this.tenantName, required this.role});
  final String tenantId;
  final String tenantName;
  final String role;

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
        tenantId: json['tenant_id'].toString(),
        tenantName: (json['tenant_name'] ?? 'Company').toString(),
        role: (json['role'] ?? 'member').toString(),
      );
}

class SessionController extends ChangeNotifier {
  SessionController({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(),
        api = ApiClient() {
    api.onTokenRotation = _persistTokens;
  }

  static const _accessKey = 'apexbooks_access_token';
  static const _refreshKey = 'apexbooks_refresh_token';
  static const _tenantKey = 'apexbooks_tenant_id';
  final FlutterSecureStorage _storage;
  final ApiClient api;

  SessionStage stage = SessionStage.loading;
  String? error;
  String? challengeToken;
  String? userName;
  String? userEmail;
  bool totpEnabled = false;
  String? tenantId;
  String? tenantName;
  List<Membership> memberships = [];

  Future<void> initialize() async {
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    tenantId = await _storage.read(key: _tenantKey);
    if (access == null || refresh == null) {
      stage = SessionStage.signedOut;
      notifyListeners();
      return;
    }
    api.configure(
        accessToken: access, refreshToken: refresh, tenantId: tenantId);
    try {
      await _loadIdentity();
      _resolveTenant();
    } catch (_) {
      await _clearSession();
      stage = SessionStage.signedOut;
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    error = null;
    notifyListeners();
    try {
      final data = await api.post('/auth/login',
          body: {'email': email.trim(), 'password': password}, tenant: false);
      if (data is Map && data['requires_2fa'] == true) {
        challengeToken = data['challenge_token']?.toString();
        stage = SessionStage.twoFactor;
        notifyListeners();
        return;
      }
      await _acceptTokens(Map<String, dynamic>.from(data as Map));
      await _loadIdentity();
      _resolveTenant();
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> verifyTwoFactor(String code) async {
    final challenge = challengeToken;
    if (challenge == null) return;
    error = null;
    try {
      final data = await api.post('/auth/2fa/challenge',
          body: {
            'challenge_token': challenge,
            'totp_code': code.trim(),
          },
          tenant: false);
      await _acceptTokens(Map<String, dynamic>.from(data as Map));
      challengeToken = null;
      await _loadIdentity();
      _resolveTenant();
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String companyName,
    String? phone,
    String? gstin,
    String? pan,
  }) async {
    error = null;
    try {
      await api.post('/auth/register', tenant: false, body: {
        'email': email.trim(),
        'password': password,
        'full_name': fullName.trim(),
        'phone_number': phone?.trim().isEmpty == true ? null : phone?.trim(),
        'company_legal_name': companyName.trim(),
        'company_gstin':
            gstin?.trim().isEmpty == true ? null : gstin?.trim().toUpperCase(),
        'company_pan':
            pan?.trim().isEmpty == true ? null : pan?.trim().toUpperCase(),
      });
      await login(email, password);
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> forgotPassword(String email) async {
    await api.post('/auth/forgot-password',
        tenant: false, body: {'email': email.trim()});
  }

  Future<void> _acceptTokens(Map<String, dynamic> data) async {
    final access = data['access_token']?.toString();
    final refresh = data['refresh_token']?.toString();
    if (access == null || refresh == null) {
      throw ApiException('Login did not return session tokens.');
    }
    api.configure(
        accessToken: access, refreshToken: refresh, tenantId: tenantId);
    await _persistTokens(access, refresh);
  }

  Future<void> _persistTokens(String access, String refresh) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> _loadIdentity() async {
    final me = Map<String, dynamic>.from(
        await api.get('/auth/me', tenant: false) as Map);
    userName = me['full_name']?.toString();
    userEmail = me['email']?.toString();
    totpEnabled = me['totp_enabled'] == true;
    final raw = await api.get('/auth/memberships', tenant: false);
    memberships = (raw as List)
        .map((e) => Membership.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  void _resolveTenant() {
    final selected = memberships.where((m) => m.tenantId == tenantId).toList();
    if (selected.isNotEmpty) {
      tenantName = selected.first.tenantName;
      api.tenantId = tenantId;
      stage = SessionStage.signedIn;
    } else if (memberships.length == 1) {
      selectCompany(memberships.first);
    } else {
      tenantId = null;
      tenantName = null;
      api.tenantId = null;
      stage = SessionStage.companySelection;
    }
  }

  Future<void> selectCompany(Membership membership) async {
    tenantId = membership.tenantId;
    tenantName = membership.tenantName;
    api.tenantId = tenantId;
    await _storage.write(key: _tenantKey, value: tenantId);
    stage = SessionStage.signedIn;
    notifyListeners();
  }

  void switchCompany() {
    stage = SessionStage.companySelection;
    notifyListeners();
  }

  void updateTotpEnabled(bool value) {
    totpEnabled = value;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      if (api.refreshToken != null) {
        await api.post('/auth/logout',
            tenant: false, body: {'refresh_token': api.refreshToken});
      }
    } catch (_) {}
    await _clearSession();
    stage = SessionStage.signedOut;
    notifyListeners();
  }

  Future<void> _clearSession() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _tenantKey);
    api.clear();
    tenantId = null;
    tenantName = null;
    memberships = [];
    userName = null;
    userEmail = null;
  }
}
