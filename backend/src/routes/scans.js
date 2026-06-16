const express = require('express');
const router = express.Router();
const ScanResult = require('../models/ScanResult');

// GET /api/scans - Lista todos os scans (mais recentes primeiro)
router.get('/', async (req, res) => {
  try {
    const scans = await ScanResult.find().sort({ scanned_at: -1 }).limit(50);
    res.json(scans);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/scans/:id - Busca scan por ID
router.get('/:id', async (req, res) => {
  try {
    const scan = await ScanResult.findById(req.params.id);
    if (!scan) {
      return res.status(404).json({ error: 'Scan não encontrado' });
    }
    res.json(scan);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/scans - Cria novo scan
router.post('/', async (req, res) => {
  try {
    const scan = new ScanResult(req.body);
    const saved = await scan.save();
    res.status(201).json(saved);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// DELETE /api/scans/:id - Remove scan
router.delete('/:id', async (req, res) => {
  try {
    const scan = await ScanResult.findByIdAndDelete(req.params.id);
    if (!scan) {
      return res.status(404).json({ error: 'Scan não encontrado' });
    }
    res.json({ message: 'Scan removido com sucesso' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
