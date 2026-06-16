const mongoose = require('mongoose');

const userProfileSchema = new mongoose.Schema({
  name: { type: String, required: true },
  disorders: [{ type: String }],
  custom_allergens: [{ type: String }],
}, {
  timestamps: true,
});

module.exports = mongoose.model('UserProfile', userProfileSchema);
