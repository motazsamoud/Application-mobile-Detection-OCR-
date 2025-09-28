import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';

import 'package:version1/Providers/opportunities_report_provider.dart';

class OpportunitiesReportPage extends StatefulWidget {
  const OpportunitiesReportPage({super.key});

  @override
  State<OpportunitiesReportPage> createState() => _OpportunitiesReportPageState();
}

class _OpportunitiesReportPageState extends State<OpportunitiesReportPage> {
  final df = DateFormat('dd/MM/yyyy');

  Future<void> _pickDate(BuildContext context, bool isFrom) async {
    final p = context.read<OpportunitiesReportProvider>();
    final initial = isFrom
        ? (p.from ?? DateTime.now().subtract(const Duration(days: 30)))
        : (p.to ?? DateTime.now());
    final first = DateTime(2020);
    final last = DateTime.now().add(const Duration(days: 1));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: isFrom ? 'Date de début' : 'Date de fin',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00E5FF),
            onPrimary: Color(0xFF001B2E),
            surface: Color(0xFF0E1626),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      final from = isFrom ? picked : p.from;
      final to = isFrom ? p.to : picked;
      p.setRange(from, to);
    }
  }

  Widget _glass(Widget child) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withOpacity(0.18),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: child,
      );

  Widget _kpi(String label, String value, {IconData? icon}) {
    return Expanded(
      child: _glass(
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: const Color(0xFF00E5FF)),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Aperçu interne du CSV (tableau des opportunités uniquement)
  Future<void> _previewCsv(String path) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CsvPreviewPage(path: path)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OpportunitiesReportProvider>();
    final fromText = p.from != null ? df.format(p.from!) : '—';
    final toText   = p.to   != null ? df.format(p.to!)   : '—';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporting & Exports (Gemini)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0F1F), Color(0xFF001B2E)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _glass(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Période',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(context, true),
                            icon: const Icon(Icons.date_range),
                            label: Text('De: $fromText'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(context, false),
                            icon: const Icon(Icons.event),
                            label: Text('À: $toText'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            final now = DateTime.now();
                            p.setRange(now.subtract(const Duration(days: 7)), now);
                          },
                          child: const Text('7 jours'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            final now = DateTime.now();
                            p.setRange(now.subtract(const Duration(days: 30)), now);
                          },
                          child: const Text('30 jours'),
                        ),
                        OutlinedButton(
                          onPressed: () => p.setRange(null, null),
                          child: const Text('Tout'),
                        ),
                        FilledButton.icon(
                          onPressed: p.loading ? null : p.run,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Générer avec Gemini'),
                        ),

                        // 👉 Bouton 1 : aperçu (tableau simple)
                        FilledButton.icon(
                          onPressed: p.loading ? null : () async {
                            final path = await p.exportCsv(full: false); // opportunités seules
                            if (!context.mounted) return;
                            if (path == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Export opportunités échoué')),
                              );
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('CSV opportunités: $path')),
                            );
                            await _previewCsv(path);
                          },
                          icon: const Icon(Icons.table_view),
                          label: const Text('Aperçu opportunités'),
                        ),

                        // 👉 Bouton 2 : rapport complet (sections + tableau)
                        IconButton.filled(
                          tooltip: 'Exporter rapport complet (CSV)',
                          color: const Color(0xFF001B2E),
                          icon: const Icon(Icons.download),
                          onPressed: p.loading ? null : () async {
                            final path = await p.exportCsv(full: true);
                            if (!context.mounted) return;

                            if (path == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Export CSV IA échoué')),
                              );
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Rapport complet enregistré: $path')),
                            );
                            // pas d’aperçu ici: c’est un CSV multi-sections
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              if (p.loading) const LinearProgressIndicator(minHeight: 6),

              if (!p.loading && p.error != null) ...[
                _glass(Text(p.error!, style: const TextStyle(color: Colors.redAccent))),
                const SizedBox(height: 12),
              ],

              if (!p.loading && p.ai != null) ...[
                Row(
                  children: [
                    _kpi('Total opportunités', '${p.total}', icon: Icons.all_inbox),
                    const SizedBox(width: 10),
                    _kpi('Montant total', '${p.sumAmount.toStringAsFixed(0)}',
                        icon: Icons.monetization_on_outlined),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _kpi('Win rate', '${(p.winRate * 100).toStringAsFixed(1)} %',
                        icon: Icons.emoji_events_outlined),
                  ],
                ),
                const SizedBox(height: 12),

                if (p.summary.isNotEmpty)
                  _glass(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Résumé',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(p.summary, style: const TextStyle(color: Colors.white70)),
                    ],
                  )),

                const SizedBox(height: 12),

                if (p.insightsByStage.isNotEmpty)
                  _glass(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Insights par étape',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...p.insightsByStage.map((e) {
                        final stage = '${e['stage'] ?? '-'}';
                        final note  = '${e['note'] ?? ''}';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 6, right: 8),
                                width: 6, height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00E5FF), shape: BoxShape.circle),
                              ),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(children: [
                                    TextSpan(text: '$stage: ',
                                        style: const TextStyle(
                                          color: Colors.white, fontWeight: FontWeight.w600)),
                                    TextSpan(text: note,
                                        style: const TextStyle(color: Colors.white70)),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  )),

                const SizedBox(height: 12),

                if (p.topCompanies.isNotEmpty)
                  _glass(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Top sociétés',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...p.topCompanies.map((e) {
                        final company = '${e['company'] ?? '-'}';
                        final count   = (e['count'] as num?)?.toInt() ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('• $company — $count opportunité(s)',
                              style: const TextStyle(color: Colors.white70)),
                        );
                      }),
                    ],
                  )),

                const SizedBox(height: 12),

                if (p.actions.isNotEmpty)
                  _glass(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Actions recommandées',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: p.actions.take(10).map<Widget>((a) => Chip(
                          label: Text('$a'),
                          backgroundColor: Colors.white12,
                          labelStyle: const TextStyle(color: Colors.white),
                          shape: const StadiumBorder(
                            side: BorderSide(color: Colors.white24)),
                        )).toList(),
                      ),
                    ],
                  )),

                const SizedBox(height: 12),

                if (p.risks.isNotEmpty)
                  _glass(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Risques',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...p.risks.take(10).map<Widget>((r) =>
                        Text('• $r', style: const TextStyle(color: Colors.white70))),
                    ],
                  )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// =================== APERÇU CSV – UX VERTICALE PRO ======================
