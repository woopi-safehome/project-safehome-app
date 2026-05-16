import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

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
  static const _baseUrl = String.fromEnvironment('API_URL', defaultValue: '');
  static String get _url =>
      _baseUrl.isNotEmpty ? _baseUrl : 'http://devupii.store:38080';

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
        state = LoginError('카카오 로그인에 실패했습니다.');
      }
      return;
    } catch (_) {
      state = LoginError('카카오 로그인에 실패했습니다.');
      return;
    }

    // 2. 서버 인증
    try {
      final response = await http
          .post(
            Uri.parse('$_url/api/auth/kakao'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'kakaoAccessToken': kakaoAccessToken}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>;
        await TokenStorage.saveTokens(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
          expiresIn: data['expiresIn'] as int,
        );
        state = LoginSuccess(isNewUser: data['isNewUser'] as bool);
      } else {
        state = LoginError('서버 인증에 실패했습니다. 다시 시도해 주세요.');
      }
    } catch (_) {
      state = LoginError('네트워크 오류가 발생했습니다. 다시 시도해 주세요.');
    }
  }

  /// 카카오톡 설치 시 앱 로그인, 미설치 시 웹뷰 OAuth
  Future<String> _kakaoLogin() async {
    OAuthToken token;
    if (await isKakaoTalkInstalled()) {
      try {
        token = await UserApi.instance.loginWithKakaoTalk();
      } catch (_) {
        // 카카오톡 로그인 실패 시 웹뷰 fallback
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
