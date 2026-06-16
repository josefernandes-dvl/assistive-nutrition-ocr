import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// URL do backend selecionada conforme a plataforma de execução.
/// - Web: localhost
/// - Android emulador: 10.0.2.2 (host loopback)
/// - iOS simulador / Desktop: localhost
/// - Android/iOS físico: defina sobrescrevendo `override` (ou via dart-define)
class ApiConfig {
  static const _envOverride = String.fromEnvironment('BACKEND_URL');

  static String get baseUrl {
    if (_envOverride.isNotEmpty) return _envOverride;
    if (kIsWeb) return 'http://localhost:3000/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    return 'http://localhost:3000/api';
  }
}
