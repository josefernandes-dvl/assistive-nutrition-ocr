import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show OrdinalSortKey;
import 'package:flutter/services.dart' show HapticFeedback, SystemSound, SystemSoundType;
import '../core/disorder_explanations.dart';
import '../core/theme.dart';
import '../models/enriched_analysis.dart';
import '../models/ingredient.dart';
import '../models/nutrition.dart';
import '../models/scan_result.dart';
import '../utils/text_parser.dart';
import '../widgets/ingredient_card.dart';
import '../widgets/medical_disclaimer.dart';

/// Nível de severidade do resultado (RF25). Ordem crescente de gravidade.
enum _Severity { none, attention, danger }

class ResultScreen extends StatefulWidget {
  final ScanResult scanResult;
  final EnrichmentBundle? enrichment;

  /// Enriquecimento assíncrono (RA-10). Quando informado, a tela abre com o
  /// resultado local já pronto e preenche produto e alérgenos oficiais quando
  /// esta Future resolve — sem bloquear a navegação esperando o backend.
  final Future<EnrichmentBundle?>? enrichmentFuture;

  /// Declarações diretas "Contém X" lidas no próprio rótulo (ex.: "CONTÉM
  /// GLÚTEN") e relevantes ao perfil — presença declarada, alerta mais forte
  /// que os avisos de traço.
  final List<ContainsDeclaration> containsWarnings;
  final List<TraceWarning> traceWarnings;
  final bool lowQualityOcr;

  /// Fluxo de código de barras: a Open Food Facts tem o produto, mas não tem a
  /// lista de ingredientes nem alérgenos dele. Nesse caso não há o que analisar,
  /// e a tela precisa dizer isso — em vez de mostrar um verde "sem
  /// correspondência" que passaria falsa sensação de segurança (RN03).
  final bool noIngredientData;

