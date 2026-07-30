const mongoose = require('mongoose');
const mongoosePaginate = require('mongoose-paginate-v2');
const baseSchemaFields = require('./BaseSchema');

const activityLogSchema = new mongoose.Schema({
  ...baseSchemaFields,
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  action: { type: String, required: true, trim: true, maxlength: 255 }, // e.g. 'Created Policy'
  entityType: { type: String, required: true, trim: true, maxlength: 100 }, // e.g. 'Policy'
  entityId: { type: mongoose.Schema.Types.ObjectId },
}, { timestamps: true, strict: true });

activityLogSchema.index({ userId: 1, isDeleted: 1, createdAt: -1 });

activityLogSchema.plugin(mongoosePaginate);

module.exports = mongoose.model('ActivityLog', activityLogSchema);
