class NetworkException implements Exception {
  final String message;
  final String url;
  final Object? cause;

  const NetworkException(this.message, this.url, {this.cause});

  @override
  String toString() => 'NetworkException: $message (url: $url)';
}

/// 서버가 정하는 에러 코드. **원본은 서버 저장소 README 의 계약 절이다.**
///
/// 모르는 코드가 와도 동작해야 하므로 [unknown] 으로 떨어뜨린다 — 서버가 앱보다 먼저 배포된다.
/// 문자열을 화면 곳곳에 흩뿌리지 않기 위해 여기 한 곳에만 둔다.
enum ApiErrorCode {
  validationFailed('VALIDATION_FAILED'),
  constraintViolation('CONSTRAINT_VIOLATION'),
  unauthorized('UNAUTHORIZED'),
  forbidden('FORBIDDEN'),
  notFound('NOT_FOUND'),
  dailyLimitExceeded('DAILY_LIMIT_EXCEEDED'),
  kakaoApiError('KAKAO_API_ERROR'),
  internalServerError('INTERNAL_SERVER_ERROR'),
  unknown('');

  const ApiErrorCode(this.wire);

  /// 서버가 쓰는 값.
  final String wire;

  static ApiErrorCode from(Object? code) => values.firstWhere(
        (e) => e != unknown && e.wire == code,
        orElse: () => unknown,
      );
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String url;
  final String? jobId;

  /// 서버가 보낸 판별 코드. 봉투를 읽지 못했으면 [ApiErrorCode.unknown] 이다.
  final ApiErrorCode code;

  const ApiException(
    this.message,
    this.statusCode,
    this.url, {
    this.jobId,
    this.code = ApiErrorCode.unknown,
  });

  @override
  String toString() =>
      'ApiException[$statusCode/${code.name}]: $message (url: $url)';
}

class ParseException implements Exception {
  final String message;
  final String? jobId;

  const ParseException(this.message, {this.jobId});

  @override
  String toString() => 'ParseException: $message';
}