  const ResultScreen({
    super.key,
    required this.scanResult,
    this.enrichment,
    this.enrichmentFuture,
    this.containsWarnings = const [],
    this.traceWarnings = const [],
    this.lowQualityOcr = false,
    this.noIngredientData = false,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  EnrichmentBundle? _enrichment;
  bool _enrichmentPending = false;
  bool _feedbackFired = false;

  // Getters mantêm o corpo dos métodos _build* inalterado após a conversão
  // para StatefulWidget.
  ScanResult get scanResult => widget.scanResult;
  EnrichmentBundle? get enrichment => _enrichment;
  List<ContainsDeclaration> get containsWarnings => widget.containsWarnings;
  List<TraceWarning> get traceWarnings => widget.traceWarnings;
  bool get lowQualityOcr => widget.lowQualityOcr;
  bool get noIngredientData => widget.noIngredientData;

  @override
  void initState() {
    super.initState();
    _enrichment = widget.enrichment;

    // RA-10: não esperamos o backend antes de mostrar o resultado. Se veio uma
    // Future de enriquecimento, o resultado local já está na tela e o produto
    // aparece quando (e se) o backend responder.
    final future = widget.enrichmentFuture;
    if (future != null) {
      _enrichmentPending = true;
      future.then((bundle) {
        if (!mounted) return;
        setState(() {
          _enrichment = bundle;
          _enrichmentPending = false;
        });
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _enrichmentPending = false);
      });
    }

    // RF21: reforço tátil e sonoro quando há alerta, para quem não olha a tela.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fireAlertFeedback());
  }

  void _fireAlertFeedback() {
    if (_feedbackFired) return;
    _feedbackFired = true;
    final dangerous = widget.scanResult.flaggedIngredients.isNotEmpty ||
        widget.containsWarnings.isNotEmpty ||
        widget.traceWarnings.isNotEmpty;
    if (!dangerous) return;
    try {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      // Plataforma sem suporte (desktop/testes) — silencioso por desenho.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado da Análise'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ordem de anúncio para leitor de tela (UC05): situação geral,
            // aviso de não-substituição, e só então o detalhe da análise.
            Semantics(
              sortKey: const OrdinalSortKey(0),
              child: _buildStatusBanner(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Semantics(
                sortKey: const OrdinalSortKey(1),
                child: const MedicalDisclaimer(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (scanResult.imagePath != null) _buildImagePreview(),
                  const SizedBox(height: 20),

                  if (lowQualityOcr) ...[
                    _buildLowQualityNotice(),
                    const SizedBox(height: 20),
                  ],

                  // RA-10: enquanto o backend responde, o resultado local já
                  // está visível; aqui só sinalizamos que o produto está a
                  // caminho, sem bloquear a tela.
                  if (_enrichmentPending) ...[
                    _buildEnrichmentPending(),
                    const SizedBox(height: 20),
                  ],

                  // Card do produto (se identificado via Open Food Facts)
                  if (enrichment?.product != null) ...[
                    _buildProductCard(enrichment!.product!),
                    const SizedBox(height: 20),
                  ],

                  // Alérgenos oficiais (Open Food Facts) que afetam o perfil
                  if ((enrichment?.officialAllergens ?? []).isNotEmpty) ...[
                    _buildOfficialAllergens(enrichment!.officialAllergens),
                    const SizedBox(height: 20),
                  ],

                  // Declarações diretas "Contém X" do rótulo (presença
                  // declarada) — mais severo que traço, vem antes.
                  if (containsWarnings.isNotEmpty) ...[
                    _buildContainsWarnings(containsWarnings),
                    const SizedBox(height: 20),
                  ],

                  // Avisos de "contém traços / pode conter" do rótulo
                  if (traceWarnings.isNotEmpty) ...[
                    _buildTraceWarnings(traceWarnings),
                    const SizedBox(height: 20),
                  ],

                  // Sem lista de ingredientes da OFF não há resumo nem lista a
                  // mostrar — só o aviso honesto de que não deu para analisar.
                  if (noIngredientData) ...[
                    _buildNoDataNotice(),
                    const SizedBox(height: 20),
                  ] else ...[
                    _buildSummaryCard(),
                    const SizedBox(height: 20),

                    if (scanResult.flaggedIngredients.isNotEmpty) ...[
                      _buildWhyCareSection(scanResult.flaggedIngredients),
                      const SizedBox(height: 20),
                      const Text(
                        'Ingredientes com Alerta',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.dangerRedText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...scanResult.flaggedIngredients.map(
                        (i) => IngredientCard(ingredient: i),
                      ),
                      const SizedBox(height: 20),
                    ],

                    const Text(
                      'Todos os Ingredientes Detectados',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...scanResult.ingredients.map(
                      (i) => IngredientCard(ingredient: i),
                    ),
                  ],

                  const SizedBox(height: 20),
                  _buildRawTextSection(),
                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: const Text('Nova Análise'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// RF25 — severidade em três níveis, considerando ingredientes sinalizados,
  /// alérgenos oficiais e avisos de traços:
  /// - [_Severity.danger]  presença CONFIRMADA de gatilho do perfil
  ///   (ingrediente sinalizado, alérgeno oficial do OFF ou declaração direta
  ///   "Contém X" no rótulo).
  /// - [_Severity.attention]  presença apenas POSSÍVEL — avisos de traço
  ///   ("pode conter / traços"), sem gatilho confirmado.
  /// - [_Severity.none]  nenhuma correspondência. RN03: é ausência de
  ///   correspondência na base atual, e não uma afirmação de segurança.
  _Severity get _severity {
    final confirmado = scanResult.flaggedIngredients.isNotEmpty ||
        (enrichment?.officialAllergens.isNotEmpty ?? false) ||
        containsWarnings.isNotEmpty;
    if (confirmado) return _Severity.danger;
    if (traceWarnings.isNotEmpty) return _Severity.attention;
    return _Severity.none;
  }

  Widget _buildStatusBanner() {
    final ingredientCount = scanResult.flaggedIngredients.length;
    final officialCount = enrichment?.officialAllergens.length ?? 0;
    final containsCount = containsWarnings.length;
    final traceCount = traceWarnings.length;
    final severity = _severity;

    final List<String> partes = [];
    if (ingredientCount > 0) {
      partes.add('$ingredientCount ingrediente(s) problemático(s)');
    }
    if (officialCount > 0) {
      partes.add('$officialCount alérgeno(s) oficial(is)');
    }
    if (containsCount > 0) {
      partes.add('$containsCount declarado(s) no rótulo');
    }
    if (traceCount > 0) {
      partes.add('$traceCount aviso(s) de traços');
    }

    final List<Color> gradient;
    final IconData icon;
    final String title;
    final String subtitle;
    switch (severity) {
      case _Severity.danger:
        gradient = const [AppTheme.dangerRed, AppTheme.dangerRedText];
        icon = Icons.warning_amber_rounded;
        title = 'Atenção! Alertas Detectados';
        subtitle = partes.join(' · ');
        break;
      case _Severity.attention:
        // Âmbar escuro nas duas pontas do gradiente para o texto branco manter
        // contraste em toda a faixa (RNF07).
        gradient = const [AppTheme.accentOrangeDark, Color(0xFF7A3700)];
        icon = Icons.info_outline;
        title = 'Atenção: Possível Presença';
        subtitle = partes.isEmpty
            ? 'O rótulo indica possível presença por contaminação cruzada.'
            : partes.join(' · ');
        break;
      case _Severity.none:
        if (noIngredientData) {
          // Produto existe na OFF, mas sem lista de ingredientes/alérgenos:
          // não é "sem correspondência", é "não deu para analisar". Âmbar, não
          // verde — para não sugerir segurança.
          gradient = const [AppTheme.accentOrangeDark, Color(0xFF7A3700)];
          icon = Icons.help_outline;
          title = 'Produto não analisado';
          subtitle = 'A Open Food Facts não tem a lista de ingredientes deste '
              'produto. Escaneie o rótulo (foto) para verificar os alérgenos.';
        } else {
          gradient = const [AppTheme.primaryGreen, AppTheme.primaryGreenDark];
          icon = Icons.check_circle_outline;
          title = 'Sem Correspondência para seu Perfil';
          // RN03 — não afirmar segurança; apenas ausência de correspondência.
          subtitle = 'Nenhum gatilho do seu perfil foi encontrado no que foi '
              'lido. Isso não afirma que o produto é seguro.';
        }
        break;
    }
    final alertaLike = severity != _Severity.none;

    return Semantics(
      header: true,
      liveRegion: true,
      excludeSemantics: true,
      label: alertaLike ? 'Alerta: $title. $subtitle.' : '$title. $subtitle.',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 48),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    final file = File(scanResult.imagePath!);
    if (!file.existsSync()) return const SizedBox.shrink();
    return Semantics(
      image: true,
      label: 'Foto do rótulo analisado',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          file,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductInfo product) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (product.imageUrl != null)
                  Semantics(
                    image: true,
                    label: 'Foto do produto identificado',
                    child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      product.imageUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 64,
                        height: 64,
                        child: Icon(Icons.fastfood_outlined, size: 32),
                      ),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name ?? 'Produto identificado',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (product.brand != null)
                        Text(product.brand!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary)),
                      if (product.barcode != null)
                        Text('Código: ${product.barcode}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (product.nutriscoreGrade != null &&
                    product.nutriscoreGrade!.isNotEmpty &&
                    product.nutriscoreGrade != 'unknown')
                  _buildNutriScoreBadge(product.nutriscoreGrade!),
                if (product.novaGroup != null)
                  _buildNovaBadge(product.novaGroup!),
              ],
            ),
            // RF13: tabela nutricional detalhada (por 100 g), quando a Open
            // Food Facts a fornece.
            if (product.nutriments != null &&
                _hasAnyNutrient(product.nutriments!)) ...[
              const SizedBox(height: 16),
              _buildNutritionTable(product.nutriments!),
            ],
          ],
        ),
      ),
    );
  }

  static bool _hasAnyNutrient(NutritionInfo n) =>
      [n.calories, n.carbohydrates, n.sugars, n.fiber, n.protein, n.totalFat,
              n.saturatedFat, n.sodium]
          .any((v) => v != null);

  /// RF13 — Informação nutricional por 100 g, com tipografia escalável (herda
  /// o `textScaler` do RF18). Valores ausentes aparecem como "—".
  Widget _buildNutritionTable(NutritionInfo n) {
    String fmt(double? v, String unit) {
      if (v == null) return '—';
      final s = v == v.roundToDouble()
          ? v.toStringAsFixed(0)
          : v.toStringAsFixed(1);
      return '$s $unit';
    }

    final rows = <List<String>>[
      ['Valor energético', fmt(n.calories, 'kcal')],
      ['Carboidratos', fmt(n.carbohydrates, 'g')],
      ['   dos quais açúcares', fmt(n.sugars, 'g')],
      ['Fibras', fmt(n.fiber, 'g')],
      ['Proteínas', fmt(n.protein, 'g')],
      ['Gorduras totais', fmt(n.totalFat, 'g')],
      ['   das quais saturadas', fmt(n.saturatedFat, 'g')],
      ['Sódio', fmt(n.sodium, 'g')],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: const Text(
            'Informação nutricional (por 100 g)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        const SizedBox(height: 8),
        ...rows.map(
          (r) => Semantics(
            excludeSemantics: true,
            container: true,
            label: '${r[0].trim()}: ${r[1]}',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(r[0],
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textPrimary)),
                  ),
                  const SizedBox(width: 12),
                  Text(r[1],
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnrichmentPending() {
    return Semantics(
      liveRegion: true,
      label: 'Consultando dados do produto no servidor',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Consultando dados do produto (Nutri-Score, NOVA, alérgenos '
                'oficiais)… O resultado abaixo já está pronto.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutriScoreBadge(String grade) {
    final colors = <String, Color>{
      'a': const Color(0xFF038141),
      'b': const Color(0xFF85BB2F),
      'c': const Color(0xFFFECB02),
      'd': const Color(0xFFEE8100),
      'e': const Color(0xFFE63E11),
    };
    final color = colors[grade.toLowerCase()] ?? Colors.grey;
    // As faixas oficiais do Nutri-Score vão do verde-escuro ao amarelo. Manter
    // texto branco em todas reprovaria o contraste nas claras (C e D); a cor
    // do rótulo é escolhida pela que contrasta melhor com a faixa.
    final onColor = _readableOn(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Nutri-Score',
              style: TextStyle(
                  color: onColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text(grade.toUpperCase(),
              style: TextStyle(
                  color: onColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// Preto ou branco — o que render mais contraste sobre `background`.
  static Color _readableOn(Color background) {
    final l = background.computeLuminance();
    final comBranco = 1.05 / (l + 0.05);
    final comPreto = (l + 0.05) / 0.05;
    return comBranco >= comPreto ? Colors.white : AppTheme.textPrimary;
  }

  Widget _buildNovaBadge(int nova) {
    const labels = {
      1: 'In natura',
      2: 'Ingrediente culinário',
      3: 'Processado',
      4: 'Ultraprocessado',
    };
    final color = nova >= 4
        ? AppTheme.dangerRedText
        : nova == 3
            ? AppTheme.accentOrangeDark
            : AppTheme.safeGreenText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        'NOVA $nova · ${labels[nova] ?? ''}',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildContainsWarnings(List<ContainsDeclaration> declarations) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dangerRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline,
                  color: AppTheme.dangerRedText, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Contém (declarado no rótulo)',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.dangerRedText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'O fabricante declara a presença destes itens no produto — não é '
            'apenas traço. Evite se algum afetar seu perfil.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          ...declarations.map((d) => Semantics(
                label: 'Contém ${d.term}. Afeta: ${d.disorders.join(", ")}.',
                excludeSemantics: true,
                container: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(
                              color: AppTheme.dangerRedText,
                              fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: d.term,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppTheme.dangerRedText),
                              ),
                              TextSpan(
                                text: '  (${d.disorders.join(", ")})',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTraceWarnings(List<TraceWarning> warnings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentOrange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppTheme.accentOrangeDark, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pode conter / Traços (do próprio rótulo)',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.accentOrangeDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'O fabricante avisa que pode haver presença residual destes itens '
            '— relevante para alergias graves.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          ...warnings.map((w) => Semantics(
                label: 'Pode conter ${w.term}. '
                    'Afeta: ${w.disorders.join(", ")}.',
                excludeSemantics: true,
                container: true,
                child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(
                            color: AppTheme.accentOrangeDark,
                            fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: w.term,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            TextSpan(
                              text: '  (${w.disorders.join(", ")})',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                ),
              )),
        ],
      ),
    );
  }

  /// Agrupa os ingredientes flagged por distúrbio relacionado e explica por
  /// que cada distúrbio reage àqueles ingredientes — com sintomas/mecanismo.
  Widget _buildWhyCareSection(List<Ingredient> flagged) {
    // disorder -> lista de ingredientes (nomes) que dispararam por ele
    final byDisorder = <String, List<String>>{};
    for (final ing in flagged) {
      final disorders = (ing.relatedDisorder ?? '')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);
      for (final d in disorders) {
        byDisorder.putIfAbsent(d, () => []).add(ing.name);
      }
    }
    if (byDisorder.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dangerRed.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  color: AppTheme.dangerRedText, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Por que tomar cuidado com estes ingredientes?',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.dangerRedText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...byDisorder.entries.map((e) {
            final explanation = disorderExplanations[e.key];
            return _buildDisorderExplanationCard(
              disorder: e.key,
              triggers: e.value,
              explanation: explanation,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDisorderExplanationCard({
    required String disorder,
    required List<String> triggers,
    required DisorderExplanation? explanation,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                explanation?.icon ?? Icons.warning_amber_rounded,
                color: AppTheme.dangerRedText,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  disorder,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'No rótulo: ',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppTheme.textSecondary),
                ),
                TextSpan(
                  text: triggers.toSet().join(', '),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.dangerRedText),
                ),
              ],
            ),
          ),
          if (explanation != null) ...[
            const SizedBox(height: 8),
            Text(
              explanation.shortReason,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              explanation.detail,
              style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLowQualityNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningYellow.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.5)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppTheme.accentOrangeDark, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Qualidade do OCR baixa',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.accentOrangeDark),
                ),
                SizedBox(height: 2),
                Text(
                  'A foto não tinha contraste/foco ideais. Confira os ingredientes '
                  'abaixo manualmente — alguns podem estar com grafia errada. Para '
                  'um resultado preciso, use "Ler Código de Barras".',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Fluxo de código de barras sem lista de ingredientes na OFF. Explica por
  /// que não há alertas e encaminha para a análise por foto do rótulo.
  Widget _buildNoDataNotice() {
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.warningYellow.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.5)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.search_off, color: AppTheme.accentOrangeDark, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sem lista de ingredientes para este produto',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.accentOrangeDark),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'A Open Food Facts identificou o produto, mas não tem a lista '
                    'de ingredientes nem os alérgenos dele cadastrados. Por isso '
                    'não foi possível procurar gatilhos do seu perfil — isso não '
                    'significa que o produto seja seguro. Para analisar, volte e '
                    'use "Analisar Rótulo" fotografando a lista de ingredientes.',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficialAllergens(List<OfficialAllergen> allergens) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dangerRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gpp_bad, color: AppTheme.dangerRedText, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Alérgenos oficiais (Open Food Facts)',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.dangerRedText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: allergens
                .map((a) => Chip(
                      label: Text(a.prettyName,
                          style: const TextStyle(fontSize: 12)),
                      backgroundColor:
                          AppTheme.dangerRed.withValues(alpha: 0.15),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    // "Alertas" conta TODOS os itens de alerta da tela — ingredientes
    // sinalizados, alérgenos oficiais, declarações diretas "Contém" e avisos
    // de traço. Antes contava só os ingredientes, então uma declaração
    // "CONTÉM X" (que gera o quadro vermelho) deixava o número em 0, dando
    // falsa sensação de segurança.
    final int alertasTotais = scanResult.flaggedIngredients.length +
        containsWarnings.length +
        (enrichment?.officialAllergens.length ?? 0) +
        traceWarnings.length;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStat(
              icon: Icons.list_alt,
              value: '${scanResult.totalIngredients}',
              // "Total" = ingredientes detectados (os dois primeiros quadros
              // são sobre a lista; "Alertas" abaixo soma todas as categorias).
              label: 'Total',
              color: AppTheme.primaryGreen,
            ),
            Container(width: 1, height: 40, color: Colors.grey.shade300),
            _buildStat(
              icon: Icons.check_circle,
              value:
                  '${scanResult.totalIngredients - scanResult.flaggedIngredients.length}',
              // RN03 — "sem alerta" ≠ "seguro": conta ingredientes sem gatilho,
              // não é afirmação de segurança do produto.
              label: 'Sem alerta',
              color: AppTheme.safeGreenText,
            ),
            Container(width: 1, height: 40, color: Colors.grey.shade300),
            _buildStat(
              icon: Icons.warning,
              value: '$alertasTotais',
              label: 'Alertas',
              color: AppTheme.dangerRedText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      container: true,
      child: Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary)),
      ],
      ),
    );
  }

  Widget _buildRawTextSection() {
    return ExpansionTile(
      title: const Text(
        'Texto Bruto do OCR',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      leading: const Icon(Icons.text_snippet_outlined),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            scanResult.rawText,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
      ],
    );
  }
}
