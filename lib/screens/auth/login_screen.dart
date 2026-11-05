import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/phone.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
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

  /// Normalise what the user typed to `0` + the last 9 digits. The backend
  /// only compares the last 9 digits, so +251 / 251 / 0 / bare input all work.
  static String normalizePhone(String raw) => Phone.normalize(raw) ?? raw.trim();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Phone number only. Admins sign in with their phone number too.
    final phone = normalizePhone(_identifier.text);
    try {
      await ref.read(authProvider.notifier).login(phone, _password.text);
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
              label: 'Phone number',
              hint: '0912345678',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: Phone.validate,
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
            AuthButton(
              label: 'Sign in',
              loading: isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: 12),
            AuthButton(
              label: 'Create an account',
              secondary: true,
              onPressed: isLoading ? null : () => context.push('/register'),
            ),
          ],
        ),
      ),
    );
  }
}
