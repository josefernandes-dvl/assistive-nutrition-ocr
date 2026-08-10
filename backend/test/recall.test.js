/**
 * CA03 no backend — mesma medição de recall que o app faz, sobre o mesmo
 * corpus (`validation/recall_corpus.json`).
 *
 * O backend não recebe o texto bruto: recebe a lista de ingredientes já
 * extraída pelo app (RN08). Por isso a entrada aqui é o campo `ingredients`
 * de cada caso. Se as duas camadas divergirem, o alerta local e o alerta
 * remoto discordariam para o mesmo rótulo — que é a falha que a RN02 e o
 * teste de paridade existem para impedir.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const { analyze } = require('../src/services/ingredientAnalyzer');

const corpus = JSON.parse(
  fs.readFileSync(
    path.join(__dirname, '..', '..', 'validation', 'recall_corpus.json'),
    'utf8'
  )
);

const norm = (s) =>
  String(s || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/ç/g, 'c');

function sinalizouCorretamente(resultado, gatilho, disturbio) {
  const alvo = norm(gatilho);
  return resultado.ingredients.some(
    (i) =>
      i.is_flagged &&
      String(i.related_disorder || '').includes(disturbio) &&
      (norm(i.flag_reason).includes(alvo) || norm(i.name).includes(alvo))
  );
}

function analisar(caso) {
  return analyze({
    ingredients: caso.ingredients,
    disorders: caso.disorders,
    customAllergens: caso.custom_allergens,
  });
}

test('o corpus compartilhado tem os 20 rótulos positivos do CA03', () => {
  assert.equal(corpus.positivos.length, 20);
});

test('CA03 — recall ≥ 85% na camada do backend', () => {
  const falhas = [];

  for (const caso of corpus.positivos) {
    const r = analisar(caso);
    if (!sinalizouCorretamente(r, caso.expected_trigger, caso.expected_disorder)) {
      falhas.push(
        `${caso.id} (${caso.produto}): esperado "${caso.expected_trigger}" ` +
          `para "${caso.expected_disorder}"`
      );
    }
  }

  const acertos = corpus.positivos.length - falhas.length;
  const recall = (acertos / corpus.positivos.length) * 100;
  console.log(
    `CA03 · recall (backend) = ${recall.toFixed(1)}% ` +
      `(${acertos}/${corpus.positivos.length})`
  );

  assert.ok(
    acertos >= 17,
    `recall ${recall.toFixed(1)}% abaixo de 85%.\n${falhas.join('\n')}`
  );
});

test('nenhum rótulo do corpus deixa de ser sinalizado no backend', () => {
  const falhas = corpus.positivos
    .filter(
      (caso) =>
        !sinalizouCorretamente(
          analisar(caso),
          caso.expected_trigger,
          caso.expected_disorder
        )
    )
    .map((caso) => `${caso.id} — ${caso.produto}`);

  assert.deepEqual(falhas, []);
});

test('controle negativo — rótulos sem gatilho não geram alerta', () => {
  const falsosPositivos = [];

  for (const caso of corpus.negativos) {
    const r = analisar(caso);
    const marcados = r.ingredients.filter((i) => i.is_flagged);
    if (marcados.length > 0) {
      falsosPositivos.push(
        `${caso.id} (${caso.produto}): ` +
          marcados.map((i) => `${i.name} → ${i.flag_reason}`).join(' | ')
      );
    }
  }

  assert.deepEqual(falsosPositivos, [], falsosPositivos.join('\n'));
});

test('a severidade acompanha os alertas do corpus', () => {
  for (const caso of corpus.positivos) {
    assert.notEqual(
      analisar(caso).summary.severity,
      'safe',
      `${caso.id} deveria sair de "safe"`
    );
  }
  for (const caso of corpus.negativos) {
    assert.equal(
      analisar(caso).summary.severity,
      'safe',
      `${caso.id} deveria permanecer "safe"`
    );
  }
});
