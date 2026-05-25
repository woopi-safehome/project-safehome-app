import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/services/fcm_service.dart';
import 'core/services/logger.dart';

const _kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FcmService.initialize();
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
    appRunner: () {
      // Flutter 프레임워크 에러 (위젯 빌드 오류 등)
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        AppLogger.error(
          'FlutterError',
          details.exceptionAsString(),
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      // 비동기 Dart 에러 (Zone 밖에서 던져진 예외)
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
