import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../models/enriched_analysis.dart';
import '../models/scan_result.dart';
import '../models/user_profile.dart';

class ApiService {
  static String get baseUrl => ApiConfig.baseUrl;

  // === Análise de ingredientes (Open Food Facts + correlação) ===

  /// Analisa uma lista de ingredientes contra o perfil do usuário,
  /// opcionalmente passando um código de barras para enriquecer com
  /// dados do Open Food Facts.
  static Future<EnrichedAnalysis> analyzeIngredients({
    required List<String> ingredients,
    required List<String> disorders,
    List<String> customAllergens = const [],
    String? barcode,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/ocr/analyze'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'ingredients': ingredients,
            'disorders': disorders,
            'customAllergens': customAllergens,
            if (barcode != null) 'barcode': barcode,
          }),
        )
        .timeout(timeout);

    if (response.statusCode == 200) {
      return EnrichedAnalysis.fromJson(
        json.decode(response.body) as Map<String, dynamic>,
      );
    }
    throw Exception('Erro ao analisar (${response.statusCode}): ${response.body}');
  }

  /// Busca informações do produto pelo código de barras via Open Food Facts (proxy backend).
  static Future<ProductInfo?> getProductByBarcode(String barcode) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/products/barcode/$barcode'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return ProductInfo.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Falha silenciosa — modo offline
    }
    return null;
  }

  // === Scan Results ===

  static Future<ScanResult> saveScanResult(ScanResult result) async {
    final response = await http.post(
      Uri.parse('$baseUrl/scans'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(result.toJson()),
    );

    if (response.statusCode == 201) {
      return ScanResult.fromJson(
        json.decode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Erro ao salvar scan: ${response.statusCode}');
    }
  }

  static Future<List<ScanResult>> getScanHistory() async {
    final response = await http.get(Uri.parse('$baseUrl/scans'));

    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List<dynamic>;
      return list
          .map((e) => ScanResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Erro ao buscar histórico: ${response.statusCode}');
    }
  }

  // === User Profile ===

  static Future<UserProfile> saveProfile(UserProfile profile) async {
    final response = await http.post(
      Uri.parse('$baseUrl/profiles'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(profile.toJson()),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return UserProfile.fromJson(
        json.decode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception('Erro ao salvar perfil: ${response.statusCode}');
    }
  }

  static Future<UserProfile?> getProfile() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/profiles/current'));

      if (response.statusCode == 200) {
        return UserProfile.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Backend offline - funciona no modo local
    }
    return null;
  }

  /// Verifica se o backend está acessível
  static Future<bool> isBackendAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}