import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:flutter/material.dart';

enum SnackBarType { success, error, info, warning }

class CustomSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    final config = _getSnackBarConfig(type);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(config.icon, color: AppColors.pepsiWhite, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.inputText.copyWith(
                  color: AppColors.pepsiWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: config.backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        action: action,
        elevation: 6,
      ),
    );
  }

  static _SnackBarConfig _getSnackBarConfig(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return _SnackBarConfig(
          backgroundColor: const Color(
            0xFF16A34A,
          ), // Green that complements Pepsi colors
          icon: Icons.check_circle,
        );
      case SnackBarType.error:
        return _SnackBarConfig(
          backgroundColor: AppColors.pepsiRedLight, // Using Pepsi Red Light
          icon: Icons.error,
        );
      case SnackBarType.warning:
        return _SnackBarConfig(
          backgroundColor: const Color(
            0xFFEA580C,
          ), // Orange that matches Pepsi palette
          icon: Icons.warning,
        );
      case SnackBarType.info:
        return _SnackBarConfig(
          backgroundColor: AppColors.pepsiBlue, // Using Pepsi Blue Light
          icon: Icons.info,
        );
    }
  }
}

class _SnackBarConfig {
  final Color backgroundColor;
  final IconData icon;

  _SnackBarConfig({required this.backgroundColor, required this.icon});
}
