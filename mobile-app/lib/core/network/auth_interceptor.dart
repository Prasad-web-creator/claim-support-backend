import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:claimsupport/core/utils/auth_storage.dart';
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final token = await AuthStorage.getToken();

      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // If SharedPreferences fails, continue without token
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Token expired — attempt refresh
      try {
        final refreshToken = await AuthStorage.getRefreshToken();

        if (refreshToken != null) {
          // Create a fresh Dio instance to avoid interceptor loop
          final freshDio = Dio(BaseOptions(
            baseUrl: err.requestOptions.baseUrl,
          ));

          final response = await freshDio.post('/auth/refresh', data: {
            'refreshToken': refreshToken,
          });

          if (response.statusCode == 200) {
            final newToken = response.data['token'];
            final newRefreshToken = response.data['refreshToken'];

            await AuthStorage.saveToken(newToken);
            if (newRefreshToken != null) {
              await AuthStorage.saveRefreshToken(newRefreshToken);
            }

            // Retry the original request with the new token
            err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            final opts = Options(
              method: err.requestOptions.method,
              headers: err.requestOptions.headers,
            );

            final retryResponse = await freshDio.request(
              err.requestOptions.path,
              options: opts,
              data: err.requestOptions.data,
              queryParameters: err.requestOptions.queryParameters,
            );

            return handler.resolve(retryResponse);
          }
        }
      } catch (_) {
        // Refresh failed — fall through to original error
      }
    }

    handler.next(err);
  }
}
