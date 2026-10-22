import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Reusable bottom toast (SnackBar) helpers so screens show feedback the same
/// way everywhere instead of inline banners.
class AppToast {
  AppToast._();

  static void error(BuildContext context, String message) =>
      _show(context, message,
          bg: const Color(0xFFB91C1C), icon: Icons.error_outline);

  static void success(BuildContext context, String message) =>
      _show(context, message,
          bg: AppColors.primary, icon: Icons.check_circle_outline);

  static void info(BuildContext context, String message) =>
      _show(context, message,
          bg: AppColors.neutral900, icon: Icons.info_outline);

  static void _show(
    BuildContext context,
    String message, {
    required Color bg,
    required IconData icon,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        elevation: 6,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
