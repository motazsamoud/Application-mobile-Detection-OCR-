// lib/Views/ocr/detections_list_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:version1/Views/ocr/scan_result_page.dart';
import 'package:version1/providers/ocr_detections_provider.dart';
import 'package:version1/config/api.dart'; // API_BASE_URL

class OcrDetectionsListPage extends StatefulWidget {
  const OcrDetectionsListPage({super.key});

  @override
  State<OcrDetectionsListPage> createState() => _OcrDetectionsListPageState();
}

class _OcrDetectionsListPageState extends State<OcrDetectionsListPage> {
  @override
  void initState() {
    super.initState();
    // charge à l’ouverture
    Future.microtask(() => context.read<OcrDetectionsProvider>().fetch());
  }

  // URL réseau: http://IP:3000/uploads/<fileName>
  String _imageUrlFromDoc(Map<String, dynamic> doc) {
    final dynamicName =
        doc['fileName'] ?? doc['filename'] ?? doc['originalFileName'] ?? doc['originalname'];
    final fileName = dynamicName?.toString();
    if (fileName == null || fileName.isEmpty) return '';
    return '$API_BASE_URL/uploads/${Uri.encodeComponent(fileName)}';
  }

  // Chemin local éventuel: <appDoc>/ocr_cards/<id>.(jpg|jpeg|png|webp)
  Future<String?> _localPathForId(String id) async {
    if (id.isEmpty) return null;
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'ocr_cards'));
    if (!await folder.exists()) return null;

    for (final ext in ['.jpg', '.jpeg', '.png', '.webp']) {
      final f = File(p.join(folder.path, '$id$ext'));
      if (await f.exists()) return f.path;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pvd = context.watch<OcrDetectionsProvider>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Cartes scannées'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0F1F), Color(0xFF001B2E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: pvd.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _FilterBar(
                  current: pvd.filter,
                  onChanged: (f) => pvd.setFilter(f),
                  total: pvd.rawItems.length,
                  shown: pvd.items.length,
                ),
                const SizedBox(height: 12),

                if (pvd.loading) const _LoadingList(),
                if (!pvd.loading && pvd.error != null)
                  _ErrorBox(message: pvd.error!, onRetry: pvd.fetch),
                if (!pvd.loading && pvd.error == null && pvd.items.isEmpty)
                  const _EmptyBox(),

                if (!pvd.loading && pvd.items.isNotEmpty)
                  ...pvd.items.map((doc) {
                    final id = (doc['_id'] ?? doc['id'])?.toString() ?? '';
                    final imageUrl = _imageUrlFromDoc(doc);

                    return FutureBuilder<String?>(
                      future: _localPathForId(id),
                      builder: (context, snap) {
                        final localPath = snap.data; // null => on tentera l’URL réseau
                        return _DetectionCard(
                          data: doc,
                          localPath: localPath,
                          imageUrl: imageUrl,
                          onOpen: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ScanResultPage(
                                  result: {
                                    'id': id,
                                    'fileName': doc['fileName'] ??
                                        doc['filename'] ??
                                        doc['originalFileName'] ??
                                        doc['originalname'],
                                    'detectionStatus':
                                        doc['status'] ??
                                        doc['detectionStatus'] ??
                                        'draft',
                                    'confidence': doc['confidence'] ?? 0,
                                    'fieldScores': doc['fieldScores'] ?? {},
                                    'rawText': doc['rawText'] ?? '',
                                    'fullName': doc['fullName'],
                                    'company': doc['company'],
                                    'email': doc['email'],
                                    'phone': doc['phone'],
                                    'position': doc['position'],
                                    'address': doc['address'],
                                    'website': doc['website'],
                                  },
                                  // si on a l’image locale on la passe
                                  imagePath: localPath,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================= UI widgets =================

class _FilterBar extends StatelessWidget {
  final String current;
  final void Function(String) onChanged;
  final int total;
  final int shown;
  const _FilterBar({
    required this.current,
    required this.onChanged,
    required this.total,
    required this.shown,
  });

  @override
  Widget build(BuildContext context) {
    final chips = const [
      ['all', 'Tous'],
      ['draft', 'Brouillons'],
      ['confirmed', 'Confirmés'],
      ['rejected', 'Rejetés'],
    ];
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total: $shown / $total',
              style: const TextStyle(color: Color.fromARGB(179, 255, 255, 255))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips.map((c) {
              final selected = current == c[0];
              return ChoiceChip(
                label: Text(
                  c[1],
                  style: TextStyle(
                    color: selected ? const Color(0xFF001B2E) : Colors.white,
                  ),
                ),
                selected: selected,
                selectedColor: const Color(0xFF00E5FF),
                backgroundColor: Colors.white12,
                onSelected: (_) => onChanged(c[0]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DetectionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String? localPath; // ← chemin image locale si dispo
  final String imageUrl;   // ← fallback réseau
  final VoidCallback onOpen;
  const _DetectionCard({
    required this.data,
    required this.localPath,
    required this.imageUrl,
    required this.onOpen,
  });

  // ==== Actions intelligentes =========================================

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openWebsite(BuildContext context, String? website) async {
    final v = website?.trim();
    if (v == null || v.isEmpty || v == '—') return;
    final url = v.startsWith('http://') || v.startsWith('https://') ? v : 'https://$v';
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _toast(context, "Impossible d'ouvrir le site.");
    }
  }

  Future<void> _openEmail(BuildContext context, String? email) async {
    final v = email?.trim();
    if (v == null || v.isEmpty || v == '—') return;
    final uri = Uri(scheme: 'mailto', path: v);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _toast(context, "Impossible d’ouvrir l’e-mail.");
    }
  }

  Future<void> _openPhone(BuildContext context, String? phone) async {
    final v = phone?.trim();
    if (v == null || v.isEmpty || v == '—') return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1626),
        title: const Text('Appeler ?', style: TextStyle(color: Colors.white)),
        content: Text(v, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
        ],
      ),
    );

    if (ok != true) return;

    final sanitized = v.replaceAll(' ', '');
    final uri = Uri(scheme: 'tel', path: sanitized);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _toast(context, "Impossible d’ouvrir le téléphone.");
    }
  }

  Future<void> _openAddress(BuildContext context, String? address) async {
    final v = address?.trim();
    if (v == null || v.isEmpty || v == '—') return;

    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(v)}');

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _toast(context, "Impossible d’ouvrir la carte.");
    }
  }

  // ====================================================================

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? data['detectionStatus'] ?? 'draft').toString();
    final extraction = (data['extractionStatus'] ?? 'new').toString();
    final conf = ((data['confidence'] ?? 0) as num).toDouble();

    Widget row(
      IconData ic,
      String label,
      String? val, {
      VoidCallback? onTap,
    }) {
      final clickable = onTap != null && (val?.trim().isNotEmpty ?? false);
      final textColor = clickable ? const Color(0xFF00E5FF) : Colors.white;
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: InkWell(
          onTap: clickable ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(ic, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      (val?.trim().isNotEmpty == true) ? val!.trim() : '—',
                      style: TextStyle(
                        color: textColor,
                        decoration: clickable ? TextDecoration.underline : TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              if (clickable) const Icon(Icons.open_in_new, size: 16, color: Colors.white54),
            ],
          ),
        ),
      );
    }

    Color _statusColor(String s) {
      switch (s) {
        case 'confirmed':
          return Colors.greenAccent;
        case 'rejected':
          return Colors.redAccent;
        default:
          return Colors.orangeAccent;
      }
    }

    Widget _thumb() {
      // 1) priorité à l’image locale
      if (localPath != null && localPath!.isNotEmpty) {
        return Image.file(File(localPath!), fit: BoxFit.cover);
      }
      // 2) sinon, URL réseau si dispo
      if (imageUrl.isNotEmpty) {
        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _ThumbPlaceholder(),
        );
      }
      // 3) sinon placeholder
      return const _ThumbPlaceholder();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _Glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(width: 72, height: 72, child: _thumb()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _Chip(text: 'Status: $status', color: _statusColor(status)),
                      _Chip(text: 'Extraction: $extraction', color: Colors.blueAccent),
                      _Chip(text: 'Confiance: ${conf.round()}%', color: const Color(0xFF00E5FF)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new, color: Colors.white70),
                  tooltip: 'Ouvrir',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // body fields (avec actions)
            row(Icons.person, 'Nom complet', data['fullName']?.toString()),
            row(Icons.business, 'Société', data['company']?.toString()),
            row(
              Icons.email,
              'Email',
              data['email']?.toString(),
              onTap: () => _openEmail(context, data['email']?.toString()),
            ),
            row(
              Icons.phone,
              'Téléphone',
              data['phone']?.toString(),
              onTap: () => _openPhone(context, data['phone']?.toString()),
            ),
            row(Icons.badge, 'Fonction', data['position']?.toString()),
            row(
              Icons.location_on,
              'Adresse',
              data['address']?.toString(),
              onTap: () => _openAddress(context, data['address']?.toString()),
            ),
            row(
              Icons.language,
              'Site web',
              data['website']?.toString(),
              onTap: () => _openWebsite(context, data['website']?.toString()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white12,
      child: const Icon(Icons.credit_card, color: Colors.white70),
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  const _Glass({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.2),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        border: Border.all(color: color.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _Glass(
            child: Container(
              height: 120,
              alignment: Alignment.centerLeft,
              child: const LinearProgressIndicator(
                minHeight: 6,
                color: Color(0xFF00E5FF),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final Future<void> Function({int limit}) onRetry;
  const _ErrorBox({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Erreur', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => onRetry(limit: 100),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox();
  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Row(
        children: const [
          Icon(Icons.inbox, color: Colors.white54),
          SizedBox(width: 10),
          Expanded(child: Text('Aucune carte trouvée.', style: TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }
}
