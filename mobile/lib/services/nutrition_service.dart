import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/nutrition.dart';

/// Serviço de consulta nutricional.
///
/// Atualmente integra apenas com Open Food Facts (gratuita, sem chave).
/// A integração com a API de nutrição completa (ingredientes + condições
/// alimentares) será implementada na próxima fase do projeto.
class NutritionService {
  /// Busca informações nutricionais via Open Food Facts a partir do código de barras.
  static Future<NutritionInfo?> fetchFromOpenFoodFacts(String barcode) async {
    try {
      final url = Uri.parse(
        '${AppConstants.openFoodFactsBaseUrl}/product/$barcode.json',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final product = data['product'] as Map<String, dynamic>?;
        if (product == null) return null;

        final nutriments = product['nutriments'] as Map<String, dynamic>?;
        if (nutriments == null) return null;

        return NutritionInfo(
          calories: (nutriments['energy-kcal_100g'] as num?)?.toDouble(),
          totalFat: (nutriments['fat_100g'] as num?)?.toDouble(),
          saturatedFat:
              (nutriments['saturated-fat_100g'] as num?)?.toDouble(),
          carbohydrates:
              (nutriments['carbohydrates_100g'] as num?)?.toDouble(),
          sugars: (nutriments['sugars_100g'] as num?)?.toDouble(),
          fiber: (nutriments['fiber_100g'] as num?)?.toDouble(),
          protein: (nutriments['proteins_100g'] as num?)?.toDouble(),
          sodium: (nutriments['sodium_100g'] as num?)?.toDouble(),
        );
      }
    } catch (_) {
      // Falha silenciosa — modo offline / produto não encontrado
    }
    return null;
  }

  /// Busca produtos por nome no Open Food Facts (catálogo livre).
  static Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    try {
      final url = Uri.parse(
        '${AppConstants.openFoodFactsBaseUrl}/search?search_terms=$query'
        '&search_simple=1&json=1&page_size=5',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final products = data['products'] as List<dynamic>? ?? [];
        return products.cast<Map<String, dynamic>>();
      }
    } catch (_) {
      // Falha silenciosa
    }
    return [];
  }
}
