class NetworkException implements Exception {
  final String message;
  final String url;
  final Object? cause;

  const NetworkException(this.message, this.url, {this.cause});

  @override
  String toString() => 'NetworkException: $message (url: $url)';
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String url;
  final String? jobId;

  const ApiException(this.message, this.statusCode, this.url, {this.jobId});

  @override
  String toString() =>
      'ApiException[$statusCode]: $message (url: $url)';
}

class ParseException implements Exception {
  final String message;
  final String? jobId;

  const ParseException(this.message, {this.jobId});

  @override
  String toString() => 'ParseException: $message';
}
