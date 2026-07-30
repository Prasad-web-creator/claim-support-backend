const mongoose = require('mongoose');

const counterSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  entityType: {
    type: String,
    required: true, // e.g., 'Policy', 'Prescription', 'AnalysisReport'
  },
  seq: {
    type: Number,
    default: 0,
  }
});

// Compound unique index so each user has their own sequence per entity type
counterSchema.index({ userId: 1, entityType: 1 }, { unique: true });

module.exports = mongoose.model('Counter', counterSchema);
