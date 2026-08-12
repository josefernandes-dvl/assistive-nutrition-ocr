import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../models/enriched_analysis.dart';

/// Cliente HTTP do backend NutriScan.
///
/// Free tier do Render adormece o servidor após ~15min sem requests. A primeira
/// chamada ("cold start") pode levar 20-30s. Esta classe trata isso com:
///   - Timeouts generosos (até 40s na análise principal).
///   - Retry automático em timeout/503/504 (1 tentativa extra) — geralmente a
///     segunda chamada já encontra o servidor acordado.
///   - `warmUp()` chamado no startup para acordar o backend cedo, antes do
///     usuário tentar escanear.
class ApiService {
  static String get baseUrl => ApiConfig.baseUrl;

  // === Health / Warm-up ===

  /// Chamada leve para acordar o servidor (cold start do Render free).
  /// Falha silenciosamente — só serve para iniciar o boot do backend.
  static Future<void> warmUp() async {
    try {
      await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 40));
    } catch (_) {/* ignore — pode ser offline */}
  }

  /// Verifica se o backend está acessível (timeout curto, sem retry).
  static Future<bool> isBackendAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // === Análise de ingredientes (Open Food Facts + correlação) ===

  /// Analisa ingredientes (ou barcode) contra o perfil do usuário.
  /// Tenta 2 vezes em caso de timeout/5xx — bom contra cold start do Render.
  static Future<EnrichedAnalysis> analyzeIngredients({
    required List<String> ingredients,
    required List<String> disorders,
    List<String> customAllergens = const [],
    String? barcode,
    Duration timeout = const Duration(seconds: 40),
  }) async {
    final body = json.encode({
      'ingredients': ingredients,
      'disorders': disorders,
      'customAllergens': customAllergens,
      if (barcode != null) 'barcode': barcode,
    });

    final response = await _retryingPost(
      Uri.parse('$baseUrl/ocr/analyze'),
      body: body,
      timeout: timeout,
    );

    if (response.statusCode == 200) {
      return EnrichedAnalysis.fromJson(
        json.decode(response.body) as Map<String, dynamic>,
      );
    }
    throw _friendlyError(response.statusCode, response.body);
  }

  /// Busca informações do produto pelo código de barras.
  /// Timeout generoso + retry para acomodar cold start.
  static Future<ProductInfo?> getProductByBarcode(String barcode) async {
    try {
      final response = await _retryingGet(
        Uri.parse('$baseUrl/products/barcode/$barcode'),
        timeout: const Duration(seconds: 30),
      );
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

  // ============================================================
  // Helpers internos
  // ============================================================

  /// POST com 1 retry em timeout / 503 / 504.
  /// Boa para sobrepor o cold start do Render free.
  static Future<http.Response> _retryingPost(
    Uri uri, {
    required String body,
    required Duration timeout,
  }) async {
    return _withRetry(() async {
      return http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(timeout);
    });
  }

  static Future<http.Response> _retryingGet(
    Uri uri, {
    required Duration timeout,
  }) async {
    return _withRetry(() async {
      return http.get(uri).timeout(timeout);
    });
  }

  static Future<http.Response> _withRetry(
    Future<http.Response> Function() request, {
    int maxAttempts = 2,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await request();
        // Códigos típicos de servidor adormecendo ou reiniciando.
        if (response.statusCode == 503 || response.statusCode == 504) {
          if (attempt < maxAttempts) {
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
        }
        return response;
      } on TimeoutException catch (e) {
        lastError = e;
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        throw _friendlyTimeoutException();
      } on SocketException catch (e) {
        lastError = e;
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        throw _friendlyOfflineException();
      }
    }
    throw Exception('Falha na requisição: $lastError');
  }

  static Exception _friendlyError(int status, String body) {
    if (status >= 500) {
      return Exception(
        'O servidor está com problemas (HTTP $status). '
        'Tente novamente em instantes.',
      );
    }
    if (status >= 400) {
      return Exception('Requisição rejeitada pelo servidor (HTTP $status).');
    }
    return Exception('Erro inesperado: HTTP $status — $body');
  }

  static Exception _friendlyTimeoutException() {
    return Exception(
      'O servidor demorou demais para responder. '
      'Verifique sua conexão ou tente novamente — pode ser que o serviço '
      'esteja acordando do modo econômico (até 30s).',
    );
  }

  static Exception _friendlyOfflineException() {
    return Exception(
      'Sem conexão com o servidor. '
      'A análise local continua funcionando — apenas os dados extras '
      '(Nutri-Score, alérgenos oficiais) não aparecerão.',
    );
  }
}
