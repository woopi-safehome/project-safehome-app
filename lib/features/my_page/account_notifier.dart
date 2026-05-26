import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/services/api_client.dart';
import '../../core/services/fcm_service.dart';
import '../../core/services/logger.dart';
import '../../core/services/token_storage.dart';

const _tag = 'AccountNotifier';

sealed class AccountState {
  const AccountState();
}

class AccountIdle extends AccountState {
  const AccountIdle();
}

class AccountLoading extends AccountState {
  const AccountLoading();
}

class AccountDone extends AccountState {
  const AccountDone();
}

class AccountError extends AccountState {
  final String message;
  const AccountError(this.message);
}

class AccountNotifier extends Notifier<AccountState> {
  @override
  AccountState build() => const AccountIdle();

  /// 로그아웃: 카카오 세션 종료(실패 무관) → JWT 삭제
  Future<void> logout() async {
    state = const AccountLoading();
    try {
      await UserApi.instance.logout();
    } catch (_) {
      // 카카오 서버 장애 시에도 로컬 JWT 삭제 후 진행
    }
    FcmService.cancelTokenRefreshListener();
    await TokenStorage.clear();
    state = const AccountDone();
  }

  /// 회원탈퇴: 서버 계정 삭제 (서버에서 카카오 unlink 호출)
  Future<void> withdraw() async {
    state = const AccountLoading();
    try {
      await ref.read(apiClientProvider).withdraw();
      await TokenStorage.clear();
      state = const AccountDone();
    } on ApiException catch (e) {
      AppLogger.error(_tag, '탈퇴 실패 (API)', error: e);
      state = const AccountError('탈퇴 처리에 실패했습니다. 다시 시도해 주세요.');
    } on NetworkException catch (e) {
      AppLogger.error(_tag, '탈퇴 실패 (Network)', error: e);
      state = const AccountError('네트워크 오류가 발생했습니다. 다시 시도해 주세요.');
    } catch (e) {
      AppLogger.error(_tag, '탈퇴 실패 (Unknown)', error: e);
      state = const AccountError('알 수 없는 오류가 발생했습니다.');
    }
  }
}

final accountProvider =
    NotifierProvider<AccountNotifier, AccountState>(AccountNotifier.new);
