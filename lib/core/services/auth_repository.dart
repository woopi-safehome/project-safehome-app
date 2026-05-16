import 'dart:convert';

import 'package:http/http.dart' as http;

import 'token_storage.dart';

enum TokenCheckResult { authenticated, unauthenticated, networkError }

class AuthRepository {
  const AuthRepository._();

  static const _baseUrl = String.fromEnvironment('API_URL', defaultValue: '');

  static String get _url =>
      _baseUrl.isNotEmpty ? _baseUrl : 'http://devupii.store:38080';

  static Future<TokenCheckResult> checkAndRefresh() async {
    if (!await TokenStorage.hasTokens()) return TokenCheckResult.unauthenticated;

    if (await TokenStorage.isAccessTokenValid()) return TokenCheckResult.authenticated;

    // accessToken 만료 → refreshToken으로 갱신 시도
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null) {
      await TokenStorage.clear();
      return TokenCheckResult.unauthenticated;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_url/api/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
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
        return TokenCheckResult.authenticated;
      }

      // 401 등 refreshToken 만료
      await TokenStorage.clear();
      return TokenCheckResult.unauthenticated;
    } catch (_) {
      return TokenCheckResult.networkError;
    }
  }
}
