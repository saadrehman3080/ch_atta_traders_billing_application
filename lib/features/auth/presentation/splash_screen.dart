import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../common/themes/color_schemes.dart';
import '../../../common/themes/text_styles.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBlue,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                // Logo
                SvgPicture.asset(
                  'assets/images/atta_trader_logo.svg',
                  width: 120,
                  height: 120,
                ),
                const SizedBox(height: 32),
                // Company Name with Animation
                AnimatedTextKit(
                  animatedTexts: [
                    TypewriterAnimatedText(
                      'CH. ATTA TRADERS',
                      textStyle: AppTextStyles.pageTitle,
                      speed: const Duration(milliseconds: 100),
                    ),
                  ],
                  totalRepeatCount: 1,
                  pause: const Duration(milliseconds: 500),
                  displayFullTextOnTap: true,
                ),
                const SizedBox(height: 12),
                // Subtitle
                Text(
                  'Pepsi Distribution for Kallar Syedan',
                  style: AppTextStyles.pageSubtitle,
                  textAlign: TextAlign.center,
                ),
                const Spacer(flex: 2),
                // Loading Indicator
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.pepsiRed,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Loading...', style: AppTextStyles.helperText),
                const Spacer(flex: 1),
                // Footer
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
                      Text(
                        'Powered by Atta Tech',
                        style: AppTextStyles.footerText,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'v1.0.0',
                        style: AppTextStyles.footerText.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
