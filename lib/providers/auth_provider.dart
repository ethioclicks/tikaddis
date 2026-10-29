import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';
import '../core/session_token.dart';

/// Immutable auth state mirroring the backend TokenPayLoad.
class AuthState {
  final String? token;
  final String? pid;
  final String? firstName;
  final String? lastName;
  final String? email;
  final List<String> roles;
  final bool isLoading;

  /// True once startup state (token + onboarding flag) has been restored
  /// from storage. Until then the app shows the splash.
  final bool initialized;

  /// Whether the first-launch walkthrough has already been seen.
  final bool seenOnboarding;
  final bool sessionExpired;

  const AuthState({
    this.token,
    this.pid,
    this.firstName,
    this.lastName,
    this.email,
    this.roles = const [],
    this.isLoading = false,
    this.initialized = false,
    this.seenOnboarding = false,
    this.sessionExpired = false,
  });

  bool get isLoggedIn => token != null;
  bool get isInfluencer => roles.contains('INFLUENCER');
  bool get isAdmin => roles.contains('ADMIN');

  String get displayName =>
      [firstName, lastName].where((e) => (e ?? '').isNotEmpty).join(' ').trim();

  AuthState copyWith({
    String? token,
    String? pid,
    String? firstName,
    String? lastName,
    String? email,
    List<String>? roles,
    bool? isLoading,
    bool? initialized,
    bool? seenOnboarding,
    bool? sessionExpired,
  }) {
    return AuthState(
      token: token ?? this.token,
      pid: pid ?? this.pid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      roles: roles ?? this.roles,
      isLoading: isLoading ?? this.isLoading,
      initialized: initialized ?? this.initialized,
      seenOnboarding: seenOnboarding ?? this.seenOnboarding,
      sessionExpired: sessionExpired ?? this.sessionExpired,
    );
  }
}

/// Thrown for auth failures with a user-friendly message. For registration
/// validation (HTTP 406) the backend returns a field -> message map, surfaced
/// here as [fieldErrors].
class AuthException implements Exception {
  final String message;
  final Map<String, String> fieldErrors;
  AuthException(this.message, {this.fieldErrors = const {}});

  @override
  String toString() => message;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;
  int _authGeneration = 0;

  AuthNotifier(this._api) : super(const AuthState()) {
    _loadFromStorage();
  }

  static const _kToken = 'token';
  static const _kPid = 'pid';
  static const _kFirst = 'firstName';
  static const _kLast = 'lastName';
  static const _kEmail = 'email';
  static const _kRoles = 'roles';

  static const _kOnboarding = 'hasSeenOnboarding';

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    final pid = prefs.getString(_kPid);
    final seenOnboarding = prefs.getBool(_kOnboarding) ?? false;

