import '../../widgets/app_toast.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/channel_detail_view.dart';
import '../../widgets/shimmer.dart';

/// Platform-themed detail page for an influencer's own channel, with
/// edit + delete management.
class ChannelDetailScreen extends ConsumerWidget {
  const ChannelDetailScreen({super.key, required this.accountId});
  final String accountId; // accountPublicId

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(accountDetailProvider(accountId));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: detail.when(
        loading: () => const _DetailSkeleton(),
        error: (e, _) => ErrorView(
          message: 'Could not load this channel.',
          onRetry: () => ref.invalidate(accountDetailProvider(accountId)),
        ),
        data: (account) => _Detail(account: account),
      ),
    );
  }
}

/// Shimmering placeholder with the same layout as the loaded page: a full
/// width photo with round buttons, the white sheet with the name, the fact
/// bar, the price row and a few content blocks. The back arrow stays usable.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    const base = kSkeletonBase;
    final top = MediaQuery.of(context).padding.top;
    const overlap = ChannelDetailView.sheetOverlap;

    Widget block(double h) => SkeletonBox(
      width: double.infinity,
      height: h,
      radius: 18,
      color: kSkeletonLight,
    );

    final content = ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        SkeletonBox(
          width: double.infinity,
          height: top + ChannelDetailView.photoHeight,
          radius: 0,
        ),
        Transform.translate(
          offset: const Offset(0, -overlap),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 170, height: 24, radius: 8, color: base),
                          SizedBox(height: 10),
                          SkeletonBox(width: 110, height: 14, radius: 6, color: base),
                        ],
                      ),
                    ),
                    SkeletonBox(width: 88, height: 50, radius: 14, color: base),
                  ],
                ),
                const SizedBox(height: 18),
                block(84),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 80, height: 12, radius: 6, color: base),
                          SizedBox(height: 8),
                          SkeletonBox(width: 130, height: 26, radius: 8, color: base),
                        ],
                      ),
                    ),
                    SkeletonBox(width: 140, height: 52, radius: 26, color: base),
                  ],
                ),
                const SizedBox(height: 28),
                const SkeletonBox(width: 70, height: 18, radius: 6, color: base),
                const SizedBox(height: 14),
                const SkeletonBox(width: double.infinity, height: 14, radius: 6, color: kSkeletonLight),
                const SizedBox(height: 8),
                const SkeletonBox(width: 240, height: 14, radius: 6, color: kSkeletonLight),
                const SizedBox(height: 28),
                const SkeletonBox(width: 90, height: 18, radius: 6, color: base),
                const SizedBox(height: 14),
                block(78),
                const SizedBox(height: 10),
                block(78),
              ],
            ),
          ),
        ),
      ],
    );

    return Semantics(
      label: 'Loading channel',
      child: Stack(
        children: [
          ExcludeSemantics(child: Shimmer(child: content)),
          Positioned(
            top: top + 8,
            left: 12,
            child: IconButton(
              tooltip: 'Back',
              onPressed: () => context.pop(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.92),
                fixedSize: const Size(44, 44),
              ),
              icon: const Icon(Icons.arrow_back, color: AppColors.neutral900),
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.account});
  final InfluencerAccount account;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete channel?'),
        content: Text(
          'This will remove "${account.title ?? 'this channel'}" from your '
          'listings. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final pid = ref.read(authProvider).pid;
    if (pid == null || account.accountPublicId == null) return;
    try {
      await ref
          .read(apiServiceProvider)
          .deleteInfluencerAccount(account.accountPublicId!, pid);
      ref.invalidate(myAccountsProvider);
      if (!context.mounted) return;
      AppToast.success(context, 'Channel deleted.');
      context.go('/browse');
    } on DioException catch (e) {
      if (!context.mounted) return;
      final data = e.response?.data;
      AppToast.error(
        context,
        data is String && data.isNotEmpty
            ? data
            : 'Could not delete the channel.',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChannelDetailView(
      account: account,
      bottomPadding: 100,
      leading: HeaderIconButton(
        icon: Icons.arrow_back,
        tooltip: 'Back',
        onPressed: () => context.pop(),
      ),
      actions: [
        HeaderIconButton(
          icon: Icons.edit_outlined,
          tooltip: 'Edit',
          onPressed: () =>
              context.push('/influencer/accounts/edit', extra: account),
        ),
        HeaderIconButton(
          icon: Icons.delete_outline,
          tooltip: 'Delete',
          onPressed: () => _delete(context, ref),
        ),
      ],
    );
  }
}
