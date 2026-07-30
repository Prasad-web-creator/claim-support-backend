import 'package:dio/dio.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/core/exceptions/app_exception.dart';

class AnalysisRepository {
  final Dio _dio = ApiClient().dio;

  Future<Map<String, dynamic>> startAnalysis(String prescriptionPath, String policyPath, CancelToken cancelToken) async {
    try {
      final response = await _dio.post(
        '/analysis/start',
        data: {
          'prescriptionPath': prescriptionPath,
          'policyPath': policyPath,
        },
        cancelToken: cancelToken,
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      }
      throw AppException(message: 'Analysis failed: Unexpected status code ${response.statusCode}');
    } on DioException catch (e, st) {
      if (CancelToken.isCancel(e)) {
        throw AppException(message: 'Analysis cancelled', originalException: e, stackTrace: st);
      }
      throw AppException(
        statusCode: e.response?.statusCode,
        message: e.response?.data?['message'] ?? 'Analysis failed',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AppException(message: 'Failed to start analysis: $e', originalException: e, stackTrace: st);
    }
  }
}
