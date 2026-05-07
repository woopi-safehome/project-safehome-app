import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/deed.dart';

class ChecklistRow extends StatelessWidget {
  final ChecklistItem item;
  final bool isLast;

  const ChecklistRow({super.key, required this.item, this.isLast = false});

  (String label, Color color, Color bg) get _statusStyle => switch (item.status) {
    ChecklistStatus.good => ('양호', AppColors.statusGood, AppColors.statusGoodBg),
    ChecklistStatus.caution => ('주의', AppColors.statusCaution, AppColors.statusCautionBg),
    ChecklistStatus.danger => ('위험', AppColors.statusDanger, AppColors.statusDangerBg),
    ChecklistStatus.unknown => ('확인불가', AppColors.statusUnknown, AppColors.statusUnknownBg),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = _statusStyle;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.item,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.detail,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, color: AppColors.border),
      ],
    );
  }
}
