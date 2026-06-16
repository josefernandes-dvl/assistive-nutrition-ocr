const express = require('express');
const router = express.Router();
const UserProfile = require('../models/UserProfile');

// GET /api/profiles/current - Busca perfil atual (último criado)
router.get('/current', async (req, res) => {
  try {
    const profile = await UserProfile.findOne().sort({ createdAt: -1 });
    if (!profile) {
      return res.status(404).json({ error: 'Nenhum perfil encontrado' });
    }
    res.json(profile);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/profiles - Cria ou atualiza perfil
router.post('/', async (req, res) => {
  try {
    // Atualiza o perfil existente ou cria um novo
    const existing = await UserProfile.findOne().sort({ createdAt: -1 });

    if (existing) {
      existing.name = req.body.name;
      existing.disorders = req.body.disorders;
      existing.custom_allergens = req.body.custom_allergens || [];
      const saved = await existing.save();
      return res.status(200).json(saved);
    }

    const profile = new UserProfile(req.body);
    const saved = await profile.save();
    res.status(201).json(saved);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

module.exports = router;
