import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:version1/Providers/AuthProvider.dart';

class EditProfileDialog extends StatefulWidget {
  const EditProfileDialog({super.key});

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _dateOfBirthController;
  bool _receiveNotifications = true;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AuthProvider>(context, listen: false);
    final user = provider.user!;
    _usernameController = TextEditingController(text: user.username);
    _emailController = TextEditingController(text: user.email);
    _dateOfBirthController = TextEditingController(
      text: provider.profile?.dateOfBirth != null
          ? DateFormat('yyyy-MM-dd')
              .format(DateTime.parse(provider.profile!.dateOfBirth!))
          : '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<AuthProvider>(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00E5FF), Color(0xFFB041F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withOpacity(0.6),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0F1F), // fond sombre
            borderRadius: BorderRadius.circular(23),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Edit Profile",
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField('Username', _usernameController, Icons.person),
                  const SizedBox(height: 15),
                  _buildDatePickerField('Date of Birth', _dateOfBirthController, Icons.calendar_today),
                  const SizedBox(height: 15),
                  _buildTextField('Email', _emailController, Icons.email),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Checkbox(
                        value: _receiveNotifications,
                        activeColor: Colors.cyanAccent,
                        checkColor: Colors.black,
                        onChanged: (value) {
                          setState(() {
                            _receiveNotifications = value!;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          "Receive all notifications and updates",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSaveButton(profileProvider),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Champ texte stylisé néon
  Widget _buildTextField(String label, TextEditingController controller, IconData icon) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label, icon),
    );
  }

  // Champ date
  Widget _buildDatePickerField(String label, TextEditingController controller, IconData icon) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label, icon),
      readOnly: true,
      onTap: () async {
        DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: controller.text.isNotEmpty
              ? DateTime.parse(controller.text)
              : DateTime(2000),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (pickedDate != null) {
          setState(() {
            controller.text = DateFormat('yyyy-MM-dd').format(pickedDate);
          });
        }
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.cyanAccent),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white24),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.cyanAccent),
      ),
    );
  }

  // Bouton SAVE stylisé comme SIGN IN
  Widget _buildSaveButton(AuthProvider profileProvider) {
    return GestureDetector(
      onTap: () async {
        if (_formKey.currentState!.validate()) {
          final userId = profileProvider.user?.id;
          if (userId != null) {
            Map<String, dynamic> updatedData = {
              "username": _usernameController.text,
              "email": _emailController.text,
              "dateOfBirth": _dateOfBirthController.text,
            };
            bool success = await profileProvider.updateUserProfile(userId, updatedData);
            if (success) {
              final updatedProfile = profileProvider.profile;
              if (updatedProfile != null) {
                _usernameController.text = updatedProfile.username;
                _emailController.text = updatedProfile.email;
                if (updatedProfile.dateOfBirth != null) {
                  _dateOfBirthController.text = DateFormat('yyyy-MM-dd')
                      .format(DateTime.parse(updatedProfile.dateOfBirth!));
                }
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("✅ Profile updated successfully!")),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("❌ Failed to update profile: ${profileProvider.error}")),
              );
            }
          }
        }
      },
      child: Container(
        height: 50,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00E5FF), Color(0xFFB041F0)],
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Center(
          child: Text(
            "SAVE",
            style: TextStyle(
              fontSize: 18,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
