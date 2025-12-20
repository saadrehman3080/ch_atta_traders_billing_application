import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBlue,
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 60, width: double.maxFinite),
            SvgPicture.asset(
              'assets/images/atta_trader_logo.svg',
              width: 100,
              height: 100,
            ),
            const SizedBox(height: 20),
            Text('CH. ATTA TRADERS', style: AppTextStyles.pageTitle),
            const SizedBox(height: 10),
            Text(
              'Pepsi Distribution for Kallar Syedan',
              style: AppTextStyles.pageSubtitle,
            ),
            const SizedBox(height: 30),
            CredentialInputContainer(),
            const SizedBox(height: 30),
            Text('Authorized Personnel Only', style: AppTextStyles.footerText),
            const SizedBox(height: 5),
            Text('Powered by Atta Tech', style: AppTextStyles.footerText),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class CredentialInputContainer extends StatefulWidget {
  const CredentialInputContainer({super.key});

  @override
  State<CredentialInputContainer> createState() =>
      _CredentialInputContainerState();
}

class _CredentialInputContainerState extends State<CredentialInputContainer> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late FocusNode _idFocusNode;
  late FocusNode _passwordFocusNode;
  bool _showError = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _idFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _idFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final form = _formKey.currentState;
    if (form == null) return;

    if (!form.validate()) {
      setState(() => _showError = true);
      return;
    }

    setState(() {
      _showError = false;
      _isLoading = true;
    });

    try {
      // TODO: Implement actual authentication logic here
      await Future.delayed(const Duration(seconds: 1)); // Mock delay

      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _showError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            elevation: 10,
            color: AppColors.loginCardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: AppColors.pepsiWhite.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    buildInputField(
                      label: 'Salesman ID',
                      hint: 'Enter ID',
                      icon: Icons.person_outline,
                      controller: _idController,
                      focusNode: _idFocusNode,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        FocusScope.of(context).requestFocus(_passwordFocusNode);
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter Salesman ID';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    buildInputField(
                      label: 'Password',
                      hint: 'Enter Password',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        FocusScope.of(context).unfocus();
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter Password';
                        }
                        if (value.length < 4) {
                          return 'Password must be at least 4 characters';
                        }
                        return null;
                      },
                    ),
                    if (_showError) const SizedBox(height: 16),
                    if (_showError) const CredentialsError(),
                    const SizedBox(height: 16),
                    LoginButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      isLoading: _isLoading,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const LoginButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pepsiRed,
          disabledBackgroundColor: AppColors.pepsiRed.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
            : Text('Login', style: AppTextStyles.buttonLabel),
      ),
    );
  }
}

class CredentialsError extends StatelessWidget {
  const CredentialsError({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.pepsiRed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.pepsiRed.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.textError, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Please enter valid credentials provided by admin.',
              style: TextStyle(color: AppColors.textError, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

Widget buildInputField({
  required String label,
  required String hint,
  required IconData icon,
  bool isPassword = false,
  TextEditingController? controller,
  FocusNode? focusNode,
  TextInputAction? textInputAction,
  void Function(String)? onFieldSubmitted,
  String? Function(String?)? validator,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTextStyles.fieldLabel),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: isPassword,
        validator: validator,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        cursorColor: Colors.white,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.6),
            fontSize: 16,
          ),

          prefixIcon: Icon(icon, color: AppColors.pepsiWhite, size: 20),
          filled: true,
          fillColor: AppColors.inputBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.inputBg, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.pepsiWhite.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.inputBorderFocus,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.pepsiRed, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    ],
  );
}
