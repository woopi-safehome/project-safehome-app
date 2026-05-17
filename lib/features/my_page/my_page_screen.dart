import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../models/deed.dart';
import '../../widgets/safety_badge.dart';
import 'my_page_notifier.dart';

class MyPageScreen extends ConsumerStatefulWidget {
  const MyPageScreen({super.key});

  @override
  ConsumerState<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends ConsumerState<MyPageScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myPageNotifierProvider.notifier).load();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(myPageNotifierProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myPageNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '분석 이력',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(MyPageState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.jobs.isEmpty) {
      return _ErrorView(
        message: state.errorMessage!,
        onRetry: () => ref.read(myPageNotifierProvider.notifier).load(),
      );
    }

    if (state.jobs.isEmpty) {
      return const _EmptyView();
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(myPageNotifierProvider.notifier).load(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: state.jobs.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.jobs.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _JobCard(job: state.jobs[index]);
        },
      ),
    );
  }
}

// ─── Job Card ─────────────────────────────────────────────────────────────────

class _JobCard extends StatelessWidget {
  final DeedJobSummary job;

  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _buildTitle()),
                  const SizedBox(width: 8),
                  _buildStatusChip(),
                ],
              ),
              if (job.address != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        job.address!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (job.safetyLevel != null) ...[
                    SafetyBadge(level: job.safetyLevel!),
                    const SizedBox(width: 8),
                  ],
                  if (job.leaseType != null) _LeaseTypeBadge(leaseType: job.leaseType!),
                  const Spacer(),
                  Text(
                    _formatDate(job.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Row(
      children: [
        const Icon(Icons.picture_as_pdf_rounded,
            size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            job.fileName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip() {
    final (label, color, bg) = switch (job.status) {
      JobStatus.completed => ('완료', AppColors.safe, AppColors.safeBg),
      JobStatus.inProgress || JobStatus.pending => (
          '분석 중',
          AppColors.caution,
          AppColors.cautionBg
        ),
      JobStatus.failed => ('실패', AppColors.danger, AppColors.dangerBg),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    switch (job.status) {
      case JobStatus.completed:
        context.push('/result/${job.jobId}');
      case JobStatus.inProgress:
      case JobStatus.pending:
        context.push('/analyzing/${job.jobId}');
      case JobStatus.failed:
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('분석 실패'),
            content: const Text('분석에 실패한 파일입니다.\n새로운 파일을 다시 업로드해 주세요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

// ─── Lease Type Badge ─────────────────────────────────────────────────────────

class _LeaseTypeBadge extends StatelessWidget {
  final String leaseType;
  const _LeaseTypeBadge({required this.leaseType});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        leaseType,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ─── Empty View ───────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_rounded,
              size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            '분석 이력이 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '홈에서 등기부등본을 업로드하면\n분석 결과가 여기에 저장됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go('/upload'),
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text('분석 시작하기'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.danger.withValues(alpha: 0.7)),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}
