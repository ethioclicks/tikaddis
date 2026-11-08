import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/creator_profile_card.dart';
import '../../widgets/dots_loading.dart';
import '../../widgets/shimmer.dart';
import '../../widgets/delete_account_dialog.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: Column(
        children: [
          const SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Profile',
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
            child: profile.when(
              loading: () => const _ProfileSkeleton(),
              error: (e, _) => ErrorView(
                message: 'Could not load your profile.',
                onRetry: () => ref.invalidate(profileProvider),
                action: TextButton(
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                  child: const Text('Sign in again'),
                ),
              ),
              data: (p) {
                // Reconcile cached roles with the server's truth so the UI
                // reflects role changes made since login (e.g. applied to be
                // an influencer). Deferred to avoid mutating state in build.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(authProvider.notifier).syncRoles(p.roles);
                });
                return _ProfileBody(profile: p);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmering placeholder with the same layout as the loaded profile:
/// account card, then the details, notifications and session sections.
class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  Widget _label() => const SkeletonBox(
    width: 110,
    height: 12,
    radius: 6,
    color: kSkeletonBase,
  );

  Widget _row({bool last = false}) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: AppColors.neutral200)),
    ),
    child: const Row(
      children: [
        SkeletonBox(width: 26, height: 26, radius: 8, color: kSkeletonBase),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 90, height: 16, radius: 6, color: kSkeletonBase),
              SizedBox(height: 7),
              SkeletonBox(width: 160, height: 13, radius: 6, color: kSkeletonBase),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading your profile',
      child: ExcludeSemantics(
        child: Shimmer(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            children: [
              // Account card (avatar, name, role chips).
              Container(
                height: 114,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: kSkeletonBase,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Row(
                  children: [
                    SkeletonBox(width: 78, height: 78, circle: true),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 140, height: 22, radius: 8),
                          SizedBox(height: 10),
                          SkeletonBox(width: 86, height: 26, radius: 13),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _label(),
              const SizedBox(height: 10),
              _row(),
              _row(),
              _row(last: true),
              const SizedBox(height: 24),
              _label(),
              const SizedBox(height: 10),
              _row(last: true),
              const SizedBox(height: 24),
              _label(),
              const SizedBox(height: 10),
              _row(),
              _row(last: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});
  final UserProfile profile;

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final api = ref.read(apiServiceProvider);
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteAccountDialog(
        onDelete: (password) async {
          await api.deleteOwnAccount(password);
        },
      ),
    );
    if (deleted == true && context.mounted) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _LogoutSheet(),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = profile.fullName.isNotEmpty
        ? profile.fullName
        : 'Your account';
    // Watch auth LIVE so applying to be an influencer updates this screen
    // immediately (roles change -> rebuild), no app restart needed.
    final auth = ref.watch(authProvider);
    final isLoading = auth.isLoading;
    final isCandidate = auth.roles.contains('CANDIDATE');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      children: [
        // The same profile card creators see on Home. Creators also get their
        // headline, bio and photos plus an edit button; members just get
        // their photo, name and role.
        CreatorProfileCard(
          name: name,
          headline: auth.hasCreatorHome ? profile.headline : null,
          biography: profile.biography,
          avatarUrl: profile.profileImageUrl,
          gallery: auth.hasCreatorHome ? profile.galleryImages : const [],
          style: CreatorCardStyle.gradient,
          badge: _RoleBadge(auth: auth),
          showAbout: auth.hasCreatorHome,
          onEdit: auth.hasCreatorHome
              ? () => context.push('/creator-profile')
              : null,
          emptyHint:
              'Add a short biography so brands know who you are. Tap Edit.',
        ),
        const SizedBox(height: 24),

        // Become influencer CTA (hidden for existing influencers).
        if (!auth.isInfluencer) ...[
          _BecomeInfluencerCard(
            isCandidate: isCandidate,
            isLoading: isLoading,
            // Applying starts with building the creator profile (bio + photos);
            // the application is sent when that is saved.
            onApply: () => context.push('/creator-profile?apply=1'),
          ),
          const SizedBox(height: 24),
        ],

        const _SectionLabel('Account details'),
        const SizedBox(height: 10),
        _SectionCard(
          children: [
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: profile.userName ?? '—',
            ),
            _InfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: (profile.email ?? '').isNotEmpty
                  ? profile.email!
                  : 'Not set',
            ),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: (profile.address?.display ?? '').isNotEmpty
                  ? profile.address!.display
                  : 'Not set',
              last: true,
            ),
          ],
        ),

        if (auth.isInfluencer) ...[
          const SizedBox(height: 24),
          const _SectionLabel('Creator'),
          const SizedBox(height: 10),
          _SectionCard(
            children: [
              _ActionRow(
                icon: Icons.storefront_outlined,
                title: 'Creator space',
                subtitle: 'Manage channels and incoming requests',
                onTap: () => context.go('/browse'),
                last: true,
              ),
            ],
          ),
        ],

        const SizedBox(height: 24),
        const _SectionLabel('Notifications'),
        const SizedBox(height: 10),
        _SectionCard(
          children: [
            _ActionRow(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Inbox, unread updates and alert preferences',
              onTap: () => context.push('/notifications'),
              last: true,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionLabel('Session'),
        const SizedBox(height: 10),
        _SectionCard(
          children: [
            _ActionRow(
              icon: Icons.logout,
              title: 'Log out',
              danger: true,
              onTap: () => _confirmLogout(context, ref),
            ),
            _ActionRow(
              icon: Icons.person_remove_outlined,
              title: 'Delete account',
              subtitle: 'Deactivate your account and hide your channels',
              danger: true,
              onTap: () => _deleteAccount(context, ref),
              last: true,
            ),
          ],
        ),
      ],
    );
  }

}

/// The role chip on the profile card: Member, Creator, Pending approval, Admin.
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.auth});
  final AuthState auth;

  @override
  Widget build(BuildContext context) {
    final (text, icon, bg, fg) = auth.isAdmin
        ? ('Admin', Icons.shield_outlined, const Color(0xFFEFF6FF), AppColors.primary)
        : auth.isInfluencer
        ? ('Creator', Icons.verified_rounded, const Color(0xFFEFF6FF), AppColors.primary)
        : auth.isCandidate
        ? (
            'Pending approval',
            Icons.schedule_rounded,
            const Color(0xFFFFF7ED),
            AppColors.accentHover,
          )
        : ('Member', Icons.person_outline, const Color(0xFFEFF6FF), AppColors.primary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BecomeInfluencerCard extends StatelessWidget {
  const _BecomeInfluencerCard({
    required this.isCandidate,
    required this.isLoading,
    required this.onApply,
  });
  final bool isCandidate;
  final bool isLoading;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Become an influencer',
            style: TextStyle(
              color: AppColors.neutral900,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isCandidate
                ? 'Your request is pending admin approval. We\'ll notify you once it\'s reviewed.'
                : 'List your channels, set your prices, and earn from promotion requests.',
            style: const TextStyle(
              color: AppColors.neutral600,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (isCandidate || isLoading) ? null : onApply,
              child: isLoading
                  ? const DotsLoading()
                  : Text(isCandidate ? 'Request pending' : 'Apply now'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small purple section label (e.g. "Account details").
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Flat group of rows (Proton Settings style) — no card border, just rows
/// with hairline dividers.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(children: children);
  }
}

/// Flat row: standalone icon + title/subtitle, hairline divider below
/// (Proton Settings style).
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.neutral200)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 26, color: AppColors.neutral700),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
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
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.danger = false,
    this.last = false,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFB91C1C) : AppColors.neutral900;
    final iconColor = danger ? const Color(0xFFB91C1C) : AppColors.neutral700;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: AppColors.neutral200)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 26, color: iconColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppColors.neutral500,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!danger)
                const Icon(Icons.chevron_right, color: AppColors.neutral300),
            ],
          ),
        ),
      ),
    );
  }
}

/// A modern confirmation bottom sheet for logging out.
class _LogoutSheet extends StatelessWidget {
  const _LogoutSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.neutral200,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout,
                  color: Color(0xFFDC2626),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Log out?',
                style: TextStyle(
                  color: AppColors.neutral900,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "You'll need to sign in again to use your account.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.neutral500,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Log out'),
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
