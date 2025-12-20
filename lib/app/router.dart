import 'package:ch_atta_traders_billing_application/features/auth/presentation/login_screen.dart';
import 'package:ch_atta_traders_billing_application/features/home/presentation/home_screen.dart';
import 'package:go_router/go_router.dart';

// final appRouter = GoRouter(
//   routes: [
//     GoRoute(
//       path: '/',
//       name: 'home',
//       builder: (context, state) => const HomeScreen(),
//     ),
//     GoRoute(
//       path: '/loginScreen',
//       name: 'loginScreen',
//       builder: (context, state) => const LoginScreen(),
//     ),
//   ],
// );

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: 'loginScreen',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/home',
      name: 'homeScreen',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
