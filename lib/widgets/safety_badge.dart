import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/deed.dart';

class SafetyBadge extends StatelessWidget {
  final SafetyLevel level;
  final bool large;

  const SafetyBadge({super.key, required this.level, this.large = false});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color, bg) = switch (level) {
      SafetyLevel.safe => ('✅', '안전', AppColors.safe, AppColors.safeBg),
      SafetyLevel.caution => ('⚠️', '주의', AppColors.caution, AppColors.cautionBg),
      SafetyLevel.danger => ('🚨', '위험', AppColors.danger, AppColors.dangerBg),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 20 : 12,
        vertical: large ? 10 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(large ? 12 : 8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: TextStyle(fontSize: large ? 22 : 16)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: large ? 18 : 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
