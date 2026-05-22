import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/services/api_client.dart';
import '../../core/services/logger.dart';
import '../../models/deed.dart';

const _tag = 'ResultNotifier';

// ─── State ────────────────────────────────────────────────────────────────────

class ResultState {
  final DeedJob? job;
  final bool loading;
  final String? errorMessage;

  const ResultState({this.job, this.loading = true, this.errorMessage});

  ResultState copyWith({
    DeedJob? job,
    bool? loading,
    Object? errorMessage = _sentinel,
  }) {
    return ResultState(
      job: job ?? this.job,
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel ? this.errorMessage : errorMessage as String?,
    );
  }
}

const _sentinel = Object();

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ResultNotifier extends FamilyNotifier<ResultState, String> {
  @override
  ResultState build(String jobId) {
    _load(jobId);
    return const ResultState();
  }

  Future<void> _load(String jobId) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final job = await apiClient.getJob(jobId);
      AppLogger.info(_tag, 'loaded job', context: {'status': job.status.name});
      state = state.copyWith(job: job, loading: false, errorMessage: null);
    } on NetworkException catch (e) {
      AppLogger.error(_tag, 'network error', error: e);
      state = state.copyWith(loading: false, errorMessage: '네트워크 연결을 확인하세요.');
    } on ApiException catch (e) {
      AppLogger.error(_tag, 'api error', error: e);
      state = state.copyWith(loading: false, errorMessage: '서버 오류가 발생했습니다. (${e.statusCode})');
    } catch (e) {
      AppLogger.error(_tag, 'unexpected error', error: e);
      state = state.copyWith(loading: false, errorMessage: '결과를 불러올 수 없습니다.');
    }
  }

  void reload(String jobId) {
    state = const ResultState();
    _load(jobId);
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final resultNotifierProvider =
    NotifierProviderFamily<ResultNotifier, ResultState, String>(
  ResultNotifier.new,
);
