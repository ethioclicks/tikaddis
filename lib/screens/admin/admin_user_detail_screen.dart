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
import '../../widgets/creator_profile_card.dart';
import '../../widgets/dots_loading.dart';
import '../../widgets/platform_logo.dart';
import '../../widgets/shimmer.dart';

const Color _ink = Color(0xFF111111);

/// Everything an admin needs to review one user, typically a pending creator
/// application: the creator profile they wrote (photo, headline, biography,
/// photos), their contact details, their channels, and the decision buttons.
class AdminUserDetailScreen extends ConsumerStatefulWidget {
  const AdminUserDetailScreen({super.key, required this.userId});

  /// The user's public id.
  final String userId;

  @override
  ConsumerState<AdminUserDetailScreen> createState() =>
      _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen> {
  bool _busy = false;

  Future<void> _decide(String option) async {
    final approve = option == 'APPROVE';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Make influencer?' : 'Reject application?'),
        content: Text(
          approve
              ? 'They will be able to list channels and receive promotion requests.'
              : 'Their application will be declined. They can apply again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: approve
                  ? AppColors.primary
                  : const Color(0xFFB91C1C),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Make influencer' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(apiServiceProvider)
          .adminApproveInfluencer(widget.userId, option);
      ref.invalidate(adminUserDetailProvider(widget.userId));
      ref.invalidate(adminUsersByRoleProvider('CANDIDATE'));
      ref.invalidate(adminUsersByRoleProvider('INFLUENCER'));
      ref.invalidate(adminUsersProvider);
      if (!mounted) return;
      AppToast.success(
        context,
        approve ? 'Approved as influencer.' : 'Application rejected.',
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      AppToast.error(
        context,
        data is String && data.isNotEmpty ? data : 'Action failed.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(adminUserDetailProvider(widget.userId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          detail.valueOrNull?.isCandidate == true
              ? 'Application'
              : 'User details',
        ),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/admin/users'),
        ),
      ),
      body: detail.when(
        loading: () => const _DetailSkeleton(),
        error: (e, _) => ErrorView(
          message: 'Could not load this user.',
          onRetry: () => ref.invalidate(adminUserDetailProvider(widget.userId)),
        ),
        data: (u) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(adminUserDetailProvider(widget.userId));
            try {
              await ref.read(adminUserDetailProvider(widget.userId).future);
            } catch (_) {
              // The error view takes over.
            }
          },
          child: _Body(
            user: u,
            busy: _busy,
            onApprove: () => _decide('APPROVE'),
            onReject: () => _decide('DISAPPROVE'),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.user,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final AdminUserDetail user;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final u = user;
    final name = u.fullName.isNotEmpty ? u.fullName : (u.phone ?? 'User');
    final approvedChannels = u.channels.where((c) => c.approved).length;
    final audience = u.channels.fold<int>(0, (s, c) => s + c.audienceCount);

    return ListView(
      physics: const ClampingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        // The profile exactly as brands will see it.
        CreatorProfileCard(
          name: name,
          headline: u.headline,
          biography: u.biography,
          avatarUrl: u.profileImageUrl,
          gallery: u.galleryImages,
          badge: _StatusChip(user: u),
          emptyHint: u.isCandidate
              ? 'This applicant has not written a biography.'
              : 'No biography.',
          stats: [
            ProfileStat(
              '${u.channels.length}',
              u.channels.length == 1 ? 'Channel' : 'Channels',
              icon: Icons.storefront_outlined,
            ),
            ProfileStat(
              '$approvedChannels',
              'Approved',
              icon: Icons.verified_outlined,
            ),
            ProfileStat(
              Fmt.compact(audience),
              'Audience',
              icon: Icons.group_outlined,
            ),
          ],
        ),
        if (!u.hasProfile) ...[
          const SizedBox(height: 12),
          const _Notice(
            'No creator profile yet: no photo, headline or biography.',
          ),
        ],

        const SizedBox(height: 26),
        const _Heading('Contact'),
        const SizedBox(height: 10),
        _InfoRow(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: u.phone,
        ),
        _InfoRow(icon: Icons.mail_outline, label: 'Email', value: u.email),
        _InfoRow(
          icon: Icons.event_outlined,
          label: 'Joined',
          value: u.createdOn == null ? null : Fmt.date(u.createdOn!),
        ),
        _InfoRow(
          icon: Icons.shield_outlined,
          label: 'Account',
          value: [
            u.enabled ? 'Active' : 'Disabled',
            if (u.locked) 'Locked',
          ].join(' · '),
        ),

        const SizedBox(height: 26),
        _Heading(
          u.channels.isEmpty ? 'Channels' : 'Channels (${u.channels.length})',
        ),
        const SizedBox(height: 10),
        if (u.channels.isEmpty)
          const _Notice('No channels listed yet.')
        else
          for (final c in u.channels) _ChannelRow(account: c),

        if (u.isCandidate) ...[
          const SizedBox(height: 26),
          const _Heading('Decision'),
          const SizedBox(height: 12),
          if (busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: DotsLoading(color: AppColors.primary),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB91C1C),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Make influencer'),
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.user});
  final AdminUserDetail user;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = user.isAdmin
        ? ('Admin', const Color(0xFFEFF6FF), const Color(0xFF1D4ED8))
        : user.isInfluencer
        ? ('Influencer', const Color(0xFFECFDF5), const Color(0xFF047857))
        : user.isCandidate
        ? ('Pending approval', const Color(0xFFFFF7ED), AppColors.accentHover)
        : ('Member', AppColors.neutral100, AppColors.neutral600);
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

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: _ink,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.neutral100,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.neutral600, fontSize: 13.5),
    ),
  );
}

