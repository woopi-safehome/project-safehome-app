import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../models/deed.dart';
import '../../widgets/checklist_row.dart';
import '../../widgets/lease_check_item_row.dart';
import 'result_notifier.dart';

class ResultScreen extends ConsumerWidget {
  final String jobId;
  const ResultScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(resultNotifierProvider(jobId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _buildBody(context, ref, state),
      floatingActionButton: (state.job?.result != null && state.job!.result!.isValidDeed)
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('새 분석', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, ResultState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null) {
      return _FullErrorView(
        message: state.errorMessage!,
        onRetry: () => ref.read(resultNotifierProvider(jobId).notifier).reload(jobId),
        onHome: () => context.go('/'),
      );
    }

    final analysis = state.job?.result;
    if (analysis == null) {
      return _FullErrorView(
        message: '결과를 찾을 수 없습니다.',
        onRetry: () => ref.read(resultNotifierProvider(jobId).notifier).reload(jobId),
        onHome: () => context.go('/'),
      );
    }

    if (!analysis.isValidDeed) {
      return _InvalidDeedView(analysis: analysis, onHome: () => context.go('/'));
    }

    return _FullResultView(analysis: analysis, onHome: () => context.go('/'));
  }
}

// ─── Safety Hero ──────────────────────────────────────────────────────────────

class _SafetyHero extends StatelessWidget {
  final SafetyLevel level;
  final VoidCallback onHome;

  const _SafetyHero({required this.level, required this.onHome});

