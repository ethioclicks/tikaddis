import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/links.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/app_image.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/creator_profile_card.dart';
import '../../widgets/dots_loading.dart';
import '../../widgets/platform_logo.dart';
import '../../widgets/shimmer.dart';

const Color _ink = Color(0xFF111111);

/// Admin view of a single channel: everything the owner submitted, the
/// creator's profile, and the review actions (approve, disapprove, feature).
class AdminChannelDetailScreen extends ConsumerStatefulWidget {
  const AdminChannelDetailScreen({super.key, required this.accountId});

  /// The channel's public id.
  final String accountId;

  @override
  ConsumerState<AdminChannelDetailScreen> createState() =>
      _AdminChannelDetailScreenState();
}

class _AdminChannelDetailScreenState
    extends ConsumerState<AdminChannelDetailScreen> {
  bool _busy = false;

  void _refreshEverywhere() {
    ref.invalidate(accountDetailProvider(widget.accountId));
    ref.invalidate(adminAccountsProvider);
    ref.invalidate(approvedAccountsProvider);
    ref.invalidate(featuredAccountsProvider);
    ref.invalidate(myAccountsProvider);
  }

  String _errorText(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is String && data.isNotEmpty) return data;
    if (data is Map && data['message'] != null) {
      final text = data['message'].toString().replaceFirst('Cause by:', '').trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      _refreshEverywhere();
      if (mounted) AppToast.success(context, done);
    } on DioException catch (e) {
      if (mounted) {
        AppToast.error(context, _errorText(e, 'Could not update the channel.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(accountDetailProvider(widget.accountId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Channel details'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/admin/channels'),
        ),
      ),
      body: detail.when(
        loading: () => const _DetailSkeleton(),
        error: (e, _) => ErrorView(
          message: 'Could not load this channel.',
          onRetry: () => ref.invalidate(accountDetailProvider(widget.accountId)),
        ),
        data: (a) => _Body(
          account: a,
          busy: _busy,
          onApprove: () => _run(
            () => ref
                .read(apiServiceProvider)
                .adminApproveAccount(widget.accountId, 'APPROVE'),
            'Channel approved.',
          ),
          onDisapprove: () => _run(
            () => ref
                .read(apiServiceProvider)
                .adminApproveAccount(widget.accountId, 'DISAPPROVE'),
            'Channel disapproved.',
          ),
          onFeatured: (v) => _run(
            () => ref
                .read(apiServiceProvider)
                .adminFeatureAccount(widget.accountId, v),
            v ? 'Channel featured.' : 'Removed from featured.',
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.account,
    required this.busy,
    required this.onApprove,
    required this.onDisapprove,
    required this.onFeatured,
  });

  final InfluencerAccount account;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onDisapprove;
  final ValueChanged<bool> onFeatured;

  @override
  Widget build(BuildContext context) {
    final a = account;
    final color = Fmt.platformColor(a.accountType);
    final creator = a.creator;
    final views = a.maxViewPerPostCount > 0
        ? '${Fmt.compact(a.minViewPerPostCount)}–${Fmt.compact(a.maxViewPerPostCount)}'
        : '—';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        // Channel photo.
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 210,
            width: double.infinity,
            child: AppImage(
              a.imageURL,
              semanticLabel: 'Channel photo',
              fallback: Container(
                color: color.withValues(alpha: 0.14),
                alignment: Alignment.center,
                child: PlatformLogo(a.accountType, size: 54, color: color),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Text(
          a.title ?? 'Untitled',
          style: const TextStyle(
            color: _ink,
            fontSize: 26,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Chip(
              icon: PlatformLogo(a.accountType, size: 14, color: color),
              text: a.accountType?.label ?? 'Platform',
            ),
            if (a.category?.categoryName != null)
              _Chip(text: a.category!.categoryName!),
            _Chip(
              text: a.approved ? 'Approved' : 'Not approved',
              bg: a.approved ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
              fg: a.approved ? const Color(0xFF047857) : AppColors.accentHover,
            ),
            if (a.featured)
              const _Chip(
                text: 'Featured',
                bg: Color(0xFFFFF7ED),
                fg: AppColors.accentHover,
              ),
            if (a.verified)
              const _Chip(
                text: 'Verified',
                bg: Color(0xFFEFF6FF),
                fg: AppColors.primary,
              ),
          ],
        ),

        if ((a.accountURL ?? '').isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.link, size: 20, color: AppColors.neutral500),
              const SizedBox(width: 8),
              Expanded(child: LinkText(url: a.accountURL)),
            ],
          ),
        ],

        if ((a.description ?? '').isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            a.description!,
            style: const TextStyle(
              color: AppColors.neutral700,
              fontSize: 14.5,
              height: 1.55,
            ),
          ),
        ],

        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _Stat(value: Fmt.compact(a.audienceCount), label: 'Audience'),
            ),
            const SizedBox(width: 10),
            Expanded(child: _Stat(value: views, label: 'Views / post')),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(
                value: a.lowestCost == null ? '—' : Fmt.birr(a.lowestCost!),
                label: 'From',
              ),
            ),
          ],
        ),

        if (a.topViewedPost != null || a.weeklyTopViewedPost != null) ...[
          const SizedBox(height: 24),
          const _Heading('Top posts'),
          const SizedBox(height: 10),
          if (a.topViewedPost != null)
            _PostRow(title: 'Top viewed post', post: a.topViewedPost!),
          if (a.weeklyTopViewedPost != null)
            _PostRow(
              title: "This week's top viewed",
              post: a.weeklyTopViewedPost!,
            ),
        ],

        if (a.priceOptions.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _Heading('Pricing'),
          const SizedBox(height: 10),
          for (final p in a.priceOptions)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        p.priceType?.label ?? 'Price',
                        if ((p.remark ?? '').isNotEmpty) p.remark!,
                      ].join(' · '),
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    Fmt.birr(p.cost),
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],

        if (creator != null && !creator.isEmpty) ...[
          const SizedBox(height: 24),
          const _Heading('Creator'),
          const SizedBox(height: 12),
          CreatorProfileCard(
            name: creator.name ?? 'Creator',
            headline: creator.headline,
            biography: creator.biography,
            avatarUrl: creator.profileImageUrl,
            gallery: creator.galleryImages,
          ),
        ],

        const SizedBox(height: 28),
        const _Heading('Review'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.neutral100,
            borderRadius: BorderRadius.circular(18),
          ),
          child: SwitchListTile(
            value: a.featured,
            onChanged: busy || (!a.approved && !a.featured)
                ? null
                : onFeatured,
            title: const Text(
              'Featured on Browse',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              a.approved || a.featured
                  ? 'Shown at the top of Browse for everyone.'
                  : 'Approve the channel first to feature it.',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (busy)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: DotsLoading(color: AppColors.primary),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: a.approved ? onDisapprove : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Disapprove'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: a.approved ? null : onApprove,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(a.approved ? 'Approved' : 'Approve'),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Shimmering placeholder with the same layout as the loaded page: photo,
/// title and tags, link, description, the three stat boxes, Pricing, and the
/// Review section with its two buttons.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    const base = kSkeletonBase;
    const light = kSkeletonLight;

    Widget stat() => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: light,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            SkeletonBox(width: 48, height: 18, radius: 6, color: base),
            SizedBox(height: 8),
            SkeletonBox(width: 62, height: 12, radius: 6, color: base),
          ],
        ),
      ),
    );

    return Semantics(
      label: 'Loading channel',
      child: ExcludeSemantics(
        child: Shimmer(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              // Photo.
              const SkeletonBox(height: 210, radius: 24, color: base),
              const SizedBox(height: 16),
              // Title and tags.
              const SkeletonBox(width: 190, height: 26, radius: 8, color: base),
              const SizedBox(height: 12),
              const Row(
                children: [
                  SkeletonBox(width: 104, height: 32, radius: 16, color: base),
                  SizedBox(width: 8),
                  SkeletonBox(width: 90, height: 32, radius: 16, color: base),
                  SizedBox(width: 8),
                  SkeletonBox(width: 82, height: 32, radius: 16, color: base),
                ],
              ),
              const SizedBox(height: 14),
              // Link and description.
              const SkeletonBox(width: 210, height: 16, radius: 6, color: base),
              const SizedBox(height: 16),
              const SkeletonBox(width: 240, height: 14, radius: 6, color: base),
              const SizedBox(height: 18),
              // Stats.
              Row(
                children: [
                  stat(),
                  const SizedBox(width: 10),
                  stat(),
                  const SizedBox(width: 10),
                  stat(),
                ],
              ),
              const SizedBox(height: 24),
              // Pricing.
              const SkeletonBox(width: 80, height: 20, radius: 7, color: base),
              const SizedBox(height: 10),
              const SkeletonBox(height: 50, radius: 16, color: base),
              const SizedBox(height: 28),
              // Review: switch row and the two buttons.
              const SkeletonBox(width: 80, height: 20, radius: 7, color: base),
              const SizedBox(height: 12),
              const SkeletonBox(height: 78, radius: 18, color: base),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(
                    child: SkeletonBox(height: 52, radius: 26, color: base),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: SkeletonBox(height: 52, radius: 26, color: base),
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

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: _ink,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    this.icon,
    this.bg = AppColors.neutral100,
    this.fg = AppColors.neutral700,
  });
  final String text;
  final Widget? icon;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 6)],
        Text(
          text,
          style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
    decoration: BoxDecoration(
      color: AppColors.neutral100,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        FittedBox(
          child: Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppColors.neutral500, fontSize: 12),
        ),
      ],
    ),
  );
}

class _PostRow extends StatelessWidget {
  const _PostRow({required this.title, required this.post});
  final String title;
  final ViewPost post;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.neutral100,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: _ink, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              LinkText(url: post.url, label: 'Open post'),
            ],
          ),
        ),
        Text(
          '${Fmt.compact(post.count)} views',
          style: const TextStyle(
            color: AppColors.neutral700,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
