import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'app_image.dart';

const Color _ink = Color(0xFF111111);

/// One highlight figure in a [CreatorProfileCard] (e.g. an icon, "9K", "Top post").
class ProfileStat {
  const ProfileStat(this.value, this.label, {this.icon});
  final String value;
  final String label;
  final IconData? icon;
}

/// One small tag in a [CreatorProfileCard] (a platform, a category, ...).
class ProfileChip {
  const ProfileChip(this.label, {this.leading});
  final String label;
  final Widget? leading;
}

/// Visual style of a [CreatorProfileCard].
enum CreatorCardStyle {
  /// White card with an inset gradient cover (how visitors see a creator).
  light,

  /// The whole card is the brand gradient (the creator's own Home).
  gradient,
}

/// A profile card: gradient cover, a photo that overlaps it, name and headline
/// with a pill action, tags, an icon stats row, an "About" section, a photo
/// strip, and an optional big call-to-action pill.
///
/// Used for the creator's own Home (with [onEdit]) and for visitors viewing a
/// channel (read-only, no [onEdit]).
class CreatorProfileCard extends StatefulWidget {
  const CreatorProfileCard({
    super.key,
    required this.name,
    this.headline,
    this.biography,
    this.avatarUrl,
    this.gallery = const [],
    this.stats = const [],
    this.chips = const [],
    this.badge,
    this.onEdit,
    this.emptyHint,
    this.style = CreatorCardStyle.light,
    this.ctaLabel,
    this.onCta,
  });

  final String name;
  final String? headline;
  final String? biography;
  final String? avatarUrl;
  final List<String> gallery;

  /// Highlight numbers shown in a row under a divider (up to 3 look best).
  final List<ProfileStat> stats;

  /// Small tags under the name block (e.g. the platforms the creator is on).
  final List<ProfileChip> chips;

  /// Status chip under the headline (e.g. "Pending approval").
  final Widget? badge;

  /// When set, shows an "Edit profile" pill (the owner's own view).
  final VoidCallback? onEdit;

  /// Shown instead of the bio when the owner has not written one yet.
  final String? emptyHint;

  final CreatorCardStyle style;

  /// Label and action of the big pill at the bottom. Both must be set.
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  State<CreatorProfileCard> createState() => _CreatorProfileCardState();
}

class _Palette {
  const _Palette({
    required this.title,
    required this.sub,
    required this.body,
    required this.divider,
    required this.chipBg,
    required this.chipFg,
    required this.statIcon,
  });

  final Color title;
  final Color sub;
  final Color body;
  final Color divider;
  final Color chipBg;
  final Color chipFg;
  final Color statIcon;

  static const light = _Palette(
    title: _ink,
    sub: AppColors.neutral600,
    body: AppColors.neutral700,
    divider: AppColors.neutral200,
    chipBg: AppColors.neutral100,
    chipFg: AppColors.neutral700,
    statIcon: _ink,
  );

  static final gradient = _Palette(
    title: Colors.white,
    sub: Colors.white.withValues(alpha: 0.86),
    body: Colors.white.withValues(alpha: 0.92),
    divider: Colors.white.withValues(alpha: 0.28),
    chipBg: Colors.white.withValues(alpha: 0.95),
    chipFg: _ink,
    statIcon: Colors.white,
  );
}

class _CreatorProfileCardState extends State<CreatorProfileCard> {
  static const double _avatar = 78;
  bool _expanded = false;

  bool get _onGradient => widget.style == CreatorCardStyle.gradient;
  _Palette get _p => _onGradient ? _Palette.gradient : _Palette.light;

  @override
  Widget build(BuildContext context) {
    final bio = (widget.biography ?? '').trim();
    final longBio = bio.length > 140;
    final hasCta = widget.ctaLabel != null && widget.onCta != null;

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.chips.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in widget.chips)
                _Chip(chip: c, bg: _p.chipBg, fg: _p.chipFg),
            ],
          ),
        ],
        if (widget.stats.isNotEmpty) ...[
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: _p.divider),
          const SizedBox(height: 12),
          _StatsRow(stats: widget.stats, palette: _p),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: _p.divider),
        ],
        const SizedBox(height: 14),
        Text(
          'About',
          style: TextStyle(
            color: _p.title,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        if (bio.isEmpty)
          Text(
            widget.emptyHint ?? 'No biography yet.',
            style: TextStyle(color: _p.sub, fontSize: 14, height: 1.45),
          )
        else ...[
          Text(
            bio,
            maxLines: _expanded || !longBio ? null : 4,
            overflow: _expanded || !longBio
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            style: TextStyle(color: _p.body, fontSize: 14, height: 1.55),
          ),
          if (longBio)
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: _onGradient ? Colors.white : AppColors.primary,
              ),
              child: Text(
                _expanded ? 'See less' : 'See more',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
        if (widget.gallery.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Photos',
            style: TextStyle(
              color: _p.title,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.gallery.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => Semantics(
                button: true,
                label: 'Open photo ${i + 1} of ${widget.gallery.length}',
                child: GestureDetector(
                  onTap: () => showGalleryViewer(context, widget.gallery, i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 88,
                      height: 88,
                      child: AppImage(widget.gallery[i]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        if (hasCta) ...[
          const SizedBox(height: 18),
          _CtaPill(
            label: widget.ctaLabel!,
            onTap: widget.onCta!,
            onGradient: _onGradient,
          ),
        ],
      ],
    );

    final nameBlock = _NameBlock(
      name: widget.name,
      headline: (widget.headline ?? '').trim(),
      badge: widget.badge,
      palette: _p,
    );
    final editButton = widget.onEdit == null
        ? null
        : _EditButton(onPressed: widget.onEdit!, onGradient: _onGradient);

    if (_onGradient) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            const Positioned.fill(child: _Mesh()),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo and name side by side: no empty row of space.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Avatar(
                        url: widget.avatarUrl,
                        name: widget.name,
                        size: _avatar,
                        ringColor: Colors.white,
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: nameBlock),
                      if (editButton != null) ...[
                        const SizedBox(width: 8),
                        editButton,
                      ],
                    ],
                  ),
                  details,
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Light: white card with an inset cover the photo overlaps.
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryHover.withValues(alpha: 0.10),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 112,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(22)),
                    child: _Mesh(),
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: -_avatar / 2,
                  child: Avatar(
                    url: widget.avatarUrl,
                    name: widget.name,
                    size: _avatar,
                    ringColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // The name sits beside the half of the photo that hangs below the
          // cover, instead of under it.
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: _avatar + 22),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: _avatar / 2 + 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: nameBlock),
                        if (editButton != null) ...[
                          const SizedBox(width: 8),
                          editButton,
                        ],
                      ],
                    ),
                  ),
                ),
                details,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft "mesh" gradient: brand blue with glowing blobs of light and amber.
