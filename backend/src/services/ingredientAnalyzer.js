const {
  disorderTriggers,
  offAllergenToDisorders,
} = require('../data/disorderTriggers');

/**
 * Analisa lista de ingredientes contra o perfil do usuário, opcionalmente
 * enriquecendo com dados do Open Food Facts (allergens_tags, nova_group,
 * nutriscore, nutriments).
 *
 * @param {object} args
 * @param {string[]} args.ingredients     Lista de ingredientes (texto)
 * @param {string[]} args.disorders       Distúrbios selecionados pelo usuário
 * @param {string[]} args.customAllergens Alérgenos personalizados
 * @param {object|null} args.product      Produto da OFF (opcional) — se vier,
 *                                        os allergens_tags e ingredients_list dele
 *                                        podem suplantar os ingredientes manuais
 * @returns {object} resultado da análise
 */
function analyze({
  ingredients = [],
  disorders = [],
  customAllergens = [],
  product = null,
}) {
  // Política de origem dos ingredientes:
  //  - Se o usuário enviou uma lista (vinda do OCR), prefere ela — está no idioma
  //    do usuário e os triggers PT-BR só funcionam nele.
  //  - Se o usuário não enviou ingredientes (fluxo barcode-puro), cai na lista da OFF
  //    como fallback. A correlação por allergens_tags ainda cobre os principais alérgenos.
  let sourceIngredients = ingredients;
  if (
    (!ingredients || ingredients.length === 0) &&
    product &&
    Array.isArray(product.ingredients_list) &&
    product.ingredients_list.length > 0
  ) {
    sourceIngredients = product.ingredients_list;
  }

  const analyzed = sourceIngredients.map((name) =>
    analyzeIngredient(name, disorders, customAllergens)
  );

  // Alertas vindos das allergens_tags oficiais (OFF) que casam com perfil
  const officialAllergens = mapOfficialAllergens(product, disorders);

  const flagged = analyzed.filter((i) => i.is_flagged);

  return {
    ingredients: analyzed,
    flagged_ingredients: flagged,
    official_allergens: officialAllergens, // ex.: ["en:milk", "en:gluten"]
    summary: {
      total: analyzed.length,
      flagged: flagged.length,
      severity: severityOf(flagged.length, officialAllergens.length),
    },
    product: product
      ? {
          barcode: product.barcode,
          name: product.name,
          brand: product.brand,
          image_url: product.image_url,
          nova_group: product.nova_group,
          nutriscore_grade: product.nutriscore_grade,
          nutriments: product.nutriments,
        }
      : null,
  };
}

function analyzeIngredient(name, disorders, customAllergens) {
  const normalized = normalize(name);
  const reasons = [];
  const matchedDisorders = [];

  for (const disorder of disorders) {
    const triggers = disorderTriggers[disorder] || [];
    for (const trigger of triggers) {
      if (matchesAsWord(normalized, trigger)) {
        reasons.push(`${trigger} (${disorder})`);
        if (!matchedDisorders.includes(disorder)) matchedDisorders.push(disorder);
        break;
      }
    }
  }

  for (const allergen of customAllergens) {
    const t = String(allergen || '').trim();
    if (!t) continue;
    if (matchesAsWord(normalized, t)) {
      reasons.push(`${t} (alérgeno personalizado)`);
      if (!matchedDisorders.includes('Alérgeno personalizado')) {
        matchedDisorders.push('Alérgeno personalizado');
      }
    }
  }

  return {
    name: prettify(name),
    is_flagged: reasons.length > 0,
    flag_reason: reasons.length ? reasons.join(' · ') : null,
    related_disorder: matchedDisorders.length ? matchedDisorders.join(', ') : null,
  };
}

function mapOfficialAllergens(product, disorders) {
  if (!product || !Array.isArray(product.allergens_tags)) return [];
  const matched = [];
  for (const tag of product.allergens_tags) {
    const associated = offAllergenToDisorders[tag] || [];
    if (associated.some((d) => disorders.includes(d))) {
      matched.push({
        tag,
        disorders: associated.filter((d) => disorders.includes(d)),
      });
    }
  }
  return matched;
}

function severityOf(flaggedCount, officialCount) {
  if (flaggedCount === 0 && officialCount === 0) return 'safe';
  if (flaggedCount + officialCount >= 3) return 'danger';
  return 'warning';
}

// -------- helpers --------

function normalize(text) {
  return String(text || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/ç/g, 'c');
}

/**
 * Match por palavra (com fronteiras), tolerante a acentos e a flexão de
 * número (RN01). Espelha `TextParser._matchesAsWord` em
 * mobile/lib/utils/text_parser.dart — as duas camadas precisam decidir igual.
 *
 * A fronteira evita falso positivo de substring (`sal` ≠ `salsa`); as formas
 * flexionadas evitam o falso negativo simétrico (`trigo` → `trigos`).
 */
function matchesAsWord(haystack, trigger) {
  const re = triggerPattern(trigger);
  if (!re) return false;
  return re.test(haystack);
}

const patternCache = new Map();

function triggerPattern(trigger) {
  if (patternCache.has(trigger)) return patternCache.get(trigger);

  const t = normalize(trigger).trim();
  let re = null;
  if (t) {
    const body = t
      .split(/\s+/)
      .filter(Boolean)
      .map((w) => {
        const forms = inflectionForms(w).map((f) =>
          f.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
        );
        return forms.length === 1 ? forms[0] : `(?:${forms.join('|')})`;
      })
      .join('\\s+');
    re = new RegExp(`(?:^|[^a-z0-9])${body}(?:$|[^a-z0-9])`);
  }

  patternCache.set(trigger, re);
  return re;
}

/**
 * Formas de número aceitas para uma palavra já normalizada (sem acento).
 * Regras regulares do português suficientes para rotulagem: vogal → +s,
 * -l → -is, -m → -ns, -r/-z → +es, -ao → -oes. Palavras de até 2 letras
 * (`de`, `do`) não flexionam; terminadas em -s permanecem invariáveis.
 */
function inflectionForms(word) {
  const w = String(word || '').trim();
  if (w.length < 3) return [w];

  const forms = new Set([w]);
  const last = w[w.length - 1];

  if (w.endsWith('ao')) {
    forms.add(`${w.slice(0, -2)}oes`);
  } else if ('aeiou'.includes(last)) {
    forms.add(`${w}s`);
  } else if (last === 'l') {
    forms.add(`${w.slice(0, -1)}is`);
  } else if (last === 'm') {
    forms.add(`${w.slice(0, -1)}ns`);
  } else if (last === 'r' || last === 'z') {
    forms.add(`${w}es`);
  }

  return [...forms];
}

function prettify(s) {
  return String(s || '')
    .toLowerCase()
    .split(' ')
    .filter(Boolean)
    .map((w) => w[0].toUpperCase() + w.slice(1))
    .join(' ');
}

module.exports = { analyze, matchesAsWord, inflectionForms, normalize };
