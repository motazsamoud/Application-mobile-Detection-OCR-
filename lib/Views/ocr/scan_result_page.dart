// lib/Views/ocr/scan_result_page.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:version1/config/api.dart';
import 'package:version1/providers/opportunities_provider.dart';

class ScanResultPage extends StatefulWidget {
  final Map<String, dynamic> result;
  final String? imagePath; // chemin local (caméra/galerie)

  const ScanResultPage({super.key, required this.result, this.imagePath});

  @override
  State<ScanResultPage> createState() => _ScanResultPageState();
}

class _ScanResultPageState extends State<ScanResultPage> {
  // Controllers (préremplis)
  late final TextEditingController fullName =
      TextEditingController(text: widget.result['fullName'] ?? '');
  late final TextEditingController company =
      TextEditingController(text: widget.result['company'] ?? '');
  late final TextEditingController email =
      TextEditingController(text: widget.result['email'] ?? '');
  late final TextEditingController phone =
      TextEditingController(text: widget.result['phone'] ?? '');
  late final TextEditingController position =
      TextEditingController(text: widget.result['position'] ?? '');
  late final TextEditingController address =
      TextEditingController(text: widget.result['address'] ?? '');
  late final TextEditingController website =
      TextEditingController(text: widget.result['website'] ?? '');

  bool saving = false;

  @override
  void initState() {
    super.initState();
    // Sauvegarde immédiatement la vignette locale sous <id>.<ext>
    // pour que la liste puisse l'afficher.
    Future.microtask(_persistLocalThumbIfNeeded);
  }

  Map<String, num> get scores {
    final raw = widget.result['fieldScores'];
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), (v as num?) ?? 0));
    }
    return {};
  }

  String _pillText(num v) {
    if (v >= 0.85) return 'Confiance élevée';
    if (v >= 0.65) return 'À vérifier';
    return 'Faible';
  }

  InputDecoration _dec(String label, IconData icon, {String? keyScore}) {
    final sc = keyScore != null ? (scores[keyScore] ?? 0) : null;
    final hint = sc == null ? null : _pillText(sc);
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.white70),
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0x14FFFFFF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  /// Copie l'image locale vers <appDoc>/ocr_cards/<id>.<ext>
  Future<void> _persistLocalThumbIfNeeded() async {
    final local = widget.imagePath;
    final id = widget.result['id']?.toString();
    if (local == null || local.isEmpty || id == null || id.isEmpty) return;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final folder = Directory(p.join(docDir.path, 'ocr_cards'));
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
      final ext = p.extension(local).isEmpty ? '.jpg' : p.extension(local).toLowerCase();
      final dst = p.join(folder.path, '$id$ext');

      // Si déjà présent, ne rien faire
      if (!await File(dst).exists()) {
        await File(local).copy(dst);
      }
    } catch (_) {
      // on ignore silencieusement ; le fallback réseau prendra le relai
    }
  }

  /// ✅ Confirme la détection (status: confirmed)
  Future<void> _confirmDetection() async {
    setState(() => saving = true);
    try {
      final id = widget.result['id']?.toString();
      if (id == null || id.isEmpty) {
        throw Exception('Aucun id de détection dans la réponse OCR');
      }

      final resp = await http.post(
        Uri.parse('$API_BASE_URL/ocr/detections/$id/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': 'confirmed'}),
      );

      final ok = resp.statusCode >= 200 && resp.statusCode < 300;
      if (!ok) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }

      // assure que la vignette est bien cachée au cas où
      await _persistLocalThumbIfNeeded();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Détection confirmée')),
      );
      Navigator.pop(context); // Retour
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Échec confirmation: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;

    // Fallback réseau si pas d’image locale
    final fileName = r['fileName']?.toString();
    final networkUrl = (fileName != null && fileName.isNotEmpty)
        ? '$API_BASE_URL/uploads/${Uri.encodeComponent(fileName)}'
        : null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Confirmation détection'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0F1F), Color(0xFF001B2E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _HeaderPreview(
                imagePath: widget.imagePath, // locale
                networkUrl: networkUrl,      // réseau
                detectionStatus: '${r['detectionStatus'] ?? 'draft'}',
                confidence: (r['confidence'] as num?)?.toDouble() ?? 0,
              ),
              const SizedBox(height: 16),

              _Glass(
                child: Column(
                  children: [
                    _ConfidenceRow(scores: scores),
                    const SizedBox(height: 8),
                    TextField(
                        controller: fullName,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: Colors.white),
                        decoration: _dec('Nom complet', Icons.person, keyScore: 'fullName')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: company,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: Colors.white),
                        decoration: _dec('Société', Icons.business, keyScore: 'company')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: Colors.white),
                        decoration: _dec('Email', Icons.email, keyScore: 'email')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: Colors.white),
                        decoration: _dec('Téléphone', Icons.phone, keyScore: 'phone')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: position,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: Colors.white),
                        decoration: _dec('Fonction', Icons.badge, keyScore: 'position')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: address,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white),
                        decoration: _dec('Adresse', Icons.location_on, keyScore: 'address')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: website,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(color: Colors.white),
                        decoration: _dec('Site web', Icons.language, keyScore: 'website')),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              _ExpandableRawText(text: '${r['rawText'] ?? ''}'),
              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Annuler'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // NOUVEAU: créer opportunité
    Expanded(
      child: FilledButton.icon(
        onPressed: saving ? null : () async {
          final id = widget.result['id']?.toString();
          if (id == null || id.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ID OCR manquant')),
            );
            return;
          }
          // provider local pour l’action
          final created = await showDialog<Map<String, dynamic>?>(
            context: context,
            builder: (ctx) => ChangeNotifierProvider(
              create: (_) => OpportunitiesProvider(),
              child: _CreateOppDialog(ocrId: id, suggestedTitle: widget.result['fullName'] ?? 'Opportunity'),
            ),
          );
          if (created != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Opportunité créée')),
            );
          }
        },
        icon: const Icon(Icons.work_outline),
        label: const Text('Créer opportunité'),
      ),
    ),
                      const SizedBox(width: 12),

                  Expanded(
                    child: FilledButton.icon(
                      onPressed: saving ? null : _confirmDetection,
                      icon: saving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check),
                      label: Text(saving ? 'Enregistrement...' : 'Confirmer'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: const Color(0xFF001B2E),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Widgets UI ----------

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
            color: const Color(0xFF00E5FF).withOpacity(0.22),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HeaderPreview extends StatelessWidget {
  final String? imagePath;   // local
  final String? networkUrl;  // réseau
  final String detectionStatus;
  final double confidence;

  const _HeaderPreview({
    required this.imagePath,
    required this.networkUrl,
    required this.detectionStatus,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    // priorité: fichier local -> réseau -> placeholder
    Widget img;
    if (imagePath != null) {
      img = Image.file(File(imagePath!), width: 110, height: 110, fit: BoxFit.cover);
    } else if (networkUrl != null) {
      img = Image.network(
        networkUrl!,
        width: 110, height: 110, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 110, height: 110,
          color: Colors.white10,
          child: const Icon(Icons.broken_image, color: Colors.white70),
        ),
      );
    } else {
      img = Container(
        width: 110, height: 110,
        color: Colors.white10,
        child: const Icon(Icons.credit_card, color: Colors.white70),
      );
    }

    return _Glass(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: img),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Chip(text: 'Status: $detectionStatus', color: Colors.deepPurpleAccent),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Confiance ', style: TextStyle(color: Colors.white70)),
                    Text('${confidence.round()}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (confidence.clamp(0, 100)) / 100,
                  minHeight: 8,
                  color: const Color(0xFF00E5FF),
                  backgroundColor: Colors.white12,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          ),
        ],
      ),
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

class _ConfidenceRow extends StatelessWidget {
  final Map<String, num> scores;
  const _ConfidenceRow({required this.scores});

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) return const SizedBox.shrink();
    final items = <_ScoreItem>[
      _ScoreItem('Nom', 'fullName', Icons.person),
      _ScoreItem('Société', 'company', Icons.business),
      _ScoreItem('Email', 'email', Icons.email),
      _ScoreItem('Tel', 'phone', Icons.phone),
      _ScoreItem('Fonction', 'position', Icons.badge),
      _ScoreItem('Adresse', 'address', Icons.location_on),
      _ScoreItem('Web', 'website', Icons.language),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((it) {
        final v = (scores[it.key] ?? 0).toDouble();
        Color c;
        if (v >= 0.85) {
          c = Colors.greenAccent;
        } else if (v >= 0.65) {
          c = Colors.orangeAccent;
        } else {
          c = Colors.redAccent;
        }
        return _Chip(text: '${it.label} ${((v) * 100).round()}%', color: c);
      }).toList(),
    );
  }
}

