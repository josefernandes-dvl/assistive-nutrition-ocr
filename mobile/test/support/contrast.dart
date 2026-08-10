/// Auditoria de contraste WCAG 2.2 sobre a árvore realmente renderizada.
///
/// Não é uma lista de cores conferida à mão: para cada trecho de texto na
/// tela, o auditor resolve a cor efetiva do texto (já composta, se tiver
/// transparência) e a cor efetiva do fundo (empilhando os `Container`,
/// `Material`, `Card` e gradientes acima dele) e calcula a razão de contraste.
/// Qualquer tela nova entra na auditoria só de ser adicionada à lista de telas.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme.dart';

/// Uma violação encontrada: texto, cores envolvidas e a razão medida.
class ContrastViolation {
  final String screen;
  final String text;
  final Color foreground;
  final Color background;
  final double ratio;
  final double required;
  final double fontSize;
  final bool isIcon;

  const ContrastViolation({
    required this.screen,
    required this.text,
    required this.foreground,
    required this.background,
    required this.ratio,
    required this.required,
    required this.fontSize,
    this.isIcon = false,
  });

  @override
  String toString() {
    final trecho = isIcon
        ? 'ícone'
        : (text.length > 46 ? '${text.substring(0, 46)}…' : text);
    return '[$screen] "$trecho"\n'
        '    ${_hex(foreground)} sobre ${_hex(background)} — '
        '${ratio.toStringAsFixed(2)}:1 (mínimo ${required.toStringAsFixed(1)}:1, '
        'fonte ${fontSize.toStringAsFixed(0)}px)';
  }
}

String _hex(Color c) {
  String two(double v) =>
      (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${two(c.r)}${two(c.g)}${two(c.b)}'.toUpperCase();
}

/// Razão de contraste WCAG entre duas cores **opacas**.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Compõe `fg` (possivelmente translúcida) sobre `bg` opaca.
Color composite(Color fg, Color bg) {
  final a = fg.a;
  if (a >= 0.999) return fg;
  return Color.from(
    alpha: 1.0,
    red: fg.r * a + bg.r * (1 - a),
    green: fg.g * a + bg.g * (1 - a),
    blue: fg.b * a + bg.b * (1 - a),
  );
}

/// Limiar da WCAG 1.4.3: texto grande (≥24px, ou ≥18,66px em negrito) exige
/// 3:1; o restante exige 4,5:1.
double requiredRatio(double fontSize, FontWeight? weight) {
  final bold = (weight?.value ?? FontWeight.normal.value) >=
      FontWeight.w700.value;
  if (fontSize >= 24 || (bold && fontSize >= 18.66)) return 3.0;
  return 4.5;
}

/// Percorre os textos renderizados e devolve as violações.
List<ContrastViolation> auditContrast(WidgetTester tester, String screenName) {
  final violations = <ContrastViolation>[];

  for (final element in tester.allElements.toList()) {
    final widget = element.widget;
    if (widget is! RichText) continue;

    final backgrounds = _backgroundCandidates(element);
    if (backgrounds.isEmpty) continue;

    for (final piece in _textPieces(widget.text)) {
      if (piece.text.trim().isEmpty) continue;

      final rawColor = piece.style?.color;
      if (rawColor == null) continue; // sem cor resolvida: nada a medir
      if (rawColor.a < 0.05) continue; // texto invisível (ex.: placeholder oculto)

      final fontSize = piece.style?.fontSize ?? 14.0;
      // Glifos de ícone são desenhados como texto; valem pela 1.4.11 (3:1).
      // Ícone puramente decorativo — marcado no código com `ExcludeSemantics`,
      // que já o esconde do leitor de tela — está fora do critério.
      final icone = (piece.style?.fontFamily ?? '').contains('MaterialIcons');
      if (icone && _isDecorative(element)) continue;
      final minimo =
          icone ? 3.0 : requiredRatio(fontSize, piece.style?.fontWeight);

      // Pior caso entre os fundos possíveis (gradientes contam todos os pontos).
      ContrastViolation? pior;
      for (final bg in backgrounds) {
        final fg = composite(rawColor, bg);
        final ratio = contrastRatio(fg, bg);
        if (ratio + 0.005 < minimo &&
            (pior == null || ratio < pior.ratio)) {
          pior = ContrastViolation(
            screen: screenName,
            text: piece.text,
            foreground: fg,
            background: bg,
            ratio: ratio,
            required: minimo,
            fontSize: fontSize,
            isIcon: icone,
          );
        }
      }
      if (pior != null) violations.add(pior);
    }
  }

  return violations;
}

class _TextPiece {
  final String text;
  final TextStyle? style;
  const _TextPiece(this.text, this.style);
}

List<_TextPiece> _textPieces(InlineSpan root) {
  final pieces = <_TextPiece>[];

  void visit(InlineSpan span, TextStyle? inherited) {
    final style = span.style == null
        ? inherited
        : (inherited?.merge(span.style) ?? span.style);
    if (span is TextSpan) {
      final text = span.text;
      if (text != null && text.isNotEmpty) pieces.add(_TextPiece(text, style));
      for (final child in span.children ?? const <InlineSpan>[]) {
        visit(child, style);
      }
    }
  }

  visit(root, null);
  return pieces;
}

/// `true` se o elemento está sob um `ExcludeSemantics` — a marca que o projeto
/// usa para declarar um ícone decorativo.
bool _isDecorative(Element element) {
  var decorative = false;
  element.visitAncestorElements((ancestor) {
    if (ancestor.widget is ExcludeSemantics) {
      decorative = true;
      return false;
    }
    // Não vale a pena subir a árvore inteira: a marcação fica junto do ícone.
    return ancestor.widget is! Scaffold;
  });
  return decorative;
}

/// Resolve o(s) fundo(s) opaco(s) sob um texto, empilhando as camadas pintadas
/// pelos ancestrais até chegar a uma opaca.
List<Color> _backgroundCandidates(Element element) {
  final layers = <List<Color>>[];

  element.visitAncestorElements((ancestor) {
    final colors = _paintedColors(ancestor.widget);
    if (colors.isEmpty) return true;
    // Ignora camadas totalmente transparentes.
    final visiveis = colors.where((c) => c.a > 0.001).toList();
    if (visiveis.isEmpty) return true;
    layers.add(visiveis);
    // Camada opaca: pode parar de subir.
    return !visiveis.every((c) => c.a >= 0.999);
  });

  // Fundo do Scaffold como camada final garantida.
  layers.add(const [AppTheme.backgroundLight]);

  // Compõe da camada mais profunda para a mais próxima do texto. Só a camada
  // mais próxima gera variantes (gradiente); as demais usam o primeiro tom.
  Color base = layers.last.first;
  for (var i = layers.length - 2; i >= 1; i--) {
    base = composite(layers[i].first, base);
  }
  return layers.first.map((c) => composite(c, base)).toList();
}

/// Cores que um widget efetivamente pinta atrás de seus filhos.
List<Color> _paintedColors(Widget widget) {
  if (widget is ColoredBox) return [widget.color];
  if (widget is Material) {
    final c = widget.color;
    return c == null ? const [] : [c];
  }
  if (widget is DecoratedBox) {
    final d = widget.decoration;
    if (d is BoxDecoration) {
      final gradient = d.gradient;
      if (gradient is LinearGradient) return gradient.colors;
      if (gradient is RadialGradient) return gradient.colors;
      final c = d.color;
      return c == null ? const [] : [c];
    }
    return const [];
  }
  if (widget is AppBar) {
    final c = widget.backgroundColor;
    return [c ?? AppTheme.primaryGreen];
  }
  return const [];
}