  @override
  Widget build(BuildContext context) {
    final (icon, label, desc, bg, fg) = switch (level) {
      SafetyLevel.safe => (
          Icons.verified_rounded,
          '안전',
          '이 부동산은 안전합니다',
          const Color(0xFF15803D),
          const Color(0xFFDCFCE7),
        ),
      SafetyLevel.caution => (
          Icons.warning_amber_rounded,
          '주의',
          '확인이 필요한 사항이 있습니다',
          const Color(0xFFB45309),
          const Color(0xFFFEF9C3),
        ),
      SafetyLevel.danger => (
          Icons.dangerous_rounded,
          '위험',
          '위험 요소가 발견되었습니다',
          const Color(0xFFBE123C),
          const Color(0xFFFFE4E6),
        ),
    };

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            bg.withValues(alpha: 0.95),
            bg,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 앱바 행
              Row(
                children: [
                  GestureDetector(
                    onTap: onHome,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.home_rounded, size: 20, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '분석 결과',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // 안전도 배지
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: fg.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 34, color: fg),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: fg.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: fg.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        desc,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: fg,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Full Result View ─────────────────────────────────────────────────────────

class _FullResultView extends StatelessWidget {
  final DeedAnalysis analysis;
  final VoidCallback onHome;
  const _FullResultView({required this.analysis, required this.onHome});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: analysis.safetyLevel != null
              ? _SafetyHero(level: analysis.safetyLevel!, onHome: onHome)
              : const SizedBox.shrink(),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // 핵심 위험 (있을 때만, 최상단 강조)
              if (analysis.keyRiskPoints.isNotEmpty) ...[
                _KeyRiskCard(points: analysis.keyRiskPoints),
                const SizedBox(height: 12),
              ],

              // 부동산 정보
              if (analysis.propertyInfo != null) ...[
                _ResultCard(
                  title: '부동산 정보',
                  icon: Icons.location_on_rounded,
                  iconColor: AppColors.primary,
                  child: _PropertyContent(info: analysis.propertyInfo!),
                ),
                const SizedBox(height: 12),
              ],

              // 소유권 정보
              if (analysis.ownershipInfo != null) ...[
                _ResultCard(
                  title: '소유권 정보',
                  icon: Icons.person_rounded,
                  iconColor: AppColors.secondary,
                  trailing: analysis.ownershipInfo!.frequentTransferWarning
                      ? _WarningChip(label: '잦은 이전')
                      : null,
                  child: _OwnershipContent(info: analysis.ownershipInfo!),
                ),
                const SizedBox(height: 12),
              ],

              // 안전 체크리스트
              if (analysis.safetyChecklist.isNotEmpty) ...[
                _ResultCard(
                  title: '안전 체크리스트',
                  icon: Icons.checklist_rounded,
                  iconColor: AppColors.safe,
                  child: _ChecklistContent(items: analysis.safetyChecklist),
                ),
                const SizedBox(height: 12),
              ],

              // 임대 분석
              if (analysis.leaseSpecificAnalysis != null) ...[
                _ResultCard(
                  title: '${analysis.leaseSpecificAnalysis!.leaseType} 임대 분석',
                  icon: Icons.home_work_rounded,
                  iconColor: AppColors.caution,
                  child: _LeaseContent(lease: analysis.leaseSpecificAnalysis!),
                ),
                const SizedBox(height: 12),
              ],

              // 종합 위험 요약
              if (analysis.overallRiskSummary != null) ...[
                _ResultCard(
                  title: '종합 위험 요약',
                  icon: Icons.summarize_rounded,
                  iconColor: AppColors.danger,
                  child: _TextContent(text: analysis.overallRiskSummary!),
                ),
                const SizedBox(height: 12),
              ],

              // 종합 요약
              if (analysis.summary != null) ...[
                _ResultCard(
                  title: '종합 요약',
                  icon: Icons.description_rounded,
                  iconColor: AppColors.textSecondary,
                  child: _TextContent(text: analysis.summary!),
                ),
                const SizedBox(height: 12),
              ],

              // 권고사항
              if (analysis.recommendation != null) ...[
                _RecommendationCard(text: analysis.recommendation!),
                const SizedBox(height: 12),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

// ─── Cards ────────────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final Widget? trailing;

  const _ResultCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카드 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 17, color: iconColor),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing!,
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _KeyRiskCard extends StatelessWidget {
  final List<String> points;
  const _KeyRiskCard({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.report_problem_rounded, size: 18, color: AppColors.danger),
              const SizedBox(width: 8),
              const Text(
                '핵심 위험 항목',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...points.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.circle, size: 7, color: AppColors.danger),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final String text;
  const _RecommendationCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryLight, AppColors.secondaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                '권고사항',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningChip extends StatelessWidget {
  final String label;
  const _WarningChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.cautionBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.caution.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.caution),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.caution,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card Contents ────────────────────────────────────────────────────────────

class _PropertyContent extends StatelessWidget {
  final PropertyInfo info;
  const _PropertyContent({required this.info});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoRow(label: '주소', value: info.address),
        _InfoRow(label: '종류', value: info.type),
        _InfoRow(label: '면적', value: info.area),
        if (info.purpose != null) _InfoRow(label: '용도', value: info.purpose!),
        if (info.buildYear != null) _InfoRow(label: '건축연도', value: info.buildYear!, isLast: true)
        else const SizedBox.shrink(),
      ],
    );
  }
}

class _OwnershipContent extends StatelessWidget {
  final OwnershipInfo info;
  const _OwnershipContent({required this.info});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoRow(label: '현재 소유자', value: info.currentOwner),
        _InfoRow(label: '소유자 유형', value: info.ownerType),
        if (info.recentTransferDate != null)
          _InfoRow(label: '최근 이전일', value: info.recentTransferDate!),
        if (info.recentTransferCause != null)
          _InfoRow(label: '이전 원인', value: info.recentTransferCause!, isLast: true),
      ],
    );
  }
}

class _ChecklistContent extends StatelessWidget {
  final List<ChecklistItem> items;
  const _ChecklistContent({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.asMap().entries.map((e) {
        return ChecklistRow(item: e.value, isLast: e.key == items.length - 1);
      }).toList(),
    );
  }
}

class _LeaseContent extends StatelessWidget {
  final LeaseSpecificAnalysis lease;
  const _LeaseContent({required this.lease});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lease.summary,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.6),
        ),
        if (lease.checkItems.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Divider(color: AppColors.border),
          const SizedBox(height: 6),
          ...lease.checkItems.asMap().entries.map((e) {
            return LeaseCheckItemRow(item: e.value, isLast: e.key == lease.checkItems.length - 1);
          }),
        ],
      ],
    );
  }
}

class _TextContent extends StatelessWidget {
  final String text;
  const _TextContent({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.65),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  const _InfoRow({required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Invalid Deed View ────────────────────────────────────────────────────────

class _InvalidDeedView extends StatelessWidget {
  final DeedAnalysis analysis;
  final VoidCallback onHome;
  const _InvalidDeedView({required this.analysis, required this.onHome});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // 미니 앱바
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onHome,
                  child: const Icon(Icons.home_rounded, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 12),
                const Text(
                  '분석 결과',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Expanded(
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
                        color: AppColors.cautionBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        size: 38,
                        color: AppColors.caution,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '등기부등본이 아닙니다',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (analysis.reason != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        analysis.reason!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onHome,
                        icon: const Icon(Icons.home_rounded, size: 18),
                        label: const Text(
                          '다시 분석하기',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
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
          ),
        ],
      ),
    );
  }
}

// ─── Full Error View ──────────────────────────────────────────────────────────

class _FullErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onHome;
  const _FullErrorView({required this.message, required this.onRetry, required this.onHome});

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
                decoration: BoxDecoration(color: AppColors.dangerBg, shape: BoxShape.circle),
                child: const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.danger),
              ),
              const SizedBox(height: 20),
              const Text(
                '결과를 불러오지 못했어요',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onHome,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('홈으로', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onRetry,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('다시 시도', style: TextStyle(fontWeight: FontWeight.w600)),
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
}
