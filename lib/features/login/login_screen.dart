import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Column(
        children: [
          // ── 상단 브랜딩 영역 ──────────────────────────────────
          Expanded(
            flex: 5,
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  // 배경 장식 원
                  Positioned(
                    top: -30,
                    right: -50,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.secondary.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.shield_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'SafeHome',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '등기부등본 AI 분석으로\n안전한 부동산 거래를 시작하세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 15,
                            height: 1.65,
                          ),
                        ),
                        const SizedBox(height: 28),
                        // 신뢰 지표 3개
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _TrustChip(icon: Icons.verified_rounded, label: '정확한 분석'),
                            const SizedBox(width: 8),
                            _TrustChip(icon: Icons.bolt_rounded, label: '빠른 결과'),
                            const SizedBox(width: 8),
                            _TrustChip(icon: Icons.lock_rounded, label: '안전 보관'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 하단 로그인 카드 ────────────────────────────────────
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 0),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '시작하기',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '카카오 계정으로 간편하게 로그인하세요',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 카카오 로그인 버튼
                    _KakaoButton(onTap: () => context.go('/')),
                    const SizedBox(height: 14),

                    // 둘러보기
                    TextButton(
                      onPressed: () => context.go('/'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: AppColors.textMuted,
                      ),
                      child: const Text(
                        '로그인 없이 둘러보기',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),

                    const Spacer(),

                    // 약관
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        '로그인 시 이용약관 및 개인정보처리방침에 동의합니다',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted.withValues(alpha: 0.8),
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

class _TrustChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _KakaoButton extends StatelessWidget {
  final VoidCallback onTap;
  const _KakaoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFFEE500),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFEE500).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: Color(0xFF3C1E1E),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_rounded,
                size: 14,
                color: Color(0xFFFEE500),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              '카카오로 시작하기',
              style: TextStyle(
                color: Color(0xFF3C1E1E),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
