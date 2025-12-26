import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
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
            _buildTopSpacer(),
            _buildLogo(),
            const SizedBox(height: 20),
            _buildAnimatedTitle(),
            const SizedBox(height: 10),
            _buildSubtitle(),
            const SizedBox(height: 30),
            const CredentialInputContainer(),
            const SizedBox(height: 30),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSpacer() {
    return const SizedBox(height: 60, width: double.maxFinite);
  }

  Widget _buildLogo() {
    return SvgPicture.asset(
      'assets/images/atta_trader_logo.svg',
      width: 100,
      height: 100,
    );
  }

  Widget _buildAnimatedTitle() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          //const SizedBox(width: 25),
          // DefaultTextStyle(
          //   style: AppTextStyles.pageTitle,
          //   child: AnimatedTextKit(
          //     animatedTexts: [
          //       TypewriterAnimatedText(
          //         'CH. ATTA TRADERS',
          //         speed: const Duration(milliseconds: 150),
          //         textAlign: TextAlign.center,
          //       ),
          //     ],
          //     totalRepeatCount: 1,
          //     pause: const Duration(milliseconds: 1000),
          //     displayFullTextOnTap: true,
          //   ),
          // ),
          Text('CH. ATTA TRADERS', style: AppTextStyles.pageTitle),
        ],
      ),
    );
  }

  Widget _buildSubtitle() {
    return Center(
      child: SizedBox(
        height: 26,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 105,
              child: AnimatedTextKit(
                animatedTexts: [
                  RotateAnimatedText(
                    'Pepsi Cola',
                    textStyle: AppTextStyles.pageSubtitle,
                    textAlign: TextAlign.right,
                  ),
                  RotateAnimatedText(
                    'Master Cola',
                    textStyle: AppTextStyles.pageSubtitle,
                    textAlign: TextAlign.right,
                  ),
                ],
                isRepeatingAnimation: true,
                repeatForever: true,
                pause: const Duration(milliseconds: 600),
              ),
            ),
            Text(
              'Distributor for Kallar Syedan',
              style: AppTextStyles.pageSubtitle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text('Authorized Personnel Only', style: AppTextStyles.footerText),
        const SizedBox(height: 5),
        Text('Powered by Atta Tech', style: AppTextStyles.footerText),
        const SizedBox(height: 10),
      ],
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
            shape: _buildCardShape(),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _buildForm(),
            ),
          ),
        ),
      ),
    );
  }

  // ========== Business Logic Methods ==========

  Future<void> _handleLogin() async {
    _unfocusAll();
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
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _showError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter Salesman ID';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter Password';
    }
    if (value.length < 4) {
      return 'Password must be at least 4 characters';
    }
    return null;
  }

  void _focusPassword() {
    FocusScope.of(context).requestFocus(_passwordFocusNode);
  }

  void _unfocusAll() {
    FocusScope.of(context).unfocus();
  }

  // ========== Main UI Building Methods ==========

  ShapeBorder _buildCardShape() {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(
        color: AppColors.pepsiWhite.withValues(alpha: 0.4),
        width: 1.5,
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildIdField(),
          const SizedBox(height: 20),
          _buildPasswordField(),
          if (_showError) const SizedBox(height: 16),
          if (_showError) const CredentialsError(),
          const SizedBox(height: 16),
          _buildLoginButton(),
        ],
      ),
    );
  }

  // ========== Form Building Methods ==========

  Widget _buildIdField() {
    return _buildInputField(
      label: 'Salesman ID',
      hint: 'Enter ID',
      icon: Icons.person_outline,
      controller: _idController,
      focusNode: _idFocusNode,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => _focusPassword(),
      validator: _validateId,
      keyboardType: TextInputType.number,
    );
  }

  Widget _buildPasswordField() {
    return _buildInputField(
      label: 'Password',
      hint: 'Enter Password',
      icon: Icons.lock_outline,
      isPassword: true,
      controller: _passwordController,
      focusNode: _passwordFocusNode,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _unfocusAll(),
      validator: _validatePassword,
      keyboardType: TextInputType.number,
    );
  }

  Widget _buildLoginButton() {
    return LoginButton(
      onPressed: _isLoading ? null : _handleLogin,
      isLoading: _isLoading,
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextEditingController? controller,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        const SizedBox(height: 8),
        _buildTextField(
          hint: hint,
          icon: icon,
          isPassword: isPassword,
          controller: controller,
          focusNode: focusNode,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          keyboardType: keyboardType,
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(label, style: AppTextStyles.fieldLabel);
  }

  Widget _buildTextField({
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextEditingController? controller,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: isPassword,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      keyboardType: keyboardType,
      cursorColor: Colors.white,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
      decoration: _buildInputDecoration(hint, icon),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
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
        borderSide: BorderSide(color: AppColors.inputBorderFocus, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.pepsiRed, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        style: _buildButtonStyle(),
        child: isLoading ? _buildLoadingIndicator() : _buildButtonLabel(),
      ),
    );
  }

  ButtonStyle _buildButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.pepsiRed,
      disabledBackgroundColor: AppColors.pepsiRed.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
    );
  }

  Widget _buildLoadingIndicator() {
    return const SizedBox(
      height: 24,
      width: 24,
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildButtonLabel() {
    return Text('Login', style: AppTextStyles.buttonLabel);
  }
}

class CredentialsError extends StatelessWidget {
  const CredentialsError({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _buildErrorDecoration(),
      child: Row(
        children: [
          _buildErrorIcon(),
          const SizedBox(width: 8),
          _buildErrorMessage(),
        ],
      ),
    );
  }

  BoxDecoration _buildErrorDecoration() {
    return BoxDecoration(
      color: AppColors.pepsiRed.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: AppColors.pepsiRed.withValues(alpha: 0.4),
        width: 1,
      ),
    );
  }

  Widget _buildErrorIcon() {
    return const Icon(Icons.info_outline, color: AppColors.textError, size: 18);
  }

  Widget _buildErrorMessage() {
    return const Expanded(
      child: Text(
        'Please enter valid credentials provided by admin.',
        style: TextStyle(color: AppColors.textError, fontSize: 13),
      ),
    );
  }
}
