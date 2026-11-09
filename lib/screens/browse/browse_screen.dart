import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/browse_error.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/app_image.dart';
import '../../widgets/creator_person_card.dart';
import '../../widgets/platform_logo.dart';
import '../../widgets/shimmer.dart';
import '../../widgets/sparkle.dart';

const Color _ink = Color(0xFF111111);

/// How many creators the Browse rail shows before "View all".
const int _railLimit = 10;

/// Creator discovery: a gradient header with search, filter pills, the
/// channels an admin has featured, then the full list of creators.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  int _tab = 0; // 0 Trending, 1 Recent, 2 Top, 3 Verified
  String _query = '';
  static const _tabs = ['Trending', 'Recent', 'Top', 'Verified'];

  List<InfluencerAccount> _sorted(List<InfluencerAccount> all) {
    final list = [...all];
    switch (_tab) {
      case 0: // Trending: by views per post
        list.sort(
          (a, b) => b.maxViewPerPostCount.compareTo(a.maxViewPerPostCount),
        );
        break;
      case 1: // Recent: newest first
        list.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
        break;
      case 2: // Top: by audience
        list.sort((a, b) => b.audienceCount.compareTo(a.audienceCount));
        break;
      case 3: // Verified only
        return list.where((a) => a.verified).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(approvedAccountsProvider);
    final featuredAsync = ref.watch(featuredAccountsProvider);
    final featured = featuredAsync.maybeWhen(
      data: (l) => l,
      orElse: () => const <InfluencerAccount>[],
    );
    final featuredLoading = featuredAsync.isLoading && !featuredAsync.hasValue;
    final creatorsAsync = ref.watch(creatorsProvider);
    final creators = creatorsAsync.maybeWhen(
      data: (l) => l,
      orElse: () => const <CreatorCard>[],
    );
    final creatorsLoading = creatorsAsync.isLoading && !creatorsAsync.hasValue;
    final searching = _query.trim().isNotEmpty;

    final content = accounts.when(
      loading: () => <Widget>[
        if (featuredLoading) ..._featuredSection(null, loading: true),
        const _SectionTitle('Channels'),
        const SizedBox(height: 12),
        for (var i = 0; i < 4; i++) const _RowSkeleton(),
      ],
      error: (e, _) => <Widget>[
        SizedBox(
          height: 380,
          child: ErrorView(
            message: browseErrorMessage(e),
            onRetry: () => ref.invalidate(approvedAccountsProvider),
            action: TextButton(
              onPressed: () => ref.read(authProvider.notifier).logout(),
              child: const Text('Sign in again'),
            ),
          ),
        ),
      ],
      data: (all) {
        final sorted = _sorted(all);
        final q = _query.trim().toLowerCase();
        final rows = q.isEmpty
            ? sorted
            : sorted
                  .where(
                    (a) =>
                        (a.title ?? '').toLowerCase().contains(q) ||
                        (a.category?.categoryName ?? '')
                            .toLowerCase()
                            .contains(q),
                  )
                  .toList();
        return <Widget>[
          if (!searching && (featuredLoading || featured.isNotEmpty))
            ..._featuredSection(featured, loading: featuredLoading),
          if (!searching && (creatorsLoading || creators.isNotEmpty))
            ..._creatorsSection(creators, loading: creatorsLoading),
          _SectionTitle(searching ? '${rows.length} results' : 'Channels'),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 36),
              child: EmptyView(
                icon: Icons.search_off,
                message: all.isEmpty
                    ? 'No approved creators are available yet. '
                          'Please check back soon.'
                    : 'No creators match your search.',
              ),
            )
          else
            for (final a in rows) _CreatorRow(account: a),
        ];
      },
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: RefreshIndicator(
          color: AppColors.primary,
          // Keep the spinner up until the data is really back, then let the
          // new list replace the old one in place (no flash to a skeleton).
          onRefresh: () async {
            ref.invalidate(featuredAccountsProvider);
            ref.invalidate(creatorsProvider);
            ref.invalidate(approvedAccountsProvider);
            try {
              await ref.read(approvedAccountsProvider.future);
            } catch (_) {
              // The error view takes over; nothing to do here.
            }
          },
          child: ListView(
            // Pulling down never moves or stretches the page; only the refresh
            // spinner appears over the top.
            physics: const ClampingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: 110),
            children: [
              _Header(onChanged: (v) => setState(() => _query = v)),
              const SizedBox(height: 16),
              _Tabs(
                tabs: _tabs,
                selected: _tab,
                onSelected: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 22),
              ...content.map(
                (w) => w is _SectionTitle
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: w,
                      )
                    : w,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The "Featured" title plus the horizontal rail (or its shimmer).
  List<Widget> _featuredSection(
    List<InfluencerAccount>? items, {
    required bool loading,
  }) {
    return [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: _SectionTitle('Featured'),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 248,
        child: loading
            ? ListView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                children: const [_FeaturedSkeleton()],
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                itemCount: items!.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (_, i) => _FeaturedCard(account: items[i]),
              ),
      ),
      const SizedBox(height: 14),
    ];
  }

  /// The "Creator profiles" title plus a horizontal rail of people (or its
  /// shimmer). Tapping one opens their full creator profile.
  List<Widget> _creatorsSection(
    List<CreatorCard> items, {
    required bool loading,
  }) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            const Expanded(child: _SectionTitle('Creator profiles')),
            if (!loading)
              TextButton(
                onPressed: () => context.push('/creators'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('View all'),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 168,
        child: loading
            ? ListView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    const _CreatorProfileSkeleton(),
                    const SizedBox(width: 12),
                  ],
                ],
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                // The rail shows the first few; "View all" opens the rest.
                itemCount: items.length > _railLimit ? _railLimit : items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => CreatorPersonCard(creator: items[i]),
              ),
      ),
      const SizedBox(height: 18),
    ];
  }
}

