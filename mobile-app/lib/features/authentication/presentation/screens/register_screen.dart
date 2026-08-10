import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:claimsupport/core/network/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimsupport/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:claimsupport/core/utils/auth_storage.dart';
import 'package:flutter/services.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _otpSent = false;

  void _sendOtp() {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    final phoneRegex = RegExp(r'^[0-9]{1,10}$');

    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields first.')),
      );
      return;
    }

    if (!emailRegex.hasMatch(_emailController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    if (!phoneRegex.hasMatch(_phoneController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid mobile number (1-10 digits).')),
      );
      return;
    }

    setState(() {
      _otpSent = true;
    });
  }

  void _verifyOtp() async {
    if (_otpController.text == '1234') {
      try {
        final response = await ApiClient().dio.post('/auth/register', data: {
          'name': _nameController.text,
          'email': _emailController.text,
          'phone': _phoneController.text,
          'otp': _otpController.text,
        });

        if (response.statusCode == 200 || response.statusCode == 201) {
          final token = response.data['token'];
          await AuthStorage.saveToken(token);
          ref.invalidate(authProvider);
          if (mounted) context.go('/dashboard');
        }
      } on DioException catch (e) {
        String errorMsg = 'Registration failed';
        if (e.response != null && e.response?.data != null) {
          errorMsg = e.response?.data['detail'] ?? e.response?.data['message'] ?? errorMsg;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP. Use 1234 for testing.')),
      );
    }
  }

  Widget _buildTextField(BuildContext context, {
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.inputDecorationTheme.fillColor ?? (isDark ? Colors.grey.shade900 : Colors.white),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
              ),
              filled: true,
              fillColor: theme.inputDecorationTheme.fillColor ?? (isDark ? Colors.grey.shade900 : Colors.white),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color primaryBlue = const Color(0xFF2563EB);
    final Color textColor = isDark ? Colors.white : const Color(0xFF111827);
    final Color textSecondaryColor = isDark ? Colors.grey.shade400 : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              // Title
              Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              // Subtitle
              Text(
                'Join Claim Support today.',
                style: TextStyle(
                  fontSize: 16,
                  color: textSecondaryColor,
                ),
              ),
              const SizedBox(height: 48),
              
              if (!_otpSent) ...[
                _buildTextField(
                  context,
                  label: 'Full Name',
                  hint: 'Alex Morgan',
                  controller: _nameController,
                ),
                _buildTextField(
                  context,
                  label: 'Email Address',
                  hint: 'alex@example.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                _buildTextField(
                  context,
                  label: 'Phone Number',
                  hint: '9876543210',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
              ] else ...[
                _buildTextField(
                  context,
                  label: 'Enter OTP',
                  hint: '000000',
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                ),
              ],
              
              const SizedBox(height: 8),
              
              // Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withAlpha(60),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _otpSent ? _verifyOtp : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _otpSent ? 'Verify OTP & Register' : 'Send OTP',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Bottom Links
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ",
                      style: TextStyle(
                        color: textSecondaryColor,
                        fontSize: 15,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        context.pop(); // Go back to login
                      },
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          color: primaryBlue,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
