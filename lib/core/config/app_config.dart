enum AppFlavor { dev, prd }

class AppConfig {
  static const String _envApiUrl =
      String.fromEnvironment('API_URL', defaultValue: '');

  /// API base URL — --dart-define=API_URL=... 로 주입, 미설정 시 기본값 사용
  /// dart-define 미주입 시 에뮬레이터 기준 로컬 서버(10.0.2.2 = 호스트 localhost)로 폴백
  static String get apiBaseUrl =>
      _envApiUrl.isNotEmpty ? _envApiUrl : 'http://10.0.2.2:8080';

  static late AppConfig _instance;
  static AppConfig get instance => _instance;

  final AppFlavor flavor;
  final String sentryDsn;
  final double tracesSampleRate;

  AppConfig._({
    required this.flavor,
    required this.sentryDsn,
    required this.tracesSampleRate,
  });

  static void init(AppFlavor flavor) {
    const dsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
    _instance = AppConfig._(
      flavor: flavor,
      sentryDsn: dsn,
      tracesSampleRate: flavor == AppFlavor.prd ? 0.1 : 1.0,
    );
  }

  bool get isDev => flavor == AppFlavor.dev;
  String get envName => flavor.name; // 'dev' | 'prd'
}
