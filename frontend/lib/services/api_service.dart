import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  // Change to your backend URL as needed
  static const String _base = 'http://10.136.91.214:8000';

  // ── Weather ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getWeather(String district) async {
    final uri = Uri.parse('$_base/weather/${Uri.encodeComponent(district)}');
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── District defaults ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getDistrictDefaults(String district) async {
    final uri = Uri.parse(
        '$_base/district-defaults/${Uri.encodeComponent(district)}');
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Soil image analysis ────────────────────────────────────────────
  Future<Map<String, dynamic>> analyzeSoilImage(File imageFile) async {
    final uri     = Uri.parse('$_base/analyze-soil-image');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final res      = await http.Response.fromStream(streamed);
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Crop recommendation ────────────────────────────────────────────
  Future<Map<String, dynamic>> recommendCrops({
    required double n,
    required double p,
    required double k,
    required double ph,
    required double temp,
    required double humidity,
    required double rainfall,
    required String season,
    required String irrigation,
    required double landAcres,
    double? budget,
    String? district,
    int topN = 10,
  }) async {
    final uri  = Uri.parse('$_base/recommend-crops');
    final body = <String, dynamic>{
      'N'          : n,
      'P'          : p,
      'K'          : k,
      'ph'         : ph,
      'temperature': temp,
      'humidity'   : humidity,
      'rainfall'   : rainfall,
      'season'     : season,
      'irrigation' : irrigation,
      'land_acres' : landAcres,
      if (budget != null) 'budget'  : budget,
      if (district != null) 'district': district,
      'top_n'    : topN,
    };
    final res = await http
        .post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Mandi prices ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMandiPrices(
      String district,
      String crop,
      ) async {
    final uri = Uri.parse(
        '$_base/mandi-prices/${Uri.encodeComponent(district)}/${Uri.encodeComponent(crop)}');
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Mandi prices — BULK (all crops for a district) ─────────────────
  Future<Map<String, dynamic>> getMandiPricesBulk(String district) async {
    final uri = Uri.parse(
        '$_base/mandi-prices-bulk/${Uri.encodeComponent(district)}');
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Pest alerts ────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getPestAlerts(
      String district,
      String crop, {
        String season = 'Kharif',
      }) async {
    final uri = Uri.parse(
        '$_base/pest-alerts/${Uri.encodeComponent(district)}/${Uri.encodeComponent(crop)}'
            '?season=${Uri.encodeComponent(season)}');
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    _checkStatus(res);
    final decoded = jsonDecode(res.body);
    // Backend returns { alerts: [...], district: ..., crop: ... }
    // or a plain list for older versions — handle both
    if (decoded is Map) {
      return decoded as Map<String, dynamic>;
    }
    return {'alerts': decoded};
  }

  // ── Report sighting ────────────────────────────────────────────────
  Future<Map<String, dynamic>> reportSighting({
    required String district,
    required String crop,
    required String pest,
    required String severity,
  }) async {
    final uri  = Uri.parse('$_base/report-sighting');
    final body = {
      'district': district,
      'crop'    : crop,
      'pest'    : pest,
      'severity': severity,
    };
    final res = await http
        .post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Disease diagnosis ──────────────────────────────────────────────
  Future<Map<String, dynamic>> diagnoseCropImage(
      File imageFile, String cropName) async {
    final uri     = Uri.parse('$_base/diagnose-crop-image');
    final request = http.MultipartRequest('POST', uri)
      ..fields['crop_name'] = cropName
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final res      = await http.Response.fromStream(streamed);
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Mandi prices ───────────────────────────────────────────────────


  // ── Helper ─────────────────────────────────────────────────────────
  void _checkStatus(http.Response res) {
      debugPrint('API ${res.request?.method} ${res.request?.url} → ${res.statusCode}');
      if (res.statusCode < 200 || res.statusCode >= 300) {
      String detail = '';
      try {
        final body = jsonDecode(res.body);
        detail = body['detail'] ?? '';
      } catch (_) {}
      throw Exception('HTTP ${res.statusCode}: ${detail.isNotEmpty ? detail : res.body}');
    }
  }
}