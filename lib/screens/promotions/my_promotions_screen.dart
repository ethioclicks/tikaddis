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
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async =>
            ref.invalidate(myPromotionsProvider(_filter?.wire)),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            const CollapsingTitleBar(title: 'My promotions'),
            SliverPersistentHeader(
              pinned: true,
              delegate: _FilterHeaderDelegate(
                child: _FilterBar(
                  selected: _filter,
                  onSelected: (s) => setState(() => _filter = s),
                ),
              ),
            ),
            promotions.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: LoadingView(),
              ),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorView(
                  message: 'Could not load your promotions.',
                  onRetry: () =>
                      ref.invalidate(myPromotionsProvider(_filter?.wire)),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(
                      icon: Icons.campaign_outlined,
                      message:
                          'No promotion requests yet.\nBrowse creators to send one.',
                      action: ElevatedButton.icon(
                        onPressed: () => context.go('/browse'),
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('Browse creators'),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList.separated(
                    itemCount: list.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (_, i) => _PromotionCard(request: list[i]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps the filter chips pinned below the collapsing title while scrolling.
class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  _FilterHeaderDelegate({required this.child});
  final Widget child;

  static const double _height = 60;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: AppColors.neutral50, child: child);
  }

  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) =>
      oldDelegate.child != child;
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});
  final PromotionStatus? selected;
  final ValueChanged<PromotionStatus?> onSelected;

  // A sensible subset for business owners to filter by, each with an icon.
  static const _options = <(PromotionStatus?, IconData)>[
    (null, Icons.apps_rounded),
    (PromotionStatus.requested, Icons.schedule_rounded),
    (PromotionStatus.ownerApproved, Icons.check_circle_outline),
    (PromotionStatus.running, Icons.bolt_rounded),
    (PromotionStatus.fulfilled, Icons.task_alt_rounded),
    (PromotionStatus.businessCanceled, Icons.cancel_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        itemCount: _options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final (opt, icon) = _options[i];
          final isSel = opt == selected;
          return GestureDetector(
            onTap: () => onSelected(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSel ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSel ? AppColors.primary : AppColors.neutral200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: isSel ? Colors.white : AppColors.neutral500,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    opt?.label ?? 'All',
                    style: TextStyle(
                      color: isSel ? Colors.white : AppColors.neutral700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
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