class CsvPreviewPage extends StatefulWidget {
  final String path;
  const CsvPreviewPage({super.key, required this.path});

  @override
  State<CsvPreviewPage> createState() => _CsvPreviewPageState();
}

class _CsvPreviewPageState extends State<CsvPreviewPage> {
  bool loading = true;
  String? error;

  late List<String> headers;
  List<Map<String, String>> rows = [];

  // UI state
  String query = '';
  String? sortCol;
  bool sortAsc = true;
  int page = 0;
  static const int pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await File(widget.path).readAsString();
      final parsed = CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
        convertEmptyTo: '',
        allowInvalid: true,
      ).convert(raw);

      if (parsed.isEmpty) {
        setState(() {
          headers = [];
          rows = [];
          loading = false;
        });
        return;
      }

      headers = parsed.first.map((e) => '$e').toList();
      rows = parsed.skip(1).map<Map<String, String>>((r) {
        final map = <String, String>{};
        for (var i = 0; i < headers.length; i++) {
          map[headers[i]] = i < r.length ? '${r[i]}' : '';
        }
        return map;
      }).toList();

      sortCol ??= headers.first;
      setState(() => loading = false);
    } catch (e) {
      setState(() {
        error = '$e';
        loading = false;
      });
    }
  }

  List<Map<String, String>> get _filteredSorted {
    final q = query.trim().toLowerCase();
    var data = q.isEmpty
        ? List<Map<String, String>>.from(rows)
        : rows.where((row) => row.values.any((v) => v.toLowerCase().contains(q))).toList();

    final col = sortCol;
    if (col != null) {
      data.sort((a, b) {
        final av = (a[col] ?? '').toLowerCase();
        final bv = (b[col] ?? '').toLowerCase();
        final cmp = av.compareTo(bv);
        return sortAsc ? cmp : -cmp;
      });
    }
    return data;
  }

  String _guessTitle(Map<String, String> row) {
    for (final k in ['title','company','fullName','name','id']) {
      if (row.containsKey(k) && row[k]!.trim().isNotEmpty) return row[k]!;
    }
    return row.values.firstWhere((v) => v.trim().isNotEmpty, orElse: () => '(vide)');
  }

  String _guessSubtitle(Map<String, String> row) {
    for (final k in ['email','position','amount','createdAt']) {
      if (row.containsKey(k) && row[k]!.trim().isNotEmpty) return row[k]!;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final filename = widget.path.split('/').last;

    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Aperçu CSV ($filename)')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Aperçu CSV ($filename)')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erreur de lecture:\n$error', textAlign: TextAlign.center),
          ),
        ),
      );
    }
    if (rows.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Aperçu CSV ($filename)')),
        body: const Center(child: Text('Fichier CSV vide')),
      );
    }

    final data = _filteredSorted;
    final totalPages = math.max(1, (data.length / pageSize).ceil());
    if (page >= totalPages) page = totalPages - 1;
    final pageItems = data.skip(page * pageSize).take(pageSize).toList();

    return Scaffold(
      appBar: AppBar(title: Text('Aperçu CSV ($filename)')),
      body: Column(
        children: [
          // barre recherche + tri
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Rechercher… (toutes colonnes)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() {
                      query = v; page = 0;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: sortCol,
                    items: headers.map((h) => DropdownMenuItem(
                      value: h, child: Text(h, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setState(() { sortCol = v; }),
                  ),
                ),
                IconButton(
                  tooltip: sortAsc ? 'Tri croissant' : 'Tri décroissant',
                  onPressed: () => setState(() => sortAsc = !sortAsc),
                  icon: Icon(sortAsc ? Icons.arrow_downward : Icons.arrow_upward),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: pageItems.length,
              itemBuilder: (context, i) {
                final row = pageItems[i];
                final title = _guessTitle(row);
                final subtitle = _guessSubtitle(row);

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title,
                                      style: const TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.w700)),
                                  if (subtitle.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(subtitle,
                                          style: TextStyle(
                                              color: Colors.grey.shade700, fontSize: 12)),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('#${i + 1 + page*pageSize}',
                                  style: TextStyle(color: Colors.blueGrey.shade700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10, runSpacing: 6,
                          children: headers.map((h) {
                            final v = row[h] ?? '';
                            return _kvPill(h, v);
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Row(
              children: [
                Text('Lignes: ${data.length}  •  Page ${page + 1}/$totalPages'),
                const Spacer(),
                IconButton(
                  onPressed: page > 0 ? () => setState(() => page--) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  onPressed: page + 1 < totalPages ? () => setState(() => page++) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kvPill(String key, String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 260),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