    if (token != null && token.isNotEmpty && pid != null && pid.isNotEmpty) {
      state = AuthState(
        token: token,
        pid: pid,
        firstName: prefs.getString(_kFirst),
        lastName: prefs.getString(_kLast),
        email: prefs.getString(_kEmail),
        roles: prefs.getStringList(_kRoles) ?? const [],
        initialized: true,
        seenOnboarding: seenOnboarding,
      );
      unawaited(_api.renewSession());
    } else {
      state = AuthState(initialized: true, seenOnboarding: seenOnboarding);
    }
  }

  /// Marks the first-launch walkthrough as completed.
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboarding, true);
    state = state.copyWith(seenOnboarding: true);
  }

  Future<void> _persist(AuthState s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPid, s.pid ?? '');
    await prefs.setString(_kFirst, s.firstName ?? '');
    await prefs.setString(_kLast, s.lastName ?? '');
    await prefs.setString(_kEmail, s.email ?? '');
    await prefs.setStringList(_kRoles, s.roles);
  }

  /// Reconcile the cached roles with the authoritative roles from the server
  /// (e.g. GET /user). Keeps the UI in sync when the role changed server-side
  /// since login (such as applying to become an influencer). No-op if equal.
  Future<void> syncRoles(List<String> serverRoles) async {
    if (!state.isLoggedIn) return;
    final current = state.roles;
    final same =
        current.length == serverRoles.length &&
        current.toSet().containsAll(serverRoles);
    if (same || serverRoles.isEmpty) return;
    final next = state.copyWith(roles: serverRoles);
    final prefs = await SharedPreferences.getInstance();
    if (state.token != next.token || prefs.getString(_kToken) != next.token) {
      return;
    }
    await prefs.setStringList(_kRoles, serverRoles);
    if (state.token == next.token) state = next;
  }

  void requireVerification() {
    if (mounted && state.isLoggedIn) {
      state = state.copyWith(sessionExpired: true);
    }
  }

  void acceptRenewedSession(Map<String, dynamic> data) {
    if (!mounted || !state.isLoggedIn || data['pid'] != state.pid) return;
    state = state.copyWith(
      token: data['token'] as String,
      roles: (data['roles'] as List?)?.map((r) => r.toString()).toList(),
      sessionExpired: false,
    );
  }

  Future<void> verifyAccount(String password) async {
    final old = state;
    if (old.token == null) return;
    // Subject is only a login hint; the backend verifies the password and owner.
    final username = sessionUsername(old.token!);
    if (username == null) {
      throw AuthException('Sign out and sign in to verify this account.');
    }
    try {
      final response = await _api.login(username, password);
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['pid'] != old.pid || state.token != old.token) return;
      await _api.storeSession(
        data['token'] as String,
        refreshToken: data['refreshToken'] as String?,
      );
      if (state.token == old.token) acceptRenewedSession(data);
    } on DioException catch (error) {
      throw AuthException(_loginErrorMessage(error));
    }
  }

  Future<void> login(String userName, String password) async {
    final generation = ++_authGeneration;
    final previous = state;
    state = state.copyWith(isLoading: true);
    final seen = state.seenOnboarding;
    try {
      final res = await _api.login(userName.trim(), password);
      if (generation != _authGeneration) return;
      final data = res.data as Map<String, dynamic>;
      final next = AuthState(
        token: data['token'] as String?,
        pid: data['pid'] as String?,
        firstName: data['firstName'] as String?,
        lastName: data['lastName'] as String?,
        email: data['email'] as String?,
        roles:
            (data['roles'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        initialized: true,
        seenOnboarding: seen,
      );
      await _api.storeSession(
        next.token!,
        refreshToken: data['refreshToken'] as String?,
      );
      if (generation != _authGeneration) return;
      await _persist(next);
      if (generation == _authGeneration) state = next;
    } on DioException catch (e) {
      if (generation != _authGeneration) return;
      state = previous.copyWith(isLoading: false, initialized: true);
      throw AuthException(_loginErrorMessage(e));
    } catch (_) {
      if (generation != _authGeneration) return;
      state = previous.copyWith(isLoading: false, initialized: true);
      throw AuthException('Something went wrong. Please try again.');
    }
  }

  /// Registers a new user. On success the user is NOT auto-logged-in (the
  /// backend returns the created profile, not a token), so callers should
  /// send the user to the login screen.
  Future<void> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    String? email,
    required String city,
    required String street,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _api.register({
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'userName': phone.trim(),
        'userPassword': password,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        'address': {'city': city.trim(), 'street': street.trim()},
      });
      state = state.copyWith(isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false);
      // 406 => validation map {field: message}
      final data = e.response?.data;
      if (e.response?.statusCode == 406 && data is Map) {
        final fieldErrors = data.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
        throw AuthException(
          fieldErrors.values.isNotEmpty
              ? fieldErrors.values.first
              : 'Please check the form and try again.',
          fieldErrors: fieldErrors,
        );
      }
      throw AuthException(_genericNetworkMessage(e));
    } catch (_) {
      state = state.copyWith(isLoading: false);
      throw AuthException('Something went wrong. Please try again.');
    }
  }

  Future<void> refreshAccountRoles() async {
    final token = state.token;
    final pid = state.pid;
    if (token == null || pid == null) return;
    try {
      final response = await _api.getProfile(pid);
      if (state.token != token || state.pid != pid) return;
      final raw = response.data is Map ? response.data['roles'] : null;
      if (raw is! List || raw.isEmpty) return;
      final roles = raw
          .map((r) => r is Map ? r['name'].toString() : r.toString())
          .toList();
      if (roles.any(
        (r) => !const {
          'USER',
          'CANDIDATE',
          'INFLUENCER',
          'ADMIN',
          'SUPER_ADMIN',
          'AGENT',
        }.contains(r),
      )) {
        return;
      }
      final next = state.copyWith(roles: roles);
      final prefs = await SharedPreferences.getInstance();
      if (state.token != token ||
          state.pid != pid ||
          prefs.getString(_kToken) != token) {
        return;
      }
      // Updating roles must never rewrite an old token during a concurrent logout.
      await prefs.setStringList(_kRoles, roles);
      if (state.token == token && state.pid == pid) state = next;
    } catch (_) {
      /* A later profile refresh can retry; keep the active session. */
    }
  }

  Future<void> logout({bool sessionExpired = false}) async {
    ++_authGeneration;
    final clearing = _api.clearSession();
    // Intentional sign-out changes UI immediately, even when the network is down.
    final seenBefore = state.seenOnboarding;
    state = AuthState(initialized: true, seenOnboarding: seenBefore);
    await clearing;
    // Do not overwrite a newer login after waiting for network revocation.
  }

  /// Step 1 of password reset: verify the phone exists and trigger an OTP
  /// email. Backend: POST /public/phone-number-check (UserResetModel).
  ///   200 -> OTP sent
  ///   404 -> user not found
  ///   429 -> too many OTP requests
  Future<void> requestPasswordResetOtp(String phone) async {
    state = state.copyWith(isLoading: true);
    try {
      await _api.checkPhoneNumber(phone.trim());
      state = state.copyWith(isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false);
      final code = e.response?.statusCode;
      if (code == 404) {
        throw AuthException('No account found with that phone number.');
      }
      if (code == 429) {
        throw AuthException(
          'Too many requests. Please wait a bit and try again.',
        );
      }
      throw AuthException(_resetErrorMessage(e));
    } catch (_) {
      state = state.copyWith(isLoading: false);
      throw AuthException('Something went wrong. Please try again.');
    }
  }

  /// Step 2 of password reset: submit OTP + new password.
  /// Backend: POST /public/user-password-reset (UserResetModel).
  ///   200 -> "Reset Success"
  ///   400 -> bad request (e.g. wrong/expired OTP)
  Future<void> resetPassword({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _api.resetPassword(phone.trim(), otp.trim(), newPassword);
      state = state.copyWith(isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false);
      if (e.response?.statusCode == 400) {
        final data = e.response?.data;
        throw AuthException(
          data is String && data.isNotEmpty
              ? data
              : 'The code is incorrect or has expired. Please try again.',
        );
      }
      throw AuthException(_resetErrorMessage(e));
    } catch (_) {
      state = state.copyWith(isLoading: false);
      throw AuthException('Something went wrong. Please try again.');
    }
  }

  /// Request the influencer role. Backend: POST /user/become-influencer
  ///   200 -> "Role updated to Candidate"
  ///   404 -> "You can't apply for influncer position"
  /// Returns the server's message on success.
  Future<String> becomeInfluencer() async {
    final generation = _authGeneration;
    final pid = state.pid;
    if (pid == null) {
      throw AuthException('Your session expired. Please sign in again.');
    }
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.becomeInfluencer(pid);
      if (generation != _authGeneration || state.pid != pid) {
        return 'Request submitted.';
      }
      // Reflect the new pending state locally so the UI stops offering "Apply
      // now" and shows the pending state instead. Backend moved USER -> CANDIDATE.
      final next = state.copyWith(isLoading: false, roles: const ['CANDIDATE']);
      await _persist(next);
      if (generation == _authGeneration && state.pid == pid) state = next;
      return res.data?.toString() ?? 'Request submitted.';
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false);
      if (e.response?.statusCode == 404) {
        final data = e.response?.data;
        throw AuthException(
          data is String && data.isNotEmpty
              ? data
              : "You can't apply to become an influencer right now.",
        );
      }
      throw AuthException(_genericNetworkMessage(e));
    } catch (_) {
      state = state.copyWith(isLoading: false);
      throw AuthException('Something went wrong. Please try again.');
    }
  }

  String _resetErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is String && data.isNotEmpty) return data;
    return _genericNetworkMessage(e);
  }

  String _loginErrorMessage(DioException e) {
    // Connection problems get the network message; everything else on the
    // login call is treated as bad credentials with a clean, friendly line.
    // (The backend returns its own raw "Generic exception..." string with a
    // non-401 code, so we never surface that directly.)
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Can\'t reach the server. Check your connection and try again.';
    }
    return 'Phone number or password is not correct.';
  }

  String _genericNetworkMessage(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Can\'t reach the server. Check your connection and try again.';
    }
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return 'Something went wrong. Please try again.';
  }
}

final Provider<ApiService> apiServiceProvider = Provider<ApiService>(
  (ref) => ApiService(
    onSessionExpired: () => Future.sync(
      () => ref.read(authProvider.notifier).requireVerification(),
    ),
    onSessionRenewed: (data) =>
        ref.read(authProvider.notifier).acceptRenewedSession(data),
  ),
);
final StateNotifierProvider<AuthNotifier, AuthState> authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>(
      (ref) => AuthNotifier(ref.read(apiServiceProvider)),
    );
