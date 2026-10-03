import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'auth_provider.dart';

/// Current user's profile (GET /user).
final profileProvider =
    FutureProvider.autoDispose<UserProfile>((ref) async {
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
