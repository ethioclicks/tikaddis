import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';
import 'auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Normalise what the user typed into the stored form `0XXXXXXXXX`.
  static String normalizePhone(String raw) {
    var s = raw.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (s.startsWith('+251')) {
      s = s.substring(4);
    } else if (s.startsWith('251')) {
      s = s.substring(3);
    }
    if (s.length == 9 && !s.startsWith('0')) s = '0$s';
    return s;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final identifier = _identifier.text.trim();
    final isPhone = RegExp(r'^[+\d\s()\-]+$').hasMatch(identifier);
    try {
      await ref
          .read(authProvider.notifier)
          .login(
            isPhone ? normalizePhone(identifier) : identifier,
            _password.text,
          );
      if (!mounted) return;
      final isAdmin = ref.read(authProvider).isAdmin;
      context.go(isAdmin ? '/admin' : '/dashboard');
    } on AuthException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isLoading = auth.isLoading;

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: auth.sessionExpired
          ? 'Your session expired. Please sign in again.'
          : 'Sign in to continue to Tikaddis',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthField(
              controller: _identifier,
              label: 'Phone number or username',
              hint: '0912345678 or username',
              icon: Icons.person_outline,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              validator: (v) {
                final identifier = (v ?? '').trim();
                if (identifier.isEmpty) {
                  return 'Enter your phone number or username';
                }
                final isPhone = RegExp(r'^[+\d\s()\-]+$').hasMatch(identifier);
                if (isPhone &&
                    !RegExp(r'^0\d{9}$').hasMatch(normalizePhone(identifier))) {
                  return 'Enter a valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AuthField(
              controller: _password,
              label: 'Password',
              hint: 'Your password',
              icon: Icons.lock_outline,
              obscure: _obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              trailing: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.neutral500,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              validator: (v) =>
                  (v ?? '').isEmpty ? 'Enter your password' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isLoading
                    ? null
                    : () => context.push('/forgot-password'),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              label: 'Sign in',
              loading: isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Don't have an account? ",
                  style: TextStyle(color: AppColors.neutral500),
                ),
                GestureDetector(
                  onTap: isLoading ? null : () => context.push('/register'),
                  child: const Text(
                    'Create one',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
