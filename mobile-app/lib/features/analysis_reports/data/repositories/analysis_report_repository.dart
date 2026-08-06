import 'package:dio/dio.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/features/analysis_reports/data/models/analysis_report.dart';
import 'package:claimsupport/core/models/pagination_response.dart';
import 'package:claimsupport/core/exceptions/app_exception.dart';

class AnalysisReportRepository {
  final Dio _dio = ApiClient().dio;

  Future<PaginationResponse<AnalysisReport>> getAnalysisReports({int page = 1, int limit = 10, String search = ''}) async {
    try {
      final response = await _dio.get('/analysis', queryParameters: {
        'page': page,
        'limit': limit,
        'search': search,
      });
      return PaginationResponse.fromJson(
        response.data,
        (json) => AnalysisReport.fromJson(json),
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
        message: 'Failed to fetch analysis reports: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }

  Future<AnalysisReport> getAnalysisReport(String id) async {
    try {
      final response = await _dio.get('/analysis/$id');
      return AnalysisReport.fromJson(response.data);
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
        message: 'Failed to fetch analysis report details: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }

  Future<void> deleteAnalysisReport(String id) async {
    try {
      await _dio.delete('/analysis/$id');
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
        message: 'Failed to delete analysis report: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }

  Future<void> deleteBatchAnalysisReports(List<String> ids) async {
    try {
      await _dio.post('/analysis/reports/batch-delete', data: {'ids': ids});
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
        message: 'Failed to batch delete analysis reports: $e',
        originalException: e,
        stackTrace: st,
      );
    }
  }
}
