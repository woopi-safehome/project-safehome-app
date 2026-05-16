import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/auth_repository.dart';

enum SplashStatus { checking, authenticated, unauthenticated, networkError }

class SplashNotifier extends Notifier<SplashStatus> {
  @override
  SplashStatus build() => SplashStatus.checking;

  Future<void> checkAuth() async {
    final result = await AuthRepository.checkAndRefresh();
    state = switch (result) {
      TokenCheckResult.authenticated => SplashStatus.authenticated,
      TokenCheckResult.unauthenticated => SplashStatus.unauthenticated,
      TokenCheckResult.networkError => SplashStatus.networkError,
    };
  }
}

final splashProvider =
    NotifierProvider<SplashNotifier, SplashStatus>(SplashNotifier.new);
