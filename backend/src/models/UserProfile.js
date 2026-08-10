const mongoose = require('mongoose');

const userProfileSchema = new mongoose.Schema({
  // RNF15 — anonimato por design: o backend NÃO exige um identificador pessoal
  // direto. O nome é opcional (default vazio); o perfil funciona sem ele.
  name: { type: String, default: '', trim: true },
  disorders: [{ type: String }],
  custom_allergens: [{ type: String }],
}, {
  timestamps: true,
});

module.exports = mongoose.model('UserProfile', userProfileSchema);
