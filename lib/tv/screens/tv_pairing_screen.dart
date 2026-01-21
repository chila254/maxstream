import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/tv_typography.dart';
import '../../services/device_code_service.dart';

class TVPairingScreen extends StatefulWidget {
  const TVPairingScreen({super.key});

  @override
  State<TVPairingScreen> createState() => _TVPairingScreenState();
}

class _TVPairingScreenState extends State<TVPairingScreen> {
  String? _generatedCode;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _generateTVCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _generatedCode = null;
    });

    try {
      final code = await DeviceCodeService.generateDeviceCode();
      if (mounted) {
        setState(() {
          _generatedCode = code;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _copyToClipboard() {
    if (_generatedCode != null) {
      Clipboard.setData(ClipboardData(text: _generatedCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code copied to clipboard'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _generateNew() {
    setState(() {
      _generatedCode = null;
      _errorMessage = null;
    });
    _generateTVCode();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('TV Pairing', style: TextStyle(color: Colors.white)),  // TV-specific title
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tv, color: Colors.blue, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sign In on Your TV',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Without entering your password',
                                style: TvTextStyles.subtitle,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Instructions
              const Text(
                'How it works:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),  // TODO: Use TvTypography
              const SizedBox(height: 16),
              _buildInstructionStep(
                number: '1',
                title: 'Generate Code',
                description: 'Generate a unique code for your TV',
              ),
              const SizedBox(height: 12),
              _buildInstructionStep(
                number: '2',
                title: 'Go to MaxStream TV',
                description:
                    'Open MaxStream on your TV and navigate to sign in',
              ),
              const SizedBox(height: 12),
              _buildInstructionStep(
                number: '3',
                title: 'Enter Code',
                description: 'Enter the generated code on your TV',
              ),
              const SizedBox(height: 32),

              // Code Generation Section
              if (_generatedCode == null && _errorMessage == null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _generateTVCode,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.code),
                    label: Text(
                      _isLoading ? 'Generating...' : 'Generate TV Code',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

              // Code Display Section
              if (_generatedCode != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your TV Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(color: Colors.blue, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _generatedCode!,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Expires in 15 minutes',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _copyToClipboard,
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy Code'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2A2A2A),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _generateNew,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Generate New'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

              // Error Message
              if (_errorMessage != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(25),
                        border: Border.all(color: Colors.red),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _generateTVCode,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
