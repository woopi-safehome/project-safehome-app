import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../config/app_config.dart';
import 'token_storage.dart';

String get _url => AppConfig.apiBaseUrl;

class _AuthInterceptor extends Interceptor {
  final Dio _dio;

  _AuthInterceptor(this._dio);

  // 동시 다중 401 시 갱신 중복 방지
  Completer<void>? _refreshCompleter;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await TokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    final options = err.requestOptions;

    // 재시도 요청이 또 401 → 토큰 삭제 후 로그인 화면으로
    if (options.extra['isRetry'] == true) {
      await _clearAndLogout();
      handler.next(err);
      return;
    }

    // 다른 요청이 이미 갱신 중이면 완료될 때까지 대기
    if (_refreshCompleter != null) {
      try {
        await _refreshCompleter!.future;
        handler.resolve(await _retry(options));
      } catch (_) {
        handler.next(err);
      }
      return;
    }

    // 갱신 시작
    _refreshCompleter = Completer<void>();
    try {
      final refreshToken = await TokenStorage.getRefreshToken();
      if (refreshToken == null) {
        throw Exception('no refresh token');
      }

      final response = await _dio.post(
        '/api/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {'isRetry': true}),
      );

      final data = response.data['data'] as Map<String, dynamic>;
      await TokenStorage.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        expiresIn: data['expiresIn'] as int,
      );

      _refreshCompleter!.complete();
      _refreshCompleter = null;

      handler.resolve(await _retry(options));
    } catch (_) {
      _refreshCompleter!.completeError('refresh_failed');
      _refreshCompleter = null;
      await _clearAndLogout();
      handler.next(err);
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions options) {
    return _dio.fetch(options..extra['isRetry'] = true);
  }

  Future<void> _clearAndLogout() async {
    await TokenStorage.clear();
    appRouter.go('/login');
  }
}

Dio _buildDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: _url,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  dio.interceptors.add(_AuthInterceptor(dio));
  return dio;
}

final dioClientProvider = Provider<Dio>((ref) => _buildDio());
