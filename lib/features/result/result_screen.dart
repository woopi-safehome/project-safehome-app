import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../models/deed.dart';
import '../../widgets/card_section.dart';
import '../../widgets/checklist_row.dart';
import '../../widgets/info_row.dart';
import '../../widgets/lease_check_item_row.dart';
import '../../widgets/safety_badge.dart';
import 'result_notifier.dart';

class ResultScreen extends ConsumerWidget {
  final String jobId;
  const ResultScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(resultNotifierProvider(jobId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('분석 결과'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/'),
        ),
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, ResultState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('😢', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () =>
                    ref.read(resultNotifierProvider(jobId).notifier).reload(jobId),
                child: const Text('다시 불러오기'),
              ),
            ],
          ),
        ),
      );
    }

    final analysis = state.job?.result;
    if (analysis == null) return const Center(child: Text('결과를 찾을 수 없습니다.'));

    // 유효하지 않은 등기부
    if (!analysis.isValidDeed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📄', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text(
                '등기부등본이 아닙니다',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (analysis.reason != null) ...[
                const SizedBox(height: 8),
                Text(
                  analysis.reason!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return _FullResultView(analysis: analysis);
  }
}

// ─── Full Result View ─────────────────────────────────────────────────────────

class _FullResultView extends StatelessWidget {
  final DeedAnalysis analysis;
  const _FullResultView({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 안전도 배지
          if (analysis.safetyLevel != null)
            Center(child: SafetyBadge(level: analysis.safetyLevel!, large: true)),
          const SizedBox(height: 16),

          // 부동산 정보
          if (analysis.propertyInfo != null)
            _PropertyCard(info: analysis.propertyInfo!),
          const SizedBox(height: 12),

          // 소유권 정보
          if (analysis.ownershipInfo != null)
            _OwnershipCard(info: analysis.ownershipInfo!),
          const SizedBox(height: 12),

          // 핵심 위험 항목
          if (analysis.keyRiskPoints.isNotEmpty)
            _KeyRiskCard(points: analysis.keyRiskPoints),
          const SizedBox(height: 12),

          // 안전 체크리스트
          if (analysis.safetyChecklist.isNotEmpty)
            _ChecklistCard(items: analysis.safetyChecklist),
          const SizedBox(height: 12),

          // 종합 위험 요약
          if (analysis.overallRiskSummary != null)
            _SummaryCard(title: '종합 위험 요약', content: analysis.overallRiskSummary!),
          const SizedBox(height: 12),

          // 임대 분석
          if (analysis.leaseSpecificAnalysis != null)
            _LeaseCard(lease: analysis.leaseSpecificAnalysis!),
          const SizedBox(height: 12),

          // 종합 요약
          if (analysis.summary != null)
            _SummaryCard(title: '종합 요약', content: analysis.summary!),
          const SizedBox(height: 12),

          // 권고사항
          if (analysis.recommendation != null)
            _SummaryCard(title: '권고사항', content: analysis.recommendation!),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Sub Cards ────────────────────────────────────────────────────────────────

class _PropertyCard extends StatelessWidget {
  final PropertyInfo info;
  const _PropertyCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return CardSection(
      title: '부동산 정보',
      children: [
        InfoRow(label: '주소', value: info.address),
        InfoRow(label: '종류', value: info.type),
        InfoRow(label: '면적', value: info.area),
        if (info.purpose != null) InfoRow(label: '용도', value: info.purpose!),
        if (info.buildYear != null)
          InfoRow(label: '건축연도', value: info.buildYear!, isLast: true)
        else
          const InfoRow(label: '', value: '', isLast: true),
      ],
    );
  }
}

class _OwnershipCard extends StatelessWidget {
  final OwnershipInfo info;
  const _OwnershipCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return CardSection(
      title: '소유권 정보',
      trailing: info.frequentTransferWarning
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.cautionBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '⚠️ 잦은 이전',
                style: TextStyle(color: AppColors.caution, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            )
          : null,
      children: [
        InfoRow(label: '현재 소유자', value: info.currentOwner),
        InfoRow(label: '소유자 유형', value: info.ownerType),
        if (info.recentTransferDate != null)
          InfoRow(label: '최근 이전일', value: info.recentTransferDate!),
        if (info.recentTransferCause != null)
          InfoRow(label: '이전 원인', value: info.recentTransferCause!, isLast: true)
        else
          const InfoRow(label: '', value: '', isLast: true),
      ],
    );
  }
}

class _KeyRiskCard extends StatelessWidget {
  final List<String> points;
  const _KeyRiskCard({required this.points});

  @override
  Widget build(BuildContext context) {
    return CardSection(
      title: '핵심 위험 항목',
      children: points
          .map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
                  Expanded(
                    child: Text(p, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  final List<ChecklistItem> items;
  const _ChecklistCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return CardSection(
      title: '안전 체크리스트',
      children: items.asMap().entries.map((e) {
        return ChecklistRow(item: e.value, isLast: e.key == items.length - 1);
      }).toList(),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String content;
  const _SummaryCard({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return CardSection(
      title: title,
      children: [
        Text(content, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.6)),
      ],
    );
  }
}

class _LeaseCard extends StatelessWidget {
  final LeaseSpecificAnalysis lease;
  const _LeaseCard({required this.lease});

  @override
  Widget build(BuildContext context) {
    return CardSection(
      title: '${lease.leaseType} 분석',
      children: [
        Text(lease.summary, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.6)),
        if (lease.checkItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(color: AppColors.border),
          const SizedBox(height: 4),
          ...lease.checkItems.asMap().entries.map((e) {
            return LeaseCheckItemRow(item: e.value, isLast: e.key == lease.checkItems.length - 1);
          }),
        ],
      ],
    );
  }
}
