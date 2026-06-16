const mongoose = require('mongoose');

const ingredientSchema = new mongoose.Schema({
  name: { type: String, required: true },
  is_flagged: { type: Boolean, default: false },
  flag_reason: { type: String, default: null },
  related_disorder: { type: String, default: null },
});

const nutritionSchema = new mongoose.Schema({
  calories: Number,
  total_fat: Number,
  saturated_fat: Number,
  carbohydrates: Number,
  sugars: Number,
  fiber: Number,
  protein: Number,
  sodium: Number,
});

const scanResultSchema = new mongoose.Schema({
  raw_text: { type: String, required: true },
  ingredients: [ingredientSchema],
  nutrition_info: { type: nutritionSchema, default: null },
  flagged_ingredients: [ingredientSchema],
  image_path: { type: String, default: null },
  scanned_at: { type: Date, default: Date.now },
}, {
  timestamps: true,
});

module.exports = mongoose.model('ScanResult', scanResultSchema);
