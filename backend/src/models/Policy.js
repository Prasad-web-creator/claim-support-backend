const mongoose = require('mongoose');
const mongoosePaginate = require('mongoose-paginate-v2');
const baseSchemaFields = require('./BaseSchema');

const policySchema = new mongoose.Schema({
  ...baseSchemaFields,
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  policyNumber: { type: String, trim: true, maxlength: 255 },
  policyName: { type: String, trim: true, maxlength: 255 },
  insuranceCompany: { type: String, trim: true, maxlength: 255 },
  policyType: { type: String, trim: true, maxlength: 255 },
  policyStartDate: { type: Date },
  policyEndDate: { type: Date },
  coverageAmount: { type: Number, min: 0 },
  status: { type: String, default: 'Active', trim: true, maxlength: 50 },
  gridFsFileId: { type: mongoose.Schema.Types.ObjectId, ref: 'fs.files' },
  originalFileName: { type: String, trim: true, maxlength: 255 },
  mimeType: { type: String, trim: true, maxlength: 255 },
  fileSize: { type: Number, min: 0 },
  sequenceNumber: { type: Number, min: 0 },
  agreement: {
    accepted: { type: Boolean },
    termsAccepted: { type: Boolean },
    termsVersion: { type: String, trim: true, maxlength: 50 },
    acceptedAt: { type: Date },
    appVersion: { type: String, trim: true, maxlength: 50 },
    platform: { type: String, trim: true, maxlength: 50 },
  },
}, { timestamps: true, strict: true });

// Compound index for optimal dashboard counts and pagination
policySchema.index({ userId: 1, isDeleted: 1, createdAt: -1 });

policySchema.pre('save', async function(next) {
  if (this.isNew) {
    const Counter = require('./Counter');
    const counter = await Counter.findOneAndUpdate(
      { userId: this.userId, entityType: 'Policy' },
      { $inc: { seq: 1 } },
      { new: true, upsert: true }
    );
    this.sequenceNumber = counter.seq;
  }
  next();
});

policySchema.plugin(mongoosePaginate);

module.exports = mongoose.model('Policy', policySchema);
