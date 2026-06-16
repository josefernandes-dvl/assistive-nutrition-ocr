const axios = require('axios');
const NodeCache = require('node-cache');

const BASE_URL = 'https://world.openfoodfacts.org';
const USER_AGENT = 'NutriScan-IC/1.0 (assistive-nutrition-ocr; contato: projeto-ic)';

// Cache em memória: 1h para produtos, 5min para buscas
const productCache = new NodeCache({ stdTTL: 3600, checkperiod: 600 });
const searchCache = new NodeCache({ stdTTL: 300, checkperiod: 120 });

const client = axios.create({
  baseURL: BASE_URL,
  timeout: 8000,
  headers: { 'User-Agent': USER_AGENT, Accept: 'application/json' },
});

/**
 * Busca um produto por código de barras (EAN/UPC).
 * Retorna o payload simplificado ou null se não encontrado.
 */
async function getProductByBarcode(barcode) {
  const code = String(barcode).trim();
  if (!code) return null;

  const cached = productCache.get(code);
  if (cached !== undefined) return cached;

  try {
    const { data } = await client.get(`/api/v2/product/${code}.json`);
    if (data.status !== 1 || !data.product) {
      productCache.set(code, null);
      return null;
    }
    const simplified = simplifyProduct(data.product);
    productCache.set(code, simplified);
    return simplified;
  } catch (err) {
    if (err.response && err.response.status === 404) {
      productCache.set(code, null);
      return null;
    }
    throw err;
  }
}

/**
 * Busca produtos por texto (catálogo).
 */
async function searchProductsByText(query, limit = 5) {
  const q = String(query || '').trim();
  if (!q) return [];
  const key = `${q}|${limit}`;
  const cached = searchCache.get(key);
  if (cached !== undefined) return cached;

  try {
    const { data } = await client.get('/cgi/search.pl', {
      params: {
        search_terms: q,
        search_simple: 1,
        action: 'process',
        json: 1,
        page_size: limit,
      },
    });
    const products = (data.products || []).map(simplifyProduct);
    searchCache.set(key, products);
    return products;
  } catch (_) {
    return [];
  }
}

/**
 * Reduz o payload completo da OFF para apenas o que o app consome.
 */
function simplifyProduct(p) {
  const nutriments = p.nutriments || {};
  return {
    barcode: p.code || null,
    name: p.product_name_pt || p.product_name || null,
    brand: p.brands || null,
    image_url: p.image_url || p.image_front_url || null,
    ingredients_text:
      p.ingredients_text_pt || p.ingredients_text || p.ingredients_text_en || '',
    ingredients_list: Array.isArray(p.ingredients)
      ? p.ingredients.map((i) => i.text).filter(Boolean)
      : [],
    allergens_tags: Array.isArray(p.allergens_tags) ? p.allergens_tags : [],
    traces_tags: Array.isArray(p.traces_tags) ? p.traces_tags : [],
    additives_tags: Array.isArray(p.additives_tags) ? p.additives_tags : [],
    nova_group: p.nova_group ?? null,
    nutriscore_grade: p.nutriscore_grade || null,
    nutriments: {
      calories: numOr(nutriments['energy-kcal_100g']),
      total_fat: numOr(nutriments['fat_100g']),
      saturated_fat: numOr(nutriments['saturated-fat_100g']),
      carbohydrates: numOr(nutriments['carbohydrates_100g']),
      sugars: numOr(nutriments['sugars_100g']),
      fiber: numOr(nutriments['fiber_100g']),
      protein: numOr(nutriments['proteins_100g']),
      sodium: numOr(nutriments['sodium_100g']),
    },
  };
}

function numOr(v) {
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

module.exports = {
  getProductByBarcode,
  searchProductsByText,
};
