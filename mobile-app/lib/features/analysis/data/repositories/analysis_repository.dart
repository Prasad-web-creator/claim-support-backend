import 'package:dio/dio.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:claimsupport/core/exceptions/app_exception.dart';

class AnalysisRepository {
  final Dio _dio = ApiClient().dio;

  Future<Map<String, dynamic>> startAnalysis(String prescriptionPath, {String? policyPath, String? policyId, required CancelToken cancelToken}) async {
    try {
      final Map<String, dynamic> requestData = {
        'prescriptionPath': prescriptionPath,
      };
      if (policyPath != null) requestData['policyPath'] = policyPath;
      if (policyId != null) requestData['policyId'] = policyId;

      final response = await _dio.post(
        '/analysis/start',
        data: requestData,
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

  Future<Map<String, dynamic>> submitAnswers(String sessionId, Map<String, dynamic> answers, {required CancelToken cancelToken}) async {
    try {
      final response = await _dio.post(
        '/analysis/$sessionId/answer',
        data: {'answers': answers},
        cancelToken: cancelToken,
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      }
      throw AppException(message: 'Submission failed: Unexpected status code ${response.statusCode}');
    } on DioException catch (e, st) {
      if (CancelToken.isCancel(e)) {
        throw AppException(message: 'Submission cancelled', originalException: e, stackTrace: st);
      }
      throw AppException(
        statusCode: e.response?.statusCode,
        message: e.response?.data?['message'] ?? 'Submission failed',
        responseBody: e.response?.data,
        originalException: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AppException(message: 'Failed to submit answers: $e', originalException: e, stackTrace: st);
    }
  }
}