/// Fills whatever space it is given.
class _Mesh extends StatelessWidget {
  const _Mesh();

  Widget _blob(Color c, double size, {double? left, double? top, double? right, double? bottom}) =>
      Positioned(
        left: left,
        top: top,
        right: right,
        bottom: bottom,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryHover,
                  AppColors.primary,
                  AppColors.primaryLight,
                ],
              ),
            ),
          ),
        ),
        _blob(AppColors.primaryLight.withValues(alpha: 0.9), 220, left: -60, top: -80),
        _blob(AppColors.accentLight.withValues(alpha: 0.55), 200, right: -70, bottom: -90),
        _blob(const Color(0xFF7DD3FC).withValues(alpha: 0.5), 150, right: 30, top: -60),
      ],
    );
  }
}

class _NameBlock extends StatelessWidget {
  const _NameBlock({
    required this.name,
    required this.headline,
    required this.badge,
    required this.palette,
  });

  final String name;
  final String headline;
  final Widget? badge;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name.isEmpty ? 'Creator' : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.title,
            fontSize: 22,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
        ),
        if (headline.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              headline,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.sub, fontSize: 14, height: 1.3),
            ),
          ),
        if (badge != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: badge!,
          ),
      ],
    );
  }
}

/// Round icon button for editing the profile (outlined white on the gradient,
/// solid black on white), like the reference's round bookmark button.
class _EditButton extends StatelessWidget {
  const _EditButton({required this.onPressed, required this.onGradient});
  final VoidCallback onPressed;
  final bool onGradient;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Edit profile',
      onPressed: onPressed,
      icon: const Icon(Icons.edit_outlined),
      iconSize: 19,
      style: IconButton.styleFrom(
        fixedSize: const Size(40, 40),
        foregroundColor: Colors.white,
        backgroundColor: onGradient ? Colors.white.withValues(alpha: 0.18) : _ink,
        side: onGradient
            ? const BorderSide(color: Colors.white, width: 1.4)
            : BorderSide.none,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.chip, required this.bg, required this.fg});
  final ProfileChip chip;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (chip.leading != null) ...[chip.leading!, const SizedBox(width: 6)],
        Flexible(
          child: Text(
            chip.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

/// Icon + value over a small label, evenly spread (like Rating / Posts / Followers).
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.palette});
  final List<ProfileStat> stats;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final s in stats)
          Expanded(
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.icon != null) ...[
                        Icon(s.icon, size: 18, color: palette.statIcon),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        s.value,
                        style: TextStyle(
                          color: palette.title,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.sub, fontSize: 12.5),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The big pill at the bottom ("Get in Touch" in the reference): a circle with
/// an arrow on the left and a centered label.
class _CtaPill extends StatelessWidget {
  const _CtaPill({
    required this.label,
    required this.onTap,
    required this.onGradient,
  });
  final String label;
  final VoidCallback onTap;
  final bool onGradient;

  @override
  Widget build(BuildContext context) {
    final bg = onGradient ? Colors.white : _ink;
    final fg = onGradient ? _ink : Colors.white;
    final circle = onGradient ? _ink : Colors.white;
    final arrow = onGradient ? Colors.white : _ink;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: onGradient ? bg : null,
            // Light style fades from black to grey on the right, like the reference.
            gradient: onGradient
                ? null
                : const LinearGradient(
                    colors: [_ink, _ink, Color(0xFF5A5A5A)],
                    stops: [0, 0.6, 1],
                  ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Row(
              children: [
                const SizedBox(width: 9),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: circle, shape: BoxShape.circle),
                  child: Icon(Icons.arrow_forward_rounded, color: arrow, size: 22),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 49),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen, swipeable, pinch-to-zoom photo viewer.
Future<void> showGalleryViewer(
  BuildContext context,
  List<String> images,
  int initial,
) {
  final controller = PageController(initialPage: initial);
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    builder: (ctx) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: controller,
            itemCount: images.length,
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: AppImage(
                  images[i],
                  fit: BoxFit.contain,
                  semanticLabel: 'Photo ${i + 1} of ${images.length}',
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
