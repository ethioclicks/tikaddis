import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';

class MyPromotionsScreen extends ConsumerStatefulWidget {
  const MyPromotionsScreen({super.key});

  @override
  ConsumerState<MyPromotionsScreen> createState() =>
      _MyPromotionsScreenState();
}

class _MyPromotionsScreenState extends ConsumerState<MyPromotionsScreen> {
  PromotionStatus? _filter; // null = All

  @override
  Widget build(BuildContext context) {
    final promotions = ref.watch(myPromotionsProvider(_filter?.wire));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: const Text('My promotions',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          _FilterBar(
            selected: _filter,
            onSelected: (s) => setState(() => _filter = s),
          ),
          Expanded(
            child: promotions.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: 'Could not load your promotions.',
                onRetry: () =>
                    ref.invalidate(myPromotionsProvider(_filter?.wire)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyView(
                    icon: Icons.campaign_outlined,
                    message:
                        'No promotion requests yet.\nBrowse creators to send one.',
                    action: ElevatedButton.icon(
                      onPressed: () => context.go('/browse'),
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('Browse creators'),
                    ),
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async =>
                      ref.invalidate(myPromotionsProvider(_filter?.wire)),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (_, i) =>
                        _PromotionCard(request: list[i]),
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});
  final PromotionStatus? selected;
  final ValueChanged<PromotionStatus?> onSelected;

  // A sensible subset for business owners to filter by.
  static const _options = <PromotionStatus?>[
    null,
    PromotionStatus.requested,
    PromotionStatus.ownerApproved,
    PromotionStatus.running,
    PromotionStatus.fulfilled,
    PromotionStatus.businessCanceled,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final opt = _options[i];
          final isSel = opt == selected;
          return ChoiceChip(
            label: Text(opt?.label ?? 'All'),
            selected: isSel,
            onSelected: (_) => onSelected(opt),
            showCheckmark: false,
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.neutral100,
            labelStyle: TextStyle(
              color: isSel ? Colors.white : AppColors.neutral600,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            side: BorderSide.none,
          );
        },
      ),
    );
  }
}

class _PromotionCard extends StatelessWidget {
  const _PromotionCard({required this.request});
  final PromotionRequest request;

  @override
  Widget build(BuildContext context) {
    final account = request.influencerAccount;
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
              Icon(Fmt.platformIcon(account?.accountType),
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  account?.title ?? 'Creator',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StatusBadge(status: request.status),
            ],
          ),
          if ((request.promotionText ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              request.promotionText!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.neutral600,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
          if (request.dateList.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.event_outlined,
                    size: 15, color: AppColors.neutral500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    request.dateList.map(Fmt.date).join(', '),
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
          if ((request.feedback ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.neutral50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      size: 14, color: AppColors.neutral500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      request.feedback!,
                      style: const TextStyle(
                        color: AppColors.neutral600,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
