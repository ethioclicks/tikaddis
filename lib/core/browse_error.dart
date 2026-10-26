import 'package:dio/dio.dart';

String browseErrorMessage(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return 'Cannot connect. Check your internet connection and try again.';
      default:
        break;
    }
    switch (error.response?.statusCode) {
      case 401:
        return 'Your session expired. Please sign in again.';
      case 403:
        return 'Your account could not access creators. Sign out and sign in '
            'again. If this continues, contact support.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Creators are temporarily unavailable. Please try again shortly.';
    }
  }
  return 'Could not load creators. Please try again.';
}
