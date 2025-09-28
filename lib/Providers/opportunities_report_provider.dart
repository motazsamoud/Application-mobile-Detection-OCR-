import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:version1/config/api.dart';

class OpportunitiesReportProvider extends ChangeNotifier {
  // --- état ---
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _ai;
  String? _csvRaw;
  String? _csvPath;

  DateTime? from;
  DateTime? to;

  // --- getters ---
  bool get loading => _loading;
  String? get error => _error;
  Map<String, dynamic>? get ai => _ai;
  String? get csvPath => _csvPath;

  int get total => ((_ai?['kpis']?['total']) as num?)?.toInt() ?? 0;
  double get sumAmount => ((_ai?['kpis']?['sumAmount']) as num?)?.toDouble() ?? 0;
  double get winRate => ((_ai?['kpis']?['winRate']) as num?)?.toDouble() ?? 0;

  List<dynamic> get actions =>
      (_ai?['actions'] is List) ? (_ai!['actions'] as List) : const [];
  List<dynamic> get risks =>
      (_ai?['risks'] is List) ? (_ai!['risks'] as List) : const [];
  List<dynamic> get insightsByStage =>
      (_ai?['insightsByStage'] is List) ? (_ai!['insightsByStage'] as List) : const [];
  List<dynamic> get topCompanies =>
      (_ai?['topCompanies'] is List) ? (_ai!['topCompanies'] as List) : const [];
  String get summary => (_ai?['summary'] as String?) ?? '';

  void setRange(DateTime? f, DateTime? t) {
    from = f;
    to = t;
    notifyListeners();
  }

  // --- appel API ---
  Future<void> run() async {
    _loading = true;
    _error = null;
    _ai = null;
    _csvRaw = null;
    _csvPath = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        if (from != null) 'from': from!.toIso8601String(),
        if (to != null) 'to': to!.toIso8601String(),
        'limit': 300,
      };

      final resp = await http.post(
        Uri.parse('$API_BASE_URL/ai/opportunities/insights'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }

      final decoded = jsonDecode(resp.body);
      Map<String, dynamic>? aiObj;

      final dynamic aiRaw = (decoded is Map) ? decoded['ai'] : null;
      if (aiRaw is Map) {
        aiObj = aiRaw.cast<String, dynamic>();
      } else if (aiRaw is String) {
        try {
          aiObj = jsonDecode(aiRaw) as Map<String, dynamic>;
        } catch (_) {}
      }

      _ai = aiObj;
      _csvRaw = (decoded is Map && decoded['csv'] is String) ? decoded['csv'] as String : null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // --- export CSV ---
  Future<String?> exportCsv({bool full = true}) async {
    try {
      // 🔑 Vérifier permission stockage
      if (Platform.isAndroid) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          _error = "Permission stockage refusée";
          notifyListeners();
          return null;
        }
      }

      // 📂 Dossier cible
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory("/storage/emulated/0/Download"); // ✅ visible par l’utilisateur
      } else {
        dir = await getDownloadsDirectory(); // iOS/macOS
      }

      if (dir == null || !(await dir.exists())) {
        _error = "Impossible de trouver le dossier de téléchargement";
        notifyListeners();
        return null;
      }

      // Nom de fichier
      final filename = full
          ? "opportunities_full_report_${DateTime.now().millisecondsSinceEpoch}.csv"
          : "opportunities_only_${DateTime.now().millisecondsSinceEpoch}.csv";
      final path = p.join(dir.path, filename);

      // Contenu CSV
      String csvData;
      if (!full) {
        if (_csvRaw == null || _csvRaw!.isEmpty) return null;
        csvData = _csvRaw!;
      } else {
        final rows = <List<dynamic>>[];

        rows.add(['Reporting & Exports (Gemini)']);
        rows.add(['Généré le', DateTime.now().toIso8601String()]);
        rows.add(['Période', from?.toIso8601String() ?? '', to?.toIso8601String() ?? '']);
        rows.add([]);

        rows.add(['KPIs']);
        rows.add(['Total opportunités', total]);
        rows.add(['Montant total', sumAmount]);
        rows.add(['Win rate', '${(winRate * 100).toStringAsFixed(1)} %']);
        rows.add([]);

        if (summary.isNotEmpty) {
          rows.add(['Résumé']);
          for (final line in summary.split('\n')) {
            rows.add([line]);
          }
          rows.add([]);
        }

        if (insightsByStage.isNotEmpty) {
          rows.add(['Insights par étape']);
          rows.add(['stage', 'note']);
          for (final e in insightsByStage) {
            rows.add(['${e['stage'] ?? ''}', '${e['note'] ?? ''}']);
          }
          rows.add([]);
        }

        if (topCompanies.isNotEmpty) {
          rows.add(['Top sociétés']);
          rows.add(['company', 'count']);
          for (final e in topCompanies) {
            rows.add(['${e['company'] ?? ''}', (e['count'] as num?)?.toInt() ?? 0]);
          }
          rows.add([]);
        }

        if (actions.isNotEmpty) {
          rows.add(['Actions recommandées']);
          for (final a in actions) rows.add(['$a']);
          rows.add([]);
        }

        if (risks.isNotEmpty) {
          rows.add(['Risques']);
          for (final r in risks) rows.add(['$r']);
          rows.add([]);
        }

        if (_csvRaw != null && _csvRaw!.isNotEmpty) {
          rows.add(['Opportunités']);
          final opp = const CsvToListConverter(eol: '\n').convert(_csvRaw!);
          rows.addAll(opp);
        }

        csvData = const ListToCsvConverter().convert(rows);
      }

      // ✍️ Écriture dans le fichier
      final file = File(path);
      await file.writeAsString(csvData, flush: true);

      _csvPath = path;
      notifyListeners();
      return path;
    } catch (e) {
      _error = 'Export CSV échoué: $e';
      notifyListeners();
      return null;
    }
  }
}
