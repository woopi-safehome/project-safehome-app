import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/app_config.dart';

class AppLogger {
  static void info(String tag, String message, {Map<String, dynamic>? context}) {
    if (kDebugMode || AppConfig.instance.isDev) {
      debugPrint('[INFO][$tag] $message ${context ?? ''}');
    }
  }

  static void warn(String tag, String message, {Map<String, dynamic>? context}) {
    debugPrint('[WARN][$tag] $message ${context ?? ''}');
    Sentry.addBreadcrumb(
      Breadcrumb(message: '[$tag] $message', level: SentryLevel.warning, data: context),
    );
  }

  static void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    debugPrint('[ERROR][$tag] $message ${context ?? ''}');
    if (error != null) {
      Sentry.captureException(error, stackTrace: stackTrace, hint: Hint.withMap({'tag': tag, 'message': message, ...?context}));
    }
  }
}
