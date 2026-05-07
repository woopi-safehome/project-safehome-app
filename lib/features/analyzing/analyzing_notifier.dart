import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/services/logger.dart';
import '../../models/deed.dart';
import '../upload/upload_notifier.dart';

const _tag = 'AnalyzingNotifier';
const _pollInterval = Duration(seconds: 2);

// ─── State ────────────────────────────────────────────────────────────────────

class AnalyzingState {
  final DeedJob? job;
  final String? errorMessage;
  final bool completed;

  const AnalyzingState({this.job, this.errorMessage, this.completed = false});

  AnalyzingState copyWith({
    DeedJob? job,
    Object? errorMessage = _sentinel,
    bool? completed,
  }) {
    return AnalyzingState(
      job: job ?? this.job,
      errorMessage: errorMessage == _sentinel ? this.errorMessage : errorMessage as String?,
      completed: completed ?? this.completed,
    );
  }
}

const _sentinel = Object();

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AnalyzingNotifier extends FamilyNotifier<AnalyzingState, String> {
  Timer? _timer;

  @override
  AnalyzingState build(String jobId) {
    ref.onDispose(() => _timer?.cancel());
    _startPolling(jobId);
    return const AnalyzingState();
  }

  void _startPolling(String jobId) {
    _timer = Timer.periodic(_pollInterval, (_) => _poll(jobId));
    _poll(jobId); // 즉시 첫 번째 폴링
  }

  Future<void> _poll(String jobId) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final job = await apiClient.getJob(jobId);
      AppLogger.info(_tag, 'poll', context: {'status': job.status.name, 'step': job.step?.name});

      state = state.copyWith(job: job, errorMessage: null);

      if (job.status == JobStatus.completed || job.status == JobStatus.failed) {
        _timer?.cancel();
        if (job.status == JobStatus.completed) {
          state = state.copyWith(completed: true);
        } else {
          state = state.copyWith(errorMessage: '분석에 실패했습니다. 다시 시도해주세요.');
        }
      }
    } on NetworkException catch (e) {
      AppLogger.error(_tag, 'network error', error: e);
      state = state.copyWith(errorMessage: '네트워크 연결을 확인하세요.');
    } on ApiException catch (e) {
      AppLogger.error(_tag, 'api error', error: e);
      state = state.copyWith(errorMessage: '서버 오류가 발생했습니다. (${e.statusCode})');
    } catch (e) {
      AppLogger.error(_tag, 'unexpected error', error: e);
      state = state.copyWith(errorMessage: '알 수 없는 오류가 발생했습니다.');
    }
  }

  void retry(String jobId) {
    state = const AnalyzingState();
    _startPolling(jobId);
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final analyzingNotifierProvider =
    NotifierProviderFamily<AnalyzingNotifier, AnalyzingState, String>(
  AnalyzingNotifier.new,
);
