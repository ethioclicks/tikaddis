import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/app_image.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/dots_loading.dart';

/// Sort choices for the admin channel list: (label, Spring sort expression).
const List<(String, String)> _sortOptions = [
  ('Name A–Z', 'title,asc'),
  ('Name Z–A', 'title,desc'),
  ('Newest first', 'id,desc'),
  ('Oldest first', 'id,asc'),
];

/// Admin: review influencer channels, open their details, approve or
/// disapprove them, and choose which ones are featured.
class AdminChannelsScreen extends ConsumerStatefulWidget {
  const AdminChannelsScreen({super.key});

  @override
  ConsumerState<AdminChannelsScreen> createState() =>
      _AdminChannelsScreenState();
}

class _AdminChannelsScreenState extends ConsumerState<AdminChannelsScreen> {
  String _status = 'ALL'; // ALL / APPROVED / DISAPPROVED
  String _sort = _sortOptions.first.$2; // ascending by name

  AdminAccountsQuery get _query => (_status, _sort);

  String get _sortLabel =>
      _sortOptions.firstWhere((o) => o.$2 == _sort).$1;

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(adminAccountsProvider(_query));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Channels',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.neutral900,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/admin/channel-options'),
                    icon: const Icon(Icons.tune),
                    label: const Text('Options'),
                  ),
                ],
              ),
            ),
          ),
          _StatusFilter(
            value: _status,
            options: const ['ALL', 'APPROVED', 'DISAPPROVED'],
            onChanged: (v) => setState(() => _status = v),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    accounts.maybeWhen(
                      data: (l) =>
                          '${l.length} ${l.length == 1 ? 'channel' : 'channels'}',
                      orElse: () => '',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.neutral500,
                      fontSize: 13,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Sort channels',
                  initialValue: _sort,
                  onSelected: (v) => setState(() => _sort = v),
                  itemBuilder: (_) => [
                    for (final o in _sortOptions)
                      PopupMenuItem(value: o.$2, child: Text(o.$1)),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sort_rounded,
                          size: 18,
                          color: AppColors.neutral700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _sortLabel,
                          style: const TextStyle(
                            color: AppColors.neutral700,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.neutral700,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: accounts.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: 'Could not load channels.',
                onRetry: () => ref.invalidate(adminAccountsProvider(_query)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyView(
                    icon: Icons.storefront_outlined,
                    message: 'No channels in this view.',
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async =>
                      ref.invalidate(adminAccountsProvider(_query)),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: list.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (_, i) => _AdminChannelCard(
                      key: ValueKey(list[i].accountPublicId),
                      account: list[i],
                      onChanged: () {
                        ref.invalidate(adminAccountsProvider);
                        ref.invalidate(myAccountsProvider);
                        ref.invalidate(approvedAccountsProvider);
                        ref.invalidate(featuredAccountsProvider);
                        if (list[i].accountPublicId != null) {
                          ref.invalidate(
                            accountDetailProvider(list[i].accountPublicId!),
                          );
                        }
                      },
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
  const _AdminChannelCard({
    super.key,
    required this.account,
    required this.onChanged,
  });
  final InfluencerAccount account;
  final VoidCallback onChanged;

  @override
  ConsumerState<_AdminChannelCard> createState() => _AdminChannelCardState();
}

class _AdminChannelCardState extends ConsumerState<_AdminChannelCard> {
  bool _busy = false;
  bool? _approved;
  bool? _featured;

  @override
  void didUpdateWidget(covariant _AdminChannelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account.approved != widget.account.approved) _approved = null;
    if (oldWidget.account.featured != widget.account.featured) {
      _featured = null;
    }
  }

  String _errorText(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is String && data.isNotEmpty) return data;
    if (data is Map && data['message'] != null) {
      final text = data['message'].toString().replaceFirst('Cause by:', '').trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  Future<void> _act(String option) async {
    final id = widget.account.accountPublicId;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiServiceProvider).adminApproveAccount(id, option);
      if (!mounted) return;
      setState(() {
        _approved = option == 'APPROVE';
        // Disapproving also removes a channel from the featured list.
        if (option != 'APPROVE') _featured = false;
      });
      widget.onChanged();
      AppToast.success(
        context,
        option == 'APPROVE' ? 'Channel approved.' : 'Channel disapproved.',
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.error(context, _errorText(e, 'Could not update the channel.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFeatured(bool next) async {
    final id = widget.account.accountPublicId;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiServiceProvider).adminFeatureAccount(id, next);
      if (!mounted) return;
      setState(() => _featured = next);
      widget.onChanged();
      AppToast.success(
        context,
        next ? 'Channel featured.' : 'Removed from featured.',
      );
    } on DioException catch (e) {
      if (!mounted) return;
      AppToast.error(context, _errorText(e, 'Could not update featured.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    final approved = _approved ?? a.approved;
    final featured = _featured ?? a.featured;
    final id = a.accountPublicId;
    final platformColor = Fmt.platformColor(a.accountType);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: id == null ? null : () => context.push('/admin/channel/$id'),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: AppImage(
                        a.imageURL,
                        fallback: Container(
                          color: platformColor.withValues(alpha: 0.12),
                          child: Icon(
                            Fmt.platformIcon(a.accountType),
                            color: platformColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.title ?? 'Untitled',
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
                            a.accountType?.label,
                            a.category?.categoryName,
                          ].where((e) => e != null).join(' · '),
                          style: const TextStyle(
                            color: AppColors.neutral500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Pill(
                    text: approved ? 'Approved' : 'Not approved',
                    approved: approved,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Wraps onto a second line on narrow phones instead of overflowing.
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.group_outlined,
                              size: 15,
                              color: AppColors.neutral500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${Fmt.compact(a.audienceCount)} audience',
                              style: const TextStyle(
                                color: AppColors.neutral600,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                        if (a.lowestCost != null)
                          Text(
                            'from ${Fmt.birr(a.lowestCost!)}',
                            style: const TextStyle(
                              color: AppColors.accentHover,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Featured toggle: only approved channels can be featured.
                  Tooltip(
                    message: featured
                        ? 'Remove from featured'
                        : approved
                        ? 'Feature this channel'
                        : 'Approve the channel to feature it',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: _busy || (!approved && !featured)
                          ? null
                          : () => _toggleFeatured(!featured),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              featured
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 20,
                              color: featured
                                  ? AppColors.accent
                                  : approved
                                  ? AppColors.neutral500
                                  : AppColors.neutral300,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              featured ? 'Featured' : 'Feature',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: featured
                                    ? AppColors.accentHover
                                    : AppColors.neutral600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_busy)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: DotsLoading(color: AppColors.primary),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: approved ? () => _act('DISAPPROVE') : null,
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
                        onPressed: approved ? null : () => _act('APPROVE'),
                        child: Text(approved ? 'Approved' : 'Approve'),
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
    required this.value,
    required this.options,
    required this.onChanged,
  });
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
                  color: sel ? AppColors.primary : AppColors.neutral200,
                ),
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
