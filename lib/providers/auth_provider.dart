import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';

/// Immutable auth state mirroring the backend TokenPayLoad.
class AuthState {
  final String? token;
  final String? pid;
  final String? firstName;
  final String? lastName;
  final String? email;
  final List<String> roles;
  final bool isLoading;

  const AuthState({
    this.token,
    this.pid,
    this.firstName,
    this.lastName,
    this.email,
    this.roles = const [],
    this.isLoading = false,
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
  }) {
    return AuthState(
      token: token ?? this.token,
      pid: pid ?? this.pid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      roles: roles ?? this.roles,
      isLoading: isLoading ?? this.isLoading,
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

  AuthNotifier(this._api) : super(const AuthState()) {
    _loadFromStorage();
  }

  static const _kToken = 'token';
  static const _kPid = 'pid';
  static const _kFirst = 'firstName';
  static const _kLast = 'lastName';
  static const _kEmail = 'email';
  static const _kRoles = 'roles';

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    final pid = prefs.getString(_kPid);
    if (token != null && pid != null) {
      state = AuthState(
        token: token,
        pid: pid,
        firstName: prefs.getString(_kFirst),
        lastName: prefs.getString(_kLast),
        email: prefs.getString(_kEmail),
        roles: prefs.getStringList(_kRoles) ?? const [],
      );
    }
  }

  Future<void> _persist(AuthState s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, s.token ?? '');
    await prefs.setString(_kPid, s.pid ?? '');
    await prefs.setString(_kFirst, s.firstName ?? '');
    await prefs.setString(_kLast, s.lastName ?? '');
    await prefs.setString(_kEmail, s.email ?? '');
    await prefs.setStringList(_kRoles, s.roles);
  }

  Future<void> login(String userName, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.login(userName.trim(), password);
      final data = res.data as Map<String, dynamic>;
      final next = AuthState(
        token: data['token'] as String?,
        pid: data['pid'] as String?,
        firstName: data['firstName'] as String?,
        lastName: data['lastName'] as String?,
        email: data['email'] as String?,
        roles: (data['roles'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
      );
      await _persist(next);
      state = next;
    } on DioException catch (e) {
      state = const AuthState();
      throw AuthException(_loginErrorMessage(e));
    } catch (_) {
      state = const AuthState();
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
        'address': {
          'city': city.trim(),
          'street': street.trim(),
        },
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

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = const AuthState();
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
            'Too many requests. Please wait a bit and try again.');
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

  String _resetErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is String && data.isNotEmpty) return data;
    return _genericNetworkMessage(e);
  }

  String _loginErrorMessage(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) {
      return 'Phone number or password is not correct.';
    }
    return _genericNetworkMessage(e);
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

final apiServiceProvider = Provider((ref) => ApiService());
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
    (ref) => AuthNotifier(ref.read(apiServiceProvider)));
