import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:version1/Providers/AuthProvider.dart';
import 'package:version1/Routes/app_routes.dart';
import 'package:version1/Views/Profile/ChangePasswordScreen.dart';
import 'package:version1/Views/Profile/EditProfile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null && authProvider.user!.id.isNotEmpty) {
        authProvider.fetchUserProfile(authProvider.user!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0A0F1F), // Bleu nuit sombre
              Color(0xFF001B2E), // Noir bleuté
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: profileProvider.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
            : profileProvider.user == null
                ? const Center(
                    child: Text(
                      "❌ Error: Unable to load profile",
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 30),
                      child: Column(
                        children: [
                          // Photo de profil avec halo néon
                          Center(
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00E5FF)
                                            .withOpacity(0.6),
                                        blurRadius: 25,
                                        spreadRadius: 2,
                                      ),
                                      BoxShadow(
                                        color: const Color(0xFFB041F0)
                                            .withOpacity(0.4),
                                        blurRadius: 15,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 55,
                                    backgroundImage: const AssetImage(
                                        'assets/splash_image.png'),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    // TODO: Update photo profil
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF00E5FF), Color(0xFFB041F0)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    padding: const EdgeInsets.all(6),
                                    child: const Icon(Icons.edit,
                                        color: Colors.white, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),

                          // Nom d'utilisateur
                          Text(
                            profileProvider.user!.username,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Email dans un petit container néon
                          _buildGradientContainer(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: Text(
                                profileProvider.user!.email,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            borderRadius: 12,
                          ),

                          const SizedBox(height: 40),

                          // Menu (Edit, Password, Logout)
                          _buildGradientContainer(
                            borderRadius: 18,
                            child: Column(
                              children: [
                                _buildMenuItem(Icons.person_outline,
                                    "Edit Profile", () {
                                  showDialog(
                                    context: context,
                                    builder: (context) =>
                                        const EditProfileDialog(),
                                  );
                                }),
                                _divider(),
                                _buildMenuItem(Icons.lock_outline,
                                    "Change Password", () {
                                  showDialog(
                                    context: context,
                                    builder: (context) =>
                                        const ChangePasswordScreen(),
                                  );
                                }),
                                _divider(),
                                _buildMenuItem(Icons.logout, "Logout", () {
                                  _handleLogout(context);
                                }, isLogout: true),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _divider() => Divider(
        color: Colors.white.withOpacity(0.2),
        thickness: 1,
        indent: 16,
        endIndent: 16,
      );

  // Container avec contour néon
  Widget _buildGradientContainer(
      {required Widget child, double borderRadius = 10}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00E5FF), Color(0xFFB041F0)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius + 2),
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1F),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: child,
      ),
    );
  }

  // Menu items stylisés
  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap,
      {bool isLogout = false}) {
    final baseColor = isLogout ? Colors.redAccent : const Color(0xFF00E5FF);
    return ListTile(
      leading: Icon(icon, color: baseColor),
      title: Text(
        title,
        style: TextStyle(
          color: baseColor,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios,
          color: Colors.white70, size: 16),
      onTap: onTap,
    );
  }

  // Logout
  void _handleLogout(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A0F1F),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Logout",
              style: TextStyle(color: Colors.white, fontSize: 18)),
          content: const Text("Are you sure you want to log out?",
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                authProvider.logout();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: const [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 10),
                        Text('You have been logged out successfully.'),
                      ],
                    ),
                    backgroundColor: const Color(0xFF00E5FF),
                  ),
                );
                Navigator.pushNamedAndRemoveUntil(
                    context, AppRoutes.singin, (route) => false);
              },
              child: const Text("Logout",
                  style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }
}
