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
  Timer? _pollTimer;
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
      _pollTimer?.cancel();
      _stepTimer?.cancel();
    });
    _stepStartTime = DateTime.now();
    _startPolling(jobId);
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
      state = state.copyWith(job: _latestJob, completed: true);
    }
  }

  // ── 2초 폴링 ──────────────────────────────────────────────────────────────────

  void _startPolling(String jobId) {
    final apiClient = ref.read(apiClientProvider);
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final job = await apiClient.getJob(jobId);
        AppLogger.info(_tag, 'poll', context: {'status': job.status.name, 'step': job.step?.name});

        if (job.step != null) _scheduleStep(job.step!);

        if (job.status == JobStatus.completed) {
          _pollTimer?.cancel();
          _pollTimer = null;
          _latestJob = job;
          _serverCompleted = true;
          _scheduleFinish();
        } else if (job.status == JobStatus.failed) {
          _pollTimer?.cancel();
          _pollTimer = null;
          _serverFailed = true;
          _scheduleFinish();
        }
      } on NetworkException catch (e) {
        AppLogger.error(_tag, 'poll network error', error: e);
        _stopAll();
        state = state.copyWith(errorMessage: '네트워크 연결을 확인하세요.');
      } on ApiException catch (e) {
        AppLogger.error(_tag, 'poll api error', error: e);
        _stopAll();
        state = state.copyWith(errorMessage: '서버 오류가 발생했습니다. (${e.statusCode})');
      } catch (e) {
        AppLogger.error(_tag, 'poll unexpected error', error: e);
        _stopAll();
        state = state.copyWith(errorMessage: '알 수 없는 오류가 발생했습니다.');
      }
    });
  }

  void _stopAll() {
    _pollTimer?.cancel();
    _pollTimer = null;
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
    _stepStartTime = DateTime.now();
    state = AnalyzingState(displayStep: AnalysisStep.pdfParsing);
    _startPolling(jobId);
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final analyzingNotifierProvider =
    NotifierProviderFamily<AnalyzingNotifier, AnalyzingState, String>(
  AnalyzingNotifier.new,
);
