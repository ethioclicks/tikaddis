import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/dots_loading.dart';
import '../../widgets/hex_pattern.dart';
import '../../widgets/app_toast.dart';
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
              loading: () => const LoadingView(),
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

  Future<void> _becomeInfluencer(BuildContext context, WidgetRef ref) async {
    try {
      final msg = await ref.read(authProvider.notifier).becomeInfluencer();
      if (!context.mounted) return;
      AppToast.success(context, msg);
    } on AuthException catch (e) {
      if (!context.mounted) return;
      AppToast.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = profile.fullName.isNotEmpty
        ? profile.fullName
        : 'Your account';
    final initials = _initials(profile);
    // Watch auth LIVE so applying to be an influencer updates this screen
    // immediately (roles change -> rebuild), no app restart needed.
    final auth = ref.watch(authProvider);
    final isLoading = auth.isLoading;
    final isCandidate = auth.roles.contains('CANDIDATE');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      children: [
        // Prominent account card.
        _AccountCard(name: name, initials: initials, roles: auth.roles),
        const SizedBox(height: 24),

        // Become influencer CTA (hidden for existing influencers).
        if (!auth.isInfluencer) ...[
          _BecomeInfluencerCard(
            isCandidate: isCandidate,
            isLoading: isLoading,
            onApply: () => _becomeInfluencer(context, ref),
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

  String _initials(UserProfile p) {
    final f = (p.firstName ?? '').trim();
    final l = (p.lastName ?? '').trim();
    final a = f.isNotEmpty ? f[0] : '';
    final b = l.isNotEmpty ? l[0] : '';
    final res = (a + b).toUpperCase();
    return res.isEmpty ? 'U' : res;
  }
}

class _RoleChips extends StatelessWidget {
  const _RoleChips({required this.roles});
  final List<String> roles;

  String _label(String r) {
    switch (r) {
      case 'INFLUENCER':
        return 'Influencer';
      case 'CANDIDATE':
        return 'Influencer (pending)';
      case 'ADMIN':
        return 'Admin';
      case 'USER':
        return 'Member';
      default:
        return r;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = roles.isEmpty ? ['USER'] : roles;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: shown
          .map(
            (r) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _label(r),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
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

/// Prominent account header card (avatar, name, role chips).
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.name,
    required this.initials,
    required this.roles,
  });
  final String name;
  final String initials;
  final List<String> roles;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: HexBackground(
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 132),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _RoleChips(roles: roles),
                    ],
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
