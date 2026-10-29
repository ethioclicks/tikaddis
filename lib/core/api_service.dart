import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'session_token.dart';

class ApiService {
  static const String baseUrl =
      'https://tikaddis-app-w6zbh.ondigitalocean.app'; // hosted backend
  late final Dio _dio;
  final Future<void> Function()? onSessionExpired;
  final Map<String, Future<void>> _sessionChecks = {};

  ApiService({this.onSessionExpired}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token');
          if (!options.path.startsWith('/public/') &&
              token != null &&
              isSessionTokenExpired(token)) {
            await onSessionExpired?.call();
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
                error: 'Your session expired. Please sign in again.',
              ),
            );
            return;
          }
          if (token != null &&
              token.isNotEmpty &&
              !options.path.startsWith('/public/')) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // A 403 can also mean a valid account lacks permission. Only a 401
          // or a token with a past expiry should clear the session.
          final sent = error.requestOptions.headers['Authorization'];
          if (error.response?.statusCode == 401 &&
              error.requestOptions.extra['sessionCheck'] != true &&
              sent is String &&
              sent.startsWith('Bearer ')) {
            final prefs = await SharedPreferences.getInstance();
            if (sent == 'Bearer ${prefs.getString('token')}') {
              await _confirmSessionExpired(sent);
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;

  Future<void> _confirmSessionExpired(String authorization) async {
    final pending = _sessionChecks[authorization];
    if (pending != null) return pending;
    final check = _checkSession(authorization);
    _sessionChecks[authorization] = check;
    try {
      await check;
    } finally {
      _sessionChecks.remove(authorization);
    }
  }

  Future<void> _checkSession(String authorization) async {
    // A resource failure must not clear a valid login. Verify against an
    // owner-scoped authenticated endpoint; never retry the original mutation.
    try {
      await _dio.get(
        '/account/notifications/snapshot',
        options: Options(
          extra: {'sessionCheck': true},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) return;
      final prefs = await SharedPreferences.getInstance();
      if (authorization == 'Bearer ${prefs.getString('token')}' &&
          error.requestOptions.headers['Authorization'] == authorization) {
        await onSessionExpired?.call();
      }
    }
  }

  Future<Response> getNotifications({
    String filter = 'ALL',
    int page = 0,
    int size = 20,
  }) => _dio.get(
    '/account/notifications',
    queryParameters: {'filter': filter, 'page': page, 'size': size},
  );
  Future<Response> getNotificationSnapshot() =>
      _dio.get('/account/notifications/snapshot');
  Future<Response> getPromotionRequest(String id) => _dio.get(
    '/user/promotion/secure/get-promotion-request/${Uri.encodeComponent(id)}',
  );
  Future<Response> setNotificationRead(int id, bool value) =>
      _dio.put('/account/notifications/$id/read', data: {'value': value});
  Future<Response> setNotificationArchived(int id, bool value) =>
      _dio.put('/account/notifications/$id/archive', data: {'value': value});
  Future<Response> markAllNotificationsRead() =>
      _dio.post('/account/notifications/read-all');
  Future<Response> saveNotificationPreferences(
    Map<String, dynamic> preferences,
  ) => _dio.put('/account/notifications/preferences', data: preferences);
  Future<Response<ResponseBody>> openNotificationStream(CancelToken cancel) =>
      _dio.get<ResponseBody>(
        '/account/notifications/stream',
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero,
          headers: {'Accept': 'text/event-stream'},
        ),
      );

  // Auth
  Future<Response> login(String userName, String password) => _dio.post(
    '/public/authenticate',
    data: {'userName': userName, 'password': password},
  );

  Future<Response> register(Map<String, dynamic> data) =>
      _dio.post('/public/create-user', data: data);

  Future<Response> checkPhoneNumber(String phone) =>
      _dio.post('/public/phone-number-check', data: {'phoneNumber': phone});

  Future<Response> resetPassword(
    String phone,
    String otp,
    String newPassword,
  ) => _dio.post(
    '/public/user-password-reset',
    data: {'phoneNumber': phone, 'otp': otp, 'userPassword': newPassword},
  );

  // User Profile
  Future<Response> deleteOwnAccount(String currentPassword) => _dio.delete(
    '/account/me',
    data: {'password': currentPassword, 'confirmDeletion': true},
  );

  Future<Response> getProfile(String pid) =>
      _dio.get('/user', options: Options(headers: {'pid': pid}));

  Future<Response> becomeInfluencer(String pid) => _dio.post(
    '/user/become-influencer',
    options: Options(headers: {'pid': pid}),
  );

  // Influencer Accounts
  Future<Response> createInfluencerAccount(
    String pid,
    int categoryId,
    Map<String, dynamic> data,
  ) => _dio.post(
    '/influencer/create-influencer-account/$categoryId',
    data: data,
    options: Options(headers: {'pid': pid}),
  );

  Future<Response> getMyAccounts(String pid) => _dio.get(
    '/influencer/get-influencer-account-list',
    options: Options(headers: {'pid': pid}),
  );

  Future<Response> getApprovedAccounts({int page = 0, int size = 20}) =>
      _dio.get(
        '/influencer/get-approved-influencer-accounts',
        queryParameters: {'page': page, 'size': size},
      );

  Future<Response> getAccountDetail(String accountPublicId) => _dio.get(
    '/influencer/get-influencer-account/$accountPublicId',
    // Backend returns 302 (FOUND) with the body for this endpoint;
    // accept it as success instead of treating it as a redirect error.
    options: Options(
      validateStatus: (s) => s != null && s >= 200 && s < 400,
      followRedirects: false,
    ),
  );

  Future<Response> updateInfluencerAccount(
    String pid,
    Map<String, dynamic> data,
  ) => _dio.post(
    '/influencer/update-influencer-account',
    data: data,
    options: Options(headers: {'pid': pid}),
  );

  Future<Response> deleteInfluencerAccount(
    String accountPublicId,
    String pid,
  ) => _dio.delete(
    '/influencer/delete-influencer-account/$accountPublicId',
    options: Options(headers: {'pid': pid}),
  );

  Future<Response> getPromotionRequests(String userPublicId) => _dio.get(
    '/influencer/get-influencer-promotion-request-list',
    options: Options(headers: {'userPublicId': userPublicId}),
  );

  Future<Response> approveRejectPromotion(
    String promotionRequestPublicId,
    String option,
  ) => _dio.post(
    '/influencer/approve-reject-promotion-request-as-account-owner?approvalOptionsDto=$option',
    options: Options(
      headers: {'promotionRequestPublicId': promotionRequestPublicId},
    ),
  );

  // Promotion Requests
  Future<Response> createPromotionBrief(
    String accountPublicId,
    Map<String, dynamic> brief,
    List<MultipartFile> files,
  ) => _dio.post(
    '/user/promotion/secure/brief',
    data: FormData.fromMap({
      'brief': MultipartFile.fromString(
        jsonEncode(brief),
        contentType: DioMediaType('application', 'json'),
      ),
      'files': files,
    }, ListFormat.multi),
    options: Options(
      headers: {'accountPublicId': accountPublicId},
      contentType: 'multipart/form-data',
      sendTimeout: const Duration(minutes: 2),
    ),
  );

  Future<Response<List<int>>> downloadPromotionAttachment(String id) =>
      _dio.get<List<int>>(
        '/promotion-files/$id',
        options: Options(responseType: ResponseType.bytes),
      );

  Future<Response> createPromotion(
    String userPublicId,
    String accountPublicId,
    Map<String, dynamic> data,
  ) => _dio.post(
    '/user/promotion/secure/create-promotion-request-as-business-owner',
    data: data,
    options: Options(
      headers: {
        'userPublicId': userPublicId,
        'accountPublicId': accountPublicId,
      },
    ),
  );

  Future<Response> getMyPromotions(
    String pid, {
    String? status,
    int page = 0,
    int size = 20,
  }) {
    final query = <String, dynamic>{'page': page, 'size': size};
    if (status != null) query['status'] = status;
    return _dio.get(
      '/user/promotion/secure/get-my-promotion-requests',
      options: Options(headers: {'pid': pid}),
      queryParameters: query,
    );
  }

  // Categories
  Future<Response> getCategories() =>
      _dio.get('/user/category/secure/account-categories');

  // ---------------- Admin ----------------
  Future<Response> adminUserList({
    String keyword = '',
    int page = 0,
    int size = 30,
  }) => _dio.get(
    '/admin/user-list',
    queryParameters: {'keyword': keyword, 'page': page, 'size': size},
  );

  /// Users filtered by role, server-side paginated (GET /admin/user-list/{role}).
  /// Requires the admin's pid header. Role is e.g. CANDIDATE, INFLUENCER, USER.
  Future<Response> adminUsersByRole(
    String role,
    String adminPid, {
    int page = 0,
    int size = 30,
  }) => _dio.get(
    '/admin/user-list/$role',
    queryParameters: {'page': page, 'size': size},
    options: Options(headers: {'pid': adminPid}),
  );

  Future<Response> adminAccountsByStatus(
    String approvalStatus, {
    int page = 0,
    int size = 30,
  }) => _dio.get(
    '/admin/account-list-by-approval-status',
    queryParameters: {
      'approvalStatus': approvalStatus,
      'page': page,
      'size': size,
    },
  );

  Future<Response> adminPromotionList({
    String? status,
    int page = 0,
    int size = 30,
  }) {
    final q = <String, dynamic>{'page': page, 'size': size};
    if (status != null) q['status'] = status;
    return _dio.get('/admin/promotion-request-list', queryParameters: q);
  }

  Future<Response> adminApproveAccount(String accountPublicId, String option) =>
      _dio.post(
        '/admin/approve-disapprove-user-account?approvalOptions=$option',
        options: Options(headers: {'accountPublicId': accountPublicId}),
      );

  Future<Response> adminApproveInfluencer(
    String userPid,
    String option,
  ) => _dio.post(
    '/admin/approve-disapprove-user-to-be-influencer?approvalOptions=$option',
    options: Options(headers: {'pid': userPid}),
  );

  Future<Response> adminApproveRejectPromotion(
    String promotionRequestPublicId,
    String option,
  ) => _dio.post(
    '/admin/approve-reject-promotion-request-as-admin?approvalOptionsDto=$option',
    options: Options(
      headers: {'promotionRequestPublicId': promotionRequestPublicId},
    ),
  );

  Future<Response> adminTransitionRunning(String promotionRequestPublicId) =>
      _dio.post(
        '/admin/promotion-request-transition-to-running',
        options: Options(
          headers: {'promotionRequestPublicId': promotionRequestPublicId},
        ),
      );

  Future<Response> adminTransitionFulfilled(String promotionRequestPublicId) =>
      _dio.post(
        '/admin/promotion-request-transition-to-fulfilled',
        options: Options(
          headers: {'promotionRequestPublicId': promotionRequestPublicId},
        ),
      );

  Future<Response> adminCreateCategory(Map<String, dynamic> data) =>
      _dio.post('/admin/account-category', data: data);

  Future<Response> adminGetCategories() => _dio.get('/admin/account-category');

  Future<Response> adminUpdateCategory(int id, Map<String, dynamic> data) =>
      _dio.put('/admin/account-category/$id', data: data);

  Future<Response> adminDeleteCategory(int id) =>
      _dio.delete('/admin/account-category/$id');

  Future<Response> getPlatforms({bool admin = false}) =>
      _dio.get(admin ? '/admin/channel-platforms' : '/user/channel-platforms');

  Future<Response> adminSavePlatform(
    Map<String, dynamic> data, {
    String? code,
  }) => code == null
      ? _dio.post('/admin/channel-platforms', data: data)
      : _dio.put('/admin/channel-platforms/$code', data: data);

  Future<Response> adminDeletePlatform(String code) =>
      _dio.delete('/admin/channel-platforms/$code');
}
