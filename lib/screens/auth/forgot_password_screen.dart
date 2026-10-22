import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';
import 'auth_scaffold.dart';

/// Two-step password reset matching the backend:
///   1. POST /public/phone-number-check  -> emails an OTP
///   2. POST /public/user-password-reset -> OTP + new password
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

enum _Step { phone, reset }

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _newPassword = TextEditingController();
  bool _obscure = true;

  _Step _step = _Step.phone;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _newPassword.dispose();
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

  Future<void> _requestOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    try {
      await ref
          .read(authProvider.notifier)
          .requestPasswordResetOtp(_normalizePhone(_phone.text));
      if (!mounted) return;
      setState(() => _step = _Step.reset);
      AppToast.info(context, 'We sent a code to the email on your account.');
    } on AuthException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    }
  }

  Future<void> _resetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;

    try {
      await ref.read(authProvider.notifier).resetPassword(
            phone: _normalizePhone(_phone.text),
            otp: _otp.text,
            newPassword: _newPassword.text,
          );
      if (!mounted) return;
      AppToast.success(context, 'Password reset. Please sign in.');
      context.go('/login');
    } on AuthException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;
    final isPhone = _step == _Step.phone;

    return AuthScaffold(
      title: isPhone ? 'Forgot your password?' : 'Enter the code',
      subtitle: isPhone
          ? 'Enter your phone number and we will email a reset code to the '
              'address on your account.'
          : 'Enter the code sent to your email and choose a new password.',
      onBack: () {
        if (isPhone) {
          context.go('/login');
        } else {
          setState(() => _step = _Step.phone);
        }
      },
      child: isPhone ? _buildPhoneStep(isLoading) : _buildResetStep(isLoading),
    );
  }

  Widget _buildPhoneStep(bool isLoading) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthField(
            controller: _phone,
            label: 'Phone number',
            hint: '9•• ••• •••',
            prefixText: '+251 ',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _requestOtp(),
            validator: (v) {
              final s = _normalizePhone(v ?? '');
              if (s.isEmpty) return 'Enter your phone number';
              if (!RegExp(r'^0\d{9}$').hasMatch(s)) {
                return 'Enter a valid phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Send reset code',
            loading: isLoading,
            onPressed: _requestOtp,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: isLoading ? null : () => context.go('/login'),
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    );
  }

  Widget _buildResetStep(bool isLoading) {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthField(
            controller: _otp,
            label: 'Reset code',
            hint: '6-digit code',
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Enter the reset code' : null,
          ),
          const SizedBox(height: 16),
          AuthField(
            controller: _newPassword,
            label: 'New password',
            hint: 'At least 6 characters',
            icon: Icons.lock_outline,
            obscure: _obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _resetPassword(),
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
              if (s.isEmpty) return 'Enter a new password';
              if (s.length < 6) return 'At least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Reset password',
            loading: isLoading,
            onPressed: _resetPassword,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: isLoading
                ? null
                : () => setState(() => _step = _Step.phone),
            child: const Text('Use a different phone number'),
          ),
        ],
      ),
    );
  }
}


