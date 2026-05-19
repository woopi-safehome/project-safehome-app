import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/services/logger.dart';
import '../../models/deed.dart';
import '../upload/upload_notifier.dart';

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
  StreamSubscription<dynamic>? _subscription;
  Timer? _stepTimer;

  DeedJob? _latestJob;
  bool _serverCompleted = false;
  bool _serverFailed = false;

  DateTime _stepStartTime = DateTime.now();
  AnalysisStep? _pendingStep;
  bool _pendingFinish = false;

  @override
  AnalyzingState build(String jobId) {
    ref.onDispose(() {
      _subscription?.cancel();
      _stepTimer?.cancel();
    });
    _applyStep(AnalysisStep.pdfParsing);
    _startStreaming(jobId);
    return AnalyzingState(displayStep: AnalysisStep.pdfParsing);
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
      // 방금 바뀐 단계도 최소 시간 보장 후 완료
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
    // 아직 단계 전환 타이머가 살아 있으면 그쪽에서 처리
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
      state = state.copyWith(job: _latestJob, completed: true);
    }
  }

  // ── SSE 스트리밍 ──────────────────────────────────────────────────────────────

  void _startStreaming(String jobId) {
    final apiClient = ref.read(apiClientProvider);
    _subscription = apiClient.streamJobEvents(jobId).listen(
      (event) async {
        AppLogger.info(_tag, 'sse event', context: {'status': event.status.name, 'step': event.step?.name});

        if (event.step != null) _scheduleStep(event.step!);

        if (event.status == JobStatus.completed) {
          await _subscription?.cancel();
          _subscription = null;
          try {
            _latestJob = await apiClient.getJob(jobId);
          } on NetworkException catch (e) {
            AppLogger.error(_tag, 'getJob network error', error: e);
            _stopAll();
            state = state.copyWith(errorMessage: '네트워크 연결을 확인하세요.');
            return;
          } on ApiException catch (e) {
            AppLogger.error(_tag, 'getJob api error', error: e);
            _stopAll();
            state = state.copyWith(errorMessage: '서버 오류가 발생했습니다. (${e.statusCode})');
            return;
          }
          _serverCompleted = true;
          _scheduleFinish();
        } else if (event.status == JobStatus.failed) {
          await _subscription?.cancel();
          _subscription = null;
          _serverFailed = true;
          _scheduleFinish();
        }
      },
      onError: (Object e) {
        AppLogger.error(_tag, 'stream error', error: e);
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
        // 스트림이 완료/실패 처리 없이 닫힌 경우
        if (!_serverCompleted && !_serverFailed) {
          AppLogger.error(_tag, 'stream closed unexpectedly');
          state = state.copyWith(errorMessage: '분석 결과를 받지 못했습니다. 다시 시도해주세요.');
        }
      },
    );
  }

  void _stopAll() {
    _subscription?.cancel();
    _subscription = null;
    _stepTimer?.cancel();
  }

  // ── 재시도 ────────────────────────────────────────────────────────────────────

  void retry(String jobId) {
    _stopAll();
    _latestJob = null;
    _serverCompleted = false;
    _serverFailed = false;
    _pendingStep = null;
    _pendingFinish = false;
    _applyStep(AnalysisStep.pdfParsing);
    state = AnalyzingState(displayStep: AnalysisStep.pdfParsing);
    _startStreaming(jobId);
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final analyzingNotifierProvider =
    NotifierProviderFamily<AnalyzingNotifier, AnalyzingState, String>(
  AnalyzingNotifier.new,
);
