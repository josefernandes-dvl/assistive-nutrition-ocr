import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Aviso de não-substituição de aconselhamento médico (RNF24, restrição R2).
///
/// Fica na tela de resultado, acima da dobra: é ali que a decisão de consumir
/// ou não é tomada, e é ali que o caráter informativo do app precisa estar
/// declarado. O texto combina ícone, cor e conteúdo — a informação não depende
/// de cor (RNF08) — e é anunciado como um bloco único por leitores de tela.
class MedicalDisclaimer extends StatelessWidget {
  const MedicalDisclaimer({super.key, this.compact = false});

  /// Versão reduzida, para telas onde o aviso acompanha outro conteúdo denso.
  final bool compact;

  static const String title = 'Conteúdo informativo';

  static const String message =
      'O NutriScan apoia a leitura do rótulo, mas não faz diagnóstico nem '
      'prescreve dieta e não substitui a orientação de médico ou '
      'nutricionista. Em caso de dúvida sobre um alimento, procure um '
      'profissional de saúde.';

  /// Chave usada pelos testes de aceitação (CA15) para localizar o aviso.
  static const Key widgetKey = Key('medical-disclaimer');

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: widgetKey,
      label: '$title. $message',
      excludeSemantics: true,
      container: true,
      child: Container(
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.accentOrangeDark.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.medical_information_outlined,
              color: AppTheme.accentOrangeDark,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.accentOrangeDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: compact ? 11.5 : 12.5,
                      height: 1.4,
                      color: AppTheme.textPrimary,
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
}
