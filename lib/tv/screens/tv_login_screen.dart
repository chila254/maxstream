import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/device_code_auth_service.dart';
import '../../services/auth_service.dart';
import '../utils/index.dart';

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
  int _selectedTab = 0; // 0: Device Code, 1: Sign In, 2: Sign Up
  int _focusedField = 0; // 0: Tabs, 1: Field 1, 2: Field 2, 3: Submit
  String? _errorMessage;
  String? _successMessage;

  late FocusNode _rootFocus;
  late FocusNode _tabsFocus;
  late FocusNode _field1Focus;
  late FocusNode _field2Focus;
  late FocusNode _submitFocus;

  int get _maxField => _selectedTab == 0 ? 2 : 3;

  @override
  void initState() {
    super.initState();
    _rootFocus = FocusNode();
    _tabsFocus = FocusNode();
    _field1Focus = FocusNode();
    _field2Focus = FocusNode();
    _submitFocus = FocusNode();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tabsFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _rootFocus.dispose();
    _tabsFocus.dispose();
    _field1Focus.dispose();
    _field2Focus.dispose();
    _submitFocus.dispose();

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

  /// Single D-pad controller for the whole screen.
  /// Returns [KeyEventResult.ignored] for keys it does not handle so that
  /// text input is never swallowed.
  KeyEventResult _handleScreenKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _focusedField = (_focusedField - 1).clamp(0, _maxField);
        _updateFocus();
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _focusedField = (_focusedField + 1).clamp(0, _maxField);
        _updateFocus();
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_focusedField == 0) {
        setState(() {
          _selectedTab = _selectedTab == 0 ? 2 : _selectedTab - 1;
          _resetForTabChange();
        });
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (_focusedField == 0) {
        setState(() {
          _selectedTab = (_selectedTab + 1) % 3;
          _resetForTabChange();
        });
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter) {
      if (_focusedField == 0) {
        // Confirm the selected tab and move into its form.
        setState(() => _focusedField = 1);
        _updateFocus();
        return KeyEventResult.handled;
      }
      if (_focusedField == _maxField) {
        _submit();
        return KeyEventResult.handled;
      }
      // A text field: bring up the Android TV on-screen keyboard.
      _openKeyboardForField(_focusedField);
      return KeyEventResult.handled;
    }
    // Everything else (characters, etc.) passes through to the focused field.
    return KeyEventResult.ignored;
  }

  void _openKeyboardForField(int field) {
    final node = field == 1 ? _field1Focus : _field2Focus;
    node.requestFocus();
    // Explicitly show the platform IME (Android TV on-screen keyboard).
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  void _resetForTabChange() {
    _keyboardDismiss();
    _focusedField = 0;
    _errorMessage = null;
    _successMessage = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tabsFocus.requestFocus();
    });
  }

  void _keyboardDismiss() {
    FocusScope.of(context).unfocus();
  }

  void _updateFocus() {
    if (_focusedField == 0) {
      _tabsFocus.requestFocus();
    } else if (_focusedField == 1) {
      _field1Focus.requestFocus();
      _showKeyboardIfNeeded();
    } else if (_focusedField == 2) {
      if (_selectedTab == 0) {
        _submitFocus.requestFocus();
      } else {
        _field2Focus.requestFocus();
        _showKeyboardIfNeeded();
      }
    } else if (_focusedField == 3) {
      _submitFocus.requestFocus();
    }
  }

  void _showKeyboardIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  void _moveToNextField() {
    setState(() {
      _focusedField = (_focusedField + 1).clamp(0, _maxField);
      _updateFocus();
    });
  }

  void _submitFromField() {
    if (_selectedTab == 0) {
      _signInWithCode();
    } else if (_focusedField == 1 && _selectedTab != 0) {
      _moveToNextField();
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    switch (_selectedTab) {
      case 0:
        await _signInWithCode();
        break;
      case 1:
        await _signInWithPassword();
        break;
      case 2:
        await _signUp();
        break;
    }
  }

  Future<void> _signInWithCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showError('Please enter your device code');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userInfo = await DeviceCodeAuthService.authenticateWithDeviceCode(
        code,
      );
      final email = userInfo['email'] ?? '';
      final password = userInfo['password'] ?? '';
      if (!mounted) return;

      if (password.isNotEmpty && email.isNotEmpty) {
        // Sign in directly with the code; no password step needed.
        final user = await AuthService.signInWithEmail(email, password);
        if (!mounted) return;
        if (user != null) {
          setState(() {
            _successMessage = 'Signed in successfully!';
            _errorMessage = null;
          });
          // TvAuthGate's auth state stream switches to the main screen.
          return;
        }
      }

      // Fallback for codes without an embedded password (e.g. Google-created
      // accounts): prefill the email and let the user enter their password.
      setState(() {
        _emailController.text = email;
        _selectedTab = 1;
        _focusedField = 2;
        _keyboardDismiss();
        _errorMessage = null;
        _successMessage = 'Code validated! Enter your password to sign in.';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _field2Focus.requestFocus();
      });
    } catch (e) {
      _showError('Invalid code: ${e.toString().split('\n').first}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter your email and password');
      return;
    }

    setState(() => _isLoading = true);
    _keyboardDismiss();
    try {
      await AuthService.signInWithEmail(email, password);
      if (mounted) {
        _showSuccess('Login successful!');
      }
    } on FirebaseAuthException catch (e) {
      _showError(_authErrorMessage(e));
    } catch (e) {
      _showError('Login failed: ${e.toString().split('\n').first}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter your email and password');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showError('Please enter a valid email address');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);
    _keyboardDismiss();
    try {
      await AuthService.signUpWithEmail(email, password);
      if (mounted) {
        _showSuccess('Account created! Welcome to MaxStream.');
      }
    } on FirebaseAuthException catch (e) {
      _showError(_authErrorMessage(e));
    } catch (e) {
      _showError('Sign up failed: ${e.toString().split('\n').first}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password is too weak (min 6 characters)';
      case 'invalid-email':
        return 'Invalid email format';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled';
      case 'network-request-failed':
        return 'Network error. Check your connection';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      default:
        return e.message ?? 'Authentication failed';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _successMessage = null;
    });
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    setState(() {
      _successMessage = message;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(
            child: Image(
              image: AssetImage('assets/images/background.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          KeyboardListener(
            focusNode: _rootFocus,
            onKeyEvent: (event) => _handleScreenKey(_rootFocus, event),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(TvUtils.responsivePadding(24, context)),
                child: SingleChildScrollView(
                  child: _buildCard(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      width: TvUtils.responsiveWidth(1000, context, maxWidth: 1100),
      padding: EdgeInsets.all(TvUtils.responsivePadding(28, context)),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          SizedBox(height: TvUtils.responsivePadding(24, context)),
          _buildTabs(),
          SizedBox(height: TvUtils.responsivePadding(24, context)),
          _buildFields(),
          SizedBox(height: TvUtils.responsivePadding(20, context)),
          _buildMessages(),
          SizedBox(height: TvUtils.responsivePadding(16, context)),
          _buildSubmitButton(),
          SizedBox(height: TvUtils.responsivePadding(20, context)),
          _buildNavigationHints(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Image.asset(
          'assets/images/maxstream_logo.png',
          width: TvUtils.responsiveFontSize(64, context, maxSize: 96),
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.play_circle_fill,
            size: TvUtils.responsiveFontSize(64, context, maxSize: 96),
            color: const Color(0xFFE50914),
          ),
        ),
        SizedBox(width: TvUtils.responsivePadding(16, context)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MaxStream TV', style: TvTypography.heroTitle),
              Text(
                _selectedTab == 0
                    ? 'Sign in on your TV using a code from your phone'
                    : _selectedTab == 1
                        ? 'Welcome back, sign in to continue'
                        : 'Create your account to get started',
                style: TvTypography.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Focus(
      focusNode: _tabsFocus,
      onKeyEvent: (node, event) => _handleScreenKey(node, event),
      child: Container(
        decoration: BoxDecoration(
          border: _focusedField == 0
              ? Border.all(color: Colors.white, width: 4)
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            for (int i = 0; i < 3; i++) ...[
              if (i > 0)
                SizedBox(width: TvUtils.responsivePadding(12, context)),
              Expanded(child: _buildTab(i)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index) {
    final labels = ['Device Code', 'Sign In', 'Sign Up'];
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
          _resetForTabChange();
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: TvUtils.responsivePadding(14, context),
        ),
        decoration: BoxDecoration(
          color: _selectedTab == index
              ? const Color(0xFFE50914)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          labels[index],
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: TvUtils.responsiveFontSize(18, context, maxSize: 26),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFields() {
    return Column(
      children: [
        _buildTextField(
          focusNode: _field1Focus,
          controller: _field1Controller,
          label: _field1Label,
          icon: _selectedTab == 0 ? Icons.code : Icons.mail_outline,
          isPassword: false,
          isFocused: _focusedField == 1,
          keyboardType: _selectedTab == 0
              ? TextInputType.text
              : TextInputType.emailAddress,
          textInputAction: _selectedTab == 0
              ? TextInputAction.done
              : TextInputAction.next,
          onSubmitted: (_) => _submitFromField(),
        ),
        if (_selectedTab != 0) ...[
          SizedBox(height: TvUtils.responsivePadding(16, context)),
          _buildTextField(
            focusNode: _field2Focus,
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline,
            isPassword: true,
            isFocused: _focusedField == 2,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required FocusNode focusNode,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isPassword,
    required bool isFocused,
    required TextInputType keyboardType,
    required TextInputAction textInputAction,
    required ValueChanged<String> onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFocused
              ? Colors.white
              : Colors.white.withValues(alpha: 0.2),
          width: isFocused ? 4 : 1,
        ),
      ),
      child: TextField(
        focusNode: focusNode,
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: TextStyle(
          color: Colors.white,
          fontSize: TvUtils.responsiveFontSize(22, context, maxSize: 32),
        ),
        cursorColor: const Color(0xFFE50914),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isFocused ? Colors.white : Colors.white54,
            fontSize: TvUtils.responsiveFontSize(16, context, maxSize: 24),
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.white70,
            size: TvUtils.responsiveFontSize(26, context, maxSize: 36),
          ),
          hintText: isFocused ? 'Use the on-screen keyboard' : null,
          hintStyle: TextStyle(
            color: Colors.white38,
            fontSize: TvUtils.responsiveFontSize(16, context, maxSize: 24),
          ),
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            vertical: TvUtils.responsivePadding(18, context),
            horizontal: TvUtils.responsivePadding(16, context),
          ),
        ),
      ),
    );
  }

  TextEditingController get _field1Controller =>
      _selectedTab == 0 ? _codeController : _emailController;

  String get _field1Label => _selectedTab == 0 ? 'Device Code' : 'Email';

  Widget _buildMessages() {
    if (_errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(TvUtils.responsivePadding(12, context)),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.redAccent),
        ),
        child: Text(
          _errorMessage!,
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: TvUtils.responsiveFontSize(16, context, maxSize: 22),
          ),
        ),
      );
    }
    if (_successMessage != null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(TvUtils.responsivePadding(12, context)),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green),
        ),
        child: Text(
          _successMessage!,
          style: TextStyle(
            color: Colors.greenAccent,
            fontSize: TvUtils.responsiveFontSize(16, context, maxSize: 22),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSubmitButton() {
    final label = _selectedTab == 0
        ? 'Sign In with Code'
        : _selectedTab == 1
            ? 'Sign In'
            : 'Create Account';

    return Focus(
      focusNode: _submitFocus,
      onKeyEvent: (node, event) => _handleScreenKey(node, event),
      child: GestureDetector(
        onTap: _submit,
        child: Container(
          width: double.infinity,
          height: TvUtils.responsiveButtonHeight(context),
          decoration: BoxDecoration(
            color: const Color(0xFFE50914),
            borderRadius: BorderRadius.circular(12),
            border: _focusedField == _maxField
                ? Border.all(color: Colors.white, width: 4)
                : null,
          ),
          child: Center(
            child: _isLoading
                ? SizedBox(
                    height: TvUtils.responsiveFontSize(26, context, maxSize: 36),
                    width: TvUtils.responsiveFontSize(26, context, maxSize: 36),
                    child: const CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize:
                          TvUtils.responsiveFontSize(22, context, maxSize: 32),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationHints() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildHint('⬆ ⬇', 'Move'),
        SizedBox(width: TvUtils.responsivePadding(24, context)),
        _buildHint('⬅ ➡', 'Tabs'),
        SizedBox(width: TvUtils.responsivePadding(24, context)),
        _buildHint('OK', 'Select / Submit'),
      ],
    );
  }

  Widget _buildHint(String keys, String action) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          keys,
          style: TextStyle(
            color: const Color(0xFFE50914),
            fontSize: TvUtils.responsiveFontSize(14, context, maxSize: 20),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: TvUtils.responsivePadding(8, context)),
        Text(
          action,
          style: TextStyle(
            color: Colors.white54,
            fontSize: TvUtils.responsiveFontSize(14, context, maxSize: 20),
          ),
        ),
      ],
    );
  }
}
