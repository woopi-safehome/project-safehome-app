import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_theme.dart';
import 'features/analyzing/analyzing_screen.dart';
import 'features/home/home_screen.dart';
import 'features/login/login_screen.dart';
import 'features/my_page/my_page_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/result/result_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/upload/upload_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (_, __) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (_, __) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      path: '/upload',
      builder: (_, __) => const UploadScreen(),
    ),
    GoRoute(
      path: '/analyzing/:jobId',
      builder: (_, state) => AnalyzingScreen(
        jobId: state.pathParameters['jobId']!,
      ),
    ),
    GoRoute(
      path: '/result/:jobId',
      builder: (_, state) => ResultScreen(
        jobId: state.pathParameters['jobId']!,
      ),
    ),
    GoRoute(
      path: '/my-page',
      builder: (_, __) => const MyPageScreen(),
    ),
  ],
);

class SafeHomeApp extends StatelessWidget {
  const SafeHomeApp({super.key});

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
