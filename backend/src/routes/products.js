const express = require('express');
const router = express.Router();

const {
  getProductByBarcode,
  searchProductsByText,
} = require('../services/openFoodFacts');

/**
 * GET /api/products/barcode/:code
 * Retorna o produto da Open Food Facts (já simplificado).
 */
router.get('/barcode/:code', async (req, res) => {
  try {
    const product = await getProductByBarcode(req.params.code);
    if (!product) {
      return res.status(404).json({ error: 'Produto não encontrado' });
    }
    res.json(product);
  } catch (err) {
    res.status(502).json({ error: 'Falha ao consultar Open Food Facts', detail: err.message });
  }
});

/**
 * GET /api/products/search?q=texto&limit=5
 */
router.get('/search', async (req, res) => {
  const q = String(req.query.q || '').trim();
  if (!q) return res.status(400).json({ error: 'Parâmetro "q" obrigatório' });
  const limit = Math.min(Number(req.query.limit) || 5, 20);
  try {
    const products = await searchProductsByText(q, limit);
    res.json(products);
  } catch (err) {
    res.status(502).json({ error: 'Falha ao consultar Open Food Facts', detail: err.message });
  }
});

module.exports = router;
