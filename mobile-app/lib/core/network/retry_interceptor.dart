import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

class RetryInterceptor extends Interceptor {
  final int maxRetries;
  final Dio dio;

  RetryInterceptor({this.maxRetries = 3, required this.dio});

  bool _shouldRetry(DioException err) {
    if (err.requestOptions.method != 'GET' && err.requestOptions.method != 'HEAD') {
      return false; // Only retry idempotent requests
    }

    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }

    final statusCode = err.response?.statusCode;
    if (statusCode != null) {
      return statusCode == 408 || // Request Timeout
             statusCode == 429 || // Too Many Requests
             statusCode == 502 || // Bad Gateway
             statusCode == 503 || // Service Unavailable
             statusCode == 504;   // Gateway Timeout
    }
    
    return false;
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    int extraRetries = err.requestOptions.extra['retryCount'] ?? 0;

    if (_shouldRetry(err) && extraRetries < maxRetries) {
      extraRetries++;
      
      // Exponential backoff
      int delayMs = (pow(2, extraRetries) * 500).toInt() + Random().nextInt(500);
      debugPrint('[RetryInterceptor] Request failed with ${err.response?.statusCode ?? err.type}. Retrying ($extraRetries/$maxRetries) in $delayMs ms...');
      
      await Future.delayed(Duration(milliseconds: delayMs));

      try {
        err.requestOptions.extra['retryCount'] = extraRetries;
        
        final response = await dio.request(
          err.requestOptions.path,
          options: Options(
            method: err.requestOptions.method,
            headers: err.requestOptions.headers,
            extra: err.requestOptions.extra,
            responseType: err.requestOptions.responseType,
            contentType: err.requestOptions.contentType,
            validateStatus: err.requestOptions.validateStatus,
            receiveDataWhenStatusError: err.requestOptions.receiveDataWhenStatusError,
            followRedirects: err.requestOptions.followRedirects,
            maxRedirects: err.requestOptions.maxRedirects,
            requestEncoder: err.requestOptions.requestEncoder,
            responseDecoder: err.requestOptions.responseDecoder,
            listFormat: err.requestOptions.listFormat,
          ),
          data: err.requestOptions.data,
          queryParameters: err.requestOptions.queryParameters,
          cancelToken: err.requestOptions.cancelToken,
          onReceiveProgress: err.requestOptions.onReceiveProgress,
          onSendProgress: err.requestOptions.onSendProgress,
        );
        return handler.resolve(response);
      } catch (e) {
        if (e is DioException) {
          return super.onError(e, handler);
        }
      }
    }

    return super.onError(err, handler);
  }
}
