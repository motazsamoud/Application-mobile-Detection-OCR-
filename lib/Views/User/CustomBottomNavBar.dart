// lib/Widgets/custom_bottom_nav_bar_user.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:version1/Views/User/HomePage.dart';
import 'package:version1/Views/Profile/ProfileScreen.dart';
import 'package:version1/Views/ocr/scan_result_page.dart';
import 'package:version1/Views/ocr/detections_list_page.dart';
import 'package:version1/Views/opportunitites/opportunities_list_page.dart';

// ⬇️ NOUVEAU: imports opportunités
import 'package:version1/providers/opportunities_provider.dart';

import 'package:version1/providers/ocr_provider.dart';
import 'package:version1/providers/ocr_detections_provider.dart';

class CustomBottomNavBarUser extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const CustomBottomNavBarUser({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  _CustomBottomNavBarUserState createState() => _CustomBottomNavBarUserState();
}

class _CustomBottomNavBarUserState extends State<CustomBottomNavBarUser> {
  late int _currentIndex;

  // icônes
  final List<IconData> _icons = const [
    Icons.home,          // 0 Accueil
    Icons.camera_alt,    // 1 Scanner
    Icons.credit_card,   // 2 Cartes scannées
    Icons.person,        // 3 Profil
    Icons.work_outline,  // 4 Opportunités  ⬅️ NOUVEAU
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
  }

  Future<void> _onItemTapped(int index) async {
    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (_, __, ___) => const HomePage(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
        break;

      case 1:
        // flux scan: Caméra/Galerie -> upload -> résultat
        _openScanBottomSheet();
        break;

      case 2:
        // Page "Cartes scannées" (liste depuis /ocr/detections)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider(
              create: (_) => OcrDetectionsProvider(),
              child: const OcrDetectionsListPage(),
            ),
          ),
        );
        break;

      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ).then((_) => setState(() {}));
        break;

      case 4: // ⬅️ NOUVEAU: opportunités
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider(
              create: (_) => OpportunitiesProvider(),
              child: const OpportunitiesListPage(),
            ),
          ),
        );
        break;
    }

    widget.onItemSelected(index);
  }

  void _openScanBottomSheet() {
    final ocr = OcrProvider(); // provider local pour ce flow
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ChangeNotifierProvider.value(
          value: ocr,
          child: const _ScanSheet(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        height: 65,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1F),
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: const Color(0xFFB041F0).withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_icons.length, (index) {
            final isSelected = _currentIndex == index;
            return GestureDetector(
              onTap: () => _onItemTapped(index),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Colors.white.withOpacity(0.1)
                          : Colors.transparent,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withOpacity(0.6),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      _icons[index],
                      size: 28,
                      color: isSelected
                          ? const Color(0xFF00E5FF)
                          : Colors.white.withOpacity(0.6),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00E5FF),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ---------- Bottom sheet privée pour le flow scan ----------
class _ScanSheet extends StatelessWidget {
  const _ScanSheet();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OcrProvider>();
    final hasImage = p.selected != null;

    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF121621),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4, width: 48,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Scanner une carte',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 12),

            if (p.error != null)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Une erreur est survenue',
                    style: TextStyle(color: Colors.redAccent)),
              ),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: p.uploading ? null : () async {
                      await context.read<OcrProvider>().pickFromGallery();
                      await _maybeUploadAndNavigate(context);
                    },
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galerie'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: p.uploading ? null : () async {
                      await context.read<OcrProvider>().pickFromCamera();
                      await _maybeUploadAndNavigate(context);
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Caméra'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (hasImage)
              FilledButton.icon(
                onPressed: p.uploading ? null : () async {
                  await _maybeUploadAndNavigate(context);
                },
                icon: p.uploading
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(p.uploading ? 'Envoi...' : 'Envoyer'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _maybeUploadAndNavigate(BuildContext context) async {
    final prov = context.read<OcrProvider>();
    if (prov.selected == null) return;

    final res = await prov.uploadToBackend();
    if (res == null) return;

    // ferme la bottom sheet
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // ouvre la page de confirmation
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScanResultPage(
            result: res,
            imagePath: prov.selected!.path,
          ),
        ),
      );
    }
  }
}
