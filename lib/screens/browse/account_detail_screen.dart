import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';

class AccountDetailScreen extends ConsumerWidget {
  final String accountId; // accountPublicId
  const AccountDetailScreen({super.key, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(accountDetailProvider(accountId));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: detail.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load this creator.',
          onRetry: () => ref.invalidate(accountDetailProvider(accountId)),
        ),
        data: (account) => _Detail(account: account),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.account});
  final InfluencerAccount account;

  @override
  Widget build(BuildContext context) {
    final pColor = Fmt.platformColor(account.accountType);
    final lowest = account.lowestCost;

    return Stack(
      children: [
        CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            // ── Photo hero + stats strip (one block, no fragile overlap) ─
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _Hero(account: account, color: pColor),
                  Transform.translate(
                    offset: const Offset(0, -28),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: _StatsStrip(account: account),
                    ),
                  ),
                ],
              ),
            ),

            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    if ((account.description ?? '').isNotEmpty) ...[
                      const _SectionTitle('About'),
                      const SizedBox(height: 10),
                      Text(
                        account.description!,
                        style: const TextStyle(
                          color: AppColors.neutral700,
                          fontSize: 14.5,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Engagement highlight bar.
                    _EngagementCard(account: account, color: pColor),
                    const SizedBox(height: 24),

                    const _SectionTitle('Pricing'),
                    const SizedBox(height: 12),
                    if (account.priceOptions.isEmpty)
                      const Text('No pricing listed.',
                          style: TextStyle(color: AppColors.neutral500))
                    else
                      ...account.priceOptions
                          .map((p) => _PriceCard(option: p)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // ── Back button over the hero ─────────────────────────────────
        Positioned(
          top: MediaQuery.of(context).padding.top + 6,
          left: 10,
          child: _CircleButton(
            icon: Icons.arrow_back,
            onTap: () => context.pop(),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 6,
          right: 10,
          child: _CircleButton(
            icon: Icons.share_outlined,
            onTap: () {},
          ),
        ),

        // ── Sticky bottom CTA ──────────────────────────────────────────
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(
                  top: BorderSide(color: AppColors.neutral200)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Starting from',
                            style: TextStyle(
                                color: AppColors.neutral500, fontSize: 11.5)),
                        const SizedBox(height: 1),
                        Text(
                          lowest != null ? Fmt.birr(lowest) : '—',
                          style: const TextStyle(
                            color: AppColors.neutral900,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.campaign_rounded, size: 19),
                          onPressed: account.accountPublicId == null
                              ? null
                              : () => context.push(
                                    '/browse-detail/${account.accountPublicId}/promote',
                                    extra: account,
                                  ),
                          label: const Text('Request promotion'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Photo hero with scrim + overlaid identity ──────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero({required this.account, required this.color});
  final InfluencerAccount account;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final url = account.imageURL ?? '';
    return SizedBox(
      height: 340,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url.isNotEmpty)
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                color: color.withValues(alpha: 0.18),
                alignment: Alignment.center,
                child: Icon(Fmt.platformIcon(account.accountType),
                    color: color, size: 64),
              ),
            )
          else
            Container(
              color: color.withValues(alpha: 0.18),
              alignment: Alignment.center,
              child: Icon(Fmt.platformIcon(account.accountType),
                  color: color, size: 64),
            ),

          // Scrim.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.78),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Identity.
          Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Fmt.platformIcon(account.accountType),
                              color: color, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            account.accountType?.label ?? '',
                            style: const TextStyle(
                              color: AppColors.neutral900,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if ((account.category?.categoryName ?? '').isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          account.category!.categoryName!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        account.title ?? 'Creator',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                    if (account.verified) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.verified_rounded,
                          color: Colors.white, size: 22),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Floating stats strip ────────────────────────────────────────────────
class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.account});
  final InfluencerAccount account;

  @override
  Widget build(BuildContext context) {
    final views = account.maxViewPerPostCount > 0
        ? '${Fmt.compact(account.minViewPerPostCount)}–${Fmt.compact(account.maxViewPerPostCount)}'
        : '—';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatCell(
              value: Fmt.compact(account.audienceCount), label: 'Followers'),
          const _Sep(),
          _StatCell(value: views, label: 'Views / post'),
          const _Sep(),
          _StatCell(
            value: account.verified ? 'Yes' : 'No',
            label: 'Verified',
            highlight: account.verified,
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    this.highlight = false,
  });
  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: highlight ? AppColors.primary : AppColors.neutral900,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.neutral500,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 34, color: AppColors.neutral100);
}

// ── Engagement highlight card ───────────────────────────────────────────
class _EngagementCard extends StatelessWidget {
  const _EngagementCard({required this.account, required this.color});
  final InfluencerAccount account;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // A simple illustrative engagement rate from the demo numbers.
    final reach = account.audienceCount == 0
        ? 0.0
        : (account.maxViewPerPostCount / account.audienceCount)
            .clamp(0.0, 1.0);
    final pct = (reach * 100).clamp(1, 99).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.trending_up_rounded, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$pct% avg. reach per post',
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Strong, consistent engagement',
                  style: TextStyle(
                      color: AppColors.neutral600, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: AppColors.neutral900,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      );
}

// ── Circle icon button (for hero overlay) ───────────────────────────────
class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: AppColors.neutral900, size: 21),
        ),
      ),
    );
  }
}

// ── Pricing card ─────────────────────────────────────────────────────────
class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.option});
  final PriceOptions option;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.sell_rounded,
                color: AppColors.accentHover, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.priceType?.label ?? 'Price',
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((option.remark ?? '').isNotEmpty)
                  Text(
                    option.remark!,
                    style: const TextStyle(
                        color: AppColors.neutral500, fontSize: 12.5),
                  ),
              ],
            ),
          ),
          Text(
            Fmt.birr(option.cost),
            style: const TextStyle(
              color: AppColors.neutral900,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}
