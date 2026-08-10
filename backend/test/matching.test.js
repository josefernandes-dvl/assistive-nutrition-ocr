/**
 * Suíte de pares para a RN01 (marcação de ingrediente como gatilho).
 *
 * Cobre os dois riscos simétricos da regra:
 *   - CA11: ausência de falso positivo por substring (`salsa` ≠ `sal`).
 *   - CA16: gatilho no singular casando com a forma flexionada do rótulo
 *           (`trigo` → `trigos`).
 *
 * Espelhada em mobile/test/matching_test.dart — a regra vale nas duas camadas.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  analyze,
  matchesAsWord,
  inflectionForms,
  normalize,
} = require('../src/services/ingredientAnalyzer');

// --- CA11: nenhum casamento por substring -----------------------------------

const SUBSTRING_TRAPS = [
  ['salsa', 'sal'],
  ['salsicha', 'sal'],
  ['novo', 'ovo'],
  ['renovo', 'ovo'],
  ['melancia', 'mel'],
  ['caramelo', 'mel'],
  ['soja-livre', 'sojaX'],
  ['trigonometria', 'trigo'],
  ['alhonso', 'alho'],
  ['natal', 'nata'],
  ['gemada', 'gema'],
  ['maltodextrina', 'malte'],
  ['cebolinha', 'cebola'],
  ['tomatada', 'tomate'],
];

test('CA11 — nenhum gatilho casa por substring', () => {
  for (const [word, trigger] of SUBSTRING_TRAPS) {
    assert.equal(
      matchesAsWord(normalize(word), trigger),
      false,
      `"${trigger}" não deveria casar dentro de "${word}"`
    );
  }
});

test('CA11 — "salsa"/"salsicha" não disparam alérgeno personalizado "sal"', () => {
  const r = analyze({
    ingredients: ['Salsa', 'Salsicha', 'Salsão'],
    disorders: [],
    customAllergens: ['sal'],
  });
  assert.equal(r.summary.flagged, 0);
});

test('CA11 — "novo" não dispara alergia ao ovo', () => {
  const r = analyze({
    ingredients: ['Sabor novo', 'Renovo'],
    disorders: ['Alergia ao Ovo'],
  });
  assert.equal(r.summary.flagged, 0);
});

// --- CA16: flexão de número --------------------------------------------------

const PLURAL_PAIRS = [
  ['trigos', 'trigo'],
  ['leites', 'leite'],
  ['ovos', 'ovo'],
  ['queijos', 'queijo'],
  ['cebolas', 'cebola'],
  ['alhos', 'alho'],
  ['corantes artificiais', 'corante artificial'],
  ['farinhas de trigo', 'farinha de trigo'],
  ['claras de ovo', 'clara de ovo'],
  ['alcoois', 'alcool'],
  ['conservantes', 'conservante'],
  ['gorduras trans', 'gordura trans'],
];

test('CA16 — gatilho no singular casa com a forma plural do rótulo', () => {
  for (const [labelWord, trigger] of PLURAL_PAIRS) {
    assert.equal(
      matchesAsWord(normalize(labelWord), trigger),
      true,
      `"${trigger}" deveria casar com "${labelWord}"`
    );
  }
});

test('CA16 — plural no rótulo dispara o alerta na análise completa', () => {
  const r = analyze({
    ingredients: ['Farinhas de trigos enriquecidas', 'Açúcar'],
    disorders: ['Doença Celíaca'],
  });
  assert.equal(r.summary.flagged, 1);
  assert.match(r.flagged_ingredients[0].flag_reason, /trigo/i);
});

test('CA16 — plural em aviso de alérgeno personalizado', () => {
  const r = analyze({
    ingredients: ['Amendoins torrados'],
    disorders: ['Alergia ao Amendoim'],
  });
  assert.equal(r.summary.flagged, 1);
});

test('flexão não é gerada para palavras curtas nem para terminadas em -s', () => {
  assert.deepEqual(inflectionForms('de'), ['de']);
  assert.deepEqual(inflectionForms('arachis'), ['arachis']);
  assert.deepEqual(inflectionForms('trigo').sort(), ['trigo', 'trigos']);
  assert.deepEqual(inflectionForms('alcool').sort(), ['alcoois', 'alcool']);
});

test('acentuação do rótulo não impede o casamento', () => {
  assert.equal(matchesAsWord(normalize('Glúten de trigo'), 'gluten'), true);
  assert.equal(matchesAsWord(normalize('Proteína de soja'), 'proteina de soja'), true);
  assert.equal(matchesAsWord(normalize('Álcoois'), 'alcool'), true);
});
