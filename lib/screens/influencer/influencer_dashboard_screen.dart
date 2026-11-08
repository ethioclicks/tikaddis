import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../widgets/app_image.dart';
import '../../widgets/platform_logo.dart';
import '../../widgets/shimmer.dart';
import '../auth/auth_scaffold.dart' show AuthButton;

const Color _ink = Color(0xFF111111);

/// The creator's "Channels" tab: a clean white page with a title, a round
/// add button, and the creator's channels as soft grey cards.
class InfluencerDashboardScreen extends ConsumerWidget {
  const InfluencerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(myAccountsProvider);

    final list = accounts.asData?.value;
    final subtitle = list == null
        ? null
        : list.isEmpty
        ? 'No channels yet'
        : '${list.length} ${list.length == 1 ? 'channel' : 'channels'}'
              '  ·  ${Fmt.compact(list.fold<int>(0, (s, c) => s + c.audienceCount))} total audience';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My channels',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 32,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.9,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (subtitle == null)
                          const Shimmer(
                            child: SkeletonBox(
                              width: 150,
                              height: 14,
                              radius: 6,
                              color: kSkeletonBase,
                            ),
                          )
                        else
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: AppColors.neutral500,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: accounts.when(
              loading: () => const _ChannelsSkeleton(),
              error: (e, _) => ErrorView(
                message: 'Could not load your channels.',
                onRetry: () => ref.invalidate(myAccountsProvider),
              ),
              data: (list) {
                if (list.isEmpty) return const _EmptyChannels();
                return RefreshIndicator(
                  color: AppColors.primary,
                  // Keep the spinner up until the data is back; the page
                  // itself never moves.
                  onRefresh: () async {
                    ref.invalidate(myAccountsProvider);
                    try {
                      await ref.read(myAccountsProvider.future);
                    } catch (_) {
                      // The error view takes over.
                    }
                  },
                  child: ListView.separated(
                    physics: const ClampingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    // Extra room so the last card clears the floating button.
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 170),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _ChannelCard(account: list[i]),
                  ),
                );
              },
            ),
          ),
        ],
          ),
          // Floating add button, just above the bottom bar.
          if (list != null && list.isNotEmpty)
            Positioned(
              right: 20,
              bottom: 112,
              child: Semantics(
                button: true,
                label: 'Add channel',
                child: Material(
                  color: AppColors.primary,
                  elevation: 6,
                  shadowColor: AppColors.primary.withValues(alpha: 0.4),
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => context.push('/influencer/accounts/new'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Add channel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyChannels extends StatelessWidget {
  const _EmptyChannels();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 90),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: AppColors.neutral100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_outlined,
                size: 38,
                color: AppColors.neutral500,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No channels yet',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'List your first channel so brands can find you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.neutral500,
                fontSize: 14.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            AuthButton(
              label: 'Add your first channel',
              onPressed: () => context.push('/influencer/accounts/new'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.account});
  final InfluencerAccount account;

  @override
  Widget build(BuildContext context) {
    final pColor = Fmt.platformColor(account.accountType);
    final category = account.category?.categoryName;
    final lowest = account.lowestCost;

    Widget chip(Widget icon, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: AppColors.neutral100,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: account.accountPublicId == null
            ? null
            : () => context.push('/channel/${account.accountPublicId}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: 62,
                      height: 62,
                      child: AppImage(
                        account.imageURL,
                        fallback: Container(
                          color: Colors.white,
                          alignment: Alignment.center,
                          child: PlatformLogo(
                            account.accountType,
                            size: 28,
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
                        Text(
                          account.title ?? 'Untitled',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            PlatformLogo(
                              account.accountType,
                              size: 13,
                              color: pColor,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                [
                                  account.accountType?.label,
                                  if (category != null && category.isNotEmpty)
                                    category,
                                ].whereType<String>().join(' · '),
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
                        const SizedBox(height: 8),
                        _StatusPill(approved: account.approved),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Flexible(
                    child: chip(
                      const Icon(
                        Icons.group_outlined,
                        size: 16,
                        color: AppColors.neutral600,
                      ),
                      '${Fmt.compact(account.audienceCount)} audience',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: chip(
                      const Icon(
                        Icons.payments_outlined,
                        size: 16,
                        color: AppColors.neutral600,
                      ),
                      lowest != null ? 'From ${Fmt.birr(lowest)}' : 'No price',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.approved});
  final bool approved;

  @override
  Widget build(BuildContext context) {
    final (label, icon, bg, fg) = approved
        ? (
            'Approved',
            Icons.verified_rounded,
            const Color(0xFFECFDF5),
            const Color(0xFF047857),
          )
        : (
            'Pending approval',
            Icons.schedule_rounded,
            const Color(0xFFFFF7ED),
            AppColors.accentHover,
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmering placeholders with the same layout as the channel cards.
class _ChannelsSkeleton extends StatelessWidget {
  const _ChannelsSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget card() => Container(
      height: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSkeletonBase,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 62, height: 62, radius: 18),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 140, height: 17, radius: 6),
                    SizedBox(height: 8),
                    SkeletonBox(width: 110, height: 13, radius: 6),
                    SizedBox(height: 8),
                    SkeletonBox(width: 84, height: 22, radius: 11),
                  ],
                ),
              ),
            ],
          ),
          Spacer(),
          Row(
            children: [
              SkeletonBox(width: 120, height: 34, radius: 17),
              SizedBox(width: 8),
              SkeletonBox(width: 118, height: 34, radius: 17),
            ],
          ),
        ],
      ),
    );

    return Semantics(
      label: 'Loading your channels',
      child: ExcludeSemantics(
        child: Shimmer(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
            children: [
              for (var i = 0; i < 3; i++) ...[
                card(),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
