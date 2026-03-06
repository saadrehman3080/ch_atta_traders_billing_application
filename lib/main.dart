import 'package:ch_atta_traders_billing_application/app/router.dart';
import 'package:ch_atta_traders_billing_application/common/themes/app_theme.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:ch_atta_traders_billing_application/data/database/shop_database_helper.dart';
import 'package:ch_atta_traders_billing_application/features/auth/providers/auth_provider.dart';
import 'package:ch_atta_traders_billing_application/features/products/providers/product_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize date formatting for English locale (ensures consistent Firebase paths)
  await initializeDateFormatting('en_US', null);

  // Initialize App Preferences
  await AppPreferences.init();

  // Initialize and seed shop database
  try {
    await ShopDatabaseHelper.instance.seedFromCsv();
  } catch (e) {
    debugPrint('Shop seeding failed: $e');
  }

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
        theme: AppTheme.light,
      ),
    );
  }
}
