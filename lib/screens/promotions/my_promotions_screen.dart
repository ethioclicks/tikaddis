import '../../widgets/promotion_brief_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../widgets/app_image.dart';
import '../../widgets/shimmer.dart';

/// Business owner's promotions — editorial: bold headline, search, filter
/// tabs, and image-forward request cards.
class MyPromotionsScreen extends ConsumerStatefulWidget {
  const MyPromotionsScreen({super.key});

  @override
  ConsumerState<MyPromotionsScreen> createState() => _MyPromotionsScreenState();
}

class _MyPromotionsScreenState extends ConsumerState<MyPromotionsScreen> {
  PromotionStatus? _filter; // null = All
  String _query = '';

  static const _tabs = <(PromotionStatus?, String)>[
    (null, 'All'),
    (PromotionStatus.requested, 'Pending'),
    (PromotionStatus.running, 'Running'),
    (PromotionStatus.fulfilled, 'Done'),
    (PromotionStatus.businessCanceled, 'Canceled'),
  ];

  @override
  Widget build(BuildContext context) {
    // Fetch unfiltered and filter client-side (works with demo data too).
    final promotions = ref.watch(myPromotionsProvider(null));

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(myPromotionsProvider(null));
          try {
            await ref.read(myPromotionsProvider(null).future);
          } catch (_) {
            // The error view takes over; nothing to do here.
          }
        },
        child: promotions.when(
          // While loading, the page (title, search, filters) is already there
          // and only the cards shimmer.
          loading: () => _list(null),
          error: (e, _) => ErrorView(
            message: 'Could not load your promotions.',
            onRetry: () => ref.invalidate(myPromotionsProvider(null)),
          ),
          data: _list,
        ),
      ),
    );
  }

  /// The page. [all] is null while the promotions are still loading.
  Widget _list(List<PromotionRequest>? all) {
            final q = _query.trim().toLowerCase();
            final rows = (all ?? const <PromotionRequest>[]).where((r) {
              final matchesStatus = _filter == null || r.status == _filter;
              final title = (r.influencerAccount?.title ?? '').toLowerCase();
              final text = (r.promotionText ?? '').toLowerCase();
              final matchesQuery =
                  q.isEmpty || title.contains(q) || text.contains(q);
              return matchesStatus && matchesQuery;
            }).toList();

            final activeCount = (all ?? const <PromotionRequest>[])
                .where(
                  (r) =>
                      r.status == PromotionStatus.running ||
                      r.status == PromotionStatus.adminApproved ||
                      r.status == PromotionStatus.ownerApproved,
                )
                .length;

            return ListView(
              // Pulling down never moves or stretches the page; only the
              // refresh spinner appears over the top.
              physics: const ClampingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My promotions',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.7,
                            color: AppColors.neutral900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (all == null)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 2),
                            child: Shimmer(
                              child: SkeletonBox(
                                width: 130,
                                height: 14,
                                radius: 6,
                                color: kSkeletonBase,
                              ),
                            ),
                          )
                        else
                          Text(
                            '${all.length} total  ·  $activeCount active',
                            style: const TextStyle(
                              color: AppColors.neutral500,
                              fontSize: 14,
                            ),
                          ),
                        const SizedBox(height: 18),
                        _SearchBar(
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _Tabs(
                  tabs: _tabs,
                  selected: _filter,
                  onSelected: (s) => setState(() => _filter = s),
                ),
                const SizedBox(height: 20),
                if (all == null)
                  const _PromotionSkeletons()
                else if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: EmptyView(
                      icon: Icons.campaign_outlined,
                      message: _query.isEmpty && _filter == null
                          ? 'No promotion requests yet.\nBrowse creators to send one.'
                          : 'No promotions match this filter.',
                      action: _query.isEmpty && _filter == null
                          ? ElevatedButton.icon(
                              onPressed: () => context.go('/browse'),
                              icon: const Icon(Icons.search, size: 18),
                              label: const Text('Browse creators'),
                            )
                          : null,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        for (final r in rows) ...[
                          _PromotionCard(request: r),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
              ],
            );
  }
}

/// Shimmering placeholders for the promotion cards (same size and layout).
class _PromotionSkeletons extends StatelessWidget {
  const _PromotionSkeletons();

  @override
  Widget build(BuildContext context) {
    Widget card() => Container(
      height: 162,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 46, height: 46, circle: true, color: kSkeletonBase),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 130, height: 16, radius: 6, color: kSkeletonBase),
                    SizedBox(height: 8),
                    SkeletonBox(width: 70, height: 12, radius: 6, color: kSkeletonBase),
                  ],
                ),
              ),
              SkeletonBox(width: 96, height: 28, radius: 14, color: kSkeletonBase),
            ],
          ),
          SizedBox(height: 14),
          SkeletonBox(width: 180, height: 13, radius: 6, color: kSkeletonBase),
          Spacer(),
          Row(
            children: [
              SkeletonBox(width: 150, height: 13, radius: 6, color: kSkeletonBase),
              Spacer(),
              SkeletonBox(width: 56, height: 15, radius: 6, color: kSkeletonBase),
            ],
          ),
        ],
      ),
    );

    return Semantics(
      label: 'Loading your promotions',
      child: ExcludeSemantics(
        child: Shimmer(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  card(),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Search ────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 15, color: AppColors.neutral900),
      decoration: InputDecoration(
        hintText: 'Search promotions',
        hintStyle: const TextStyle(color: AppColors.neutral500, fontSize: 14.5),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.neutral500,
          size: 21,
        ),
        filled: true,
        fillColor: AppColors.neutral50,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.neutral200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}

// ── Tabs ────────────────────────────────────────────────────────────────
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });
  final List<(PromotionStatus?, String)> tabs;
  final PromotionStatus? selected;
  final ValueChanged<PromotionStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: tabs.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (status, label) = tabs[i];
          final active = status == selected;
          return GestureDetector(
            onTap: () => onSelected(status),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active ? AppColors.primary : AppColors.neutral200,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : AppColors.neutral600,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Promotion card ──────────────────────────────────────────────────────
class _PromotionCard extends StatelessWidget {
  const _PromotionCard({required this.request});
  final PromotionRequest request;

  @override
  Widget build(BuildContext context) {
    final account = request.influencerAccount;
    final hasImage = (account?.imageURL ?? '').isNotEmpty;
    final pColor = Fmt.platformColor(account?.accountType);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.neutral200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Creator avatar.
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: pColor.withValues(alpha: 0.10),
                      image: hasImage
                          ? DecorationImage(
                              image: NetworkImage(mediaUrl(account!.imageURL)!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: hasImage
                        ? null
                        : Icon(
                            Fmt.platformIcon(account?.accountType),
                            color: pColor,
                            size: 20,
                          ),
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: pColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(
                        Fmt.platformIcon(account?.accountType),
                        color: Colors.white,
                        size: 9,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account?.title ?? 'Creator',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.neutral900,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account?.accountType?.label ?? '',
                      style: const TextStyle(
                        color: AppColors.neutral500,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: request.status),
            ],
          ),
          PromotionBriefDetails(request: request),
          if ((request.promotionText ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.neutral100),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.event_rounded,
                size: 15,
                color: AppColors.neutral500,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  request.dateList.isNotEmpty
                      ? request.dateList.map(Fmt.date).join(', ')
                      : 'No dates set',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.neutral600,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (account?.lowestCost != null)
                Text(
                  Fmt.birr(account!.lowestCost!),
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
            ],
          ),
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
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 14,
                    color: AppColors.neutral500,
                  ),
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