// ── Header with title and search ──────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppGradients.hero),
      padding: EdgeInsets.fromLTRB(20, top + 20, 20, 24),
      child: Stack(
        children: [
          const Positioned(
            top: 4,
            right: 8,
            child: Sparkle(size: 26, color: Colors.white),
          ),
          const Positioned(
            top: 40,
            right: 44,
            child: Sparkle(size: 13, color: AppColors.accentLight),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Find the perfect\ncreator for your brand',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryHover.withValues(alpha: 0.18),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: onChanged,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 15.5, color: _ink),
                  decoration: const InputDecoration(
                    hintText: 'Search creators, categories…',
                    hintStyle: TextStyle(
                      color: AppColors.neutral500,
                      fontSize: 15,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.neutral500,
                      size: 22,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Filter pills ──────────────────────────────────────────────────────────
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final active = i == selected;
          return Semantics(
            button: true,
            selected: active,
            label: tabs[i],
            child: GestureDetector(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? _ink : AppColors.neutral100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: ExcludeSemantics(
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      color: active ? Colors.white : AppColors.neutral700,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      color: _ink,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
    ),
  );
}

// ── Featured card: photo first, details over a soft scrim ─────────────────
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.account});
  final InfluencerAccount account;

  @override
  Widget build(BuildContext context) {
    final pColor = Fmt.platformColor(account.accountType);
    final lowest = account.lowestCost;
    final category = account.category?.categoryName;

    return Container(
      width: 268,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryHover.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Material(
          color: pColor,
          child: InkWell(
            onTap: account.accountPublicId == null
                ? null
                : () => context.push('/browse-detail/${account.accountPublicId}'),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Channel photo, or a platform-coloured panel with its logo.
                Positioned.fill(
                  child: AppImage(
                    account.imageURL,
                    fallback: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [pColor.withValues(alpha: 0.85), pColor],
                        ),
                      ),
                      child: Align(
                        alignment: const Alignment(0, -0.35),
                        child: PlatformLogo(
                          account.accountType,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                  ),
                ),
                // Scrim so the white text is always readable.
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00000000),
                          Color(0x00000000),
                          Color(0xD9000000),
                        ],
                        stops: [0, 0.4, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  child: _PlatformPill(account: account),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: AppColors.accent,
                      size: 20,
                      semanticLabel: 'Featured',
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              account.title ?? 'Creator',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          if (account.verified) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          '${Fmt.compact(account.audienceCount)} followers',
                          if (category != null && category.isNotEmpty) category,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Takes the free width so the price is not cut short.
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                lowest != null
                                    ? 'From ${Fmt.birr(lowest)}'
                                    : 'No price yet',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: _ink,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ],
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

/// White pill with the platform's real logo and name.
class _PlatformPill extends StatelessWidget {
  const _PlatformPill({required this.account});
  final InfluencerAccount account;

  @override
  Widget build(BuildContext context) {
    final pColor = Fmt.platformColor(account.accountType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlatformLogo(account.accountType, size: 14, color: pColor),
          const SizedBox(width: 6),
          Text(
            account.accountType?.label ?? '',
            style: const TextStyle(
              color: _ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Creator row: soft grey card ───────────────────────────────────────────
class _CreatorRow extends StatelessWidget {
  const _CreatorRow({required this.account});
  final InfluencerAccount account;

  @override
  Widget build(BuildContext context) {
    final pColor = Fmt.platformColor(account.accountType);
    final lowest = account.lowestCost;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Material(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: account.accountPublicId == null
              ? null
              : () => context.push('/browse-detail/${account.accountPublicId}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: AppImage(
                      account.imageURL,
                      fallback: Container(
                        color: Colors.white,
                        alignment: Alignment.center,
                        child: PlatformLogo(
                          account.accountType,
                          size: 26,
                          color: pColor,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              account.title ?? 'Creator',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (account.verified) ...[
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.primary,
                              size: 15,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          PlatformLogo(account.accountType, size: 13, color: pColor),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${account.accountType?.label ?? 'Channel'} · '
                              '${Fmt.compact(account.audienceCount)} followers',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.neutral500,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'From',
                      style: TextStyle(
                        color: AppColors.neutral500,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      lowest != null ? Fmt.birr(lowest) : '—',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatorProfileSkeleton extends StatelessWidget {
  const _CreatorProfileSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading creator profiles',
    child: ExcludeSemantics(
      child: Shimmer(
        child: Container(
          width: 136,
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          decoration: BoxDecoration(
            color: kSkeletonBase,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            children: [
              SkeletonBox(width: 52, height: 52, circle: true),
              SizedBox(height: 8),
              SkeletonBox(width: 90, height: 14, radius: 6),
              SizedBox(height: 6),
              SkeletonBox(width: 100, height: 11, radius: 6),
              Spacer(),
              SkeletonBox(width: 80, height: 22, radius: 11),
            ],
          ),
        ),
      ),
    ),
  );
}
// ── Shimmer placeholders (same sizes as the real cards) ───────────────────
class _FeaturedSkeleton extends StatelessWidget {
  const _FeaturedSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading featured creators',
    child: ExcludeSemantics(
      child: Shimmer(
        child: Container(
          width: 268,
          decoration: BoxDecoration(
            color: kSkeletonBase,
            borderRadius: BorderRadius.circular(26),
          ),
          padding: const EdgeInsets.all(16),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 96, height: 30, radius: 15),
              Spacer(),
              SkeletonBox(width: 150, height: 22, radius: 8),
              SizedBox(height: 8),
              SkeletonBox(width: 190, height: 13, radius: 6),
              SizedBox(height: 16),
              Row(
                children: [
                  SkeletonBox(width: 120, height: 36, radius: 18),
                  Spacer(),
                  SkeletonBox(width: 40, height: 40, circle: true),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
    child: Semantics(
      label: 'Loading creators',
      child: ExcludeSemantics(
        child: Shimmer(
          child: Container(
            height: 84,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kSkeletonBase,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Row(
              children: [
                SkeletonBox(width: 60, height: 60, radius: 16),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 130, height: 16, radius: 6),
                      SizedBox(height: 9),
                      SkeletonBox(width: 180, height: 12, radius: 6),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                SkeletonBox(width: 62, height: 30, radius: 8),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
