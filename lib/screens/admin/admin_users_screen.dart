import '../../widgets/app_toast.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/dots_loading.dart';

/// Admin: users split into tabs so pending influencer requests are isolated
/// and each list stays paginated server-side (scales to large user bases).
class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.neutral50,
        body: Column(
          children: [
            const SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Users',
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
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.neutral500,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
              tabs: [
                Tab(text: 'Pending'),
                Tab(text: 'Influencers'),
                Tab(text: 'All'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  // Pending influencer applications (role CANDIDATE).
                  _RoleUserList(
                    role: 'CANDIDATE',
                    emptyMessage: 'No pending requests.',
                  ),
                  // Approved influencers (role INFLUENCER).
                  _RoleUserList(
                    role: 'INFLUENCER',
                    emptyMessage: 'No influencers yet.',
                  ),
                  // Everyone (keyword list).
                  _AllUsersList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A user list backed by the role-filtered admin endpoint.
class _RoleUserList extends ConsumerWidget {
  const _RoleUserList({required this.role, required this.emptyMessage});
  final String role;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersByRoleProvider(role));
    return users.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        message: 'Could not load users.',
        onRetry: () => ref.invalidate(adminUsersByRoleProvider(role)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return EmptyView(icon: Icons.people_outline, message: emptyMessage);
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(adminUsersByRoleProvider(role)),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _UserCard(
              user: list[i],
              // Refresh the role tab and the All tab after an approve/reject,
              // since a change moves the user between lists.
              onChanged: () {
                ref.invalidate(adminUsersByRoleProvider(role));
                ref.invalidate(adminUsersByRoleProvider('INFLUENCER'));
                ref.invalidate(adminUsersProvider);
              },
            ),
          ),
        );
      },
    );
  }
}

/// The "All" tab backed by the keyword admin endpoint.
class _AllUsersList extends ConsumerWidget {
  const _AllUsersList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider);
    return users.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        message: 'Could not load users.',
        onRetry: () => ref.invalidate(adminUsersProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyView(
            icon: Icons.people_outline,
            message: 'No users found.',
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(adminUsersProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _UserCard(
              user: list[i],
              onChanged: () {
                ref.invalidate(adminUsersProvider);
                ref.invalidate(adminUsersByRoleProvider('CANDIDATE'));
                ref.invalidate(adminUsersByRoleProvider('INFLUENCER'));
              },
            ),
          ),
        );
      },
    );
  }
}

class _UserCard extends ConsumerStatefulWidget {
  const _UserCard({required this.user, required this.onChanged});
  final AdminUser user;
  final VoidCallback onChanged;

  @override
  ConsumerState<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends ConsumerState<_UserCard> {
  bool _busy = false;

  Future<void> _act(String option) async {
    final pid = widget.user.userPublicId;
    if (pid == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiServiceProvider).adminApproveInfluencer(pid, option);
      widget.onChanged();
      if (!mounted) return;
      AppToast.success(
        context,
        option == 'APPROVE'
            ? 'Approved as influencer.'
            : 'Application rejected.',
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
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
    final u = widget.user;
    final name = u.fullName.isNotEmpty ? u.fullName : (u.userName ?? 'User');
    final initials = _initials(u);

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
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.neutral900,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((u.userName ?? '').isNotEmpty)
                      Text(
                        u.userName!,
                        style: const TextStyle(
                          color: AppColors.neutral500,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              _RoleTag(roles: u.roles),
            ],
          ),
          if (u.isCandidate) ...[
            const SizedBox(height: 14),
            if (_busy)
              const Center(child: DotsLoading(color: AppColors.primary))
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
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _act('APPROVE'),
                      child: const Text('Make influencer'),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  String _initials(AdminUser u) {
    final f = (u.firstName ?? '').trim();
    final l = (u.lastName ?? '').trim();
    final res = ((f.isNotEmpty ? f[0] : '') + (l.isNotEmpty ? l[0] : ''))
        .toUpperCase();
    return res.isEmpty ? 'U' : res;
  }
}

class _RoleTag extends StatelessWidget {
  const _RoleTag({required this.roles});
  final List<String> roles;

  @override
  Widget build(BuildContext context) {
    String label;
    Color bg;
    Color fg;
    if (roles.contains('ADMIN')) {
      label = 'Admin';
      bg = const Color(0xFFEFF6FF);
      fg = const Color(0xFF1D4ED8);
    } else if (roles.contains('INFLUENCER')) {
      label = 'Influencer';
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF047857);
    } else if (roles.contains('CANDIDATE')) {
      label = 'Pending';
      bg = const Color(0xFFFFF7ED);
      fg = AppColors.accentHover;
    } else {
      label = 'Member';
      bg = AppColors.neutral100;
      fg = AppColors.neutral600;
    }
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
