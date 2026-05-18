import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/services/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.init(AppFlavor.prd);

  await SentryFlutter.init(
    (options) {
      options.dsn = AppConfig.instance.sentryDsn;
      options.environment = AppConfig.instance.envName;
      options.tracesSampleRate = AppConfig.instance.tracesSampleRate;
      options.sendDefaultPii = false;
    },
    appRunner: () {
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        AppLogger.error(
          'FlutterError',
          details.exceptionAsString(),
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      PlatformDispatcher.instance.onError = (error, st) {
        AppLogger.error('PlatformDispatcher', error.toString(), error: error, stackTrace: st);
        return true;
      };

      runApp(
        const ProviderScope(
          child: SafeHomeApp(),
        ),
      );
    },
  );
}