class _ScoreItem {
  final String label;
  final String key;
  final IconData icon;
  _ScoreItem(this.label, this.key, this.icon);
}

class _ExpandableRawText extends StatefulWidget {
  final String text;
  const _ExpandableRawText({required this.text});
  @override
  State<_ExpandableRawText> createState() => _ExpandableRawTextState();
}

class _ExpandableRawTextState extends State<_ExpandableRawText> {
  bool open = false;
  @override
  Widget build(BuildContext context) {
    if (widget.text.trim().isEmpty) return const SizedBox.shrink();
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description, color: Colors.white70),
              const SizedBox(width: 8),
              const Text('Texte brut', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => open = !open),
                icon: Icon(open ? Icons.expand_less : Icons.expand_more, color: Colors.white70),
              )
            ],
          ),
          if (open)
            Text(widget.text,
                style: const TextStyle(color: Colors.white70), textAlign: TextAlign.left),
        ],
      ),
    );
  }
}
class _CreateOppDialog extends StatefulWidget {
  final String ocrId;
  final String? suggestedTitle;
  const _CreateOppDialog({required this.ocrId, this.suggestedTitle});

  @override
  State<_CreateOppDialog> createState() => _CreateOppDialogState();
}

class _CreateOppDialogState extends State<_CreateOppDialog> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _currency = TextEditingController(text: 'TND');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title.text = widget.suggestedTitle?.toString() ?? 'Opportunity';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OpportunitiesProvider>();
    return AlertDialog(
      backgroundColor: const Color(0xFF0E1626),
      title: const Text('Créer une opportunité', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Titre', labelStyle: TextStyle(color: Colors.white70)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amount, keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Montant (optionnel)', labelStyle: TextStyle(color: Colors.white70)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _currency,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Devise', labelStyle: TextStyle(color: Colors.white70)),
          ),
          if (p.error != null) ...[
            const SizedBox(height: 8),
            Text(p.error!, style: const TextStyle(color: Colors.redAccent)),
          ]
        ],
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, null),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: _saving ? null : () async {
            setState(() => _saving = true);
            final created = await context.read<OpportunitiesProvider>().createFromOcr(
              ocrDetectionId: widget.ocrId,
              title: _title.text.trim().isEmpty ? null : _title.text.trim(),
              amount: double.tryParse(_amount.text.trim()),
              currency: _currency.text.trim().isEmpty ? null : _currency.text.trim(),
            );
            if (!mounted) return;
            setState(() => _saving = false);
            Navigator.pop(context, created);
          },
          child: _saving ? const SizedBox(
            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Text('Créer'),
        ),
      ],
    );
  }
}

