import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/app_provider.dart';

/// Tela de Acessibilidade (RF18 e RF20).
///
/// Reúne, num só lugar, o aumento interno de fonte e o tema de alto contraste.
/// As duas preferências são persistidas pelo `AppProvider` e sobrevivem ao
/// encerramento do app.
class AccessibilityScreen extends StatelessWidget {
  const AccessibilityScreen({super.key});

  static const _fontOptions = <String, double>{
    'Padrão': 1.0,
    'Grande': 1.3,
    'Muito grande': 1.6,
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Acessibilidade')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- RF18: aumento interno de fonte -------------------------------
          Semantics(
            header: true,
            child: const Text(
              'Tamanho da fonte',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Aumenta o texto do app além do ajuste do seu aparelho.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          ..._fontOptions.entries.map(
            (e) => _OptionRow(
              label: e.key,
              selected: provider.fontScale == e.value,
              onTap: () => provider.setFontScale(e.value),
            ),
          ),

          const Divider(height: 32),

          // --- RF20: alto contraste ----------------------------------------
          SwitchListTile(
            value: provider.highContrast,
            onChanged: provider.setHighContrast,
            contentPadding: EdgeInsets.zero,
            title: Semantics(
              header: true,
              child: const Text(
                'Alto contraste',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            subtitle: const Text(
              'Texto preto sobre fundo branco e bordas reforçadas, para baixa '
              'visão.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),

          const SizedBox(height: 24),

          // Prévia do efeito das opções acima.
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prévia',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Farinha de trigo, leite em pó, açúcar. '
                    'Pode conter traços de amendoim.',
                    style: TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha de seleção única de fonte. Substitui `RadioListTile` (cuja API de
/// grupo foi depreciada) por um controle acessível próprio: rótulo semântico
/// com estado de seleção e alvo de toque de altura confortável.
class _OptionRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected
                    ? AppTheme.primaryGreen
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
