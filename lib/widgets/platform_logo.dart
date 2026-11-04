import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/format.dart';
import '../models/models.dart';

/// Real brand logo for a channel's social platform (Telegram, YouTube,
/// TikTok, Facebook, Instagram). Unknown or custom platforms fall back to a
/// globe. Always carries a semantic label for screen readers.
class PlatformLogo extends StatelessWidget {
  const PlatformLogo(this.type, {super.key, this.size = 16, this.color});

  final AccountType? type;
  final double size;

  /// Icon colour. Defaults to the platform's brand colour.
  final Color? color;

  static FaIconData iconFor(AccountType? t) {
    switch (t?.wire) {
      case 'TELEGRAM':
        return FontAwesomeIcons.telegram;
      case 'YOUTUBE':
        return FontAwesomeIcons.youtube;
      case 'TIKTOK':
        return FontAwesomeIcons.tiktok;
      case 'FACEBOOK':
        return FontAwesomeIcons.facebook;
      case 'INSTAGRAM':
        return FontAwesomeIcons.instagram;
      default:
        return FontAwesomeIcons.globe;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FaIcon(
      iconFor(type),
      size: size,
      color: color ?? Fmt.platformColor(type),
      semanticLabel: type?.label ?? 'Unknown platform',
    );
  }
}
