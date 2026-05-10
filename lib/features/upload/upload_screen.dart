import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import 'upload_notifier.dart';

class UploadScreen extends ConsumerWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(uploadNotifierProvider);
    final notifier = ref.read(uploadNotifierProvider.notifier);
    final apiClient = ref.read(apiClientProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('등기부등본 분석'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 안내 헤더
              _SectionHeader(
                icon: Icons.upload_file_rounded,
                title: 'PDF 파일 선택',
                subtitle: '등기부등본 PDF를 선택해주세요',
              ),
              const SizedBox(height: 12),

              // 파일 선택 영역
              GestureDetector(
                onTap: state.uploading ? null : notifier.pickFile,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 200,
                  decoration: BoxDecoration(
                    color: state.selectedFile != null
                        ? AppColors.secondaryLight
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: state.selectedFile != null
                          ? AppColors.secondary
                          : AppColors.border,
                      width: state.selectedFile != null ? 2 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: state.selectedFile != null
                      ? _SelectedFileView(
                          fileName: state.selectedFile!.name,
                          fileSize: state.selectedFile!.size,
                        )
                      : const _DropZonePlaceholder(),
                ),
              ),
              const SizedBox(height: 24),

              // 임대 유형 선택
              _SectionHeader(
                icon: Icons.home_work_rounded,
                title: '임대 유형 선택',
                subtitle: '선택하면 맞춤형 분석 결과를 제공해요',
              ),
              const SizedBox(height: 12),
              Row(
                children: ['전세', '월세'].map((type) {
                  final selected = state.leaseType == type;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: type == '전세' ? 8 : 0),
                      child: GestureDetector(
                        onTap: () => notifier.toggleLeaseType(type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? AppColors.primary : AppColors.border,
                              width: selected ? 2 : 1.5,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Column(
                            children: [
                              Icon(
                                type == '전세'
                                    ? Icons.account_balance_rounded
                                    : Icons.monetization_on_rounded,
                                size: 26,
                                color: selected ? Colors.white : AppColors.textSecondary,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                type,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // 에러 메시지
              if (state.errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // 분석 시작 버튼
              GestureDetector(
                onTap: (state.selectedFile == null || state.uploading)
                    ? null
                    : () async {
                        final jobId = await notifier.upload(apiClient);
                        if (jobId != null && context.mounted) {
                          context.go('/analyzing/$jobId');
                        }
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: state.selectedFile != null && !state.uploading
                        ? const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    color: state.selectedFile == null || state.uploading
                        ? AppColors.border
                        : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: state.selectedFile != null && !state.uploading
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: state.uploading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_rounded,
                                color: state.selectedFile != null
                                    ? Colors.white
                                    : AppColors.textMuted,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'AI 분석 시작',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: state.selectedFile != null
                                      ? Colors.white
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 소요 시간 안내
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    const Text(
                      '평균 분석 소요 시간: 10~30초',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SectionHeader({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Drop Zone ────────────────────────────────────────────────────────────────

class _DropZonePlaceholder extends StatelessWidget {
  const _DropZonePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.picture_as_pdf_rounded,
            size: 30,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'PDF 파일을 선택하세요',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          '탭하여 파일 탐색기 열기',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ─── Selected File ────────────────────────────────────────────────────────────

class _SelectedFileView extends StatelessWidget {
  final String fileName;
  final int fileSize;
  const _SelectedFileView({required this.fileName, required this.fileSize});

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 32,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            fileName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatSize(fileSize),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          '탭하여 다른 파일 선택',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.secondary.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
