import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:version1/Providers/AuthProvider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  _ChangePasswordPopupState createState() => _ChangePasswordPopupState();
}

class _ChangePasswordPopupState extends State<ChangePasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  int _currentStep = 1;

  int _resendCooldown = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _emailController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00E5FF), Color(0xFFB041F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0F1F), // fond sombre interne
            borderRadius: BorderRadius.circular(26),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getTitle(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Text(
                      _getInstruction(),
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 20),

                    if (_currentStep == 1)
                      _buildEmailField()
                    else if (_currentStep == 2)
                      _buildOtpBoxes()
                    else if (_currentStep == 3)
                      _buildNewPasswordFields(),

                    const SizedBox(height: 24),
                    _buildActionButton(authProvider),

                    const SizedBox(height: 12),
                    if (authProvider.error != null && authProvider.error!.isNotEmpty)
                      Text(
                        authProvider.error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 14),
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

  String _getTitle() {
    if (_currentStep == 1) return "🔑 Enter Email";
    if (_currentStep == 2) return "📩 OTP Verification";
    if (_currentStep == 3) return "🔒 Reset Password";
    return "";
  }

  String _getInstruction() {
    if (_currentStep == 1) return "Enter your email to receive an OTP.";
    if (_currentStep == 2) return "Enter the 6-digit OTP code.";
    if (_currentStep == 3) return "Enter and confirm your new password.";
    return "";
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration("Email", Icons.email),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter your email';
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
          return 'Invalid email format';
        }
        return null;
      },
    );
  }

  Widget _buildOtpBoxes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 40,
          child: TextFormField(
            controller: _otpControllers[index],
            keyboardType: TextInputType.number,
            maxLength: 1,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: const InputDecoration(
              counterText: "",
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white38),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.cyanAccent),
              ),
            ),
            onChanged: (value) {
              if (value.length == 1) FocusScope.of(context).nextFocus();
            },
          ),
        );
      }),
    );
  }

  Widget _buildNewPasswordFields() {
    return Column(
      children: [
        _buildPasswordField("New Password", _newPasswordController,
            _obscureNewPassword, () {
          setState(() => _obscureNewPassword = !_obscureNewPassword);
        }),
        const SizedBox(height: 16),
        _buildPasswordField("Confirm Password", _confirmPasswordController,
            _obscureConfirmPassword, () {
          setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
        }),
      ],
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller,
      bool isObscure, VoidCallback onToggle) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label, Icons.lock).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            isObscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.white70,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return "Please enter your password";
        if (value.length < 6) return "Password must be at least 6 characters";
        return null;
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.cyanAccent),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white24),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.cyanAccent),
      ),
    );
  }

  Widget _buildActionButton(AuthProvider authProvider) {
    String buttonText = "Send OTP";
    if (_currentStep == 2) {
      buttonText =
          _resendCooldown > 0 ? "Wait $_resendCooldown s" : "Verify OTP";
    }
    if (_currentStep == 3) {
      buttonText = "Reset Password";
    }

    return GestureDetector(
      onTap: authProvider.isLoading || (_currentStep == 2 && _resendCooldown > 0)
          ? null
          : () => _handleAction(authProvider),
      child: Container(
        height: 50,
        width: 220,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00E5FF), Color(0xFFB041F0)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: authProvider.isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 16,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _handleAction(AuthProvider authProvider) async {
    if (_currentStep == 1) {
      if (_formKey.currentState!.validate()) {
        bool sent = await authProvider.resendOtp(_emailController.text.trim());
        if (sent) setState(() => _currentStep = 2);
      }
    } else if (_currentStep == 2) {
      String otpCode =
          _otpControllers.map((controller) => controller.text).join();
      if (otpCode.length != 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enter complete 6-digit OTP")),
        );
        return;
      }
      bool verified = await authProvider.verifyOtp(
        _emailController.text.trim(),
        otpCode.trim(),
      );
      if (verified) setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      if (_formKey.currentState!.validate()) {
        if (_newPasswordController.text != _confirmPasswordController.text) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Passwords do not match!")),
          );
          return;
        }
        bool success = await authProvider.updatePassword(
          _emailController.text.trim(),
          _newPasswordController.text.trim(),
        );
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Password reset successfully!")),
          );
          Navigator.pop(context);
        }
      }
    }
  }
}
