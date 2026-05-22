import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/deed.dart';

class ChecklistRow extends StatefulWidget {
  final ChecklistItem item;
  final bool isLast;

  const ChecklistRow({super.key, required this.item, this.isLast = false});

  @override
  State<ChecklistRow> createState() => _ChecklistRowState();
}

class _ChecklistRowState extends State<ChecklistRow> {
  bool _expanded = false;

  (String label, Color color, Color bg) get _statusStyle => switch (widget.item.status) {
        ChecklistStatus.good => ('양호', AppColors.statusGood, AppColors.statusGoodBg),
        ChecklistStatus.caution => ('주의', AppColors.statusCaution, AppColors.statusCautionBg),
        ChecklistStatus.danger => ('위험', AppColors.statusDanger, AppColors.statusDangerBg),
        ChecklistStatus.unknown => ('확인불가', AppColors.statusUnknown, AppColors.statusUnknownBg),
      };

  bool get _hasAnalysis => widget.item.analysis != null;

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = _statusStyle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _hasAnalysis ? () => setState(() => _expanded = !_expanded) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.item,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.item.detail,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_hasAnalysis) ...[
                      const SizedBox(width: 4),
                      Icon(
                        _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_hasAnalysis && _expanded) _AnalysisDetail(analysis: widget.item.analysis!),
        if (!widget.isLast) const Divider(height: 1, color: AppColors.border),
      ],
    );
  }
}

class _AnalysisDetail extends StatelessWidget {
  final ChecklistAnalysis analysis;
  const _AnalysisDetail({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(label: '등기 내용', text: analysis.findings),
          const SizedBox(height: 8),
          _DetailRow(label: '임차인 영향', text: analysis.leaseImpact),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String text;
  const _DetailRow({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.5),
        ),
      ],
    );
  }
}