/// One contact / account fact in a soft grey row.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final v = (value ?? '').isEmpty ? 'Not provided' : value!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.neutral600),
                const SizedBox(width: 12),
                SizedBox(
                  width: 70,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.neutral500,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    v,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ),
    );
  }
}

/// One of the user's channels; opens the admin channel review page.
class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.account});
  final InfluencerAccount account;

  @override
  Widget build(BuildContext context) {
    final pColor = Fmt.platformColor(account.accountType);
    final id = account.accountPublicId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: id == null ? null : () => context.push('/admin/channel/$id'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: AppImage(
                      account.imageURL,
                      fallback: Container(
                        color: Colors.white,
                        alignment: Alignment.center,
                        child: PlatformLogo(
                          account.accountType,
                          size: 24,
                          color: pColor,
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
                        account.title ?? 'Channel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          account.accountType?.label,
                          '${Fmt.compact(account.audienceCount)} followers',
                        ].where((s) => (s ?? '').isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.neutral500,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: account.approved
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    account.approved ? 'Approved' : 'Pending',
                    style: TextStyle(
                      color: account.approved
                          ? const Color(0xFF047857)
                          : AppColors.accentHover,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmering placeholder with the same layout: profile card, contact rows,
/// channel rows and the two decision buttons.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    const base = kSkeletonBase;

    Widget row(double h) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SkeletonBox(height: h, radius: 16, color: base),
    );

    return Semantics(
      label: 'Loading user',
      child: ExcludeSemantics(
        child: Shimmer(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.neutral200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 112, radius: 22, color: base),
                    SizedBox(height: 14),
                    SkeletonBox(width: 160, height: 20, radius: 7, color: base),
                    SizedBox(height: 8),
                    SkeletonBox(width: 200, height: 13, radius: 6, color: base),
                    SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        SkeletonBox(width: 56, height: 36, radius: 8, color: base),
                        SkeletonBox(width: 56, height: 36, radius: 8, color: base),
                        SkeletonBox(width: 56, height: 36, radius: 8, color: base),
                      ],
                    ),
                    SizedBox(height: 18),
                    SkeletonBox(height: 13, radius: 6, color: base),
                    SizedBox(height: 8),
                    SkeletonBox(width: 220, height: 13, radius: 6, color: base),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              const SkeletonBox(width: 90, height: 20, radius: 7, color: base),
              const SizedBox(height: 10),
              row(48),
              row(48),
              row(48),
              const SizedBox(height: 18),
              const SkeletonBox(width: 110, height: 20, radius: 7, color: base),
              const SizedBox(height: 10),
              row(76),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Expanded(
                    child: SkeletonBox(height: 52, radius: 26, color: base),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: SkeletonBox(height: 52, radius: 26, color: base),
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
