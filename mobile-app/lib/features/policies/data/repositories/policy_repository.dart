import 'package:dio/dio.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/core/models/pagination_response.dart';
import 'package:claimsupport/features/policies/data/models/policy.dart';
import 'package:claimsupport/core/exceptions/app_exception.dart';

class PolicyRepository {
  final Dio _dio = ApiClient().dio;

  Future<PaginationResponse<Policy>> getPolicies({int page = 1, int limit = 10, String? search}) async {
    try {
      final response = await _dio.get('/policies', queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.isNotEmpty) 'search': search,
      });
      return PaginationResponse.fromJson(response.data, (json) => Policy.fromJson(json));
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
        message: 'Failed to fetch policies: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }

  Future<Policy> getPolicy(String id) async {
    try {
      final response = await _dio.get('/policies/$id');
      return Policy.fromJson(response.data);
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
        message: 'Failed to fetch policy: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }

  Future<Policy> createPolicy(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/policies', data: data);
      return Policy.fromJson(response.data);
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
        message: 'Failed to create policy: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }

  Future<Policy> updatePolicy(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/policies/$id', data: data);
      return Policy.fromJson(response.data);
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
        message: 'Failed to update policy: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }

  Future<void> deletePolicy(String id) async {
    try {
      await _dio.delete('/policies/$id');
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
        message: 'Failed to delete policy: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }

  Future<void> deleteBatchPolicies(List<String> ids) async {
    try {
      await _dio.post('/policies/batch-delete', data: {'ids': ids});
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
        message: 'Failed to batch delete policies: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }
}
