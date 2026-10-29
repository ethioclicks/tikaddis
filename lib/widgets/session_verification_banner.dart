import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../core/theme.dart';
import '../core/router.dart';

/// Authentication problems never replace a form or navigate away from work.
class SessionVerificationBanner extends ConsumerWidget {
  const SessionVerificationBanner({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsVerification = ref.watch(
      authProvider.select((s) => s.isLoggedIn && s.sessionExpired),
    );
    return Column(
      children: [
        if (needsVerification)
          Material(
            color: AppColors.neutral50,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Verify your account to continue. Your current screen is saved.',
                      ),
                    ),
                    TextButton(
                      onPressed: () => showDialog<void>(
                        context: rootNavigatorKey.currentContext ?? context,
                        builder: (_) => const _VerificationDialog(),
                      ),
                      child: const Text('Verify'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(key: const ValueKey('session-content'), child: child),
      ],
    );
  }
}

class _VerificationDialog extends ConsumerStatefulWidget {
  const _VerificationDialog();
  @override
  ConsumerState<_VerificationDialog> createState() =>
      _VerificationDialogState();
}

class _VerificationDialogState extends ConsumerState<_VerificationDialog> {
  final password = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> verify() async {
    if (password.text.isEmpty || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(authProvider.notifier).verifyAccount(password.text);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e is AuthException
              ? e.message
              : 'Could not verify your account. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Verify your account'),
    content: TextField(
      controller: password,
      obscureText: true,
      enabled: !busy,
      decoration: InputDecoration(labelText: 'Password', errorText: error),
      onSubmitted: (_) => verify(),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.of(context).pop(),
        child: const Text('Later'),
      ),
      FilledButton(
        onPressed: busy ? null : verify,
        child: Text(busy ? 'Verifying…' : 'Continue'),
      ),
    ],
  );
}
