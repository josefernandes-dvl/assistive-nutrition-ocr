import 'package:flutter/material.dart';
import '../models/scan_result.dart';
import '../models/user_profile.dart';
import '../services/local_store.dart';

/// Estado da aplicação com persistência local.
///
/// Perfil, histórico e consentimento de privacidade sobrevivem ao encerramento
/// do app (RF01, RF14, RNF11). A gravação acontece a cada mutação; o custo é
/// desprezível diante do volume de dados e evita perda em encerramento abrupto.
class AppProvider extends ChangeNotifier {
  final LocalStore _store;

  AppProvider({LocalStore? store}) : _store = store ?? LocalStore();

  static const UserProfile _emptyProfile = UserProfile(
    name: '',
    disorders: [],
  );

  UserProfile _profile = _emptyProfile;
  final List<ScanResult> _scanHistory = [];
  bool _isLoading = false;
  bool _isReady = false;
  DateTime? _privacyConsentAt;
  double _fontScale = 1.0;
  bool _highContrast = false;

  UserProfile get profile => _profile;
  List<ScanResult> get scanHistory => List.unmodifiable(_scanHistory);
  bool get isLoading => _isLoading;
  bool get hasProfile => _profile.name.isNotEmpty;

  /// `true` depois que a leitura do armazenamento local terminou. Antes disso a
  /// UI não deve decidir nada — senão o app pisca a tela de consentimento para
  /// quem já consentiu.
  bool get isReady => _isReady;

  /// Aviso de privacidade aceito nesta instalação (RNF11).
  bool get hasPrivacyConsent => _privacyConsentAt != null;
  DateTime? get privacyConsentAt => _privacyConsentAt;

  /// Escala de fonte interna do app (RF18), adicional ao ajuste do sistema
  /// operacional. 1.0 = padrão; persistida entre sessões.
  double get fontScale => _fontScale;

  /// Tema de alto contraste ativado pelo usuário (RF20); persistido.
  bool get highContrast => _highContrast;

  // ==========================================================================
  // Ciclo de vida
  // ==========================================================================

  /// Carrega o estado gravado. Idempotente e tolerante a falha: qualquer erro
  /// resulta em estado vazio, nunca em app travado no boot.
  Future<void> load() async {
    final data = await _store.read();

    if (data != null) {
      final rawProfile = data['profile'];
      if (rawProfile is Map<String, dynamic>) {
        _profile = UserProfile.fromJson(rawProfile);
      }

      final rawHistory = data['history'];
      if (rawHistory is List) {
        _scanHistory
          ..clear()
          ..addAll(
            rawHistory
                .whereType<Map<String, dynamic>>()
                .map(ScanResult.fromJson),
          );
        _sortHistory();
      }

      final consent = data['privacy_consent_at'];
      if (consent is String) {
        _privacyConsentAt = DateTime.tryParse(consent);
      }

      final scale = data['font_scale'];
      if (scale is num) _fontScale = scale.toDouble().clamp(1.0, 2.0);

      final hc = data['high_contrast'];
      if (hc is bool) _highContrast = hc;
    }

    _isReady = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    await _store.write({
      'privacy_consent_at': _privacyConsentAt?.toIso8601String(),
      'profile': _profile.toJson(),
      'history': _scanHistory.map((s) => s.toJson()).toList(),
      'font_scale': _fontScale,
      'high_contrast': _highContrast,
    });
  }

  // ==========================================================================
  // Acessibilidade (RF18 / RF20)
  // ==========================================================================

  Future<void> setFontScale(double value) async {
    _fontScale = value.clamp(1.0, 2.0);
    notifyListeners();
    await _persist();
  }

  Future<void> setHighContrast(bool value) async {
    _highContrast = value;
    notifyListeners();
    await _persist();
  }

  // ==========================================================================
  // Consentimento (RNF11)
  // ==========================================================================

  Future<void> acceptPrivacyNotice({DateTime? at}) async {
    _privacyConsentAt = at ?? DateTime.now();
    notifyListeners();
    await _persist();
  }

  // ==========================================================================
  // Perfil
  // ==========================================================================

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> updateProfile(UserProfile profile) async {
    _profile = profile;
    notifyListeners();
    await _persist();
  }

  Future<void> addDisorder(String disorder) async {
    if (_profile.disorders.contains(disorder)) return;
    _profile = _profile.copyWith(
      disorders: [..._profile.disorders, disorder],
    );
    notifyListeners();
    await _persist();
  }

  Future<void> removeDisorder(String disorder) async {
    _profile = _profile.copyWith(
      disorders: _profile.disorders.where((d) => d != disorder).toList(),
    );
    notifyListeners();
    await _persist();
  }

  /// Exclusão apenas do perfil, preservando o histórico (RF03).
  Future<void> deleteProfile() async {
    _profile = _emptyProfile;
    notifyListeners();
    await _persist();
  }

  // ==========================================================================
  // Histórico
  // ==========================================================================

  Future<void> addScanResult(ScanResult result) async {
    _scanHistory.insert(0, result);
    _sortHistory();
    if (_scanHistory.length > LocalStore.maxHistoryEntries) {
      _scanHistory.removeRange(
        LocalStore.maxHistoryEntries,
        _scanHistory.length,
      );
    }
    notifyListeners();
    await _persist();
  }

  /// Exclusão individual de uma análise (RF17).
  Future<void> removeScanResult(ScanResult result) async {
    _scanHistory.remove(result);
    notifyListeners();
    await _persist();
  }

  Future<void> clearHistory() async {
    _scanHistory.clear();
    notifyListeners();
    await _persist();
  }

  /// Ordena por data decrescente (RF15) — vale tanto para o que acabou de ser
  /// inserido quanto para o que foi lido do disco.
  void _sortHistory() {
    _scanHistory.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
  }

  // ==========================================================================
  // Direito de eliminação (RNF14 / LGPD Art. 18, VI)
  // ==========================================================================

  /// Apaga perfil, histórico e consentimento — em memória e em disco — numa
  /// única ação. Depois disto o app volta ao estado de primeira execução.
  Future<void> eraseAllData() async {
    _profile = _emptyProfile;
    _scanHistory.clear();
    _privacyConsentAt = null;
    _fontScale = 1.0;
    _highContrast = false;
    notifyListeners();
    await _store.erase();
  }
}
