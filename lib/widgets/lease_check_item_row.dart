import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/deed.dart';

class LeaseCheckItemRow extends StatelessWidget {
  final LeaseCheckItem item;
  final bool isLast;

  const LeaseCheckItemRow({super.key, required this.item, this.isLast = false});

  (String label, Color color) get _priorityStyle => switch (item.priority) {
    LeaseCheckItemPriority.required_ => ('필수', AppColors.priorityRequired),
    LeaseCheckItemPriority.recommended => ('권장', AppColors.priorityRecommended),
    LeaseCheckItemPriority.reference => ('참고', AppColors.priorityReference),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _priorityStyle;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 1),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: color),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
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
