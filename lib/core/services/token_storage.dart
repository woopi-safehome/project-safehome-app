import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kAccessToken = 'auth_access_token';
const _kRefreshToken = 'auth_refresh_token';
const _kAccessTokenExpiry = 'auth_access_token_expiry';

class TokenStorage {
  const TokenStorage._();

  static const _storage = FlutterSecureStorage();

  static Future<String?> getAccessToken() => _storage.read(key: _kAccessToken);
  static Future<String?> getRefreshToken() => _storage.read(key: _kRefreshToken);

  static Future<bool> hasTokens() async {
    final token = await _storage.read(key: _kAccessToken);
    return token != null && token.isNotEmpty;
  }

  /// accessToken 만료 1분 전부터 만료로 간주
  static Future<bool> isAccessTokenValid() async {
    final expiry = await _storage.read(key: _kAccessTokenExpiry);
    if (expiry == null) return false;
    final expiryTime = DateTime.tryParse(expiry);
    if (expiryTime == null) return false;
    return DateTime.now().isBefore(expiryTime.subtract(const Duration(minutes: 1)));
  }

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) async {
    final expiry = DateTime.now().add(Duration(seconds: expiresIn));
    await Future.wait([
      _storage.write(key: _kAccessToken, value: accessToken),
      _storage.write(key: _kRefreshToken, value: refreshToken),
      _storage.write(key: _kAccessTokenExpiry, value: expiry.toIso8601String()),
    ]);
  }

  static Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kAccessTokenExpiry),
    ]);
  }
}
