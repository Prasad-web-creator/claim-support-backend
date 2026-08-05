import 'package:dio/dio.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/features/authentication/data/models/user.dart';
import 'package:claimsupport/core/exceptions/app_exception.dart';

class AuthRepository {
  final Dio _dio = ApiClient().dio;

  Future<User> getMe() async {
    try {
      final response = await _dio.get('/auth/me');
      return User.fromJson(response.data);
    } on DioException catch (e, st) {
      throw AppException(
        statusCode: e.response?.statusCode,
        message: e.response?.data?['message'] ?? e.response?.data?['detail'] ?? e.message ?? 'Unknown error',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AppException(
        message: 'Failed to fetch user data: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }

  Future<User> updateProfile(String name, String email) async {
    try {
      final response = await _dio.put('/auth/me', data: {
        'name': name,
        'email': email,
      });
      return User.fromJson(response.data);
    } on DioException catch (e, st) {
      throw AppException(
        statusCode: e.response?.statusCode,
        message: e.response?.data?['message'] ?? e.response?.data?['detail'] ?? e.message ?? 'Unknown error',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AppException(
        message: 'Failed to update user profile: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }
}
