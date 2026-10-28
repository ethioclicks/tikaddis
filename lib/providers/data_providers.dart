import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'auth_provider.dart';

final notificationPromotionProvider = FutureProvider.autoDispose
    .family<PromotionRequest, String>((ref, id) async {
      final response = await ref
          .read(apiServiceProvider)
          .getPromotionRequest(id);
      return PromotionRequest.fromJson(response.data as Map<String, dynamic>);
    });

/// Current user's profile (GET /user).
final profileProvider = FutureProvider.autoDispose<UserProfile>((ref) async {
  final api = ref.read(apiServiceProvider);
  final pid = ref.read(authProvider).pid;
  if (pid == null) {
    throw Exception('Not signed in');
  }
  final res = await api.getProfile(pid);
  final data = res.data;
  if (data is Map<String, dynamic>) {
    return UserProfile.fromJson(data);
  }
  throw Exception('Could not load profile');
});

/// Approved influencer accounts for the Browse screen.
final approvedAccountsProvider =
    FutureProvider.autoDispose<List<InfluencerAccount>>((ref) async {
      final api = ref.read(apiServiceProvider);
      final res = await api.getApprovedAccounts();
      final page = PageResult.fromJson<InfluencerAccount>(
        res.data,
        InfluencerAccount.fromJson,
      );
      return page.content;
    });

/// Single account detail by public id.
final accountDetailProvider = FutureProvider.autoDispose
    .family<InfluencerAccount, String>((ref, accountPublicId) async {
      final api = ref.read(apiServiceProvider);
      final res = await api.getAccountDetail(accountPublicId);
      final data = res.data;
      if (data is Map<String, dynamic>) {
        return InfluencerAccount.fromJson(data);
      }
      throw Exception('Account not found');
    });

/// The signed-in influencer's own accounts (GET /influencer/get-influencer-account-list).
final myAccountsProvider = FutureProvider.autoDispose<List<InfluencerAccount>>((
  ref,
) async {
  final api = ref.read(apiServiceProvider);
  final pid = ref.read(authProvider).pid;
  if (pid == null) return [];
  final res = await api.getMyAccounts(pid);
  final page = PageResult.fromJson<InfluencerAccount>(
    res.data,
    InfluencerAccount.fromJson,
  );
  return page.content;
});

/// Account categories for the create-account picker.
final categoriesProvider = FutureProvider.autoDispose<List<AccountCategory>>((
  ref,
) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.getCategories();
  final data = res.data;
  final list = data is List ? data : (data['content'] as List? ?? const []);
  final categories = list
      .map((e) => AccountCategory.fromJson(e as Map<String, dynamic>))
      .toList();
  categories.sort((a, b) {
    final order = (a.displayOrder ?? 0).compareTo(b.displayOrder ?? 0);
    return order != 0
        ? order
        : (a.categoryName ?? '').compareTo(b.categoryName ?? '');
  });
  return categories;
});

final platformsProvider = FutureProvider.autoDispose<List<AccountType>>((
  ref,
) async {
  final res = await ref.read(apiServiceProvider).getPlatforms();
  return (res.data as List)
      .map((e) => AccountType.fromJson(e as Map<String, dynamic>))
      .toList();
});

final adminCategoriesProvider =
    FutureProvider.autoDispose<List<AccountCategory>>((ref) async {
      final res = await ref.read(apiServiceProvider).adminGetCategories();
      final list = (res.data as List)
          .map((e) => AccountCategory.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => (a.displayOrder ?? 0).compareTo(b.displayOrder ?? 0));
      return list;
    });

final adminPlatformsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final res = await ref.read(apiServiceProvider).getPlatforms(admin: true);
      return (res.data as List).cast<Map<String, dynamic>>();
    });

/// Promotion requests coming in to the influencer's accounts
/// (GET /influencer/get-influencer-promotion-request-list, header userPublicId).
final influencerRequestsProvider =
    FutureProvider.autoDispose<List<PromotionRequest>>((ref) async {
      final api = ref.read(apiServiceProvider);
      final pid = ref.read(authProvider).pid;
      if (pid == null) return [];
      final res = await api.getPromotionRequests(pid);
      final page = PageResult.fromJson<PromotionRequest>(
        res.data,
        PromotionRequest.fromJson,
      );
      return page.content
          .where(
            (r) => const {
              PromotionStatus.adminApproved,
              PromotionStatus.ownerApproved,
              PromotionStatus.ownerRejected,
              PromotionStatus.running,
              PromotionStatus.fulfilled,
            }.contains(r.status),
          )
          .toList();
    });

// ---------------- Admin providers ----------------

/// All users (admin), keyword search (default empty).
final adminUsersProvider = FutureProvider.autoDispose<List<AdminUser>>((
  ref,
) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.adminUserList();
  final page = PageResult.fromJson<AdminUser>(res.data, AdminUser.fromJson);
  return page.content;
});

/// Users filtered by role, server-side (admin). role: CANDIDATE/INFLUENCER/USER.
/// Used by the Users screen tabs so large user bases stay paginated server-side.
final adminUsersByRoleProvider = FutureProvider.autoDispose
    .family<List<AdminUser>, String>((ref, role) async {
      final api = ref.read(apiServiceProvider);
      final pid = ref.read(authProvider).pid;
      if (pid == null) return [];
      final res = await api.adminUsersByRole(role, pid);
      final page = PageResult.fromJson<AdminUser>(res.data, AdminUser.fromJson);
      return page.content;
    });

/// Influencer accounts by approval status (admin). status: ALL/APPROVED/DISAPPROVED
final adminAccountsProvider = FutureProvider.autoDispose
    .family<List<InfluencerAccount>, String>((ref, approvalStatus) async {
      final api = ref.read(apiServiceProvider);
      final res = await api.adminAccountsByStatus(approvalStatus);
      final page = PageResult.fromJson<InfluencerAccount>(
        res.data,
        InfluencerAccount.fromJson,
      );
      return page.content;
    });

/// All promotion requests (admin), optional status filter.
final adminPromotionsProvider = FutureProvider.autoDispose
    .family<List<PromotionRequest>, String?>((ref, status) async {
      final api = ref.read(apiServiceProvider);
      final res = await api.adminPromotionList(status: status);
      final page = PageResult.fromJson<PromotionRequest>(
        res.data,
        PromotionRequest.fromJson,
      );
      return page.content;
    });

/// Business owner's own promotion requests, optionally filtered by status.
final myPromotionsProvider = FutureProvider.autoDispose
    .family<List<PromotionRequest>, String?>((ref, status) async {
      final api = ref.read(apiServiceProvider);
      final pid = ref.read(authProvider).pid;
      if (pid == null) return [];
      final res = await api.getMyPromotions(pid, status: status);
      final page = PageResult.fromJson<PromotionRequest>(
        res.data,
        PromotionRequest.fromJson,
      );
      return page.content;
    });
