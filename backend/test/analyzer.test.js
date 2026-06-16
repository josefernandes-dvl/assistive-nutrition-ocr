const test = require('node:test');
const assert = require('node:assert/strict');
const { analyze } = require('../src/services/ingredientAnalyzer');

test('flagged ingredient quando há trigger correspondente', () => {
  const r = analyze({
    ingredients: ['Farinha de trigo enriquecida'],
    disorders: ['Doença Celíaca'],
  });
  assert.equal(r.summary.total, 1);
  assert.equal(r.summary.flagged, 1);
  assert.match(r.flagged_ingredients[0].flag_reason, /trigo/i);
});

test('não cria falso positivo "salsa" vs "sal"', () => {
  const r = analyze({
    ingredients: ['Salsa', 'Salsicha'],
    // Sal não está nos triggers desses distúrbios mesmo; usamos um trigger
    // diferente para garantir que o matching é por palavra, não substring.
    disorders: ['Doença Celíaca', 'Intolerância à Lactose'],
  });
  assert.equal(r.summary.flagged, 0);
});

test('alérgeno personalizado é detectado', () => {
  const r = analyze({
    ingredients: ['Açúcar', 'Mostarda'],
    disorders: [],
    customAllergens: ['mostarda'],
  });
  assert.equal(r.summary.flagged, 1);
  assert.match(r.flagged_ingredients[0].related_disorder, /personalizado/i);
});

test('múltiplos distúrbios geram múltiplos motivos', () => {
  const r = analyze({
    ingredients: ['Trigo'],
    disorders: ['Doença Celíaca', 'FODMAP Sensível'],
  });
  assert.equal(r.summary.flagged, 1);
  const reason = r.flagged_ingredients[0].flag_reason;
  assert.match(reason, /Celíaca/i);
  assert.match(reason, /FODMAP/i);
});

test('quando há ingredientes do usuário, NÃO sobrescreve com lista da OFF', () => {
  const r = analyze({
    ingredients: ['Açúcar', 'Farinha de trigo'],
    disorders: ['Doença Celíaca'],
    product: {
      ingredients_list: ['Céréale', 'Sucre', 'Cacao'], // francês
      allergens_tags: ['en:gluten'],
    },
  });
  // Total deve ser 2 (do usuário), não 3 (da OFF)
  assert.equal(r.summary.total, 2);
  assert.equal(r.summary.flagged, 1);
});

test('quando usuário não envia ingredientes, usa os do produto (fallback)', () => {
  const r = analyze({
    ingredients: [],
    disorders: ['Doença Celíaca'],
    product: {
      ingredients_list: ['Trigo integral', 'Açúcar'],
      allergens_tags: ['en:gluten'],
    },
  });
  assert.equal(r.summary.total, 2);
  assert.equal(r.summary.flagged, 1);
});

test('mapeia allergens_tags da OFF para distúrbios do perfil', () => {
  const r = analyze({
    ingredients: ['Açúcar'],
    disorders: ['Intolerância à Lactose', 'Doença Celíaca'],
    product: {
      ingredients_list: [],
      allergens_tags: ['en:milk', 'en:gluten', 'en:peanuts'],
    },
  });
  // en:peanuts não está no perfil, então não aparece
  const tags = r.official_allergens.map((a) => a.tag);
  assert.deepEqual(tags.sort(), ['en:gluten', 'en:milk']);
});

test('severidade escalona corretamente', () => {
  const safe = analyze({ ingredients: ['Água'], disorders: ['Doença Celíaca'] });
  assert.equal(safe.summary.severity, 'safe');

  const warning = analyze({
    ingredients: ['Trigo'],
    disorders: ['Doença Celíaca'],
  });
  assert.equal(warning.summary.severity, 'warning');

  const danger = analyze({
    ingredients: ['Trigo', 'Leite', 'Soja', 'Ovo'],
    disorders: [
      'Doença Celíaca',
      'Intolerância à Lactose',
      'Alergia à Soja',
      'Alergia ao Ovo',
    ],
  });
  assert.equal(danger.summary.severity, 'danger');
});

test('payload vazio não quebra (defensivo)', () => {
  const r = analyze({});
  assert.equal(r.summary.total, 0);
  assert.equal(r.summary.flagged, 0);
  assert.equal(r.summary.severity, 'safe');
});
