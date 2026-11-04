import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_toast.dart';
import 'theme.dart';

/// Parses [raw] into an openable web address, or null when it is empty or
/// not an http(s) link with a host. Bare addresses such as `t.me/channel`
/// are treated as https.
Uri? linkUri(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return null;
  final withScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(value)
      ? value
      : 'https://$value';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return uri;
}

/// Opens [raw] in the platform app (Telegram, YouTube, ...) or the browser.
/// Shows a toast instead of failing silently when it cannot be opened.
Future<void> openLink(BuildContext context, String? raw) async {
  final uri = linkUri(raw);
  if (uri == null) {
    AppToast.error(context, 'This link is not valid.');
    return;
  }
  bool opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    AppToast.error(context, 'Could not open the link.');
  }
}

/// A tappable link. Renders plain text when [url] is not a valid link, so a
/// broken address never pretends to be clickable.
class LinkText extends StatelessWidget {
  const LinkText({
    super.key,
    required this.url,
    this.label,
    this.maxLines = 1,
    this.style,
  });

  final String? url;

  /// Text to show; defaults to the URL itself.
  final String? label;
  final int maxLines;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final text = label ?? (url ?? '');
    final valid = linkUri(url) != null;
    final base = style ?? const TextStyle(fontSize: 14);
    final child = Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: valid
          ? base.copyWith(
              color: AppColors.primary,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.primary,
            )
          : base,
    );
    if (!valid) return child;
    return Semantics(
      link: true,
      child: InkWell(
        onTap: () => openLink(context, url),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: child,
        ),
      ),
    );
  }
}
