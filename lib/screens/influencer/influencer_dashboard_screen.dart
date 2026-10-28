import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';

/// The influencer "Channels" tab: shows the account list directly with a
/// floating + to add a new channel. No intermediate hub screen.
class InfluencerDashboardScreen extends ConsumerWidget {
  const InfluencerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(myAccountsProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: Stack(
        children: [
          Column(
            children: [
              const SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'My channels',
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
                child: accounts.when(
                  loading: () => const LoadingView(),
                  error: (e, _) => ErrorView(
                    message: 'Could not load your channels.',
                    onRetry: () => ref.invalidate(myAccountsProvider),
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return const EmptyView(
                        icon: Icons.storefront_outlined,
                        message:
                            'No channels yet.\nTap the + to list your first one.',
                      );
                    }
                    return RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () async => ref.invalidate(myAccountsProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: list.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, i) => _ChannelCard(account: list[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          // Add button overlaid above the floating nav bar.
          Positioned(
            right: 16,
            bottom: 120,
            child: FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => context.push('/influencer/accounts/new'),
              icon: const Icon(Icons.add),
              label: const Text('Add channel'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.account});
  final InfluencerAccount account;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: account.accountPublicId == null
            ? null
            : () => context.push('/channel/${account.accountPublicId}'),
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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Fmt.platformColor(
                        account.accountType,
                      ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Fmt.platformIcon(account.accountType),
                      color: Fmt.platformColor(account.accountType),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.title ?? 'Untitled',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.neutral900,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                  _ApprovalBadge(account: account),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.group_outlined,
                    size: 15,
                    color: AppColors.neutral500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${Fmt.compact(account.audienceCount)} audience',
                    style: const TextStyle(
                      color: AppColors.neutral600,
                      fontSize: 12.5,
                    ),
                  ),
                  const Spacer(),
                  if (account.lowestCost != null)
                    Text(
                      'from ${Fmt.birr(account.lowestCost!)}',
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

class _ApprovalBadge extends StatelessWidget {
  const _ApprovalBadge({required this.account});
  final InfluencerAccount account;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = account.approved
        ? ('Approved', const Color(0xFFECFDF5), const Color(0xFF047857))
        : ('Pending', const Color(0xFFFFF7ED), AppColors.accentHover);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
