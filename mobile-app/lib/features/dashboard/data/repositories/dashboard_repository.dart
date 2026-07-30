import 'package:dio/dio.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/features/dashboard/data/models/dashboard_stats.dart';
import 'package:claimsupport/core/exceptions/app_exception.dart';

class DashboardRepository {
  final Dio _dio = ApiClient().dio;

  Future<DashboardStats> getStats() async {
    try {
      final response = await _dio.get('/dashboard');
      return DashboardStats.fromJson(response.data);
    } on DioException catch (e, st) {
      throw AppException(
        statusCode: e.response?.statusCode,
        message: e.response?.data?['message'] ?? e.message ?? 'Unknown error',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AppException(
        message: 'Failed to fetch dashboard stats: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }
}
