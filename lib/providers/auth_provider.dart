import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';

class AuthState {
  final String? token;
  final String? pid;
  final String? firstName;
  final String? lastName;
  final List<String>? roles;
  final bool isLoading;

  AuthState({this.token, this.pid, this.firstName, this.lastName, this.roles, this.isLoading = false});

  bool get isLoggedIn => token != null;
  bool get isInfluencer => roles?.contains('INFLUENCER') ?? false;
  bool get isAdmin => roles?.contains('ADMIN') ?? false;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;

  AuthNotifier(this._api) : super(AuthState()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final pid = prefs.getString('pid');
    final firstName = prefs.getString('firstName');
    if (token != null && pid != null) {
      state = AuthState(token: token, pid: pid, firstName: firstName);
    }
  }

  Future<void> login(String userName, String password) async {
    state = AuthState(isLoading: true);
    try {
      final res = await _api.login(userName, password);
      final data = res.data;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      await prefs.setString('pid', data['pid']);
      await prefs.setString('firstName', data['firstName'] ?? '');
      state = AuthState(
        token: data['token'],
        pid: data['pid'],
        firstName: data['firstName'],
        lastName: data['lastName'],
        roles: List<String>.from(data['roles'] ?? []),
      );
    } catch (e) {
      state = AuthState();
      rethrow;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = AuthState();
  }
}

final apiServiceProvider = Provider((ref) => ApiService());
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
    (ref) => AuthNotifier(ref.read(apiServiceProvider)));
