import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../my_page/account_notifier.dart';
import 'foreground_notification_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(accountProvider, (_, state) {
      switch (state) {
        case AccountDone():
          context.go('/login');
        case AccountError(:final message):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
            ),
          );
        default:
          break;
      }
    });

    final isLoading = ref.watch(accountProvider) is AccountLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildAppBar(context, ref),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroBanner(),
                    const SizedBox(height: 24),
                    _UploadCTACard(),
                    const SizedBox(height: 24),
                    _HowItWorksSection(),
                    const SizedBox(height: 24),
                    _DisclaimerBox(),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ],
          ),
          if (isLoading)
            const ColoredBox(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, WidgetRef ref) {
    return SliverAppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x14000000),
      floating: true,
      snap: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      toolbarHeight: 60,
      title: const Row(
        children: [
          Icon(Icons.home_rounded, color: AppColors.primary, size: 24),
          SizedBox(width: 8),
          Text(
            'SafeHome',
            style: TextStyle(
              color: AppColors.secondary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.history_rounded, color: AppColors.secondary),
          tooltip: '분석 이력',
          onPressed: () => context.push('/my-page'),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: AppColors.secondary),
          tooltip: '설정',
          onPressed: () => _showSettingsSheet(context, ref),
        ),
        PopupMenuButton<_AccountAction>(
          icon: const Icon(Icons.account_circle_outlined, color: AppColors.secondary),
          color: Colors.white,
          onSelected: (action) => _onAccountAction(context, ref, action),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: _AccountAction.logout,
              child: Row(
                children: [
                  Icon(Icons.logout_rounded,
                      size: 18, color: AppColors.textSecondary),
                  SizedBox(width: 10),
                  Text('로그아웃'),
                ],
              ),
            ),
            PopupMenuItem(
              value: _AccountAction.withdraw,
              child: Row(
                children: [
                  Icon(Icons.person_remove_outlined,
                      size: 18, color: AppColors.danger),
                  SizedBox(width: 10),
                  Text('회원탈퇴',
                      style: TextStyle(color: AppColors.danger)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _showSettingsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _SettingsBottomSheet(),
    );
  }

  void _onAccountAction(
      BuildContext context, WidgetRef ref, _AccountAction action) {
    switch (action) {
      case _AccountAction.logout:
        showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('로그아웃'),
            content: const Text('로그아웃 하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('로그아웃'),
              ),
            ],
          ),
        ).then((confirmed) {
          if (confirmed == true) ref.read(accountProvider.notifier).logout();
        });
      case _AccountAction.withdraw:
        showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('회원탈퇴'),
            content: const Text('탈퇴 시 모든 분석 기록이 삭제됩니다.\n정말 탈퇴하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('탈퇴'),
              ),
            ],
          ),
        ).then((confirmed) {
          if (confirmed == true) ref.read(accountProvider.notifier).withdraw();
        });
    }
  }
}

enum _AccountAction { logout, withdraw }

// ─── Hero Banner ──────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome,
                    size: 13, color: Colors.white.withValues(alpha: 0.9)),
                const SizedBox(width: 5),
                Text(
                  'AI 기반 등기부등본 분석',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '안전한 거래를 위한\n스마트한 선택',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.3,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '등기부등본을 올리면 AI가 권리관계를\n꼼꼼하게 분석해 드립니다',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Upload CTA Card ─────────────────────────────────────────────────────────

class _UploadCTACard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 14),
            child: Text(
              '지금 바로 분석하기',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/upload'),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '분석 시작하기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── How It Works ─────────────────────────────────────────────────────────────

class _HowItWorksSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 14),
            child: Text(
              '이렇게 분석해드려요',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: const Column(
              children: [
                _StepRow(
                  step: '01',
                  icon: Icons.picture_as_pdf_rounded,
                  color: AppColors.primary,
                  title: 'PDF 업로드',
                  description: '등기부등본 PDF 파일을 선택해 주세요',
                  isLast: false,
                ),
                _StepRow(
                  step: '02',
                  icon: Icons.psychology_rounded,
                  color: AppColors.secondary,
                  title: 'AI 자동 분석',
                  description: 'AI가 권리관계, 근저당, 위험 요소를 분석합니다',
                  isLast: false,
                ),
                _StepRow(
                  step: '03',
                  icon: Icons.task_alt_rounded,
                  color: AppColors.safe,
                  title: '결과 확인',
                  description: '안전 등급과 상세 분석 결과를 확인하세요',
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String step;
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final bool isLast;

  const _StepRow({
    required this.step,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 10, bottom: isLast ? 0 : 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      step,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Settings Bottom Sheet ────────────────────────────────────────────────────

class _SettingsBottomSheet extends ConsumerWidget {
  const _SettingsBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foregroundEnabled = ref.watch(foregroundNotificationProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '설정',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: const Text(
                '앱 실행 중 푸시 알림',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: const Text(
                '앱이 열려있는 동안에도 분석 완료 알림을 표시합니다',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              value: foregroundEnabled,
              activeColor: AppColors.primary,
              onChanged: (_) =>
                  ref.read(foregroundNotificationProvider.notifier).toggle(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Disclaimer ───────────────────────────────────────────────────────────────

class _DisclaimerBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: AppColors.primary.withValues(alpha: 0.8)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '본 서비스의 분석 결과는 참고용이며, 중요한 거래 결정 전에는 반드시 전문가(법무사, 공인중개사)와 상담하시기 바랍니다.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
