import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';

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
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load this channel.',
          onRetry: () => ref.invalidate(accountDetailProvider(accountId)),
        ),
        data: (account) => _Detail(account: account),
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
            'listings. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Channel deleted.'),
          backgroundColor: AppColors.primary,
        ),
      );
      context.go('/browse');
    } on DioException catch (e) {
      if (!context.mounted) return;
      final data = e.response?.data;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data is String && data.isNotEmpty
              ? data
              : 'Could not delete the channel.'),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Fmt.platformColor(account.accountType);
    final color2 = Fmt.platformColor2(account.accountType);

    return CustomScrollView(
      slivers: [
        // Platform-themed hero header.
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.fromLTRB(
                16, MediaQuery.of(context).padding.top + 8, 16, 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color2],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () => context.push(
                        '/influencer/accounts/edit',
                        extra: account,
                      ),
                      icon: const Icon(Icons.edit_outlined,
                          color: Colors.white),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () => _delete(context, ref),
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Fmt.platformIcon(account.accountType),
                          color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.title ?? 'Untitled',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            account.accountType?.label ?? '',
                            style: const TextStyle(
                              color: Color(0xE6FFFFFF),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ApprovalPill(approved: account.approved),
              ],
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: SliverList.list(
            children: [
              if ((account.description ?? '').isNotEmpty) ...[
                _CardSection(
                  child: Text(
                    account.description!,
                    style: const TextStyle(
                      color: AppColors.neutral700,
                      fontSize: 14.5,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.group_outlined,
                      value: Fmt.compact(account.audienceCount),
                      label: 'Audience',
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.visibility_outlined,
                      value: account.maxViewPerPostCount > 0
                          ? '${Fmt.compact(account.minViewPerPostCount)}–${Fmt.compact(account.maxViewPerPostCount)}'
                          : '—',
                      label: 'Views / post',
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if ((account.accountURL ?? '').isNotEmpty)
                _CardSection(
                  child: Row(
                    children: [
                      Icon(Icons.link, size: 20, color: color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          account.accountURL!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.neutral700,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
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
                const Text('No pricing listed.',
                    style: TextStyle(color: AppColors.neutral500))
              else
                ...account.priceOptions.map((p) => _PriceRow(option: p)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ApprovalPill extends StatelessWidget {
  const _ApprovalPill({required this.approved});
  final bool approved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(approved ? Icons.verified : Icons.schedule,
              size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            approved ? 'Approved' : 'Pending approval',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: child,
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.neutral900,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(label,
              style: const TextStyle(
                  color: AppColors.neutral500, fontSize: 12.5)),
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
                Text(option.priceType?.label ?? 'Price',
                    style: const TextStyle(
                        color: AppColors.neutral900,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600)),
                if ((option.remark ?? '').isNotEmpty)
                  Text(option.remark!,
                      style: const TextStyle(
                          color: AppColors.neutral500, fontSize: 12.5)),
              ],
            ),
          ),
          Text(Fmt.birr(option.cost),
              style: const TextStyle(
                  color: AppColors.accentHover,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
