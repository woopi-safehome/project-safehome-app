import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';

const String _sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.environment = const String.fromEnvironment('APP_ENV', defaultValue: 'dev');
      options.tracesSampleRate = 0.1;
      options.sendDefaultPii = false;
    },
    appRunner: () => runApp(
      const ProviderScope(
        child: SafeHomeApp(),
      ),
    ),
  );
}
