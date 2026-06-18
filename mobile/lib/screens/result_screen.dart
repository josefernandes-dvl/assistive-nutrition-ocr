import 'dart:io';
import 'package:flutter/material.dart';
import '../core/disorder_explanations.dart';
import '../core/theme.dart';
import '../models/enriched_analysis.dart';
import '../models/ingredient.dart';
import '../models/scan_result.dart';
import '../utils/text_parser.dart';
import '../widgets/ingredient_card.dart';

class ResultScreen extends StatelessWidget {
  final ScanResult scanResult;
  final EnrichmentBundle? enrichment;
  final List<TraceWarning> traceWarnings;
  final bool lowQualityOcr;

  const ResultScreen({
    super.key,
    required this.scanResult,
    this.enrichment,
    this.traceWarnings = const [],
    this.lowQualityOcr = false,
  });

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
            _buildStatusBanner(),
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

                  // Avisos de "contém traços / pode conter" do rótulo
                  if (traceWarnings.isNotEmpty) ...[
                    _buildTraceWarnings(traceWarnings),
                    const SizedBox(height: 20),
                  ],

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
                        color: AppTheme.dangerRed,
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

  Widget _buildStatusBanner() {
    final ingredientCount = scanResult.flaggedIngredients.length;
    final officialCount = enrichment?.officialAllergens.length ?? 0;
    final traceCount = traceWarnings.length;
    final totalAlerts = ingredientCount + officialCount + traceCount;
    final isDangerous = totalAlerts > 0;

    final List<String> partes = [];
    if (ingredientCount > 0) {
      partes.add('$ingredientCount ingrediente(s) problemático(s)');
    }
    if (officialCount > 0) {
      partes.add('$officialCount alérgeno(s) oficial(is)');
    }
    if (traceCount > 0) {
      partes.add('$traceCount aviso(s) de traços');
    }
    final subtitle = isDangerous
        ? partes.join(' · ')
        : 'Nenhum problema detectado para seu perfil';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDangerous
              ? [AppTheme.dangerRed, AppTheme.dangerRed.withValues(alpha: 0.8)]
              : [AppTheme.safeGreen, AppTheme.safeGreen.withValues(alpha: 0.8)],
        ),
      ),
      child: Row(
        children: [
          Icon(
            isDangerous
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDangerous
                      ? 'Atenção! Alertas Detectados'
                      : 'Tudo Certo! Nenhum Alerta',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    final file = File(scanResult.imagePath!);
    if (!file.existsSync()) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.file(
        file,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
                  ClipRRect(
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Nutri-Score',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text(grade.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildNovaBadge(int nova) {
    const labels = {
      1: 'In natura',
      2: 'Ingrediente culinário',
      3: 'Processado',
      4: 'Ultraprocessado',
    };
    final color = nova >= 4
        ? AppTheme.dangerRed
        : nova == 3
            ? AppTheme.accentOrange
            : AppTheme.safeGreen;
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
                  color: AppTheme.accentOrange, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pode conter / Traços (do próprio rótulo)',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.accentOrange),
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
          ...warnings.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(
                            color: AppTheme.accentOrange,
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
                  color: AppTheme.dangerRed, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Por que tomar cuidado com estes ingredientes?',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.dangerRed),
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
                color: AppTheme.dangerRed,
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
                      color: AppTheme.dangerRed),
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
          Icon(Icons.info_outline, color: AppTheme.accentOrange, size: 22),
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
                      color: AppTheme.accentOrange),
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
              Icon(Icons.gpp_bad, color: AppTheme.dangerRed, size: 22),
              SizedBox(width: 8),
              Text(
                'Alérgenos oficiais (Open Food Facts)',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.dangerRed),
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
              label: 'Total',
              color: AppTheme.primaryGreen,
            ),
            Container(width: 1, height: 40, color: Colors.grey.shade300),
            _buildStat(
              icon: Icons.check_circle,
              value:
                  '${scanResult.totalIngredients - scanResult.flaggedIngredients.length}',
              label: 'Seguros',
              color: AppTheme.safeGreen,
            ),
            Container(width: 1, height: 40, color: Colors.grey.shade300),
            _buildStat(
              icon: Icons.warning,
              value: '${scanResult.flaggedIngredients.length}',
              label: 'Alertas',
              color: AppTheme.dangerRed,
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
    return Column(
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
