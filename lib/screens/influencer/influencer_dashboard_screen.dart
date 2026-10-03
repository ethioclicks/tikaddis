import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/data_providers.dart';

class InfluencerDashboardScreen extends ConsumerWidget {
  const InfluencerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(myAccountsProvider);
    final requests = ref.watch(influencerRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Influencer')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Your creator space',
              style: TextStyle(
                color: AppColors.neutral900,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Manage your channels and incoming promotion requests.',
              style: TextStyle(color: AppColors.neutral500, fontSize: 14.5),
            ),
            const SizedBox(height: 20),
            _HubCard(
              icon: Icons.storefront_outlined,
              title: 'My accounts',
              subtitle: accounts.maybeWhen(
                data: (l) => '${l.length} channel${l.length == 1 ? '' : 's'}',
                orElse: () => 'View your listed channels',
              ),
              onTap: () => context.push('/influencer/accounts'),
            ),
            _HubCard(
              icon: Icons.add_circle_outline,
              title: 'Add a channel',
              subtitle: 'List a new Telegram, YouTube, TikTok, FB or IG account',
              onTap: () => context.push('/influencer/accounts/new'),
            ),
            _HubCard(
              icon: Icons.inbox_outlined,
              title: 'Incoming requests',
              subtitle: requests.maybeWhen(
                data: (l) =>
                    '${l.length} request${l.length == 1 ? '' : 's'} to review',
                orElse: () => 'Approve or reject promotion requests',
              ),
              onTap: () => context.push('/influencer/promotions'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.neutral900,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.neutral500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.neutral300),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
