const mongoose = require('mongoose');
const mongoosePaginate = require('mongoose-paginate-v2');
const baseSchemaFields = require('./BaseSchema');

const prescriptionSchema = new mongoose.Schema({
  ...baseSchemaFields,
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  hospitalName: { type: String, trim: true, maxlength: 255 },
  doctorName: { type: String, trim: true, maxlength: 255 },
  visitDate: { type: Date },
  diagnosis: { type: String, trim: true, maxlength: 1000 },
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
prescriptionSchema.index({ userId: 1, isDeleted: 1, createdAt: -1 });

prescriptionSchema.pre('save', async function(next) {
  if (this.isNew) {
    const Counter = require('./Counter');
    const counter = await Counter.findOneAndUpdate(
      { userId: this.userId, entityType: 'Prescription' },
      { $inc: { seq: 1 } },
      { new: true, upsert: true }
    );
    this.sequenceNumber = counter.seq;
  }
  next();
});

prescriptionSchema.plugin(mongoosePaginate);

module.exports = mongoose.model('Prescription', prescriptionSchema);
