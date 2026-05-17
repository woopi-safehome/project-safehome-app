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

class _AnalyzingScreenState extends ConsumerState<AnalyzingScreen> {
  String _currentMessage = '파일을 받았어요, 분석을 시작할게요';
  bool _messageVisible = true;

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

  double _progressValue(int stepIndex) => switch (stepIndex) {
        0 => 0.25,
        1 => 0.60,
        2 => 0.88,
        _ => 0.04,
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analyzingNotifierProvider(widget.jobId));

    final msg = _messageFor(state.displayStep);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateMessage(msg));

    if (state.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/result/${widget.jobId}');
      });
    }

    final stepIndex = _stepIndex(state.displayStep);

    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      body: state.errorMessage != null
          ? _ErrorView(
              message: state.errorMessage!,
              onRetry: () => ref
                  .read(analyzingNotifierProvider(widget.jobId).notifier)
                  .retry(widget.jobId),
            )
          : _LoadingBody(
              message: _currentMessage,
              messageVisible: _messageVisible,
              progressValue: _progressValue(stepIndex),
            ),
    );
  }
}

// ─── Loading Body ─────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  final String message;
  final bool messageVisible;
  final double progressValue;

  const _LoadingBody({
    required this.message,
    required this.messageVisible,
    required this.progressValue,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _DocScanAnimation(),

            const SizedBox(height: 36),

            // 퍼센트 숫자
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.04, end: progressValue),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeInOut,
              builder: (context, value, _) {
                return Text(
                  '${(value * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: -1.5,
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // 진행 문구 (흐릿하게)
            AnimatedOpacity(
              opacity: messageVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 280),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Document Scan Animation ──────────────────────────────────────────────────

class _DocScanAnimation extends StatefulWidget {
  const _DocScanAnimation();

  @override
  State<_DocScanAnimation> createState() => _DocScanAnimationState();
}

class _DocScanAnimationState extends State<_DocScanAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const docW = 152.0;
    const docH = 120.0;
    const padH = 20.0;
    const lensSize = 22.0;
    const lineCount = 4;
    // x range the lens travels across (leaving room for icon width)
    const trackW = docW - padH * 2 - lensSize;

    // Fixed y centers of each line inside the card
    const lineYs = [24.0, 46.0, 68.0, 90.0];
    // Vary line widths to look like real text
    const lineWidths = [1.0, 0.72, 0.88, 0.58];

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final lineF = t * lineCount;
        final lineIdx = lineF.floor().clamp(0, lineCount - 1);
        final lineT = lineF - lineIdx; // 0~1 progress within current line

        // Even lines scan left→right, odd lines right→left
        final xPct = lineIdx.isEven ? lineT : 1.0 - lineT;

        final lensLeft = padH + xPct * trackW;
        final lensTop = lineYs[lineIdx] - lensSize / 2 - 2;

        return SizedBox(
          width: docW,
          height: docH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Document card
              Container(
                width: docW,
                height: docH,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.13),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Text lines
                    ...List.generate(lineCount, (i) {
                      final isActive = i == lineIdx;
                      return Positioned(
                        left: padH,
                        top: lineYs[i] - 4,
                        child: Container(
                          height: 7,
                          width: (docW - padH * 2) * lineWidths[i],
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primary.withValues(alpha: 0.38)
                                : AppColors.border.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Lens glow halo
              Positioned(
                left: lensLeft - 5,
                top: lensTop - 5,
                child: Container(
                  width: lensSize + 10,
                  height: lensSize + 10,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Magnifying glass icon
              Positioned(
                left: lensLeft,
                top: lensTop,
                child: const Icon(
                  Icons.search_rounded,
                  size: lensSize,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        );
      },
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
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: AppColors.danger,
                ),
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
                  label: const Text(
                    '다시 시도',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
