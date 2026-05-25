import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/services/api_client.dart';
import '../../core/services/fcm_service.dart';
import '../../core/services/logger.dart';
import '../../core/services/token_storage.dart';

sealed class LoginState {
  const LoginState();
}

class LoginIdle extends LoginState {
  const LoginIdle();
}

class LoginLoading extends LoginState {
  const LoginLoading();
}

class LoginSuccess extends LoginState {
  final bool isNewUser;
  const LoginSuccess({required this.isNewUser});
}

class LoginError extends LoginState {
  final String message;
  const LoginError(this.message);
}

class LoginNotifier extends Notifier<LoginState> {
  static const _tag = 'LoginNotifier';

  @override
  LoginState build() => const LoginIdle();

  Future<void> loginWithKakao() async {
    state = const LoginLoading();

    // 1. 카카오 SDK 로그인 (카카오톡 설치 여부 분기)
    final String kakaoAccessToken;
    try {
      kakaoAccessToken = await _kakaoLogin();
    } on KakaoClientException catch (e) {
      if (e.reason == ClientErrorCause.cancelled) {
        state = const LoginIdle();
      } else {
        state = const LoginError('카카오 로그인에 실패했습니다.');
      }
      return;
    } catch (_) {
      state = const LoginError('카카오 로그인에 실패했습니다.');
      return;
    }

    // 2. 서버 인증
    try {
      final result = await ref.read(apiClientProvider).login(kakaoAccessToken);
      await TokenStorage.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        expiresIn: result.expiresIn,
      );

      // FCM 디바이스 토큰 등록 (실패해도 로그인 흐름에 영향 없음)
      final fcmToken = await FcmService.getToken();
      if (fcmToken != null) {
        await ref.read(apiClientProvider).registerDevice(fcmToken);
      }

      state = LoginSuccess(isNewUser: result.isNewUser);
    } on ApiException catch (e) {
      AppLogger.error(_tag, '서버 인증 실패', error: e);
      state = const LoginError('서버 인증에 실패했습니다. 다시 시도해 주세요.');
    } on NetworkException catch (e) {
      AppLogger.error(_tag, '네트워크 오류', error: e);
      state = const LoginError('네트워크 오류가 발생했습니다. 다시 시도해 주세요.');
    } catch (e) {
      AppLogger.error(_tag, '알 수 없는 오류', error: e);
      state = const LoginError('알 수 없는 오류가 발생했습니다.');
    }
  }

  /// 카카오톡 설치 시 앱 로그인, 미설치 시 웹뷰 OAuth
  Future<String> _kakaoLogin() async {
    OAuthToken token;
    if (await isKakaoTalkInstalled()) {
      try {
        token = await UserApi.instance.loginWithKakaoTalk();
      } catch (_) {
        token = await UserApi.instance.loginWithKakaoAccount();
      }
    } else {
      token = await UserApi.instance.loginWithKakaoAccount();
    }
    return token.accessToken;
  }
}

final loginProvider =
    NotifierProvider<LoginNotifier, LoginState>(LoginNotifier.new);
