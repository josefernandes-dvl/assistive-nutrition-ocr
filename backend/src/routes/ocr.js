const express = require('express');
const router = express.Router();

const { analyze } = require('../services/ingredientAnalyzer');
const { getProductByBarcode } = require('../services/openFoodFacts');

/**
 * POST /api/ocr/analyze
 * Body:
 *   {
 *     ingredients?: string[],   // lista vinda do OCR mobile (opcional se barcode)
 *     barcode?: string,         // se enviado, busca produto no OFF
 *     disorders: string[],      // distúrbios do perfil
 *     customAllergens?: string[]
 *   }
 *
 * Resposta: { ingredients, flagged_ingredients, official_allergens, summary, product }
 */
router.post('/analyze', async (req, res) => {
  try {
    const {
      ingredients = [],
      barcode = null,
      disorders = [],
      customAllergens = [],
    } = req.body || {};

    if (!Array.isArray(disorders)) {
      return res.status(400).json({ error: 'disorders deve ser um array' });
    }
    if (!Array.isArray(ingredients)) {
      return res.status(400).json({ error: 'ingredients deve ser um array' });
    }
    if (!barcode && ingredients.length === 0) {
      return res
        .status(400)
        .json({ error: 'Envie ao menos "ingredients" ou "barcode"' });
    }

    let product = null;
    if (barcode) {
      try {
        product = await getProductByBarcode(barcode);
      } catch (err) {
        // Falha de rede ao consultar OFF não bloqueia a análise local.
        product = null;
      }
    }

    const result = analyze({
      ingredients,
      disorders,
      customAllergens,
      product,
    });

    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
