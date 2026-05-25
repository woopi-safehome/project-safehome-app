import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';

import 'logger.dart';

const _tag = 'FcmService';

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // 앱이 백그라운드/종료 상태일 때 OS가 알림을 자동 표시하므로 별도 처리 불필요
}

class FcmService {
  FcmService._();

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    AppLogger.info(
      _tag,
      'notification permission',
      context: {'status': settings.authorizationStatus.toString()},
    );
  }

  static Future<String?> getToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    AppLogger.info(_tag, 'FCM token issued', context: {'token': token ?? 'null'});
    return token;
  }

  /// 알림 탭 핸들러 등록 — SafeHomeApp.initState()에서 호출
  static void setupNotificationHandlers(GoRouter router) {
    // 백그라운드 상태에서 알림 탭
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      AppLogger.info(_tag, 'onMessageOpenedApp', context: {'data': message.data.toString()});
      _navigateFromMessage(router, message);
    });

    // 종료 상태에서 알림 탭으로 앱 실행
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message == null) return;
      AppLogger.info(_tag, 'getInitialMessage', context: {'data': message.data.toString()});
      _navigateFromMessage(router, message);
    });
  }

  static void _navigateFromMessage(GoRouter router, RemoteMessage message) {
    final jobId = message.data['jobId'] as String?;
    if (jobId == null) return;
    router.go('/result/$jobId');
  }
}
