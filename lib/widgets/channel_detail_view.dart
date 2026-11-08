import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/links.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'app_image.dart';
import 'platform_logo.dart';
import 'sparkle.dart';

const _ink = Color(0xFF111111);

/// The channel page, laid out like a property page: a full-width photo with
/// floating round buttons, a white sheet that slides over it with the name,
/// a status card, a row of key numbers, the price with a black action pill,
/// then About, Top posts, Pricing and the channel link. Built from the app's
/// own pieces (black pill, blue accents, soft borders). Used by the owner's
/// channel page and by the pre-submit preview so both look the same.
class ChannelDetailView extends StatelessWidget {
  const ChannelDetailView({
    super.key,
    required this.account,
    this.leading,
    this.actions = const [],
    this.bottomPadding = 32,
  });

  final InfluencerAccount account;

  /// Top-left floating control (usually a back button).
  final Widget? leading;

  /// Top-right floating controls.
  final List<Widget> actions;
  final double bottomPadding;

  /// Photo height below the status bar, and how far the sheet slides over it.
  static const photoHeight = 330.0;
  static const sheetOverlap = 30.0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final color = Fmt.platformColor(account.accountType);
    final topPost = account.topViewedPost;
    final weekPost = account.weeklyTopViewedPost;
    final lowest = account.lowestCost;
    final category = account.category?.categoryName ?? '';
    final subtitle = [
      account.accountType?.label,
      category,
    ].where((s) => (s ?? '').isNotEmpty).join(' · ');

