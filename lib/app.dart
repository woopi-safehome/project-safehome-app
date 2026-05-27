import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_theme.dart';
import 'core/services/fcm_service.dart';
import 'features/analyzing/analyzing_screen.dart';
import 'features/home/foreground_notification_provider.dart';
import 'features/home/home_screen.dart';
import 'features/login/login_screen.dart';
import 'features/my_page/my_page_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/result/result_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/upload/upload_screen.dart';

Page<void> _fadePage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      pageBuilder: (_, state) => _fadePage(state, const SplashScreen()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (_, state) => _fadePage(state, const LoginScreen()),
    ),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (_, state) => _fadePage(state, const OnboardingScreen()),
    ),
    GoRoute(
      path: '/',
      pageBuilder: (_, state) => _fadePage(state, const HomeScreen()),
    ),
    GoRoute(
      path: '/upload',
      pageBuilder: (_, state) => _fadePage(state, const UploadScreen()),
    ),
    GoRoute(
      path: '/analyzing/:jobId',
      pageBuilder: (_, state) => _fadePage(
        state,
        AnalyzingScreen(jobId: state.pathParameters['jobId']!),
      ),
    ),
    GoRoute(
      path: '/result/:jobId',
      pageBuilder: (_, state) => _fadePage(
        state,
        ResultScreen(jobId: state.pathParameters['jobId']!),
      ),
    ),
    GoRoute(
      path: '/my-page',
      pageBuilder: (_, state) => _fadePage(state, const MyPageScreen()),
    ),
  ],
);

class SafeHomeApp extends ConsumerStatefulWidget {
  const SafeHomeApp({super.key});

  @override
  ConsumerState<SafeHomeApp> createState() => _SafeHomeAppState();
}

class _SafeHomeAppState extends ConsumerState<SafeHomeApp> {
  @override
  void initState() {
    super.initState();
    FcmService.setupNotificationHandlers(appRouter);

    // SharedPreferences에서 설정 로드 후 포그라운드 핸들러 등록
    ref.read(foregroundNotificationProvider.notifier).init().then((_) {
      FcmService.setupForegroundNotificationHandler(
        isEnabled: () => ref.read(foregroundNotificationProvider),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SafeHome',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.1),
        ),
        child: child!,
      ),
    );
  }
}
