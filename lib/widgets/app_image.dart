import 'package:flutter/material.dart';

import '../core/api_service.dart';
import '../core/theme.dart';

/// Turns an image reference from the API into a loadable absolute URL.
/// Uploaded images come back as a path (`/public/images/<id>`); older or
/// external ones are already full http(s) links and are returned unchanged.
String? mediaUrl(String? ref) {
  final value = (ref ?? '').trim();
  if (value.isEmpty) return null;
  if (value.startsWith('/')) return '${ApiService.baseUrl}$value';
  return value;
}

/// A network image that never throws on a bad or missing URL: it shows
/// [fallback] (or a neutral placeholder) instead.
class AppImage extends StatelessWidget {
  const AppImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.fallback,
    this.semanticLabel,
  });

  final String? url;
  final BoxFit fit;
  final Widget? fallback;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final resolved = mediaUrl(url);
    final placeholder =
        fallback ??
        const ColoredBox(
          color: AppColors.neutral100,
          child: Center(
            child: Icon(Icons.image_outlined, color: AppColors.neutral300),
          ),
        );
    if (resolved == null) return placeholder;
    return Image.network(
      resolved,
      fit: fit,
      semanticLabel: semanticLabel,
      errorBuilder: (context, error, stack) => placeholder,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
    );
  }
}

/// A circular profile photo with an initials fallback.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    this.url,
    required this.name,
    this.size = 64,
    this.ringColor,
  });

  final String? url;
  final String name;
  final double size;

  /// Optional outline (e.g. white on a gradient).
  final Color? ringColor;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? 'U' : letters;
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      // Solid (not translucent) so the initials stay readable on any background.
      color: const Color(0xFFE3EFFF),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Semantics(
      label: name.isEmpty ? 'Profile photo' : 'Profile photo of $name',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: ringColor == null
                ? null
                : Border.all(color: ringColor!, width: 3),
          ),
          child: ClipOval(child: AppImage(url, fallback: fallback)),
        ),
      ),
    );
  }
}
