import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../widgets/app_image.dart';
import '../../widgets/creator_profile_card.dart';
import '../../widgets/platform_logo.dart';
import '../../widgets/shimmer.dart';
import '../../widgets/sparkle.dart';

const Color _ink = Color(0xFF111111);

/// A creator's full public profile, as brands see it: everything they added
/// when applying (photo, headline, biography, photos) plus every approved
/// channel they run.
class CreatorPublicScreen extends ConsumerWidget {
  const CreatorPublicScreen({super.key, required this.userPublicId});

  final String userPublicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(creatorProfileProvider(userPublicId));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: profile.when(
          loading: () => const _ProfileSkeleton(),
          error: (e, _) => Stack(
            children: [
              ErrorView(
                message: 'Could not load this creator.',
                onRetry: () =>
                    ref.invalidate(creatorProfileProvider(userPublicId)),
              ),
              const _BackButton(dark: true),
            ],
          ),
          data: (p) => RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(creatorProfileProvider(userPublicId));
              try {
                await ref.read(creatorProfileProvider(userPublicId).future);
              } catch (_) {
                // The error view takes over.
              }
            },
            child: _Profile(profile: p),
          ),
        ),
      ),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({required this.profile});
  final CreatorProfile profile;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final name = (profile.name ?? '').isEmpty ? 'Creator' : profile.name!;
    final channels = profile.channels;
    final platforms = <String, AccountType?>{
      for (final c in channels)
        if (c.accountType != null) c.accountType!.wire: c.accountType,
    };
    final categories = {
      for (final c in channels)
        if ((c.category?.categoryName ?? '').isNotEmpty)
          c.category!.categoryName!,
    };
    final best = channels.fold<int>(
      0,
      (m, c) => c.maxViewPerPostCount > m ? c.maxViewPerPostCount : m,
    );

    return Stack(
      children: [
        ListView(
          physics: const ClampingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.zero,
          children: [
            // Gradient header, the profile card overlaps its bottom.
            Container(
              height: top + 120,
              decoration: const BoxDecoration(gradient: AppGradients.hero),
              child: Stack(
                children: [
                  Positioned(
                    top: top + 18,
                    right: 28,
                    child: const Sparkle(size: 24, color: Colors.white),
                  ),
                  Positioned(
                    top: top + 58,
                    right: 70,
                    child: const Sparkle(
                      size: 12,
                      color: AppColors.accentLight,
                    ),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CreatorProfileCard(
                  name: name,
                  headline: profile.headline,
                  biography: profile.biography,
                  avatarUrl: profile.profileImageUrl,
                  gallery: profile.galleryImages,
                  emptyHint: 'This creator has not written a biography yet.',
                  chips: [
                    for (final t in platforms.values)
                      ProfileChip(
                        t!.label,
                        leading: PlatformLogo(
                          t,
                          size: 14,
                          color: Fmt.platformColor(t),
                        ),
                      ),
                    for (final c in categories)
                      ProfileChip(
                        c,
                        leading: const Icon(
                          Icons.category_outlined,
                          size: 14,
                          color: AppColors.neutral700,
                        ),
                      ),
                  ],
                  stats: [
                    ProfileStat(
                      '${channels.length}',
                      channels.length == 1 ? 'Channel' : 'Channels',
                      icon: Icons.storefront_outlined,
                    ),
                    ProfileStat(
                      Fmt.compact(profile.totalAudience),
                      'Audience',
                      icon: Icons.group_outlined,
                    ),
                    ProfileStat(
                      best > 0 ? Fmt.compact(best) : '—',
                      'Best views',
                      icon: Icons.visibility_outlined,
                    ),
                  ],
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channels.length == 1
                          ? 'Channel'
                          : 'Channels (${channels.length})',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final c in channels) _ChannelRow(account: c),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
        const _BackButton(),
      ],
    );
  }
}

/// One channel, styled like the Browse rows (soft grey card). Opens the
/// channel page, where brands can request a promotion.
class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.account});
  final InfluencerAccount account;

  @override
  Widget build(BuildContext context) {
    final pColor = Fmt.platformColor(account.accountType);
    final lowest = account.lowestCost;
    final sub = [
      account.accountType?.label,
      '${Fmt.compact(account.audienceCount)} followers',
    ].where((s) => (s ?? '').isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
                              account.title ?? 'Channel',
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
                          PlatformLogo(
                            account.accountType,
                            size: 13,
                            color: pColor,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.neutral500,
                                fontSize: 13,
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

class _BackButton extends StatelessWidget {
  const _BackButton({this.dark = false});

  /// Dark icon on a light page (the error state); white on the gradient.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 6,
      left: 10,
      child: IconButton(
        tooltip: 'Back',
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/browse'),
        style: IconButton.styleFrom(
          backgroundColor: dark
              ? AppColors.neutral100
              : Colors.white.withValues(alpha: 0.2),
        ),
        icon: Icon(
          Icons.arrow_back,
          color: dark ? AppColors.neutral900 : Colors.white,
        ),
      ),
    );
  }
}

/// Shimmering placeholder with the same layout: gradient header, the profile
/// card (photo, name, chips, stats, about, photos) and the channel rows.
class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    const base = kSkeletonBase;
    final top = MediaQuery.of(context).padding.top;

    Widget row() => Container(
      height: 84,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: base,
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
                SkeletonBox(width: 170, height: 12, radius: 6),
              ],
            ),
          ),
          SkeletonBox(width: 60, height: 30, radius: 8),
        ],
      ),
    );

    final content = ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Container(
          height: top + 120,
          decoration: const BoxDecoration(gradient: AppGradients.hero),
        ),
        Transform.translate(
          offset: const Offset(0, -56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.neutral200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(
                    width: double.infinity,
                    height: 112,
                    radius: 22,
                    color: base,
                  ),
                  SizedBox(height: 14),
                  SkeletonBox(width: 160, height: 20, radius: 7, color: base),
                  SizedBox(height: 8),
                  SkeletonBox(width: 210, height: 13, radius: 6, color: base),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      SkeletonBox(width: 90, height: 30, radius: 15, color: base),
                      SizedBox(width: 8),
                      SkeletonBox(width: 100, height: 30, radius: 15, color: base),
                    ],
                  ),
                  SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      SkeletonBox(width: 60, height: 36, radius: 8, color: base),
                      SkeletonBox(width: 60, height: 36, radius: 8, color: base),
                      SkeletonBox(width: 60, height: 36, radius: 8, color: base),
                    ],
                  ),
                  SizedBox(height: 18),
                  SkeletonBox(width: 70, height: 16, radius: 6, color: base),
                  SizedBox(height: 10),
                  SkeletonBox(
                    width: double.infinity,
                    height: 13,
                    radius: 6,
                    color: base,
                  ),
                  SizedBox(height: 8),
                  SkeletonBox(width: 230, height: 13, radius: 6, color: base),
                ],
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 120, height: 20, radius: 7, color: base),
                const SizedBox(height: 12),
                row(),
                row(),
              ],
            ),
          ),
        ),
      ],
    );

    return Semantics(
      label: 'Loading creator profile',
      child: Stack(
        children: [
          ExcludeSemantics(child: Shimmer(child: content)),
          const _BackButton(),
        ],
      ),
    );
  }
}
