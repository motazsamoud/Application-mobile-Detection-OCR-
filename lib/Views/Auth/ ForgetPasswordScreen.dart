import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:version1/Providers/AuthProvider.dart';
import 'package:version1/Routes/app_routes.dart';


class ForgetPasswordDialog extends StatefulWidget {
  const ForgetPasswordDialog({super.key});

  @override
  _ForgetPasswordDialogState createState() => _ForgetPasswordDialogState();
}

class _ForgetPasswordDialogState extends State<ForgetPasswordDialog> {
  final TextEditingController _emailController = TextEditingController();

  // Création de 6 TextEditingController pour l'OTP (6 chiffres)
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());

  // Pour le mot de passe temporaire, on utilise un TextEditingController classique
  final TextEditingController _tempPasswordController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isOtpSent = false;
  bool _isOtpVerified = false;
  bool _obscureText = true;
  int _resendCooldown = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _emailController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    _tempPasswordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3ED0FA), Color(0xFFB041F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // En-tête : Titre et bouton de fermeture
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Forgot Password',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8D48AA),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Texte d'instruction en fonction de l'étape
                    if (!_isOtpSent && !_isOtpVerified)
                      const Text(
                        "Enter your email to receive an OTP",
                        style: TextStyle(color: Colors.black),
                      ),
                    if (_isOtpSent && !_isOtpVerified)
                      const Text(
                        "Enter the 6-digit OTP code",
                        style: TextStyle(color: Colors.black),
                      ),
                    if (_isOtpVerified)
                      const Text(
                        "Enter your temporary password",
                        style: TextStyle(color: Colors.black),
                      ),
                    const SizedBox(height: 16),
                    // Champs de saisie
                    if (!_isOtpSent)
                      _buildEmailField()
                    else if (_isOtpSent && !_isOtpVerified)
                      _buildOtpBoxes()
                    else if (_isOtpVerified)
                      _buildTemporaryPasswordField(),
                    const SizedBox(height: 20),
                    // Bouton d'action principal
                    _buildActionButton(authProvider),
                    const SizedBox(height: 12),
                    // Messages d'erreur / succès
                    if (authProvider.error != null &&
                        authProvider.error!.isNotEmpty)
                      Text(
                        authProvider.error!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    if (authProvider.successMessage != null &&
                        authProvider.successMessage!.isNotEmpty)
                      Text(
                        authProvider.successMessage!,
                        style: const TextStyle(color: Colors.green, fontSize: 14),
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

  // Champ d'email classique
  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: Colors.black),
      decoration: const InputDecoration(
        labelText: "Email",
        labelStyle: TextStyle(color: Colors.grey),
        prefixIcon: Icon(Icons.email, color: Colors.grey),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.black),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter your email';
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value))
          return 'Invalid email format';
        return null;
      },
    );
  }

  // 6 cases pour saisir l'OTP
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
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(
              counterText: "",
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.black),
              ),
            ),
            onChanged: (value) {
              if (value.length == 1) {
                FocusScope.of(context).nextFocus();
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) return '';
              return null;
            },
          ),
        );
      }),
    );
  }

  // Champ de saisie normal pour le mot de passe temporaire
  Widget _buildTemporaryPasswordField() {
    return TextFormField(
      controller: _tempPasswordController,
      obscureText: _obscureText,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: "Temporary Password",
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: const Icon(Icons.lock, color: Colors.grey),
        suffixIcon: IconButton(
          icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
          color: Colors.grey,
          onPressed: () {
            setState(() {
              _obscureText = !_obscureText;
            });
          },
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.black),
        ),
      ),
      validator: (value) =>
          value == null || value.isEmpty ? 'Please enter the temporary password' : null,
    );
  }

  // Bouton d'action principal (taille réduite)
  Widget _buildActionButton(AuthProvider authProvider) {
    String buttonText = "Send OTP";
    if (_isOtpSent && !_isOtpVerified) {
      buttonText = _resendCooldown > 0 ? "Wait $_resendCooldown s" : "Verify OTP";
    }
    if (_isOtpVerified) buttonText = "Login";

    return GestureDetector(
      onTap: authProvider.isLoading || (!_isOtpSent && _resendCooldown > 0)
          ? null
          : () => _handleAction(authProvider),
      child: Container(
        height: 40,
        width: 120,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3ED0FA), Color(0xFFB041F0)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: authProvider.isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF3ED0FA), Color(0xFFB041F0)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          buttonText,
                          style: const TextStyle(
                            fontSize: 14,
                            letterSpacing: 1,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios,
                            color: Colors.white, size: 14),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(AuthProvider authProvider) async {
    if (!_isOtpSent) {
      bool otpSent = await authProvider.resendOtp(_emailController.text.trim());
      if (otpSent) {
        setState(() {
          _isOtpSent = true;
        });
      } else if (authProvider.error != null &&
          authProvider.error!.contains("60 seconds")) {
        setState(() {
          _resendCooldown = 60;
        });
        _resendTimer?.cancel();
        _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            if (_resendCooldown > 0) {
              _resendCooldown--;
            } else {
              timer.cancel();
            }
          });
        });
      }
    } else if (_isOtpSent && !_isOtpVerified) {
      // Rassemble le code OTP saisi dans les 6 cases
      String otpCode = _otpControllers.map((c) => c.text).join();
      bool otpVerified = await authProvider.verifyOtp(
        _emailController.text.trim(),
        otpCode.trim(),
      );
      if (otpVerified) {
        setState(() {
          _isOtpVerified = true;
        });
      }
    } else if (_isOtpVerified) {
      // Utilise le champ de saisie normal pour le mot de passe temporaire
      String tempPass = _tempPasswordController.text.trim();
      bool tempPasswordValid = await authProvider.verifyTemporaryPassword(
        _emailController.text.trim(),
        tempPass,
      );
      if (tempPasswordValid) {
        bool loginSuccess = await authProvider.login(
          _emailController.text.trim(),
          tempPass,
          context,
        );
        if (loginSuccess) {
          Navigator.pop(context);
          Navigator.pushReplacementNamed(context, AppRoutes.HomeUser);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(authProvider.error ?? 'Connexion échouée.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe temporaire invalide.')),
        );
      }
    }
  }
}
