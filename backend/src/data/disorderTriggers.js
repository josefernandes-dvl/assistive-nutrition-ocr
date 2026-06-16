/**
 * Fonte única de verdade para correlação distúrbio ↔ ingredientes problemáticos.
 * Espelhada de mobile/lib/core/constants.dart — manter sincronizado.
 *
 * Os triggers são em PT-BR sem acentos (o matching usa normalização Unicode).
 */

const disorderTriggers = {
  'Intolerância à Lactose': [
    'leite', 'lactose', 'soro de leite', 'soro do leite', 'soro lacteo',
    'caseina', 'caseinato', 'manteiga', 'creme de leite', 'queijo', 'iogurte',
    'nata', 'whey', 'lactalbumina', 'leite em po', 'leite condensado',
  ],
  'Doença Celíaca': [
    'trigo', 'gluten', 'cevada', 'centeio', 'malte', 'farinha de trigo',
    'amido de trigo', 'semolina', 'espelta', 'kamut', 'triticale',
    'farelo de trigo', 'germen de trigo', 'extrato de malte', 'cerveja',
  ],
  'Síndrome do Intestino Irritável (SII)': [
    'lactose', 'frutose', 'sorbitol', 'manitol', 'xilitol', 'maltitol',
    'inulina', 'frutano', 'galactano', 'cebola', 'alho', 'gluten',
  ],
  'Doença de Crohn': [
    'lactose', 'gluten', 'cafeina', 'alcool', 'gordura trans',
    'gordura hidrogenada', 'corante artificial', 'edulcorante',
  ],
  'Colite Ulcerativa': [
    'lactose', 'gluten', 'cafeina', 'alcool', 'pimenta', 'gordura trans',
    'conservante', 'aromatizante artificial',
  ],
  'Alergia à Proteína do Leite (APLV)': [
    'leite', 'caseina', 'caseinato', 'soro de leite', 'whey', 'manteiga',
    'creme de leite', 'queijo', 'iogurte', 'lactoalbumina', 'lactoglobulina',
  ],
  'Alergia ao Ovo': [
    'ovo', 'ovos', 'clara de ovo', 'gema', 'albumina', 'ovoalbumina',
    'lecitina de ovo', 'lisozima',
  ],
  'Alergia ao Amendoim': [
    'amendoim', 'pasta de amendoim', 'oleo de amendoim', 'arachis',
  ],
  'Alergia à Soja': [
    'soja', 'lecitina de soja', 'proteina de soja', 'oleo de soja',
    'extrato de soja', 'molho de soja', 'shoyu', 'tofu',
  ],
  'Intolerância à Frutose': [
    'frutose', 'xarope de milho', 'xarope de glicose-frutose', 'mel', 'agave',
    'sorbitol', 'xarope de frutose', 'sacarose',
  ],
  'FODMAP Sensível': [
    'frutose', 'lactose', 'sorbitol', 'manitol', 'xilitol', 'maltitol',
    'inulina', 'frutano', 'oligofrutose', 'cebola', 'alho', 'trigo',
  ],
  'Refluxo Gastroesofágico (DRGE)': [
    'cafeina', 'chocolate', 'hortela', 'menta', 'pimenta', 'tomate',
    'cebola', 'alho', 'alcool', 'gordura hidrogenada',
  ],
};

/**
 * Mapeamento das `allergens_tags` oficiais do Open Food Facts → distúrbios.
 * As tags vêm no formato "en:milk", "en:gluten", etc.
 */
const offAllergenToDisorders = {
  'en:gluten': ['Doença Celíaca', 'FODMAP Sensível', 'Doença de Crohn', 'Colite Ulcerativa'],
  'en:milk': ['Alergia à Proteína do Leite (APLV)', 'Intolerância à Lactose'],
  'en:lactose': ['Intolerância à Lactose'],
  'en:eggs': ['Alergia ao Ovo'],
  'en:peanuts': ['Alergia ao Amendoim'],
  'en:soybeans': ['Alergia à Soja'],
  'en:nuts': [],
  'en:fish': [],
  'en:crustaceans': [],
  'en:shellfish': [],
  'en:sesame-seeds': [],
  'en:mustard': [],
  'en:celery': [],
  'en:sulphur-dioxide-and-sulphites': [],
  'en:molluscs': [],
};

module.exports = {
  disorderTriggers,
  offAllergenToDisorders,
};
