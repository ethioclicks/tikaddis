import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/dots_loading.dart';
import '../../widgets/sparkle.dart';

/// Shared shell for the auth screens (login / register / reset), matching the
/// splash and launch screens: a blue gradient header with the brand mark that
/// fades to white, then a clean white area that scrolls the form.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
    this.titleInHeader = false,
  });

  /// Show [title] in the gradient header (replacing the brand mark) instead of
  /// above the form.
  final bool titleInHeader;
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            // Gradient header that fades into the white form area.
            Container(
              height: top + 150,
              width: double.infinity,
              decoration: const BoxDecoration(gradient: AppGradients.header),
              child: Stack(
                children: [
                  if (onBack != null)
                    Positioned(
                      top: top + 4,
                      left: 4,
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                  Positioned(
                    top: top + 14,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: titleInHeader
                          ? Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 56),
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            )
                          : const BrandMark(logoHeight: 40, fontSize: 21),
                    ),
                  ),
                  Positioned(
                    top: top + 64,
                    right: 36,
                    child: const Sparkle(size: 26, color: Colors.white),
                  ),
                  Positioned(
                    top: top + 92,
                    left: 40,
                    child: const Sparkle(
                      size: 14,
                      color: AppColors.accentLight,
                    ),
                  ),
                ],
              ),
            ),

            // White form area.
            Expanded(
              child: SafeArea(
                top: false,
                // Short forms (login) sit vertically centered in the white
                // area; long forms (register) simply scroll from the top.
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 28,
                      ),
                      // Slightly above true center (-1 = top, 0 = center).
                      child: Align(
                        alignment: const Alignment(0, -0.35),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!titleInHeader) ...[
                              Text(
                                title,
                                textAlign: TextAlign.left,
                                style: const TextStyle(
                                  color: Color(0xFF111111),
                                  fontSize: 28,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (subtitle.isNotEmpty) ...[
                              Text(
                                subtitle,
                                textAlign: TextAlign.left,
                                style: const TextStyle(
                                  color: AppColors.neutral500,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 28),
                            ] else if (!titleInHeader)
                              const SizedBox(height: 28)
                            else
                              const SizedBox(height: 20),
                            child,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width action button for the auth screens, matching the launch screen:
/// a black primary pill and a soft grey secondary one.
class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.secondary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final bg = secondary ? AppColors.neutral100 : const Color(0xFF111111);
    final fg = secondary ? AppColors.neutral900 : Colors.white;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          disabledBackgroundColor: bg.withValues(alpha: 0.7),
          foregroundColor: fg,
          disabledForegroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: TextStyle(
            fontSize: 16,
            fontWeight: secondary ? FontWeight.w500 : FontWeight.w600,
          ),
        ),
        child: loading ? DotsLoading(color: fg) : Text(label),
      ),
    );
  }
}

/// A labelled, intentionally-styled text field used across the auth screens.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.prefixText,
    this.obscure = false,
    this.trailing,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? prefixText;
  final bool obscure;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.neutral700,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          maxLines: obscure ? 1 : maxLines,
          minLines: obscure ? 1 : minLines,
          maxLength: maxLength,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          style: const TextStyle(
            color: AppColors.neutral900,
            fontSize: 15.5,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.neutral500,
              fontSize: 15,
            ),
            // Leading icon + an always-visible prefix label (e.g. "+251").
            // Using prefixIcon (not prefixText) so it shows even when the
            // field is empty and unfocused.
            prefixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 14),
                Icon(icon, size: 20, color: AppColors.neutral500),
                if (prefixText != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    prefixText!.trim(),
                    style: const TextStyle(
                      color: AppColors.neutral900,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
              ],
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: trailing,
            // Soft grey fill, no outline until focused (like the launch
            // screen's secondary button).
            filled: true,
            fillColor: AppColors.neutral100,
            contentPadding:
                const EdgeInsets.only(left: 2, right: 14, top: 17, bottom: 17),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.6),
            ),
          ),
        ),
      ],
    );
  }
}

/// A styled inline error banner for the auth screens.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
