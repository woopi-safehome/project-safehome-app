import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/services/api_client.dart';
import '../../core/services/logger.dart';
import '../../models/deed.dart';

const _tag = 'AnalyzingNotifier';
const _minStepDisplay = Duration(milliseconds: 1500);

// ─── State ────────────────────────────────────────────────────────────────────

class AnalyzingState {
  final DeedJob? job;
  final AnalysisStep? displayStep;
  final String? errorMessage;
  final bool completed;

  const AnalyzingState({
    this.job,
    this.displayStep,
    this.errorMessage,
    this.completed = false,
  });

  AnalyzingState copyWith({
    DeedJob? job,
    Object? displayStep = _sentinel,
    Object? errorMessage = _sentinel,
    bool? completed,
  }) {
    return AnalyzingState(
      job: job ?? this.job,
      displayStep: displayStep == _sentinel ? this.displayStep : displayStep as AnalysisStep?,
      errorMessage: errorMessage == _sentinel ? this.errorMessage : errorMessage as String?,
      completed: completed ?? this.completed,
    );
  }
}

const _sentinel = Object();

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AnalyzingNotifier extends FamilyNotifier<AnalyzingState, String> {
  StreamSubscription<SseEvent>? _sseSub;
  Timer? _stepTimer;

  bool _serverCompleted = false;
  bool _serverFailed = false;

  DateTime _stepStartTime = DateTime.now();
  AnalysisStep? _pendingStep;
  bool _pendingFinish = false;

  @override
  AnalyzingState build(String jobId) {
    ref.onDispose(_stopAll);
    _stepStartTime = DateTime.now();
    _startSse(jobId);
    return const AnalyzingState(displayStep: AnalysisStep.pdfParsing);
  }

  // ── 단계 전환 (최소 표시 시간 게이트) ───────────────────────────────────────

  void _scheduleStep(AnalysisStep next) {
    if (next == state.displayStep) return;

    final remaining = _minStepDisplay - DateTime.now().difference(_stepStartTime);
    if (remaining <= Duration.zero) {
      _applyStep(next);
      if (_pendingFinish) _scheduleFinish();
    } else {
      _pendingStep = next;
      _stepTimer?.cancel();
      _stepTimer = Timer(remaining, _onStepTimerFired);
    }
  }

  void _onStepTimerFired() {
    final next = _pendingStep;
    _pendingStep = null;
    if (next != null) _applyStep(next);
    if (_pendingFinish) {
      _pendingFinish = false;
      _scheduleFinish();
    }
  }

  void _applyStep(AnalysisStep step) {
    _stepStartTime = DateTime.now();
    state = state.copyWith(displayStep: step);
  }

  // ── 완료/실패 처리 (최소 표시 시간 게이트) ──────────────────────────────────

  void _scheduleFinish() {
    if (_pendingStep != null) {
      _pendingFinish = true;
      return;
    }

    final remaining = _minStepDisplay - DateTime.now().difference(_stepStartTime);
    if (remaining <= Duration.zero) {
      _applyFinish();
    } else {
      _stepTimer?.cancel();
      _stepTimer = Timer(remaining, _applyFinish);
    }
  }

  void _applyFinish() {
    if (_serverFailed) {
      state = state.copyWith(errorMessage: '분석에 실패했습니다. 다시 시도해주세요.');
    } else if (_serverCompleted) {
      state = state.copyWith(completed: true);
    }
  }

  // ── SSE 구독 ──────────────────────────────────────────────────────────────────

  void _startSse(String jobId) {
    final apiClient = ref.read(apiClientProvider);

    _sseSub = apiClient.streamJobEvents(jobId).listen(
      (event) async {
        AppLogger.info(_tag, 'SSE event', context: {
          'status': event.status.name,
          'step': event.step?.name,
        });

        if (event.step != null) _scheduleStep(event.step!);

        if (event.status == JobStatus.completed) {
          _sseSub?.cancel();
          _sseSub = null;

          // SSE 최종 이벤트 수신 후 jobId로 전체 결과 조회
          try {
            final job = await apiClient.getJob(jobId);
            state = state.copyWith(job: job);
          } catch (e) {
            AppLogger.error(_tag, 'getJob after SSE completed failed', error: e);
            state = state.copyWith(errorMessage: '결과를 불러오지 못했습니다.');
            return;
          }

          _serverCompleted = true;
          _scheduleFinish();
        } else if (event.status == JobStatus.failed) {
          _sseSub?.cancel();
          _sseSub = null;
          _serverFailed = true;
          _scheduleFinish();
        }
      },
      onError: (Object e) {
        AppLogger.error(_tag, 'SSE error', error: e);
        _stopAll();
        if (e is NetworkException) {
          state = state.copyWith(errorMessage: '네트워크 연결을 확인하세요.');
        } else if (e is ApiException) {
          state = state.copyWith(errorMessage: '서버 오류가 발생했습니다. (${e.statusCode})');
        } else {
          state = state.copyWith(errorMessage: '알 수 없는 오류가 발생했습니다.');
        }
      },
      onDone: () {
        // 스트림이 정상 종료됐는데 완료/실패 처리가 안 된 경우 — 연결 끊김으로 간주
        if (!_serverCompleted && !_serverFailed) {
          AppLogger.error(_tag, 'SSE stream closed unexpectedly');
          state = state.copyWith(errorMessage: '연결이 끊어졌습니다. 다시 시도해주세요.');
        }
      },
    );
  }

  // ── 재시도 ────────────────────────────────────────────────────────────────────

  void retry(String jobId) {
    _stopAll();
    _serverCompleted = false;
    _serverFailed = false;
    _pendingStep = null;
    _pendingFinish = false;
    _stepStartTime = DateTime.now();
    state = const AnalyzingState(displayStep: AnalysisStep.pdfParsing);
    _startSse(jobId);
  }

  void _stopAll() {
    _sseSub?.cancel();
    _sseSub = null;
    _stepTimer?.cancel();
    _stepTimer = null;
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final analyzingNotifierProvider =
    NotifierProviderFamily<AnalyzingNotifier, AnalyzingState, String>(
  AnalyzingNotifier.new,
);
