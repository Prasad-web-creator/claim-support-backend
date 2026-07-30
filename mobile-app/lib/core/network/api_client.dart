import 'package:dio/dio.dart';
import 'auth_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'retry_interceptor.dart';
import '../config/env_config.dart';
import '../exceptions/app_exception.dart'; // We'll create or use this if it exists, or just rewrite the error message

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late Dio dio;

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: EnvConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30), // Tighter timeouts for production
      receiveTimeout: const Duration(seconds: 30),
    ));

    dio.interceptors.add(AuthInterceptor());
    dio.interceptors.add(RetryInterceptor(dio: dio));
    
    // Only log in development
    if (!EnvConfig.isProd) {
      dio.interceptors.add(LogInterceptor(responseBody: true, requestBody: true));
    }
    
    dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException e, handler) {
        String friendlyMessage = 'An unexpected error occurred. Please try again.';
        
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.sendTimeout:
          case DioExceptionType.receiveTimeout:
            friendlyMessage = 'Connection timed out. Please check your internet connection.';
            break;
          case DioExceptionType.badCertificate:
            friendlyMessage = 'Secure connection failed. Please ensure your network is secure.';
            break;
          case DioExceptionType.badResponse:
            final statusCode = e.response?.statusCode;
            if (statusCode == 401 || statusCode == 403) {
              friendlyMessage = 'Authentication failed. Please log in again.';
            } else if (statusCode != null && statusCode >= 500) {
              friendlyMessage = 'Our servers are currently unreachable. Please try again later.';
            } else {
              friendlyMessage = e.response?.data?['message'] ?? friendlyMessage;
            }
            break;
          case DioExceptionType.connectionError:
            friendlyMessage = 'No internet connection. Please check your network settings.';
            break;
          default:
            break;
        }

        if (!EnvConfig.isProd) {
          debugPrint('Global Error: ${e.message}');
        }

        // Clone the exception to override the message for UI consumption
        final customException = DioException(
          requestOptions: e.requestOptions,
          response: e.response,
          type: e.type,
          error: friendlyMessage,
        );
        
        return handler.next(customException);
      },
    ));
  }
}

