import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:version1/Providers/AuthProvider.dart';

class FaceIDLoginScreen extends StatelessWidget {
  const FaceIDLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text("Connexion avec Face ID")),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            bool isAuthenticated = await authProvider.loginWithFaceID();

            if (isAuthenticated) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Authentification réussie !")),
              );
              Navigator.pushReplacementNamed(context, '/home'); // 🔥 Redirige après succès
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Échec de l'authentification")),
              );
            }
          },
          child: const Text("S'authentifier avec Face ID"),
        ),
      ),
    );
  }
}
