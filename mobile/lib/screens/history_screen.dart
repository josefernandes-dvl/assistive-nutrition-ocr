import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/scan_result.dart';
import '../providers/app_provider.dart';
import 'result_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final history = provider.scanHistory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Análises'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Limpar Histórico'),
                    content: const Text(
                      'Tem certeza que deseja apagar todo o histórico de análises?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () {
                          provider.clearHistory();
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          'Apagar',
                          style: TextStyle(color: AppTheme.dangerRedText),
                        ),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Limpar histórico',
            ),
        ],
      ),
      body: history.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final scan = history[index];
                final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(scan.scannedAt);

                final alertText = scan.hasDangerousIngredients
                    ? 'Alerta: ${scan.flaggedIngredients.length} '
                        'ingrediente(s) problemático(s)'
                    : 'Sem alertas';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: '$alertText. '
                              '${scan.totalIngredients} ingredientes '
                              'detectados em $dateStr. Abrir detalhe.',
                          excludeSemantics: true,
                          child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ResultScreen(scanResult: scan),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Ícone de status
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: scan.hasDangerousIngredients
                                  ? AppTheme.dangerRed.withValues(alpha: 0.1)
                                  : AppTheme.safeGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              scan.hasDangerousIngredients
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline,
                              color: scan.hasDangerousIngredients
                                  ? AppTheme.dangerRed
                                  : AppTheme.safeGreen,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${scan.totalIngredients} ingredientes detectados',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  scan.hasDangerousIngredients
                                      ? '${scan.flaggedIngredients.length} alerta(s)'
                                      : 'Nenhum alerta',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: scan.hasDangerousIngredients
                                        ? AppTheme.dangerRedText
                                        : AppTheme.safeGreenText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ],
                      ),
                    ),
                          ),
                        ),
                      ),
                      // Exclusão individual da análise (RF17)
                      IconButton(
                        onPressed: () => _confirmRemove(context, provider, scan),
                        icon: const Icon(Icons.delete_outline,
                            color: AppTheme.textSecondary),
                        tooltip: 'Excluir esta análise',
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    AppProvider provider,
    ScanResult scan,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir análise'),
        content: const Text('Esta análise será removida do histórico.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Excluir',
              style: TextStyle(color: AppTheme.dangerRedText),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await provider.removeScanResult(scan);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.history,
                size: 80,
                color: Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma análise realizada',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Escaneie um rótulo de alimento para ver o histórico aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
