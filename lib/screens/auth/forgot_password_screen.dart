import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

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
  String? _error;
  String? _info;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    setState(() {
      _error = null;
      _info = null;
    });
    if (!_phoneFormKey.currentState!.validate()) return;

    try {
      await ref.read(authProvider.notifier).requestPasswordResetOtp(
            _phone.text,
          );
      if (!mounted) return;
      setState(() {
        _step = _Step.reset;
        _info = 'We sent a code to the email on your account.';
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _resetPassword() async {
    setState(() {
      _error = null;
      _info = null;
    });
    if (!_resetFormKey.currentState!.validate()) return;

    try {
      await ref.read(authProvider.notifier).resetPassword(
            phone: _phone.text,
            otp: _otp.text,
            newPassword: _newPassword.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset. Please sign in.'),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _step == _Step.phone
                  ? _buildPhoneStep(isLoading)
                  : _buildResetStep(isLoading),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep(bool isLoading) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Forgot your password?',
            style: TextStyle(
              color: AppColors.neutral900,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter your phone number and we will email a reset code to the '
            'address on your account.',
            style: TextStyle(
              color: AppColors.neutral500,
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          if (_error != null) _Banner.error(_error!),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _requestOtp(),
            decoration: const InputDecoration(
              labelText: 'Phone number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return 'Enter your phone number';
              if (s.length < 10) return 'Enter a valid phone number';
              return null;
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: isLoading ? null : _requestOtp,
            child: isLoading
                ? const _Spinner()
                : const Text('Send reset code'),
          ),
          const SizedBox(height: 12),
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
          const Text(
            'Enter the code',
            style: TextStyle(
              color: AppColors.neutral900,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter the code sent to your email and choose a new password for '
            '${_phone.text.trim()}.',
            style: const TextStyle(
              color: AppColors.neutral500,
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          if (_error != null) _Banner.error(_error!),
          if (_info != null) _Banner.info(_info!),
          TextFormField(
            controller: _otp,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Reset code',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return 'Enter the reset code';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _newPassword,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _resetPassword(),
            decoration: InputDecoration(
              labelText: 'New password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) {
              final s = v ?? '';
              if (s.isEmpty) return 'Enter a new password';
              if (s.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: isLoading ? null : _resetPassword,
            child:
                isLoading ? const _Spinner() : const Text('Reset password'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: isLoading
                ? null
                : () => setState(() {
                      _step = _Step.phone;
                      _error = null;
                      _info = null;
                    }),
            child: const Text('Use a different phone number'),
          ),
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
}

class _Banner extends StatelessWidget {
  const _Banner._({
    required this.message,
    required this.bg,
    required this.border,
    required this.fg,
    required this.icon,
  });

  factory _Banner.error(String message) => _Banner._(
        message: message,
        bg: const Color(0xFFFEF2F2),
        border: const Color(0xFFFECACA),
        fg: const Color(0xFFB91C1C),
        icon: Icons.error_outline,
      );

  factory _Banner.info(String message) => _Banner._(
        message: message,
        bg: const Color(0xFFEFF6FF),
        border: const Color(0xFFBFDBFE),
        fg: const Color(0xFF1D4ED8),
        icon: Icons.info_outline,
      );

  final String message;
  final Color bg;
  final Color border;
  final Color fg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: fg, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
