import 'package:ch_atta_traders_billing_application/app/router.dart';
import 'package:ch_atta_traders_billing_application/common/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ChAttaBillingApp());
}

class ChAttaBillingApp extends StatelessWidget {
  const ChAttaBillingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: AppTheme.light,
    );
  }
}
