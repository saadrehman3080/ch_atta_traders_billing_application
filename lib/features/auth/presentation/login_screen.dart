import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:ch_atta_traders_billing_application/core/utils/auth_service.dart';
import 'package:ch_atta_traders_billing_application/features/auth/providers/auth_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _showFingerprint = false;
  bool _loading = true;
  bool _isBiometricAuthenticating = false;
  bool _isBiometricAvailable = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkFirstLogin();
  }

  Future<void> _checkFirstLogin() async {
    try {
      // Check if this is first login
      final isFirst = await AppPreferences.instance.isFirstLogin;

      // Check biometric availability if not first login
      bool biometricAvailable = false;
      if (!isFirst) {
        biometricAvailable = await _checkBiometricAvailability();
      }

      setState(() {
        _showFingerprint = !isFirst && biometricAvailable;
        _isBiometricAvailable = biometricAvailable;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error checking first login: $e');
      // If preferences not initialized, show password login only
      setState(() {
        _showFingerprint = false;
        _isBiometricAvailable = false;
        _loading = false;
      });
    }
  }

  /// Checks if biometric authentication is available on the device.
  /// Returns true if device supports biometrics and has enrolled biometrics.
  Future<bool> _checkBiometricAvailability() async {
    try {
      // Check if device supports biometrics
      final isSupported = await _authService.isDeviceSupported();
      if (!isSupported) {
        debugPrint('Device does not support biometric authentication');
        return false;
      }

      // Check if biometrics can be checked (hardware available)
      final canCheck = await _authService.canCheckBiometrics();
      if (!canCheck) {
        debugPrint('Biometric hardware not available');
        return false;
      }

      // Check if user has enrolled biometrics
      final availableBiometrics = await _authService.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        debugPrint('No biometrics enrolled on device');
        return false;
      }

      debugPrint(
        'Biometric authentication available: ${availableBiometrics.map((e) => e.name).join(", ")}',
      );
      return true;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  /// Handles biometric authentication flow with comprehensive error handling.
  /// Shows loading state and provides clear feedback for all scenarios.
  Future<void> _authenticateWithFingerprint() async {
    // Prevent multiple simultaneous authentication attempts
    if (_isBiometricAuthenticating) {
      debugPrint('Authentication already in progress');
      return;
    }

    // Double-check biometric availability
    if (!_isBiometricAvailable) {
      if (mounted) {
        _showBiometricUnavailableDialog();
      }
      return;
    }

    setState(() => _isBiometricAuthenticating = true);

    try {
      final result = await _authService.authenticate(biometricsOnly: true);

      if (!mounted) return;

      _handleAuthenticationResult(result);
    } catch (e) {
      debugPrint('Unexpected error during authentication: $e');
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'An unexpected error occurred. Please try password login.',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBiometricAuthenticating = false);
      }
    }
  }

  /// Handles the result of biometric authentication.
  void _handleAuthenticationResult(AuthResult result) {
    switch (result) {
      case AuthResult.success:
        debugPrint('Biometric authentication successful');
        context.go('/home');
        break;

      case AuthResult.failed:
        CustomSnackBar.show(
          context,
          message:
              'Authentication failed. Please verify your biometric or use password.',
          type: SnackBarType.error,
        );
        break;

      case AuthResult.lockedOut:
        _showLockedOutDialog();
        break;

      case AuthResult.canceled:
        // User cancelled - no action needed, silent failure is acceptable
        debugPrint('User cancelled biometric authentication');
        break;

      case AuthResult.error:
        CustomSnackBar.show(
          context,
          message: 'Unable to authenticate. Please try again or use password.',
          type: SnackBarType.error,
        );
        break;
    }
  }

  /// Shows dialog when biometric authentication is unavailable.
  void _showBiometricUnavailableDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.pepsiWhite,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fingerprint_outlined,
                  color: Colors.orange,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Biometric Unavailable',
                style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 12),
              Text(
                'Biometric authentication is not available on this device. '
                'Please ensure you have:',
                textAlign: TextAlign.center,
                style: AppTextStyles.helperText.copyWith(
                  color: AppColors.gray500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gray300, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: AppColors.gray500,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Biometric hardware (fingerprint/face)',
                            style: AppTextStyles.helperText.copyWith(
                              fontSize: 13,
                              color: AppColors.gray500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: AppColors.gray500,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'At least one biometric enrolled',
                            style: AppTextStyles.helperText.copyWith(
                              fontSize: 13,
                              color: AppColors.gray500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: AppColors.gray500,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Granted biometric permissions',
                            style: AppTextStyles.helperText.copyWith(
                              fontSize: 13,
                              color: AppColors.gray500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: AppColors.pepsiWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Got It',
                    style: AppTextStyles.smallButton.copyWith(
                      color: AppColors.pepsiWhite,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows dialog when account is locked out due to too many attempts.
  void _showLockedOutDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.pepsiWhite,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.pepsiRed.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: AppColors.pepsiRed,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Account Locked',
                style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 12),
              Text(
                'Too many failed authentication attempts. '
                'Your biometric authentication has been temporarily disabled.',
                textAlign: TextAlign.center,
                style: AppTextStyles.helperText.copyWith(
                  color: AppColors.gray500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.pepsiRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.pepsiRed.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppColors.pepsiRed,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please wait a few minutes or use password login.',
                        style: AppTextStyles.helperText.copyWith(
                          fontSize: 13,
                          color: AppColors.pepsiRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pepsiRed,
                    foregroundColor: AppColors.pepsiWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Understood',
                    style: AppTextStyles.smallButton.copyWith(
                      color: AppColors.pepsiWhite,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundBlue,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.pepsiWhite),
        ),
      );
    }
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
            if (_showFingerprint) ...[
              const SizedBox(height: 20),
              _buildFingerprintButton(),
            ],
            const SizedBox(height: 30),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildFingerprintButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.loginCardBg.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.pepsiWhite.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isBiometricAuthenticating
                    ? null
                    : _authenticateWithFingerprint,
                borderRadius: BorderRadius.circular(12),
                splashColor: AppColors.pepsiWhite.withValues(alpha: 0.2),
                highlightColor: AppColors.pepsiWhite.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isBiometricAuthenticating)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.pepsiWhite,
                            ),
                          ),
                        )
                      else
                        const Icon(
                          Icons.fingerprint,
                          size: 28,
                          color: AppColors.pepsiWhite,
                        ),
                      const SizedBox(width: 12),
                      Text(
                        _isBiometricAuthenticating
                            ? 'Authenticating...'
                            : 'Login with Fingerprint',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.pepsiWhite.withValues(
                            alpha: _isBiometricAuthenticating ? 0.7 : 0.95,
                          ),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
          const SizedBox(width: 25),
          DefaultTextStyle(
            style: AppTextStyles.pageTitle,
            child: AnimatedTextKit(
              animatedTexts: [
                TypewriterAnimatedText(
                  'CH. ATTA TRADERS',
                  speed: const Duration(milliseconds: 150),
                  textAlign: TextAlign.center,
                ),
              ],
              totalRepeatCount: 1,
              pause: const Duration(milliseconds: 1000),
              displayFullTextOnTap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'Pepsi Cola Distributor For Kallar Syedan',
      style: AppTextStyles.pageSubtitle,
      textAlign: TextAlign.center,
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
  bool _showFirebaseError = false; // Only for Firebase authentication errors
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
      return;
    }

    setState(() {
      _showFirebaseError = false;
      _isLoading = true;
    });

    try {
      // Parse credentials
      final salesmanId = int.tryParse(_idController.text.trim());
      final password = int.tryParse(_passwordController.text.trim());

      if (salesmanId == null || password == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // Authenticate with Firebase using Provider
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.login(salesmanId, password);

      if (!mounted) return;

      if (success) {
        // Mark first login as completed
        await AppPreferences.instance.markLoginCompleted();

        // Show success message
        CustomSnackBar.show(
          context,
          message: 'Welcome, ${authProvider.currentSalesman?.name ?? "User"}!',
          type: SnackBarType.success,
        );

        // Navigate to home
        context.go('/home');
      } else {
        // Show error from Firebase - invalid credentials (only show error widget, no snackbar)
        setState(() => _showFirebaseError = true);
      }
    } catch (e) {
      debugPrint('Login error: $e');
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'An unexpected error occurred. Please try again.',
          type: SnackBarType.error,
        );
      }
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
          if (_showFirebaseError) const SizedBox(height: 16),
          if (_showFirebaseError) const CredentialsError(),
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
