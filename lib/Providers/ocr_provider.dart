import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import 'package:version1/config/api.dart';

class OcrProvider extends ChangeNotifier {
  final ImagePicker _picker = ImagePicker();

  XFile? _selected;
  bool _uploading = false;
  String? _error;
  Map<String, dynamic>? _result; // JSON renvoyé par /ocr/scan

  // Getters
  XFile? get selected => _selected;
  bool get uploading => _uploading;
  String? get error => _error;
  Map<String, dynamic>? get result => _result;

  // ------------- Sélection d'image ----------------
  Future<void> pickFromCamera() async {
    _error = null;
    try {
      _selected = await _picker.pickImage(source: ImageSource.camera, imageQuality: 95);
      notifyListeners();
    } catch (e) {
      _error = 'Erreur caméra: $e';
      notifyListeners();
    }
  }

  Future<void> pickFromGallery() async {
    _error = null;
    try {
      _selected = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
      notifyListeners();
    } catch (e) {
      _error = 'Erreur galerie: $e';
      notifyListeners();
    }
  }

  void clearSelected() {
    _selected = null;
    notifyListeners();
  }

  void clearResult() {
    _result = null;
    notifyListeners();
  }

  // ------------- Upload vers backend ----------------
 // lib/providers/ocr_provider.dart  -> remplace uniquement cette méthode
Future<Map<String, dynamic>?> uploadToBackend() async {
  if (_selected == null) {
    _error = 'Aucune image sélectionnée';
    notifyListeners();
    return null;
  }
  _uploading = true;
  _error = null;
  notifyListeners();

  try {
    final uri = Uri.parse('$API_BASE_URL/ocr/scan?source=mobile');
    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        _selected!.path,
        contentType: MediaType('image', 'jpeg'),
      ));

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    // ✅ Considère tout 2xx comme succès (200, 201, 204…)
    final ok = resp.statusCode >= 200 && resp.statusCode < 300;
    if (!ok) {
      _error = 'Erreur OCR ${resp.statusCode}';
      _result = null;
      notifyListeners();
      return null;
    }

    // ✅ Parse JSON en toute sécurité
    dynamic decoded;
    try {
      decoded = jsonDecode(resp.body);
    } catch (_) {
      decoded = null;
    }

    if (decoded is Map<String, dynamic>) {
      _result = decoded;
    } else {
      // si le backend renvoie du texte mais devrait être JSON
      _result = {'raw': resp.body};
    }

    notifyListeners();
    return _result;
  } catch (e) {
    _error = 'Erreur réseau: $e';
    _result = null;
    notifyListeners();
    return null;
  } finally {
    _uploading = false;
    notifyListeners();
  }
}

}
