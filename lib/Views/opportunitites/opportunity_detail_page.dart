// lib/Views/opportunities/opportunity_detail_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version1/providers/opportunities_provider.dart';

class OpportunityDetailPage extends StatefulWidget {
  final Map<String, dynamic> opportunity;
  const OpportunityDetailPage({super.key, required this.opportunity});

  @override
  State<OpportunityDetailPage> createState() => _OpportunityDetailPageState();
}

class _OpportunityDetailPageState extends State<OpportunityDetailPage> {
  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }

  Future<void> _open(Uri uri,
      {LaunchMode mode = LaunchMode.externalApplication}) async {
    await launchUrl(uri, mode: mode);
  }

  Color _posColor(String s) {
    switch (s) {
      case 'won': return Colors.greenAccent;
      case 'lost': return Colors.redAccent;
      case 'qualified': return Colors.lightBlueAccent;
      case 'contacted': return Colors.orangeAccent;
      default: return Colors.amberAccent;
    }
  }

  Widget _chip(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.withOpacity(0.18),
          border: Border.all(color: c.withOpacity(0.6)),
          borderRadius: BorderRadius.circular(40),
        ),
        child: Text(text, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
      );

  Widget _glass(Widget child) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: child,
      );

  // ---------------- state (défauts pour éviter LateInitializationError) ----------------
  String _pipeline = 'new';
  String _title = 'Opportunity';
  String _company = '';
  String _fullName = '';
  String _email = '';
  String _phone = '';
  String _address = '';
  String _website = '';
  String _currency = 'TND';
  String _jobTitle = ''; // poste détecté
  double? _amount;

  @override
  void initState() {
    super.initState();
    final o = widget.opportunity;
    _pipeline = '${o['position'] ?? 'new'}';
    _title    = '${o['title'] ?? 'Opportunity'}';
    _company  = '${o['company'] ?? ''}';
    _fullName = '${o['fullName'] ?? ''}';
    _email    = '${o['email'] ?? ''}';
    _phone    = '${o['phone'] ?? ''}';
    _address  = '${o['address'] ?? ''}';
    _website  = '${o['website'] ?? ''}';
    _currency = '${o['currency'] ?? 'TND'}';
    _jobTitle = '${o['jobTitle'] ?? ''}';
    _amount   = _toDouble(o['amount']);
  }

  // --------------- MAILTO (sans “+”, avec poste) ---------------
  void _composeEmail() {
    if (_email.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun e-mail de destination.')),
      );
      return;
    }

    final destinataire = _email.trim();
    final societe = _company.isNotEmpty ? _company : "[Société]";
    final nomSalutation = _fullName.isNotEmpty ? _fullName : "Madame/Monsieur";
    final montant = (_amount != null) ? "${_amount!.toStringAsFixed(0)} $_currency" : null;

    final sujet = "Demande d’opportunité — $societe";

    final corps = [
      "Bonjour $nomSalutation,",
      "",
      "Je vous contacte concernant votre poste${_jobTitle.trim().isNotEmpty ? " (${_jobTitle.trim()})" : ""} chez la société $societe.",
      if (montant != null)
        "Nous vous proposons une opportunité au sein de notre société, sur un poste équivalent, avec une rémunération de $montant.",
      "",
      "Si vous êtes intéressé(e), merci de répondre à ce mail afin que nous puissions vous communiquer le nom de notre société et convenir d’une date pour la signature du contrat.",
      "",
      "Cordialement"
    ].join("\n");

    final uri = Uri.parse(
      "mailto:$destinataire"
      "?subject=${Uri.encodeComponent(sujet)}"
      "&body=${Uri.encodeComponent(corps)}",
    );
    _open(uri);
  }
  // -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final oppId = '${widget.opportunity['_id']}';
    final pvd = context.read<OpportunitiesProvider>();

    Widget row(IconData ic, String label, String value, {VoidCallback? onTap}) {
      final v = value.trim();
      final clickable = onTap != null && v.isNotEmpty && v != '—';
      return InkWell(
        onTap: clickable ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(ic, color: Colors.white70, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      v.isEmpty ? '—' : v,
                      style: TextStyle(
                        color: clickable ? const Color(0xFF00E5FF) : Colors.white,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails opportunité'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Changer le statut',
            onSelected: (val) async {
              final toEnum = {
                'new': PipelinePosition.new_,
                'contacted': PipelinePosition.contacted,
                'qualified': PipelinePosition.qualified,
                'won': PipelinePosition.won,
                'lost': PipelinePosition.lost,
              }[val]!;
              final ok = await pvd.patchPosition(oppId, toEnum);
              if (!mounted) return;
              if (ok) {
                setState(() => _pipeline = val);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Statut mis à jour')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Échec mise à jour')),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'new', child: Text('New')),
              PopupMenuItem(value: 'contacted', child: Text('Contacted')),
              PopupMenuItem(value: 'qualified', child: Text('Qualified')),
              PopupMenuItem(value: 'won', child: Text('Won')),
              PopupMenuItem(value: 'lost', child: Text('Lost')),
            ],
            icon: const Icon(Icons.swap_horiz),
          ),
          IconButton(
            tooltip: 'Supprimer',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final yes = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF0E1626),
                  title: const Text('Supprimer ?', style: TextStyle(color: Colors.white)),
                  content: const Text('Cette action est définitive.',
                      style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
                  ],
                ),
              );
              if (yes == true) {
                final ok = await pvd.delete(oppId);
                if (!mounted) return;
                if (ok) {
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Échec suppression')),
                  );
                }
              }
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
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
              _glass(
                Row(
                  children: [
                    _chip(_pipeline.toUpperCase(), _posColor(_pipeline)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          if (_amount != null)
                            Text('${_amount!.toStringAsFixed(0)} $_currency',
                                style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _glass(
                Column(
                  children: [
                    row(Icons.person, 'Nom', _fullName),
                    row(Icons.business, 'Société', _company),
                    row(Icons.badge, 'Fonction', _jobTitle), // poste affiché
                    row(Icons.email, 'Email', _email, onTap: _composeEmail),
                    row(Icons.phone, 'Téléphone', _phone, onTap: () {
                      final tel = _phone.replaceAll(' ', '');
                      if (tel.isNotEmpty) _open(Uri(scheme: 'tel', path: tel));
                    }),
                    row(Icons.location_on, 'Adresse', _address, onTap: () {
                      if (_address.trim().isNotEmpty) {
                        _open(Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(_address)}',
                        ));
                      }
                    }),
                    row(Icons.language, 'Site web', _website, onTap: () {
                      final w = _website.trim();
                      if (w.isNotEmpty) {
                        final url = w.startsWith('http') ? w : 'https://$w';
                        _open(Uri.parse(url));
                      }
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              FilledButton.icon(
                onPressed: _composeEmail,
                icon: const Icon(Icons.email),
                label: const Text('Envoyer un e-mail'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
