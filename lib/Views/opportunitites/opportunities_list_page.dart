// lib/Views/opportunities/opportunities_list_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:version1/Providers/opportunities_report_provider.dart';
import 'package:version1/Views/opportunitites/opportunities_report_page.dart';
import 'package:version1/Views/opportunitites/opportunity_detail_page.dart';

import 'package:version1/providers/opportunities_provider.dart';

// (optionnel – seulement si tu as ajouté le reporting IA)

class OpportunitiesListPage extends StatefulWidget {
  const OpportunitiesListPage({super.key});

  @override
  State<OpportunitiesListPage> createState() => _OpportunitiesListPageState();
}

class _OpportunitiesListPageState extends State<OpportunitiesListPage> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // charge la liste au premier affichage
    Future.microtask(() => context.read<OpportunitiesProvider>().fetch());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OpportunitiesProvider>();

    Widget chip(PipelinePosition? pos, String label) {
      final sel = p.filterPos == pos || (pos == null && p.filterPos == null);
      return ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: sel ? const Color(0xFF001B2E) : Colors.white,
          ),
        ),
        selected: sel,
        selectedColor: const Color(0xFF00E5FF),
        backgroundColor: Colors.white12,
        onSelected: (_) => p.setFilter(position: pos),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Opportunités'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // (optionnel) Bouton Reporting & Exports (Gemini)
          IconButton(
            tooltip: 'Reporting & Exports',
            icon: const Icon(Icons.insights),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider(
                    create: (_) => OpportunitiesReportProvider(),
                    child: const OpportunitiesReportPage(),
                  ),
                ),
              );
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
          child: Column(
            children: [
              // Filtres + recherche
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        chip(null, 'Toutes'),
                        chip(PipelinePosition.new_, 'Nouvelles'),
                        chip(PipelinePosition.contacted, 'Contactées'),
                        chip(PipelinePosition.qualified, 'Qualifiées'),
                        chip(PipelinePosition.won, 'Gagnées'),
                        chip(PipelinePosition.lost, 'Perdues'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onSubmitted: (_) => p.setSearch(_searchCtrl.text),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              prefixIcon:
                                  const Icon(Icons.search, color: Colors.white70),
                              hintText: 'Rechercher (titre / société / nom)...',
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.white12,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: () => p.setSearch(_searchCtrl.text),
                          icon: const Icon(Icons.arrow_forward),
                          color: const Color(0xFF001B2E),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: p.fetch,
                  child: p.loading
                      ? const _LoadingList()
                      : (p.error != null)
                          ? _ErrorBox(message: p.error!, onRetry: p.fetch)
                          : (p.items.isEmpty)
                              ? const _EmptyBox()
                              : ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 20),
                                  itemBuilder: (_, i) {
                                    final opp = p.items[i];
                                    return _OppCard(
                                      data: opp,
                                      onTap: () {
                                        // on réutilise le même provider pour la page détail
                                        final prov =
                                            context.read<OpportunitiesProvider>();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ChangeNotifierProvider.value(
                                              value: prov,
                                              child: OpportunityDetailPage(
                                                opportunity: opp,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemCount: p.items.length,
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Carte d’opportunité (cliquable) + parsing sûr des nombres
// ----------------------------------------------------------------------
class _OppCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onTap;
  const _OppCard({required this.data, this.onTap});

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final t = v.trim();
      if (t.isEmpty) return null;
      return double.tryParse(t.replaceAll(',', '.'));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    Color badge(String pos) {
      switch (pos) {
        case 'won':
          return Colors.greenAccent;
        case 'lost':
          return Colors.redAccent;
        case 'qualified':
          return Colors.lightBlueAccent;
        case 'contacted':
          return Colors.orangeAccent;
        default:
          return Colors.amberAccent; // new
      }
    }

    final title = '${data['title'] ?? 'Opportunity'}';
    final company = '${data['company'] ?? ''}'.trim();
    final pos = '${data['position'] ?? 'new'}';
    final amount = _toDouble(data['amount']);
    final currency = '${data['currency'] ?? 'TND'}';
    final subtitle = [
      if (company.isNotEmpty) company,
      if (amount != null) '${amount.toStringAsFixed(0)} $currency',
    ].join(' • ');

    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badge(pos).withOpacity(0.18),
              border: Border.all(color: badge(pos).withOpacity(0.6)),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Text(
              pos.toUpperCase(),
              style: TextStyle(color: badge(pos), fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white54),
        ],
      ),
    );

    return onTap == null
        ? card
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: card,
          );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
          ),
          child: const LinearProgressIndicator(
            minHeight: 6,
            color: Color(0xFF00E5FF),
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorBox({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: Colors.redAccent),
        const SizedBox(height: 8),
        Text(message, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
      ]),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(top: 40),
        child: Text(
          'Aucune opportunité.',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
