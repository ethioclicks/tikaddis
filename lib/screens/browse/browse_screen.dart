import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';

class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(approvedAccountsProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(approvedAccountsProvider),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            const CollapsingTitleBar(title: 'Browse creators'),
            accounts.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: LoadingView(),
              ),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorView(
                  message: 'Could not load creators.',
                  onRetry: () => ref.invalidate(approvedAccountsProvider),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(
                      icon: Icons.search_off,
                      message: 'No approved creators yet.\nCheck back soon.',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList.separated(
                    itemCount: list.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (_, i) => _AccountCard(account: list[i]),
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

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account});
  final InfluencerAccount account;

  @override
  Widget build(BuildContext context) {
    final lowest = account.lowestCost;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: account.accountPublicId == null
            ? null
            : () => context.push('/browse-detail/${account.accountPublicId}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Fmt.platformIcon(account.accountType),
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                account.title ?? 'Untitled',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.neutral900,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (account.verified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified,
                                  size: 15, color: AppColors.primary),
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
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Stat(
                    icon: Icons.group_outlined,
                    label: '${Fmt.compact(account.audienceCount)} audience',
                  ),
                  const SizedBox(width: 16),
                  if (account.maxViewPerPostCount > 0)
                    _Stat(
                      icon: Icons.visibility_outlined,
                      label:
                          '${Fmt.compact(account.minViewPerPostCount)}–${Fmt.compact(account.maxViewPerPostCount)} views',
                    ),
                  const Spacer(),
                  if (lowest != null)
                    Text(
                      'from ${Fmt.birr(lowest)}',
                      style: const TextStyle(
                        color: AppColors.accentHover,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
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

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.neutral500),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.neutral600, fontSize: 12.5),
        ),
      ],
    );
  }
}
