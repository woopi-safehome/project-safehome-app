import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';

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
    appRunner: () => runApp(
      const ProviderScope(
        child: SafeHomeApp(),
      ),
    ),
  );
}
