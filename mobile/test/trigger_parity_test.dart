/// RN02 — paridade da tabela de gatilhos entre app e backend.
///
/// As duas camadas mantêm cópias da tabela (risco arquitetural RA-06). Se elas
/// divergirem, o alerta offline e o alerta enriquecido discordam sobre o mesmo
/// rótulo — falha de segurança alimentar que nenhum outro teste detectaria.
/// `validation/disorder_triggers.json` é a fonte única; o teste espelhado do
/// backend está em backend/test/parity.test.js.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/constants.dart';

void main() {
  final canonical = json.decode(
    File('../validation/disorder_triggers.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final canonicalTriggers =
      (canonical['disorder_triggers'] as Map<String, dynamic>).map(
    (k, v) => MapEntry(k, (v as List).cast<String>()),
  );

  test('a tabela do app é idêntica à canônica (RN02)', () {
    expect(
      AppConstants.problematicIngredients.keys.toSet(),
      canonicalTriggers.keys.toSet(),
      reason: 'a lista de distúrbios divergiu entre app e backend',
    );

    for (final entry in canonicalTriggers.entries) {
      expect(
        AppConstants.problematicIngredients[entry.key],
        entry.value,
        reason: 'gatilhos divergentes em "${entry.key}"',
      );
    }
  });

  test('o catálogo exibido na UI cobre exatamente os distúrbios da tabela '
      '(RF04)', () {
    expect(
      AppConstants.digestiveDisorders.toSet(),
      canonicalTriggers.keys.toSet(),
    );
    expect(AppConstants.digestiveDisorders, hasLength(12));
  });

  test('os gatilhos estão normalizados: minúsculas e sem acento', () {
    final irregulares = <String>[];
    for (final entry in AppConstants.problematicIngredients.entries) {
      for (final trigger in entry.value) {
        if (trigger != trigger.toLowerCase() ||
            RegExp(r'[^\x20-\x7E]').hasMatch(trigger)) {
          irregulares.add('${entry.key}: "$trigger"');
        }
      }
    }
    expect(irregulares, isEmpty, reason: irregulares.join('\n'));
  });
}
