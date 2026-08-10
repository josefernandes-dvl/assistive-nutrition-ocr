import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'screens/privacy_screen.dart';
import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Dispara warm-up do backend em paralelo com o boot do app.
  // O free tier do Render adormece após 15min sem requests; essa chamada
  // acorda o servidor enquanto o usuário ainda está na home, antes de tentar
  // escanear algo.
  ApiService.warmUp();

  // Leitura do armazenamento local (perfil, histórico, consentimento) começa
  // junto com o boot; o AppGate espera `isReady` antes de decidir a tela.
  final provider = AppProvider();
  provider.load();

  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: const NutriScanApp(),
    ),
  );
}

class NutriScanApp extends StatelessWidget {
  const NutriScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Observa as preferências de acessibilidade para trocar tema (RF20) e
    // escala de fonte (RF18) sem reiniciar o app.
    final provider = context.watch<AppProvider>();

    return MaterialApp(
      title: 'NutriScan - Assistive Nutrition OCR',
      debugShowCheckedModeBanner: false,
      theme: provider.highContrast
          ? AppTheme.highContrastTheme
          : AppTheme.lightTheme,
      // RF18: respeita o ajuste de fonte do SO e aplica, por cima, o aumento
      // interno escolhido pelo usuário. O produto é limitado para não quebrar
      // o layout.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final osScale = media.textScaler.scale(1.0);
        final combined = (osScale * provider.fontScale).clamp(0.85, 2.2);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(combined)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AppGate(),
    );
  }
}

/// Decide a primeira tela: espera a carga do armazenamento local, exige o
/// aceite do aviso de privacidade (RNF11) e só então abre o app.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    if (!provider.isReady) {
      return Scaffold(
        body: Center(
          child: Semantics(
            label: 'Carregando o NutriScan',
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (!provider.hasPrivacyConsent) {
      return const PrivacyNoticeScreen();
    }

    return const HomeScreen();
  }
}
