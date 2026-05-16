import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';

const _kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  KakaoSdk.init(nativeAppKey: _kakaoNativeAppKey);
  debugPrint('Kakao Key Hash: ${await KakaoSdk.origin}');
  AppConfig.init(AppFlavor.dev);

  await SentryFlutter.init(
    (options) {
      options.dsn = AppConfig.instance.sentryDsn;
      options.environment = AppConfig.instance.envName;
      options.tracesSampleRate = AppConfig.instance.tracesSampleRate;
      options.sendDefaultPii = false;
      options.debug = true;
    },
    appRunner: () => runApp(
      const ProviderScope(
        child: SafeHomeApp(),
      ),
    ),
  );
}
