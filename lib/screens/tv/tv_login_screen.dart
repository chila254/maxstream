import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/device_code_auth_service.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../services/secure_password_service.dart';
import '../../utils/tv_utils.dart';
import 'tv_main_screen.dart';

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
  int _focusedField = 0; // 0: Tab toggle, 1: Input field, 2: Button
  late FocusNode _inputFocus;
  late FocusNode _buttonFocus;

  @override
  void initState() {
    super.initState();
    _inputFocus = FocusNode();
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
    if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
      setState(() {
        _focusedField = (_focusedField - 1).clamp(0, 2);
        _updateFocus();
      });
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
      setState(() {
        _focusedField = (_focusedField + 1).clamp(0, 2);
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
      } else if (_focusedField == 2) {
        // Execute login
        _selectedTab == 0 ? _signInWithCode() : _signInWithPassword();
      }
    }
  }

  void _updateFocus() {
    if (_focusedField == 1) {
      FocusScope.of(context).requestFocus(_inputFocus);
    } else if (_focusedField == 2) {
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
          style: TextStyle(
            color: Colors.white,
            fontSize: TvUtils.responsiveFontSize(20, context),
          ),
        ),
        content: Text(
          'Use $biometricType to sign in?',
          style: TextStyle(
            color: Colors.grey,
            fontSize: TvUtils.responsiveFontSize(16, context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Use Password',
              style: TextStyle(
                color: Colors.grey,
                fontSize: TvUtils.responsiveFontSize(14, context),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Use $biometricType',
              style: TextStyle(
                color: const Color(0xFFE50914),
                fontSize: TvUtils.responsiveFontSize(14, context),
              ),
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
          style: TextStyle(
            color: Colors.white,
            fontSize: TvUtils.responsiveFontSize(20, context),
          ),
        ),
        content: Text(
          'Save password for faster future sign-ins with biometric?',
          style: TextStyle(
            color: Colors.grey,
            fontSize: TvUtils.responsiveFontSize(16, context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Not Now',
              style: TextStyle(
                color: Colors.grey,
                fontSize: TvUtils.responsiveFontSize(14, context),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Save Password',
              style: TextStyle(
                color: const Color(0xFFE50914),
                fontSize: TvUtils.responsiveFontSize(14, context),
              ),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _authenticateWithBiometric(String code) async {
    setState(() => _isLoading = true);

    try {
      // Authenticate using code + biometric + password
      if (_passwordController.text.isEmpty) {
        _showError('Please enter your password to use biometric');
        return;
      }

      final user = await DeviceCodeAuthService.authenticateWithCodeAndBiometric(
        code,
        _passwordController.text,
      );

      if (user != null) {
        _showSuccess('Signed in with biometric!');

        // Prompt to save password for future passwordless logins
        final email = _emailController.text;
        final password = _passwordController.text;

        if (mounted && email.isNotEmpty && password.isNotEmpty) {
          final shouldSave = await _showSavePasswordPrompt(email);
          if (shouldSave) {
            await SecurePasswordService.savePassword(email, password);
            if (mounted) {
              _showSuccess('Password saved for future biometric logins');
            }
          }
        }

        _clearFields();
        // AuthGate will handle navigation based on auth state
        if (mounted) Navigator.pop(context);
      } else {
        _showError('Biometric authentication failed');
      }
    } catch (e) {
      _showError('Biometric error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _authenticateWithBiometricStoredPassword(String code) async {
    setState(() => _isLoading = true);

    try {
      // Authenticate using code + biometric + stored password (passwordless)
      final user =
          await DeviceCodeAuthService.authenticateWithCodeAndBiometricStoredPassword(
            code,
          );

      if (user != null) {
        _showSuccess('Auto-signed in!');
        _clearFields();
        // AuthGate will handle navigation based on auth state
        if (mounted) Navigator.pop(context);
      } else {
        _showError('Passwordless authentication failed');
      }
    } catch (e) {
      // If stored password fails, fall back to password entry
      _showError('$e');

      // Show password login
      if (mounted) {
        final userInfo = await DeviceCodeAuthService.authenticateWithDeviceCode(
          code,
        );
        _emailController.text = userInfo['email'] ?? '';
        setState(() => _selectedTab = 1);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearFields() {
    _codeController.clear();
    _emailController.clear();
    _passwordController.clear();
    _showPassword = false;
  }

  Future<void> _signInWithPassword() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      // Navigate to TV main screen after successful authentication
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const TvMainScreen()),
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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: const AssetImage('assets/images/background.jpg'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withAlpha(180),
                BlendMode.darken,
              ),
            ),
          ),
          child: SingleChildScrollView(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(TvUtils.responsivePadding(24, context)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Top: Branding with Netflix-style effect
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glow effect layer
                        Text(
                          'MaxStream',
                          style: TextStyle(
                            fontSize: TvUtils.responsiveFontSize(56, context),
                            fontWeight: FontWeight.bold,
                            color: const Color(
                              0xFFE50914,
                            ).withValues(alpha: 0.3),
                            shadows: [
                              Shadow(
                                offset: const Offset(0, 0),
                                blurRadius: 40,
                                color: const Color(
                                  0xFFE50914,
                                ).withValues(alpha: 0.6),
                              ),
                              Shadow(
                                offset: const Offset(0, 0),
                                blurRadius: 20,
                                color: const Color(
                                  0xFFE50914,
                                ).withValues(alpha: 0.4),
                              ),
                            ],
                          ),
                        ),
                        // Main text
                        Text(
                          'MaxStream',
                          style: TextStyle(
                            fontSize: TvUtils.responsiveFontSize(56, context),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFE50914),
                            shadows: [
                              Shadow(
                                offset: const Offset(2, 2),
                                blurRadius: 10,
                                color: Colors.black.withValues(alpha: 0.8),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: TvUtils.responsivePadding(8, context)),
                    Text(
                      'Watch Anywhere',
                      style: TextStyle(
                        fontSize: TvUtils.responsiveFontSize(28, context),
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: TvUtils.responsivePadding(32, context)),

                    // Login form
                    SizedBox(
                      width: TvUtils.getOptimalContentWidth(context),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Tab selection with keyboard focus
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildTabButton('Sign in with Code', 0),
                              SizedBox(
                                width: TvUtils.responsivePadding(32, context),
                              ),
                              _buildTabButton('Sign in with Password', 1),
                            ],
                          ),
                          SizedBox(
                            height: TvUtils.responsivePadding(24, context),
                          ),

                          // Content based on selected tab
                          SizedBox(
                            width: TvUtils.getOptimalContentWidth(context),
                            child: _selectedTab == 0
                                ? _buildCodeLoginForm()
                                : _buildPasswordLoginForm(),
                          ),

                          SizedBox(
                            height: TvUtils.responsivePadding(16, context),
                          ),

                          // Navigation hints
                          _buildNavigationHints(),
                        ],
                      ),
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

  Widget _buildTabButton(String label, int tabIndex) {
    final isSelected = _selectedTab == tabIndex;
    final isFocused = _focusedField == 0;
    final padding = TvUtils.responsivePadding(16, context);

    return Container(
      decoration: BoxDecoration(
        border: isFocused && isSelected
            ? Border.all(color: Colors.white, width: 4)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedTab = tabIndex),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: padding * 2,
              vertical: padding,
            ),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE50914) : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: isSelected ? const Color(0xFFE50914) : Colors.grey,
                  width: 3,
                ),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: TvUtils.responsiveFontSize(20, context, maxSize: 40),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeLoginForm() {
    final padding = TvUtils.responsivePadding(16, context);

    return Column(
      children: [
        Text(
          'Enter the code from your phone',
          style: TextStyle(
            fontSize: TvUtils.responsiveFontSize(20, context, maxSize: 32),
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: TvUtils.responsivePadding(32, context)),
        Focus(
          onKey: (node, event) {
            if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
              setState(() => _focusedField = 2);
            }
            return KeyEventResult.handled;
          },
          child: TextField(
            focusNode: _inputFocus,
            controller: _codeController,
            style: TextStyle(
              color: Colors.white,
              fontSize: TvUtils.responsiveFontSize(32, context, maxSize: 64),
              letterSpacing: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLength: 6,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: '------',
              hintStyle: TextStyle(
                color: Colors.grey,
                fontSize: TvUtils.responsiveFontSize(32, context, maxSize: 64),
              ),
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  TvUtils.responsivePadding(12, context),
                ),
                borderSide: const BorderSide(color: Colors.grey, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  TvUtils.responsivePadding(12, context),
                ),
                borderSide: const BorderSide(color: Colors.grey, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  TvUtils.responsivePadding(12, context),
                ),
                borderSide: const BorderSide(
                  color: Color(0xFFE50914),
                  width: 4,
                ),
              ),
              contentPadding: EdgeInsets.all(padding),
              counterText: '',
            ),
          ),
        ),
        SizedBox(height: TvUtils.responsivePadding(48, context)),
        Focus(
          onKey: (node, event) {
            if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
              setState(() => _focusedField = 1);
            }
            return KeyEventResult.handled;
          },
          child: SizedBox(
            width: double.infinity,
            height: TvUtils.responsiveButtonHeight(context),
            child: ElevatedButton(
              focusNode: _buttonFocus,
              onPressed: _isLoading ? null : _signInWithCode,
              style: TvButtonStyle.getLargeButton(context),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                        SizedBox(height: TvUtils.responsivePadding(4, context)),
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
              setState(() => _focusedField = 2);
            } else if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
              setState(() => _focusedField = 1);
            }
            return KeyEventResult.handled;
          },
          child: SizedBox(
            height: inputHeight,
            child: TextField(
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
          onKey: (node, event) {
            if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
              setState(() => _focusedField = 1);
            }
            return KeyEventResult.handled;
          },
          child: SizedBox(
            width: double.infinity,
            height: TvUtils.responsiveButtonHeight(context),
            child: ElevatedButton(
              focusNode: _buttonFocus,
              onPressed: _isLoading ? null : _signInWithPassword,
              style: TvButtonStyle.getLargeButton(context),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                        SizedBox(height: TvUtils.responsivePadding(4, context)),
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
