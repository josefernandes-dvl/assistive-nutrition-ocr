import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta e tema do NutriScan.
///
/// **Regra de uso (RNF07 / WCAG 2.2 AA).** As cores estão separadas em dois
/// papéis, e a auditoria automatizada (`test/contrast_audit_test.dart`) falha
/// se o papel for violado:
///
/// - **Preenchimento e ícone** (`accentOrange`, `warningYellow`, `safeGreen`,
///   `primaryGreenLight`): saturadas, boas como fundo tingido, borda ou ícone —
///   mas **não atingem 4,5:1 como cor de texto** sobre fundo claro.
/// - **Texto** (`*Text` / `*Dark` e os tokens neutros): verificadas contra
///   branco, contra o fundo do app (`backgroundLight`) e contra os fundos
///   tingidos em que efetivamente aparecem.
class AppTheme {
  // --- Cores de marca -------------------------------------------------------
  static const Color primaryGreen = Color(0xFF2E7D32); // 5,13:1 vs branco
  static const Color primaryGreenLight = Color(0xFF66BB6A); // preenchimento
  static const Color primaryGreenDark = Color(0xFF1B5E20); // 7,87:1 vs branco

  // --- Cores de preenchimento/ícone (NÃO usar como cor de texto) ------------
  static const Color accentOrange = Color(0xFFFF8F00); // 2,29:1 — só fundo/ícone
  static const Color warningYellow = Color(0xFFFFA000); // 2,04:1 — só fundo/ícone
  static const Color safeGreen = Color(0xFF388E3C); // 4,12:1 — só fundo/ícone
  static const Color dangerRed = Color(0xFFD32F2F); // 4,98:1 — fundo/ícone; texto só sobre branco puro

  // --- Variantes aprovadas para texto --------------------------------------
  /// Alerta em texto. 6,57:1 vs branco e 5,29:1 sobre o vermelho tingido a 10%
  /// usado nos cartões de ingrediente — onde `dangerRed` caía para 4,28:1.
  static const Color dangerRedText = Color(0xFFB71C1C);

  /// Aviso em texto (traços, OCR de baixa qualidade) e fundo de botão com
  /// rótulo branco. 5,94:1 vs branco, 5,47:1 sobre o laranja tingido a 10%.
  static const Color accentOrangeDark = Color(0xFFA34A00);

  /// Estado "sem alerta" em texto. 5,13:1 vs branco, 4,56:1 sobre verde a 10%.
  static const Color safeGreenText = Color(0xFF2E7D32);

  // --- Superfícies e texto neutro ------------------------------------------
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF212121); // 16,10:1
  /// 6,19:1 vs branco e 5,77:1 vs `backgroundLight`. O antigo `#757575` ficava
  /// em 4,29:1 sobre o fundo do app — reprovado.
  static const Color textSecondary = Color(0xFF616161);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: accentOrange,
        error: dangerRed,
        surface: surfaceWhite,
      ),
      scaffoldBackgroundColor: backgroundLight,
      textTheme: GoogleFonts.nunitoTextTheme().copyWith(
        headlineLarge: GoogleFonts.nunito(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.nunito(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.nunito(
          fontSize: 16,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.nunito(
          fontSize: 14,
          color: textSecondary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  /// Tema de alto contraste (RF20 / WCAG 2.2 AA reforçado).
  ///
  /// Deriva do tema claro, mas leva o texto a preto puro (21:1 sobre branco),
  /// o fundo a branco puro (elimina o `backgroundLight` de baixo contraste), a
  /// cor primária ao verde mais escuro (`primaryGreenDark`, 7,87:1) e reforça
  /// as bordas de cartões e campos, para quem tem baixa visão. É ativado por
  /// opção do usuário na tela de Acessibilidade e persiste entre sessões.
  static ThemeData get highContrastTheme {
    const hcText = Color(0xFF000000);
    const hcBg = Color(0xFFFFFFFF);
    const hcPrimary = primaryGreenDark;
    final base = lightTheme;
    return base.copyWith(
      scaffoldBackgroundColor: hcBg,
      colorScheme: base.colorScheme.copyWith(
        primary: hcPrimary,
        onPrimary: Colors.white,
        surface: hcBg,
        onSurface: hcText,
      ),
      textTheme: base.textTheme.apply(bodyColor: hcText, displayColor: hcText),
      appBarTheme: base.appBarTheme.copyWith(backgroundColor: hcPrimary),
      dividerColor: hcText,
      cardTheme: base.cardTheme.copyWith(
        color: hcBg,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: hcText, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: hcText, width: 1.5),
        ),
      ),
    );
  }
}
