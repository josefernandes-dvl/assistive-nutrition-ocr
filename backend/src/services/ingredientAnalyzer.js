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
  //    como fallback. Preferimos o array estruturado (`ingredients_list`); se ele
  //    vier vazio — comum em produtos brasileiros — ainda tentamos partir o texto
  //    livre (`ingredients_text`) em itens, para não devolver "0 ingredientes"
  //    quando a OFF tem a lista só como texto.
  let sourceIngredients = ingredients;
  if ((!ingredients || ingredients.length === 0) && product) {
    if (
      Array.isArray(product.ingredients_list) &&
      product.ingredients_list.length > 0
    ) {
      sourceIngredients = product.ingredients_list;
    } else if (
      typeof product.ingredients_text === 'string' &&
      product.ingredients_text.trim()
    ) {
      sourceIngredients = splitIngredientsText(product.ingredients_text);
    }
  }

  const analyzed = sourceIngredients.map((name) =>
    analyzeIngredient(name, disorders, customAllergens)
  );

  // Alertas vindos das allergens_tags oficiais (OFF) que casam com perfil
  const officialAllergens = mapOfficialAllergens(product, disorders);

  // Traços declarados pela OFF (traces_tags): presença POSSÍVEL por contaminação
  // cruzada. Costumam existir mesmo quando a lista de ingredientes não foi
  // cadastrada — então recuperam alertas que, de outro modo, se perderiam.
  const officialTraces = mapOfficialTraces(product, disorders);

  const flagged = analyzed.filter((i) => i.is_flagged);

  return {
    ingredients: analyzed,
    flagged_ingredients: flagged,
    official_allergens: officialAllergens, // ex.: ["en:milk", "en:gluten"]
    official_traces: officialTraces, // traços oficiais (OFF traces_tags)
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

function mapOfficialTraces(product, disorders) {
  if (!product || !Array.isArray(product.traces_tags)) return [];
  const matched = [];
  for (const tag of product.traces_tags) {
    const associated = offAllergenToDisorders[tag] || [];
    const relevant = associated.filter((d) => disorders.includes(d));
    if (relevant.length) {
      matched.push({ tag, disorders: relevant });
    }
  }
  return matched;
}

/**
 * Parte o texto livre de ingredientes da OFF (`ingredients_text`) numa lista de
 * itens. Fallback para quando o array estruturado (`ingredients`) não foi
 * cadastrado. Separa apenas nas vírgulas/;/quebras de linha de nível superior —
 * vírgulas dentro de parênteses (ex.: "farinha (trigo 34,8 %)") ficam no item.
 */
function splitIngredientsText(text) {
  const s = String(text || '');
  const parts = [];
  let depth = 0;
  let buf = '';
  for (const ch of s) {
    if (ch === '(' || ch === '[') depth++;
    else if (ch === ')' || ch === ']') depth = Math.max(0, depth - 1);

    if ((ch === ',' || ch === ';' || ch === '\n') && depth === 0) {
      if (buf.trim()) parts.push(buf.trim());
      buf = '';
    } else {
      buf += ch;
    }
  }
  if (buf.trim()) parts.push(buf.trim());

  return parts
    .map((p) => p.replace(/\.+$/, '').trim())
    // Descarta fragmentos sem letra (números, percentuais soltos, pontuação).
    .filter((p) => p && /[a-zà-ÿ]/i.test(p));
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

module.exports = {
  analyze,
  matchesAsWord,
  inflectionForms,
  normalize,
  splitIngredientsText,
};
