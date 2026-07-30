class AppException implements Exception {
  final int? statusCode;
  final String message;
  final dynamic responseBody;
  final dynamic originalException;
  final StackTrace? stackTrace;

  AppException({
    this.statusCode,
    required this.message,
    this.responseBody,
    this.originalException,
    this.stackTrace,
  });

  @override
  String toString() {
    if (statusCode != null) {
      return '[$statusCode] $message';
    }
    return message;
  }
}
