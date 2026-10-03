import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: const Text('Profile',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: profile.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load your profile.',
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (p) => _ProfileBody(profile: p, auth: auth),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile, required this.auth});
  final UserProfile profile;
  final AuthState auth;

  bool get _isCandidate => auth.roles.contains('CANDIDATE');

  Future<void> _becomeInfluencer(BuildContext context, WidgetRef ref) async {
    try {
      final msg = await ref.read(authProvider.notifier).becomeInfluencer();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.primary),
      );
    } on AuthException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = profile.fullName.isNotEmpty ? profile.fullName : 'Your account';
    final initials = _initials(profile);
    final isLoading = ref.watch(authProvider).isLoading;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: const TextStyle(
                  color: AppColors.neutral900,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              _RoleChips(roles: auth.roles),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _InfoTile(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: profile.userName ?? '—',
        ),
        _InfoTile(
          icon: Icons.email_outlined,
          label: 'Email',
          value: (profile.email ?? '').isNotEmpty ? profile.email! : 'Not set',
        ),
        _InfoTile(
          icon: Icons.location_on_outlined,
          label: 'Address',
          value: (profile.address?.display ?? '').isNotEmpty
              ? profile.address!.display
              : 'Not set',
        ),
        const SizedBox(height: 24),

        // Become influencer CTA (hidden for existing influencers).
        if (!auth.isInfluencer) _BecomeInfluencerCard(
          isCandidate: _isCandidate,
          isLoading: isLoading,
          onApply: () => _becomeInfluencer(context, ref),
        ),

        if (auth.isInfluencer)
          _ActionTile(
            icon: Icons.storefront_outlined,
            title: 'Influencer area',
            onTap: () => context.push('/influencer'),
          ),

        const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.logout,
          title: 'Log out',
          danger: true,
          onTap: () async {
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          },
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
      alignment: WrapAlignment.center,
      children: shown
          .map((r) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _label(r),
                  style: const TextStyle(
                    color: AppColors.primaryHover,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ))
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.accent.withValues(alpha: 0.10),
          ],
        ),
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
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(isCandidate ? 'Request pending' : 'Apply now'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

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
          Icon(icon, size: 20, color: AppColors.neutral500),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.neutral500,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFB91C1C) : AppColors.neutral900;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.neutral300),
            ],
          ),
        ),
      ),
    );
  }
}
