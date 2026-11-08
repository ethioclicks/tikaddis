import '../../widgets/promotion_brief_details.dart';
import '../../widgets/app_toast.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/dots_loading.dart';
import '../../widgets/shimmer.dart';

/// Incoming promotion requests for the influencer's accounts, with
/// approve/reject actions (account-owner stage of the pipeline).
class PromotionsScreen extends ConsumerWidget {
  const PromotionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(influencerRequestsProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: Column(
        children: [
          const SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Requests',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.neutral900,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: requests.when(
              loading: () => const _RequestSkeletons(),
              error: (e, _) => ErrorView(
                message: 'Could not load requests.',
                onRetry: () => ref.invalidate(influencerRequestsProvider),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyView(
                    icon: Icons.inbox_outlined,
                    message: 'No promotion requests yet.',
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async =>
                      ref.invalidate(influencerRequestsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: list.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (_, i) => _RequestCard(request: list[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({required this.request});
  final PromotionRequest request;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _busy = false;

  bool get _actionable =>
      widget.request.status == PromotionStatus.adminApproved;

  Future<void> _act(String option) async {
    final id = widget.request.promotionRequestPublicId;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          option == 'APPROVE' ? 'Approve request?' : 'Reject request?',
        ),
        content: Text(
          option == 'APPROVE'
              ? 'Accept this campaign brief so the promotion can move forward.'
              : 'This will reject the promotion request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: option == 'APPROVE'
                  ? AppColors.primary
                  : const Color(0xFFB91C1C),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(option == 'APPROVE' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(apiServiceProvider).approveRejectPromotion(id, option);
      ref.invalidate(influencerRequestsProvider);
      if (!mounted) return;
      AppToast.success(
        context,
        option == 'APPROVE' ? 'Request approved.' : 'Request rejected.',
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final data = e.response?.data;
      AppToast.error(
        context,
        data is String && data.isNotEmpty
            ? data
            : 'Could not update the request.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.error(context, 'Something went wrong.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final account = r.influencerAccount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Fmt.platformIcon(account?.accountType),
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  account?.title ?? 'Your channel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StatusBadge(status: r.status),
            ],
          ),
          PromotionBriefDetails(request: r),
          if ((r.promotionText ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              r.promotionText!,
              style: const TextStyle(
                color: AppColors.neutral700,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
          if (r.dateList.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.event_outlined,
                  size: 15,
                  color: AppColors.neutral500,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    r.dateList.map(Fmt.date).join(', '),
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
          if (_actionable) ...[
            const SizedBox(height: 14),
            if (_busy)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: DotsLoading(color: AppColors.primary),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _act('DISAPPROVE'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB91C1C),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _act('APPROVE'),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

/// Shimmering placeholders with the same layout as the request cards: channel
/// row with status, the brief lines, the dates and the two action buttons.
class _RequestSkeletons extends StatelessWidget {
  const _RequestSkeletons();

  @override
  Widget build(BuildContext context) {
    const base = kSkeletonBase;

    Widget card() => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 18, height: 18, radius: 5, color: base),
              SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SkeletonBox(width: 140, height: 16, radius: 6, color: base),
                ),
              ),
              SkeletonBox(width: 86, height: 26, radius: 13, color: base),
            ],
          ),
          SizedBox(height: 14),
          SkeletonBox(width: double.infinity, height: 13, radius: 6, color: base),
          SizedBox(height: 8),
          SkeletonBox(width: 220, height: 13, radius: 6, color: base),
          SizedBox(height: 14),
          SkeletonBox(width: 150, height: 12, radius: 6, color: base),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SkeletonBox(width: double.infinity, height: 44, radius: 22, color: base),
              ),
              SizedBox(width: 12),
              Expanded(
                child: SkeletonBox(width: double.infinity, height: 44, radius: 22, color: base),
              ),
            ],
          ),
        ],
      ),
    );

    return Semantics(
      label: 'Loading requests',
      child: ExcludeSemantics(
        child: Shimmer(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
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