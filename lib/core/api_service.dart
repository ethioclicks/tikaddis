import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8081'; // Android emulator → localhost
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  Dio get dio => _dio;

  // Auth
  Future<Response> login(String userName, String password) =>
      _dio.post('/public/authenticate', data: {'userName': userName, 'password': password});

  Future<Response> register(Map<String, dynamic> data) =>
      _dio.post('/public/create-user', data: data);

  Future<Response> checkPhoneNumber(String phone) =>
      _dio.post('/public/phone-number-check', data: {'phoneNumber': phone});

  Future<Response> resetPassword(String phone, String otp, String newPassword) =>
      _dio.post('/public/user-password-reset', data: {'phoneNumber': phone, 'otp': otp, 'userPassword': newPassword});

  // User Profile
  Future<Response> getProfile(String pid) =>
      _dio.get('/user', options: Options(headers: {'pid': pid}));

  Future<Response> becomeInfluencer(String pid) =>
      _dio.post('/user/become-influencer', options: Options(headers: {'pid': pid}));

  // Influencer Accounts
  Future<Response> createInfluencerAccount(String pid, int categoryId, Map<String, dynamic> data) =>
      _dio.post('/influencer/create-influencer-account/$categoryId', data: data, options: Options(headers: {'pid': pid}));

  Future<Response> getMyAccounts(String pid) =>
      _dio.get('/influencer/get-influencer-account-list', options: Options(headers: {'pid': pid}));

  Future<Response> getApprovedAccounts({int page = 0, int size = 20}) =>
      _dio.get('/influencer/get-approved-influencer-accounts',
          queryParameters: {'page': page, 'size': size});

  Future<Response> getAccountDetail(String accountPublicId) =>
      _dio.get('/influencer/get-influencer-account/$accountPublicId');

  Future<Response> getPromotionRequests(String userPublicId) =>
      _dio.get('/influencer/get-influencer-promotion-request-list', options: Options(headers: {'userPublicId': userPublicId}));

  Future<Response> approveRejectPromotion(String promotionRequestPublicId, String option) =>
      _dio.post('/influencer/approve-reject-promotion-request-as-account-owner?approvalOptionsDto=$option',
          options: Options(headers: {'promotionRequestPublicId': promotionRequestPublicId}));

  // Promotion Requests
  Future<Response> createPromotion(String userPublicId, String accountPublicId, Map<String, dynamic> data) =>
      _dio.post('/user/promotion/secure/create-promotion-request-as-business-owner', data: data,
          options: Options(headers: {'userPublicId': userPublicId, 'accountPublicId': accountPublicId}));

  Future<Response> getMyPromotions(String pid,
      {String? status, int page = 0, int size = 20}) {
    final query = <String, dynamic>{'page': page, 'size': size};
    if (status != null) query['status'] = status;
    return _dio.get('/user/promotion/secure/get-my-promotion-requests',
        options: Options(headers: {'pid': pid}), queryParameters: query);
  }

  // Categories
  Future<Response> getCategories() =>
      _dio.get('/user/category/secure/account-categories');
}
