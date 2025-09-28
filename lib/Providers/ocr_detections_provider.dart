import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:version1/config/api.dart';

/// Charge les détections OCR et fournit un filtrage:
/// all | draft | confirmed | rejected
class OcrDetectionsProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  String? _error;
  String _filter = 'all'; // 'all' | 'draft' | 'confirmed' | 'rejected'

  List<Map<String, dynamic>> get rawItems => _items;

  List<Map<String, dynamic>> get items {
    if (_filter == 'all') return _items;
    return _items.where((e) {
      final s = (e['status'] ?? e['detectionStatus'] ?? '').toString();
      return s == _filter;
    }).toList();
  }

  bool get loading => _loading;
  String? get error => _error;
  String get filter => _filter;

  /// http://<ip>:3000/uploads/<fileName>
  String imageUrlFor(String? fileName) {
    if (fileName == null || fileName.isEmpty) return '';
    return '$API_BASE_URL/uploads/${Uri.encodeComponent(fileName)}';
  }

  Future<void> fetch({int limit = 100}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final resp = await http.get(
        Uri.parse('$API_BASE_URL/ocr/detections?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      );
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }
      final data = jsonDecode(resp.body);

      final list = (data is List) ? data.cast<Map>() : <Map>[];
      _items = list
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          // tri récent → ancien
          .toList()
        ..sort((a, b) {
          final ad = DateTime.tryParse('${a['createdAt'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = DateTime.tryParse('${b['createdAt'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false; notifyListeners();
    }
  }

  void setFilter(String f) { _filter = f; notifyListeners(); }
  Future<void> refresh() => fetch();
}
