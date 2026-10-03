import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';

/// Admin: review all promotion requests and move them through the pipeline.
class AdminPromotionsScreen extends ConsumerStatefulWidget {
  const AdminPromotionsScreen({super.key});

  @override
  ConsumerState<AdminPromotionsScreen> createState() =>
      _AdminPromotionsScreenState();
}

class _AdminPromotionsScreenState
    extends ConsumerState<AdminPromotionsScreen> {
  PromotionStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final promos = ref.watch(adminPromotionsProvider(_filter?.wire));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: Column(
        children: [
          const SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Promotions',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.neutral900)),
              ),
            ),
          ),
          _Filter(
            selected: _filter,
            onSelected: (s) => setState(() => _filter = s),
          ),
          Expanded(
            child: promos.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: 'Could not load promotion requests.',
                onRetry: () =>
                    ref.invalidate(adminPromotionsProvider(_filter?.wire)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyView(
                      icon: Icons.campaign_outlined,
                      message: 'No promotion requests here.');
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async =>
                      ref.invalidate(adminPromotionsProvider(_filter?.wire)),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: list.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (_, i) => _AdminPromoCard(
                      request: list[i],
                      onChanged: () => ref
                          .invalidate(adminPromotionsProvider(_filter?.wire)),
                    ),
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

class _AdminPromoCard extends ConsumerStatefulWidget {
  const _AdminPromoCard({required this.request, required this.onChanged});
  final PromotionRequest request;
  final VoidCallback onChanged;

  @override
  ConsumerState<_AdminPromoCard> createState() => _AdminPromoCardState();
}

class _AdminPromoCardState extends ConsumerState<_AdminPromoCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String okMsg) async {
    setState(() => _busy = true);
    try {
      await action();
      widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(okMsg), backgroundColor: AppColors.primary));
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final data = e.response?.data;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(data is String && data.isNotEmpty
            ? data
            : 'Action failed.'),
        backgroundColor: const Color(0xFFB91C1C),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final id = r.promotionRequestPublicId;
    final api = ref.read(apiServiceProvider);
    final status = r.status;

    // Which admin actions apply at this stage.
    final canAdminApprove = status == PromotionStatus.requested;
    final canRun = status == PromotionStatus.ownerApproved;
    final canFulfill = status == PromotionStatus.running;

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
              Icon(Fmt.platformIcon(r.influencerAccount?.accountType),
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(r.influencerAccount?.title ?? 'Channel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.neutral900,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
              StatusBadge(status: status),
            ],
          ),
          if ((r.promotionText ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(r.promotionText!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.neutral600, fontSize: 13.5, height: 1.4)),
          ],
          if (r.dateList.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.event_outlined,
                  size: 15, color: AppColors.neutral500),
              const SizedBox(width: 6),
              Expanded(
                child: Text(r.dateList.map(Fmt.date).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.neutral500, fontSize: 12.5)),
              ),
            ]),
          ],
          if (id != null &&
              (canAdminApprove || canRun || canFulfill)) ...[
            const SizedBox(height: 14),
            if (_busy)
              const Center(
                  child: SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4)))
            else if (canAdminApprove)
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _run(
                        () => api.adminApproveRejectPromotion(id, 'DISAPPROVE'),
                        'Request rejected.'),
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
                    onPressed: () => _run(
                        () => api.adminApproveRejectPromotion(id, 'APPROVE'),
                        'Request approved.'),
                    child: const Text('Approve'),
                  ),
                ),
              ])
            else if (canRun)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _run(
                      () => api.adminTransitionRunning(id),
                      'Promotion is now running.'),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Mark as running'),
                ),
              )
            else if (canFulfill)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _run(
                      () => api.adminTransitionFulfilled(id),
                      'Promotion fulfilled.'),
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: const Text('Mark as fulfilled'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({required this.selected, required this.onSelected});
  final PromotionStatus? selected;
  final ValueChanged<PromotionStatus?> onSelected;

  static const _options = <PromotionStatus?>[
    null,
    PromotionStatus.requested,
    PromotionStatus.ownerApproved,
    PromotionStatus.running,
    PromotionStatus.fulfilled,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
        itemCount: _options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final opt = _options[i];
          final sel = opt == selected;
          return GestureDetector(
            onTap: () => onSelected(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: sel ? AppColors.primary : AppColors.neutral200),
              ),
              child: Text(opt?.label ?? 'All',
                  style: TextStyle(
                      color: sel ? Colors.white : AppColors.neutral700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          );
        },
      ),
    );
  }
}
