import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/api_client.dart';
import '../../core/services/auth_repository.dart';
import '../../core/services/fcm_service.dart';

enum SplashStatus { checking, authenticated, unauthenticated, networkError }

class SplashNotifier extends Notifier<SplashStatus> {
  @override
  SplashStatus build() => SplashStatus.checking;

  Future<void> checkAuth() async {
    final result = await AuthRepository.checkAndRefresh();

    if (result == TokenCheckResult.authenticated) {
      // 앱 재시작 시 FCM 토큰 갱신 등록 (실패해도 앱 동작에 영향 없음)
      final fcmToken = await FcmService.getToken();
      if (fcmToken != null) {
        await ref.read(apiClientProvider).registerDevice(fcmToken);
      }
    }

    state = switch (result) {
      TokenCheckResult.authenticated => SplashStatus.authenticated,
      TokenCheckResult.unauthenticated => SplashStatus.unauthenticated,
      TokenCheckResult.networkError => SplashStatus.networkError,
    };
  }
}

final splashProvider =
    NotifierProvider<SplashNotifier, SplashStatus>(SplashNotifier.new);
