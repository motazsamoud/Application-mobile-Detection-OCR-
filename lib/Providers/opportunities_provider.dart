// lib/providers/opportunities_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:version1/config/api.dart';

enum PipelinePosition { new_, contacted, qualified, won, lost }

PipelinePosition? parsePosition(String? v) {
  switch ((v ?? '').toLowerCase()) {
    case 'new': return PipelinePosition.new_;
    case 'contacted': return PipelinePosition.contacted;
    case 'qualified': return PipelinePosition.qualified;
    case 'won': return PipelinePosition.won;
    case 'lost': return PipelinePosition.lost;
  }
  return null;
}

String positionToString(PipelinePosition p) {
  switch (p) {
    case PipelinePosition.new_: return 'new';
    case PipelinePosition.contacted: return 'contacted';
    case PipelinePosition.qualified: return 'qualified';
    case PipelinePosition.won: return 'won';
    case PipelinePosition.lost: return 'lost';
  }
}

// ---------------- helpers sûrs ----------------
int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim().replaceAll(',', '.'));
  return null;
}
// ----------------------------------------------

class OpportunitiesProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  String? _error;

  PipelinePosition? _filterPos;
  String _search = '';
  int _page = 1;
  int _limit = 20;
  int _total = 0;

  List<Map<String, dynamic>> get items => _items;
  bool get loading => _loading;
  String? get error => _error;
  PipelinePosition? get filterPos => _filterPos;
  String get search => _search;
  int get page => _page;
  int get limit => _limit;
  int get total => _total;

  void setFilter({PipelinePosition? position, String? search}) {
    _filterPos = position;
    _search = search ?? _search;
    _page = 1;
    fetch();
  }

  void setSearch(String v) {
    _search = v.trim();
    _page = 1;
    fetch();
  }

  Future<void> fetch() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final qp = <String, String>{
        'page': '$_page',
        'limit': '$_limit',
      };
      if (_filterPos != null) qp['position'] = positionToString(_filterPos!);
      if (_search.isNotEmpty) qp['search'] = _search;

      final uri = Uri.parse('$API_BASE_URL/opportunities').replace(queryParameters: qp);
      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }

      final data = jsonDecode(resp.body);
      final list = (data is Map && data['data'] is List) ? (data['data'] as List) : const [];
      _items = list
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // ✅ parse safe (si backend renvoie "1", "20" en string)
      _total = _toInt((data as Map)['total']) ?? _items.length;
      _page  = _toInt(data['page']) ?? 1;
      _limit = _toInt(data['limit']) ?? 20;

      // (optionnel) normaliser amount côté front pour éviter d'autres casts
      for (final m in _items) {
        final a = _toDouble(m['amount']);
        if (a != null) m['amount'] = a; // on stocke en double
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> createFromOcr({
    required String ocrDetectionId,
    String? title,
    double? amount,
    String? currency,
  }) async {
    try {
      final body = {
        'ocrDetectionId': ocrDetectionId,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        if (amount != null) 'amount': amount,
        if (currency != null && currency.trim().isNotEmpty) 'currency': currency.trim(),
      };
      final resp = await http.post(
        Uri.parse('$API_BASE_URL/opportunities'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }
      final created = jsonDecode(resp.body) as Map<String, dynamic>;
      await fetch();
      return created;
    } catch (e) {
      _error = 'Création échouée: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> patchPosition(String id, PipelinePosition pos) async {
    try {
      final resp = await http.patch(
        Uri.parse('$API_BASE_URL/opportunities/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'position': positionToString(pos)}),
      );
      if (resp.statusCode < 200 || resp.statusCode >= 300) return false;
      await fetch();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      final resp = await http.delete(Uri.parse('$API_BASE_URL/opportunities/$id'));
      if (resp.statusCode < 200 || resp.statusCode >= 300) return false;
      _items.removeWhere((e) => '${e['_id']}' == id);
      _total = _total > 0 ? _total - 1 : 0;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
