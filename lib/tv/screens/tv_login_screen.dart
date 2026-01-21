import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/device_code_auth_service.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../services/secure_password_service.dart';
import '../utils/tv_utils.dart';
import '../utils/tv_typography.dart';
import 'tv_main_screen_netflix.dart';

class TvLoginScreen extends StatefulWidget {
  const TvLoginScreen({super.key});

  @override
  State<TvLoginScreen> createState() => _TvLoginScreenState();
}

class _TvLoginScreenState extends State<TvLoginScreen> {
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _showPassword = false;
  int _selectedTab = 0; // 0: Code, 1: Password
  bool _biometricAvailable = false;

  // D-pad navigation
  int _focusedField =
      0; // 0: Tab toggle, 1: Email/Code, 2: Password (if password tab), 3: Button
  late FocusNode _inputFocus;
  late FocusNode _passwordFocus;
  late FocusNode _buttonFocus;

  @override
  void initState() {
    super.initState();
    _inputFocus = FocusNode();
    _passwordFocus = FocusNode();
    _buttonFocus = FocusNode();

    // Force landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Hide system UI for TV
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // Check biometric availability
    _checkBiometricAvailability();

    // Request focus for D-pad navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_inputFocus);
    });
  }

  Future<void> _checkBiometricAvailability() async {
    final available = await BiometricService.canUseBiometric();
    if (mounted) {
      setState(() => _biometricAvailable = available);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _inputFocus.dispose();
    _passwordFocus.dispose();
    _buttonFocus.dispose();

    // Restore normal orientation and UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    final maxField = _selectedTab == 0 ? 2 : 3;
    if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
      setState(() {
        _focusedField = (_focusedField - 1).clamp(0, maxField);
        _updateFocus();
      });
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
      setState(() {
        _focusedField = (_focusedField + 1).clamp(0, maxField);
        _updateFocus();
      });
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
      if (_focusedField == 0) {
        setState(() => _selectedTab = 0);
      }
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
      if (_focusedField == 0) {
        setState(() => _selectedTab = 1);
      }
    } else if (event.isKeyPressed(LogicalKeyboardKey.select) ||
        event.isKeyPressed(LogicalKeyboardKey.enter)) {
      if (_focusedField == 0) {
        // Toggle tab
        setState(() => _selectedTab = _selectedTab == 0 ? 1 : 0);
      } else if (_focusedField == maxField) {
        // Execute login
        _selectedTab == 0 ? _signInWithCode() : _signInWithPassword();
      }
    }
  }

  void _updateFocus() {
    if (_focusedField == 1) {
      FocusScope.of(context).requestFocus(_inputFocus);
    } else if (_focusedField == 2) {
      if (_selectedTab == 0) {
        FocusScope.of(context).requestFocus(_buttonFocus);
      } else {
        FocusScope.of(context).requestFocus(_passwordFocus);
      }
    } else if (_focusedField == 3) {
      FocusScope.of(context).requestFocus(_buttonFocus);
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _signInWithCode() async {
    if (_codeController.text.isEmpty) {
      _showError('Please enter a code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final code = _codeController.text.trim();

      // Step 1: Validate device code
      final userInfo = await DeviceCodeAuthService.authenticateWithDeviceCode(
        code,
      );
      _showSuccess('Code validated!');

      final email = userInfo['email'] ?? '';

      // Step 2: Check if password is saved for this email
      final hasSavedPassword = await SecurePasswordService.hasPasswordSaved(
        email,
      );

      // Step 3: Check if biometric is available for this device
      if (_biometricAvailable) {
        // Prompt for biometric authentication
        final biometricType = await BiometricService.getBiometricTypeString();
        final showBioPrompt = await _showBiometricPrompt(biometricType);

        if (showBioPrompt) {
          // User wants to use biometric
          _codeController.clear();

          // If password is saved, use passwordless flow
          if (hasSavedPassword) {
            _authenticateWithBiometricStoredPassword(code);
          } else {
            // First time: biometric + password entry
            _authenticateWithBiometric(code);
          }
          return;
        }
      }

      // Fallback: Show password login with pre-filled email
      _emailController.text = email;
      setState(() => _selectedTab = 1); // Switch to password tab
      _codeController.clear();
    } catch (e) {
      _showError('Invalid code: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _showBiometricPrompt(String biometricType) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
           'Biometric Sign In',
           style: TvTypography.cardTitle,
         ),
         content: Text(
           'Use $biometricType to sign in?',
           style: TvTypography.bodyMedium,
         ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Use Password',
              style: TvTextStyles.subtitle,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Use $biometricType',
              style: TvTypography.buttonText,
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<bool> _showSavePasswordPrompt(String email) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
           'Save Password',
           style: TvTypography.cardTitle,
         ),
         content: Text(
           'Save password for $email?',
           style: TvTypography.bodyMedium,
         ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Don\'t Save',
              style: TvTextStyles.subtitle,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Save',
              style: TvTypography.buttonText,
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _signInWithPassword() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Please enter email and password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Authenticate with email and password
      await AuthService.signInWithEmail(email, password);
      _showSuccess('Login successful!');

      // Ask to save password
      final shouldSave = await _showSavePasswordPrompt(email);
      if (shouldSave) {
        await SecurePasswordService.savePassword(email, password);
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TvMainScreenNetflix()),
        );
      }
    } catch (e) {
      _showError('Login failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _authenticateWithBiometric(String code) async {
    try {
      final isAuthenticated = await BiometricService.authenticate(
        reason: 'Verify your identity to complete TV login',
      );
      if (!isAuthenticated) {
        _showError('Biometric authentication failed');
        return;
      }

      // Biometric successful, prompt for password to save
      _showPasswordEntryDialog(code);
    } catch (e) {
      _showError('Biometric error: $e');
    }
  }

  Future<void> _authenticateWithBiometricStoredPassword(String code) async {
    try {
      final isAuthenticated = await BiometricService.authenticate(
        reason: 'Verify your identity to complete TV login',
      );
      if (!isAuthenticated) {
        _showError('Biometric authentication failed');
        return;
      }

      // Get stored password
      final email = _emailController.text;
      final password = await SecurePasswordService.getPassword(email);

      if (password == null) {
        _showError('Stored password not found');
        return;
      }

      // Authenticate with stored password
      await AuthService.signInWithEmail(email, password);
      _showSuccess('Login successful!');

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TvMainScreenNetflix()),
        );
      }
    } catch (e) {
      _showError('Authentication error: $e');
    }
  }

  void _showPasswordEntryDialog(String code) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
           'Enter Password',
           style: TvTypography.cardTitle,
         ),
         content: TextField(
           controller: passwordController,
           obscureText: true,
           style: TvTypography.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Password',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TvTextStyles.subtitle,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loginWithBiometricAndPassword(code, passwordController.text);
            },
            child: Text(
              'Submit',
              style: TextStyle(color: const Color(0xFFE50914)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loginWithBiometricAndPassword(
      String code, String password) async {
    try {
      setState(() => _isLoading = true);

      // Validate code
      final userInfo =
          await DeviceCodeAuthService.authenticateWithDeviceCode(code);
      final email = userInfo['email'] ?? '';

      // Authenticate with password
      await AuthService.signInWithEmail(email, password);
      _showSuccess('Login successful!');

      // Ask to save password
      final shouldSave = await _showSavePasswordPrompt(email);
      if (shouldSave) {
        await SecurePasswordService.savePassword(email, password);
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TvMainScreenNetflix()),
        );
      }
    } catch (e) {
      _showError('Login failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE50914),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: _handleKeyEvent,
        child: Padding(
          padding: EdgeInsets.all(TvUtils.responsivePadding(32, context)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Tab toggle
                    Focus(
                      onKey: (node, event) {
                        if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
                          setState(() => _focusedField = 1);
                        }
                        return KeyEventResult.handled;
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: _focusedField == 0
                              ? Border.all(color: Colors.white, width: 4)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(
                                  TvUtils.responsivePadding(12, context),
                                ),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 0
                                      ? const Color(0xFFE50914)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Device Code',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: TvUtils.responsiveFontSize(
                                      18,
                                      context,
                                      maxSize: 28,
                                    ),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(
                                  TvUtils.responsivePadding(12, context),
                                ),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 1
                                      ? const Color(0xFFE50914)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Password',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: TvUtils.responsiveFontSize(
                                      18,
                                      context,
                                      maxSize: 28,
                                    ),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: TvUtils.responsivePadding(48, context)),
                    // Login form
                    if (_selectedTab == 0) _buildCodeLoginForm(),
                    if (_selectedTab == 1) _buildPasswordLoginForm(),
                  ],
                ),
              ),
              SizedBox(width: TvUtils.responsivePadding(48, context)),
              // Navigation hints
              SizedBox(
                width: 300,
                child: _buildNavigationHints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeLoginForm() {
    final inputHeight = TvUtils.responsiveInputHeight(context);

    return Column(
      children: [
        Focus(
          onKey: (node, event) {
            if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
              setState(() => _focusedField = 2);
            }
            return KeyEventResult.handled;
          },
          child: SizedBox(
            height: inputHeight,
            child: TextField(
              focusNode: _inputFocus,
              controller: _codeController,
              style: TextStyle(
                color: Colors.white,
                fontSize: TvUtils.responsiveFontSize(20, context, maxSize: 32),
              ),
              decoration: TvInputDecoration.getLargeInput(
                context,
                hintText: 'Enter Code',
              ),
            ),
          ),
        ),
        SizedBox(height: TvUtils.responsivePadding(48, context)),
        Focus(
          focusNode: _buttonFocus,
          onKey: (node, event) {
            if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
              setState(() => _focusedField = 1);
            }
            return KeyEventResult.handled;
          },
          child: Container(
            decoration: BoxDecoration(
              border: _focusedField == 2
                  ? Border.all(color: Colors.white, width: 4)
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: double.infinity,
              height: TvUtils.responsiveButtonHeight(context),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signInWithCode,
                style: TvButtonStyle.getLargeButton(context),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Sign In',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: TvUtils.responsiveFontSize(
                                24,
                                context,
                                maxSize: 48,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                              height: TvUtils.responsivePadding(4, context)),
                          Text(
                            'button login',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: TvUtils.responsiveFontSize(
                                12,
                                context,
                                maxSize: 18,
                              ),
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordLoginForm() {
    final inputHeight = TvUtils.responsiveInputHeight(context);

    return Column(
      children: [
        Focus(
          onKey: (node, event) {
            if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
              setState(() => _focusedField = 2);
            }
            return KeyEventResult.handled;
          },
          child: SizedBox(
            height: inputHeight,
            child: TextField(
              focusNode: _inputFocus,
              controller: _emailController,
              style: TextStyle(
                color: Colors.white,
                fontSize: TvUtils.responsiveFontSize(20, context, maxSize: 32),
              ),
              decoration: TvInputDecoration.getLargeInput(
                context,
                hintText: 'Email',
              ),
            ),
          ),
        ),
        SizedBox(height: TvUtils.responsivePadding(32, context)),
        Focus(
          onKey: (node, event) {
            if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
              setState(() => _focusedField = 3);
            } else if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
              setState(() => _focusedField = 1);
            }
            return KeyEventResult.handled;
          },
          child: SizedBox(
            height: inputHeight,
            child: TextField(
              focusNode: _passwordFocus,
              controller: _passwordController,
              obscureText: !_showPassword,
              style: TextStyle(
                color: Colors.white,
                fontSize: TvUtils.responsiveFontSize(20, context, maxSize: 32),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[a-zA-Z0-9@#$%&\-_.*+!~`|\\()[\]{}";:,.<>?/]'),
                ),
              ],
              decoration: TvInputDecoration.getLargeInput(
                context,
                hintText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                    size: TvUtils.responsiveFontSize(24, context, maxSize: 48),
                  ),
                  onPressed: () {
                    setState(() => _showPassword = !_showPassword);
                  },
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: TvUtils.responsivePadding(48, context)),
        Focus(
          focusNode: _buttonFocus,
          onKey: (node, event) {
            if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
              setState(() => _focusedField = 2);
            }
            return KeyEventResult.handled;
          },
          child: Container(
            decoration: BoxDecoration(
              border: _focusedField == 3
                  ? Border.all(color: Colors.white, width: 4)
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: double.infinity,
              height: TvUtils.responsiveButtonHeight(context),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signInWithPassword,
                style: TvButtonStyle.getLargeButton(context),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Sign In',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: TvUtils.responsiveFontSize(
                                24,
                                context,
                                maxSize: 48,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                              height: TvUtils.responsivePadding(4, context)),
                          Text(
                            'button login',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: TvUtils.responsiveFontSize(
                                12,
                                context,
                                maxSize: 18,
                              ),
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationHints() {
    return Container(
      padding: EdgeInsets.all(TvUtils.responsivePadding(16, context)),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(
          TvUtils.responsivePadding(8, context),
        ),
        border: Border.all(color: Colors.grey, width: 1),
      ),
      child: Column(
        children: [
          Text(
            'Navigation',
            style: TextStyle(
              color: Colors.white,
              fontSize: TvUtils.responsiveFontSize(16, context, maxSize: 24),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: TvUtils.responsivePadding(12, context)),
          _buildHintRow('⬆ ⬇', 'Navigate fields'),
          _buildHintRow('⬅ ➡', 'Switch tabs'),
          _buildHintRow('✓ Enter', 'Sign in'),
        ],
      ),
    );
  }

  Widget _buildHintRow(String keys, String action) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: TvUtils.responsivePadding(4, context),
      ),
      child: Row(
        children: [
          Text(
            keys,
            style: TextStyle(
              color: const Color(0xFFE50914),
              fontSize: TvUtils.responsiveFontSize(14, context, maxSize: 20),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: TvUtils.responsivePadding(16, context)),
          Text(
            action,
            style: TextStyle(
              color: Colors.grey,
              fontSize: TvUtils.responsiveFontSize(14, context, maxSize: 20),
            ),
          ),
        ],
      ),
    );
  }
}
