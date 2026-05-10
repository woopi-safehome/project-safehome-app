import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../models/deed.dart';
import 'analyzing_notifier.dart';

class AnalyzingScreen extends ConsumerStatefulWidget {
  final String jobId;
  const AnalyzingScreen({super.key, required this.jobId});

  @override
  ConsumerState<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends ConsumerState<AnalyzingScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotateCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  String _currentMessage = '파일을 받았어요, 분석을 시작할게요';
  bool _messageVisible = true;

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _messageFor(AnalysisStep? step) => switch (step) {
        AnalysisStep.pdfParsing => '등기부등본의 내용을 읽어오고 있어요',
        AnalysisStep.llmAnalysis => '소유권, 근저당, 가압류를 꼼꼼히 살펴보고 있어요',
        AnalysisStep.postProcessing => '분석을 마무리하고 안전 등급을 판단하고 있어요',
        null => '파일을 받았어요, 분석을 시작할게요',
      };

  void _updateMessage(String newMsg) {
    if (newMsg == _currentMessage) return;
    setState(() => _messageVisible = false);
    Future.delayed(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() {
        _currentMessage = newMsg;
        _messageVisible = true;
      });
    });
  }

  int _stepIndex(AnalysisStep? step) => switch (step) {
        AnalysisStep.pdfParsing => 0,
        AnalysisStep.llmAnalysis => 1,
        AnalysisStep.postProcessing => 2,
        null => -1,
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analyzingNotifierProvider(widget.jobId));

    final msg = _messageFor(state.job?.step);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateMessage(msg));

    if (state.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/result/${widget.jobId}');
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: state.errorMessage != null
          ? _ErrorView(
              message: state.errorMessage!,
              onRetry: () => ref
                  .read(analyzingNotifierProvider(widget.jobId).notifier)
                  .retry(widget.jobId),
            )
          : _LoadingBody(
              rotateCtrl: _rotateCtrl,
              pulseAnim: _pulseAnim,
              message: _currentMessage,
              messageVisible: _messageVisible,
              currentStep: state.job?.step,
              stepIndex: _stepIndex(state.job?.step),
            ),
    );
  }
}

// ─── Loading Body ─────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  final AnimationController rotateCtrl;
  final Animation<double> pulseAnim;
  final String message;
  final bool messageVisible;
  final AnalysisStep? currentStep;
  final int stepIndex;

  const _LoadingBody({
    required this.rotateCtrl,
    required this.pulseAnim,
    required this.message,
    required this.messageVisible,
    required this.currentStep,
    required this.stepIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 상단 네이비 배너
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'SafeHome',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // 회전 분석 아이콘
                  ScaleTransition(
                    scale: pulseAnim,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 회전 링
                        RotationTransition(
                          turns: rotateCtrl,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 3,
                              ),
                            ),
                            child: const CircularProgressIndicator(
                              color: Colors.transparent,
                              strokeWidth: 0,
                            ),
                          ),
                        ),
                        // 반원 스피너
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: CircularProgressIndicator(
                            color: Colors.white.withValues(alpha: 0.85),
                            strokeWidth: 3,
                          ),
                        ),
                        // 가운데 아이콘
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.document_scanner_rounded,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'AI가 분석하고 있어요',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedOpacity(
                    opacity: messageVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 280),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 하단 단계 카드
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '분석 진행 단계',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _AnalyzingStep(
                        icon: Icons.picture_as_pdf_rounded,
                        label: 'PDF 파싱',
                        description: '문서에서 텍스트를 추출합니다',
                        state: stepIndex > 0
                            ? _StepState.done
                            : stepIndex == 0
                                ? _StepState.active
                                : _StepState.pending,
                        isLast: false,
                      ),
                      _AnalyzingStep(
                        icon: Icons.psychology_rounded,
                        label: 'AI 권리 분석',
                        description: '소유권, 근저당, 위험 요소를 분석합니다',
                        state: stepIndex > 1
                            ? _StepState.done
                            : stepIndex == 1
                                ? _StepState.active
                                : _StepState.pending,
                        isLast: false,
                      ),
                      _AnalyzingStep(
                        icon: Icons.task_alt_rounded,
                        label: '결과 생성',
                        description: '안전 등급과 상세 리포트를 작성합니다',
                        state: stepIndex > 2
                            ? _StepState.done
                            : stepIndex == 2
                                ? _StepState.active
                                : _StepState.pending,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 5),
                      const Text(
                        '평균 10~30초 소요됩니다',
                        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _StepState { pending, active, done }

class _AnalyzingStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final _StepState state;
  final bool isLast;

  const _AnalyzingStep({
    required this.icon,
    required this.label,
    required this.description,
    required this.state,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = switch (state) {
      _StepState.done => AppColors.safe,
      _StepState.active => AppColors.secondary,
      _StepState.pending => AppColors.border,
    };

    final IconData stateIcon = switch (state) {
      _StepState.done => Icons.check_rounded,
      _StepState.active => Icons.radio_button_on_rounded,
      _StepState.pending => Icons.radio_button_off_rounded,
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, isLast ? 16 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: state == _StepState.pending ? 0.08 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  state == _StepState.done ? Icons.check_rounded : icon,
                  size: 20,
                  color: state == _StepState.pending
                      ? AppColors.textMuted
                      : color,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 28,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: AppColors.border,
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 8, bottom: isLast ? 0 : 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: state == _StepState.pending
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (state == _StepState.active) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '진행 중',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ],
                      if (state == _StepState.done) ...[
                        const SizedBox(width: 8),
                        Icon(stateIcon, size: 14, color: AppColors.safe),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error View ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.danger),
              ),
              const SizedBox(height: 20),
              const Text(
                '분석 중 오류가 발생했어요',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('다시 시도', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
