import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';

/// Admin: review influencer channels and approve/disapprove them.
class AdminChannelsScreen extends ConsumerStatefulWidget {
  const AdminChannelsScreen({super.key});

  @override
  ConsumerState<AdminChannelsScreen> createState() =>
      _AdminChannelsScreenState();
}

class _AdminChannelsScreenState extends ConsumerState<AdminChannelsScreen> {
  String _status = 'ALL'; // ALL / APPROVED / DISAPPROVED

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(adminAccountsProvider(_status));

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
                child: Text('Channels',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.neutral900)),
              ),
            ),
          ),
          _StatusFilter(
            value: _status,
            options: const ['ALL', 'APPROVED', 'DISAPPROVED'],
            onChanged: (v) => setState(() => _status = v),
          ),
          Expanded(
            child: accounts.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: 'Could not load channels.',
                onRetry: () => ref.invalidate(adminAccountsProvider(_status)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyView(
                      icon: Icons.storefront_outlined,
                      message: 'No channels in this view.');
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async =>
                      ref.invalidate(adminAccountsProvider(_status)),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: list.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (_, i) => _AdminChannelCard(
                      account: list[i],
                      onChanged: () =>
                          ref.invalidate(adminAccountsProvider(_status)),
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

class _AdminChannelCard extends ConsumerStatefulWidget {
  const _AdminChannelCard({required this.account, required this.onChanged});
  final InfluencerAccount account;
  final VoidCallback onChanged;

  @override
  ConsumerState<_AdminChannelCard> createState() => _AdminChannelCardState();
}

class _AdminChannelCardState extends ConsumerState<_AdminChannelCard> {
  bool _busy = false;

  Future<void> _act(String option) async {
    final id = widget.account.accountPublicId;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiServiceProvider).adminApproveAccount(id, option);
      widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(option == 'APPROVE'
            ? 'Channel approved.'
            : 'Channel disapproved.'),
        backgroundColor: AppColors.primary,
      ));
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final data = e.response?.data;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(data is String && data.isNotEmpty
            ? data
            : 'Could not update the channel.'),
        backgroundColor: const Color(0xFFB91C1C),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Fmt.platformColor(a.accountType)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Fmt.platformIcon(a.accountType),
                    color: Fmt.platformColor(a.accountType)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title ?? 'Untitled',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.neutral900,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600)),
                    Text(
                      [a.accountType?.label, a.category?.categoryName]
                          .where((e) => e != null)
                          .join(' · '),
                      style: const TextStyle(
                          color: AppColors.neutral500, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _Pill(
                text: a.approved ? 'Approved' : 'Pending',
                approved: a.approved,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.group_outlined,
                  size: 15, color: AppColors.neutral500),
              const SizedBox(width: 4),
              Text('${Fmt.compact(a.audienceCount)} audience',
                  style: const TextStyle(
                      color: AppColors.neutral600, fontSize: 12.5)),
              const Spacer(),
              if (a.lowestCost != null)
                Text('from ${Fmt.birr(a.lowestCost!)}',
                    style: const TextStyle(
                        color: AppColors.accentHover,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          if (_busy)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(4),
              child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4)),
            ))
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
                    child: const Text('Disapprove'),
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
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.approved});
  final String text;
  final bool approved;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = approved
        ? (const Color(0xFFECFDF5), const Color(0xFF047857))
        : (const Color(0xFFFFF7ED), AppColors.accentHover);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style:
              TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter(
      {required this.value, required this.options, required this.onChanged});
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final opt = options[i];
          final sel = opt == value;
          return GestureDetector(
            onTap: () => onChanged(opt),
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
              child: Text(
                opt[0] + opt.substring(1).toLowerCase(),
                style: TextStyle(
                  color: sel ? Colors.white : AppColors.neutral700,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