    return ColoredBox(
      color: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Full-width photo with floating buttons.
          SizedBox(
            height: top + photoHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage(
                  account.imageURL,
                  fallback: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0A84FF), Color(0xFF0A4FD6)],
                      ),
                    ),
                    child: Stack(
                      children: [
                        const Positioned(
                          top: 110,
                          right: 50,
                          child: Sparkle(size: 24, color: Colors.white),
                        ),
                        const Positioned(
                          top: 190,
                          left: 44,
                          child: Sparkle(
                            size: 14,
                            color: AppColors.accentLight,
                          ),
                        ),
                        Center(
                          child: PlatformLogo(
                            account.accountType,
                            size: 96,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Soft shade at the top so the round buttons stay readable.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [Color(0x66000000), Color(0x00000000)],
                    ),
                  ),
                ),
                Positioned(
                  top: top + 8,
                  left: 12,
                  right: 12,
                  child: Row(children: [?leading, const Spacer(), ...actions]),
                ),
                if (subtitle.isNotEmpty)
                  Positioned(
                    right: 16,
                    bottom: sheetOverlap + 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        account.accountType?.label ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // White sheet sliding over the photo.
          Transform.translate(
            offset: const Offset(0, -sheetOverlap),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: EdgeInsets.fromLTRB(20, 22, 20, bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + status card.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.title ?? 'Untitled',
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 22,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                PlatformLogo(
                                  account.accountType,
                                  size: 16,
                                  color: color,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.neutral500,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _StatusCard(
                        approved: account.approved,
                        featured: account.featured,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Key numbers in one bordered bar.
                  _FactBar(
                    items: [
                      _FactItem(
                        Icons.group_outlined,
                        Fmt.compact(account.audienceCount),
                        'Audience',
                      ),
                      _FactItem(
                        Icons.visibility_outlined,
                        account.maxViewPerPostCount > 0
                            ? '${Fmt.compact(account.minViewPerPostCount)}–${Fmt.compact(account.maxViewPerPostCount)}'
                            : '—',
                        'Per post',
                      ),
                      _FactItem(
                        Icons.emoji_events_outlined,
                        topPost == null ? '—' : Fmt.compact(topPost.count),
                        'Top post',
                      ),
                      _FactItem(
                        Icons.local_fire_department_outlined,
                        weekPost == null ? '—' : Fmt.compact(weekPost.count),
                        'This week',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Price + black action pill.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Starting price',
                              style: TextStyle(
                                color: AppColors.neutral500,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              lowest == null ? 'Not set' : Fmt.birr(lowest),
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if ((account.description ?? '').isNotEmpty) ...[
                    const _Heading('About'),
                    _AboutText(account.description!),
                  ],

                  if (topPost != null || weekPost != null) ...[
                    const _Heading('Top posts'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (topPost != null)
                          Expanded(
                            child: _PostTile(
                              icon: Icons.emoji_events_rounded,
                              title: 'Top viewed',
                              post: topPost,
                            ),
                          ),
                        if (topPost != null && weekPost != null)
                          const SizedBox(width: 12),
                        if (weekPost != null)
                          Expanded(
                            child: _PostTile(
                              icon: Icons.local_fire_department_rounded,
                              title: 'This week',
                              post: weekPost,
                            ),
                          ),
                      ],
                    ),
                  ],

                  const _Heading('Pricing'),
                  if (account.priceOptions.isEmpty)
                    const Text(
                      'No pricing listed.',
                      style: TextStyle(color: AppColors.neutral500),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (var i = 0; i < account.priceOptions.length; i++)
                          _PricePill(
                            option: account.priceOptions[i],
                            selected: i == 0,
                          ),
                      ],
                    ),

                  if ((account.accountURL ?? '').isNotEmpty) ...[
                    const _Heading('Channel link'),
                    _LinkRow(
                      icon: Fmt.platformIcon(account.accountType),
                      logo: PlatformLogo(
                        account.accountType,
                        size: 24,
                        color: color,
                      ),
                      tint: color,
                      title: account.accountType?.label ?? 'Channel',
                      url: account.accountURL!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round white button that floats on the photo.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.92),
          fixedSize: const Size(44, 44),
        ),
        icon: Icon(icon, color: _ink, size: 21),
      ),
    );
  }
}

/// Small bordered card on the right of the name (where a rating would sit).
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.approved, required this.featured});
  final bool approved;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final color = approved ? const Color(0xFF15803D) : const Color(0xFF92400E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                approved ? Icons.verified : Icons.schedule,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 5),
              Text(
                approved ? 'Approved' : 'Pending',
                style: TextStyle(
                  color: color,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (featured)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'Featured',
                style: TextStyle(
                  color: AppColors.neutral500,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FactItem {
  const _FactItem(this.icon, this.value, this.label);
  final IconData icon;
  final String value;
  final String label;
}

/// Four numbers in one bordered bar with thin dividers.
class _FactBar extends StatelessWidget {
  const _FactBar({required this.items});
  final List<_FactItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.neutral200),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.neutral200,
                ),
              Expanded(
                child: Column(
                  children: [
                    Icon(items[i].icon, size: 21, color: AppColors.neutral700),
                    const SizedBox(height: 8),
                    Text(
                      items[i].value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i].label,
                      style: const TextStyle(
                        color: AppColors.neutral500,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        color: _ink,
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
    ),
  );
}

/// Description clamped to three lines with a "Read more" toggle.
class _AboutText extends StatefulWidget {
  const _AboutText(this.text);
  final String text;

  @override
  State<_AboutText> createState() => _AboutTextState();
}

class _AboutTextState extends State<_AboutText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppColors.neutral500,
      fontSize: 14.5,
      height: 1.55,
    );
    return LayoutBuilder(
      builder: (context, c) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 3,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: c.maxWidth);
        final overflows = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              maxLines: _open ? null : 3,
              overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
              style: style,
            ),
            if (overflows)
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: () => setState(() => _open = !_open),
                  style: TextButton.styleFrom(
                    foregroundColor: _ink,
                    textStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  iconAlignment: IconAlignment.end,
                  icon: Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                  ),
                  label: Text(_open ? 'Show less' : 'Read more'),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A tappable row card (like a booking): icon tile, title, link, optional
/// view count and an arrow. Opens the link.
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.url,
    this.logo,
    this.tint,
  });
  final IconData icon;
  final String title;
  final String url;
  final Widget? logo;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final accent = tint ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => openLink(context, url),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: logo ?? Icon(icon, size: 26, color: accent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        url.replaceFirst(RegExp(r'^https?://'), ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.neutral500,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A top post as a compact card meant to sit side by side with another:
/// icon tile, title, view count and the link. Opens the link.
class _PostTile extends StatelessWidget {
  const _PostTile({
    required this.icon,
    required this.title,
    required this.post,
  });
  final IconData icon;
  final String title;
  final ViewPost post;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openLink(context, post.url),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 22, color: AppColors.primary),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_outward_rounded,
                    size: 18,
                    color: AppColors.neutral500,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${Fmt.compact(post.count)} views',
                style: const TextStyle(
                  color: AppColors.neutral500,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                post.url.replaceFirst(RegExp(r'^https?://'), ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A price option as a pill, like the time slots: the first one is filled
/// black, the rest are outlined.
class _PricePill extends StatelessWidget {
  const _PricePill({required this.option, required this.selected});
  final PriceOptions option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : _ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: selected ? _ink : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? _ink : AppColors.neutral200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            option.priceType?.label ?? 'Price',
            style: TextStyle(
              color: fg.withValues(alpha: selected ? 0.75 : 0.55),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            Fmt.birr(option.cost),
            style: TextStyle(
              color: fg,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if ((option.remark ?? '').isNotEmpty)
            Text(
              option.remark!,
              style: TextStyle(
                color: fg.withValues(alpha: selected ? 0.75 : 0.55),
                fontSize: 11.5,
              ),
            ),
        ],
      ),
    );
  }
}
