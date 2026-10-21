import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/dots_loading.dart';
import 'auth_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _city = TextEditingController();
  final _street = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _city.dispose();
    _street.dispose();
    _password.dispose();
    super.dispose();
  }

  static String _normalizePhone(String raw) {
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
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    try {
      await ref.read(authProvider.notifier).register(
            firstName: _firstName.text,
            lastName: _lastName.text,
            phone: _normalizePhone(_phone.text),
            password: _password.text,
            email: _email.text,
            city: _city.text,
            street: _street.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created. Please sign in.'),
          backgroundColor: AppColors.primary,
        ),
      );
      context.go('/login');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;

    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Join Tikaddis to request promotions or list your channels.',
      onBack: () => context.go('/login'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              AuthErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AuthField(
                    controller: _firstName,
                    label: 'First name',
                    hint: 'First',
                    icon: Icons.person_outline,
                    textInputAction: TextInputAction.next,
                    validator: _nameValidator,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AuthField(
                    controller: _lastName,
                    label: 'Last name',
                    hint: 'Last',
                    icon: Icons.person_outline,
                    textInputAction: TextInputAction.next,
                    validator: _nameValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AuthField(
              controller: _phone,
              label: 'Phone number',
              hint: '9•• ••• •••',
              prefixText: '+251 ',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: (v) {
                final s = _normalizePhone(v ?? '');
                if (s.isEmpty) return 'Phone is required';
                if (!RegExp(r'^0\d{9}$').hasMatch(s)) {
                  return 'Enter a valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AuthField(
              controller: _email,
              label: 'Email (optional)',
              hint: 'you@example.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return null;
                final ok =
                    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
                return ok ? null : 'Enter a valid email';
              },
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AuthField(
                    controller: _city,
                    label: 'City',
                    hint: 'Addis Ababa',
                    icon: Icons.location_city_outlined,
                    textInputAction: TextInputAction.next,
                    validator: _requiredValidator('Required'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AuthField(
                    controller: _street,
                    label: 'Street',
                    hint: 'Bole',
                    icon: Icons.signpost_outlined,
                    textInputAction: TextInputAction.next,
                    validator: _requiredValidator('Required'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AuthField(
              controller: _password,
              label: 'Password',
              hint: 'At least 6 characters',
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
              validator: (v) {
                final s = v ?? '';
                if (s.isEmpty) return 'Password is required';
                if (s.length < 6) return 'At least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const DotsLoading()
                    : const Text('Create account'),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Already have an account? ',
                    style: TextStyle(color: AppColors.neutral500)),
                GestureDetector(
                  onTap: isLoading ? null : () => context.go('/login'),
                  child: const Text(
                    'Sign in',
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

  static String? _nameValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    if (s.length < 2) return 'Too short';
    return null;
  }

  static FormFieldValidator<String> _requiredValidator(String message) {
    return (v) => (v ?? '').trim().isEmpty ? message : null;
  }
}
