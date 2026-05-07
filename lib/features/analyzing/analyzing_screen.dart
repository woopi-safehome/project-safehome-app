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
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  String _currentMessage = '파일을 받았어요\n잠시 후 분석을 시작할게요';
  bool _messageVisible = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.4, end: 0.85).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _messageFor(AnalysisStep? step) => switch (step) {
    AnalysisStep.pdfParsing => '등기부등본의 내용을\n읽어오고 있어요',
    AnalysisStep.llmAnalysis =>
      '소유권, 근저당, 가압류 등\n권리 관계를 꼼꼼히 살펴보고 있어요',
    AnalysisStep.postProcessing =>
      '분석을 마무리하고\n안전 여부를 판단하고 있어요',
    null => '파일을 받았어요\n잠시 후 분석을 시작할게요',
  };

  void _updateMessage(String newMsg) {
    if (newMsg == _currentMessage) return;
    setState(() => _messageVisible = false);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _currentMessage = newMsg;
        _messageVisible = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analyzingNotifierProvider(widget.jobId));

    // 메시지 업데이트
    final msg = _messageFor(state.job?.step);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateMessage(msg));

    // 완료 시 결과 화면으로 이동
    if (state.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/result/${widget.jobId}');
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: state.errorMessage != null
                ? _ErrorView(
                    message: state.errorMessage!,
                    onRetry: () => ref
                        .read(analyzingNotifierProvider(widget.jobId).notifier)
                        .retry(widget.jobId),
                  )
                : _LoadingView(
                    pulseScale: _pulseScale,
                    pulseOpacity: _pulseOpacity,
                    message: _currentMessage,
                    messageVisible: _messageVisible,
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Loading View ─────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final Animation<double> pulseScale;
  final Animation<double> pulseOpacity;
  final String message;
  final bool messageVisible;

  const _LoadingView({
    required this.pulseScale,
    required this.pulseOpacity,
    required this.message,
    required this.messageVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 펄스 원
        AnimatedBuilder(
          animation: pulseScale,
          builder: (_, __) => Transform.scale(
            scale: pulseScale.value,
            child: AnimatedOpacity(
              opacity: pulseOpacity.value,
              duration: Duration.zero,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🔍', style: TextStyle(fontSize: 48)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'AI가 분석하고 있어요',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        AnimatedOpacity(
          opacity: messageVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ),
      ],
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('😢', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
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
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onRetry,
          child: const Text('다시 시도'),
        ),
      ],
    );
  }
}
