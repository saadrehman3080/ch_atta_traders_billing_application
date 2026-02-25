import 'package:ch_atta_traders_billing_application/features/auth/presentation/login_screen.dart';
import 'package:ch_atta_traders_billing_application/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Application router configuration using GoRouter.
/// Defines all navigation routes for the CH Atta Traders Billing Application.
final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: 'loginScreen',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Page not found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => GoRouter.of(context).go('/'),
            child: const Text('Go to Home'),
          ),
        ],
      ),
    ),
  ),
);
