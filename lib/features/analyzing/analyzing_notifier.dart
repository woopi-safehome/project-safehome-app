import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/services/logger.dart';
import '../../models/deed.dart';
import '../upload/upload_notifier.dart';

const _tag = 'AnalyzingNotifier';
const _pollInterval = Duration(seconds: 2);
const _minStepDisplay = Duration(milliseconds: 1500);

// ─── State ────────────────────────────────────────────────────────────────────

class AnalyzingState {
  final DeedJob? job;
  final AnalysisStep? displayStep; // 서버 step 과 무관하게 UI가 제어하는 단계
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

  // 서버 상태 (폴링 결과)
  DeedJob? _latestJob;
  bool _serverCompleted = false;
  bool _serverFailed = false;

  // UI 단계 진행 — 서버와 무관하게 항상 3단계를 순서대로 표시
  static const _uiSteps = [
    AnalysisStep.pdfParsing,
    AnalysisStep.llmAnalysis,
    AnalysisStep.postProcessing,
  ];
  int _uiStepIndex = 0;
  bool _uiDone = false;

  @override
  AnalyzingState build(String jobId) {
    ref.onDispose(() {
      _pollTimer?.cancel();
      _stepTimer?.cancel();
    });
    _startPolling(jobId);
    // build() 반환 후 notifier 초기화 완료 시점에 실행
    Future.microtask(_advanceStep);
    return const AnalyzingState();
  }

  // ── UI 단계 진행 ─────────────────────────────────────────────────────────────

  void _advanceStep() {
    if (_uiStepIndex >= _uiSteps.length) {
      _uiDone = true;
      _tryFinish();
      return;
    }
    state = state.copyWith(displayStep: _uiSteps[_uiStepIndex]);
    _uiStepIndex++;
    _stepTimer = Timer(_minStepDisplay, _advanceStep);
  }

  // ── UI + 서버 모두 완료됐을 때만 화면 전환 ────────────────────────────────────

  void _tryFinish() {
    if (!_uiDone) return; // UI 단계가 끝나지 않았으면 대기

    if (_serverFailed) {
      state = state.copyWith(errorMessage: '분석에 실패했습니다. 다시 시도해주세요.');
    } else if (_serverCompleted) {
      state = state.copyWith(job: _latestJob, completed: true);
    }
    // 서버가 아직 응답 없으면 폴링이 완료될 때 다시 _tryFinish 호출
  }

  // ── 폴링 ─────────────────────────────────────────────────────────────────────

  void _startPolling(String jobId) {
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll(jobId));
    _poll(jobId);
  }

  Future<void> _poll(String jobId) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final job = await apiClient.getJob(jobId);
      AppLogger.info(_tag, 'poll', context: {'status': job.status.name, 'step': job.step?.name});
      _latestJob = job;

      if (job.status == JobStatus.completed) {
        _pollTimer?.cancel();
        _serverCompleted = true;
        _tryFinish();
      } else if (job.status == JobStatus.failed) {
        _pollTimer?.cancel();
        _serverFailed = true;
        _tryFinish();
      }
      // IN_PROGRESS / PENDING: UI 단계는 독립적으로 진행 중이므로 state 건드리지 않음
    } on NetworkException catch (e) {
      AppLogger.error(_tag, 'network error', error: e);
      _stopAll();
      state = state.copyWith(errorMessage: '네트워크 연결을 확인하세요.');
    } on ApiException catch (e) {
      AppLogger.error(_tag, 'api error', error: e);
      _stopAll();
      state = state.copyWith(errorMessage: '서버 오류가 발생했습니다. (${e.statusCode})');
    } catch (e) {
      AppLogger.error(_tag, 'unexpected error', error: e);
      _stopAll();
      state = state.copyWith(errorMessage: '알 수 없는 오류가 발생했습니다.');
    }
  }

  void _stopAll() {
    _pollTimer?.cancel();
    _stepTimer?.cancel();
  }

  // ── 재시도 ────────────────────────────────────────────────────────────────────

  void retry(String jobId) {
    _stepTimer?.cancel();
    _latestJob = null;
    _serverCompleted = false;
    _serverFailed = false;
    _uiStepIndex = 0;
    _uiDone = false;
    state = const AnalyzingState();
    _startPolling(jobId);
    Future.microtask(_advanceStep);
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final analyzingNotifierProvider =
    NotifierProviderFamily<AnalyzingNotifier, AnalyzingState, String>(
  AnalyzingNotifier.new,
);
