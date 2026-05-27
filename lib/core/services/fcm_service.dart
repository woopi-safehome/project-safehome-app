import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import 'logger.dart';

const _tag = 'FcmService';

const _channelId = 'safehome_foreground';
const _channelName = 'SafeHome 포그라운드 알림';

final _localNotifications = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // 앱이 백그라운드/종료 상태일 때 OS가 알림을 자동 표시하므로 별도 처리 불필요
}

class FcmService {
  FcmService._();

  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;

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

    // 로컬 알림 초기화
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);
    await _localNotifications.initialize(initSettings);

    // Android 알림 채널 생성
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<String?> getToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    AppLogger.info(_tag, 'FCM token issued', context: {'token': token ?? 'null'});
    return token;
  }

  /// 인증 완료 후 호출 — 토큰 갱신 시 서버에 자동 재등록
  static void setupTokenRefreshListener(Future<void> Function(String token) onRefresh) {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      AppLogger.info(_tag, 'FCM token refreshed', context: {'token': token});
      await onRefresh(token);
    });
  }

  /// 로그아웃 시 호출
  static void cancelTokenRefreshListener() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }

  /// 포그라운드 알림 핸들러 등록 — app.dart initState에서 호출
  /// [isEnabled] : 현재 설정 값을 반환하는 콜백
  static void setupForegroundNotificationHandler({
    required bool Function() isEnabled,
  }) {
    _foregroundSubscription?.cancel();
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) async {
      if (!isEnabled()) return;
      final notification = message.notification;
      if (notification == null) return;

      AppLogger.info(_tag, 'foreground message received', context: {'title': notification.title ?? ''});

      await _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });
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
