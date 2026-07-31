import 'package:dio/dio.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/features/prescriptions/data/models/prescription.dart';
import 'package:claimsupport/core/models/pagination_response.dart';
import 'package:claimsupport/core/exceptions/app_exception.dart';

class PrescriptionRepository {
  final Dio _dio = ApiClient().dio;

  Future<PaginationResponse<Prescription>> getPrescriptions({int page = 1, int limit = 10, String search = ''}) async {
    try {
      final response = await _dio.get('/prescriptions', queryParameters: {
        'page': page,
        'limit': limit,
        'search': search,
      });
      return PaginationResponse.fromJson(
        response.data,
        (json) => Prescription.fromJson(json),
      );
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
        message: 'Failed to fetch prescriptions: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }

  Future<Prescription> getPrescription(String id) async {
    try {
      final response = await _dio.get('/prescriptions/$id');
      return Prescription.fromJson(response.data);
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
        message: 'Failed to fetch prescription: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }

  Future<void> createPrescription(Map<String, dynamic> data) async {
    try {
      await _dio.post('/prescriptions', data: data);
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
        message: 'Failed to create prescription: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }
  Future<void> deletePrescription(String id) async {
    try {
      await _dio.delete('/prescriptions/$id');
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
        message: 'Failed to delete prescription: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }
}
