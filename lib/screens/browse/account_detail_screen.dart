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
      appBar: AppBar(title: const Text('Creator')),
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
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Fmt.platformIcon(account.accountType),
                        size: 30, color: AppColors.primary),
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
                                account.title ?? 'Untitled',
                                style: const TextStyle(
                                  color: AppColors.neutral900,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            if (account.verified) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.verified,
                                  size: 18, color: AppColors.primary),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            account.accountType?.label,
                            account.category?.categoryName,
                          ].where((e) => e != null).join(' · '),
                          style: const TextStyle(
                            color: AppColors.neutral500,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if ((account.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  account.description!,
                  style: const TextStyle(
                    color: AppColors.neutral700,
                    fontSize: 14.5,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _StatTiles(account: account),
              const SizedBox(height: 24),
              const Text(
                'Pricing',
                style: TextStyle(
                  color: AppColors.neutral900,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (account.priceOptions.isEmpty)
                const Text(
                  'No pricing listed.',
                  style: TextStyle(color: AppColors.neutral500),
                )
              else
                ...account.priceOptions.map((p) => _PriceRow(option: p)),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.campaign_outlined, size: 20),
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
        ),
      ],
    );
  }
}

class _StatTiles extends StatelessWidget {
  const _StatTiles({required this.account});
  final InfluencerAccount account;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Tile(
            icon: Icons.group_outlined,
            value: Fmt.compact(account.audienceCount),
            label: 'Audience',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Tile(
            icon: Icons.visibility_outlined,
            value: account.maxViewPerPostCount > 0
                ? '${Fmt.compact(account.minViewPerPostCount)}–${Fmt.compact(account.maxViewPerPostCount)}'
                : '—',
            label: 'Views / post',
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.neutral900,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.neutral500,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.option});
  final PriceOptions option;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.priceType?.label ?? 'Price',
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if ((option.remark ?? '').isNotEmpty)
                  Text(
                    option.remark!,
                    style: const TextStyle(
                      color: AppColors.neutral500,
                      fontSize: 12.5,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            Fmt.birr(option.cost),
            style: const TextStyle(
              color: AppColors.accentHover,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
