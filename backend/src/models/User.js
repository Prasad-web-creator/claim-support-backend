const mongoose = require('mongoose');
const mongoosePaginate = require('mongoose-paginate-v2');
const baseSchemaFields = require('./BaseSchema');

const userSchema = new mongoose.Schema({
  ...baseSchemaFields,
  name: {
    type: String,
    required: true,
    trim: true,
  },
  email: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    lowercase: true,
  },
  phone: {
    type: String,
    trim: true,
    index: true,
  },
  refreshToken: {
    type: String,
    default: null
  },
  refreshTokenExpiry: {
    type: Date,
    default: null
  }
}, { timestamps: true });

userSchema.plugin(mongoosePaginate);

module.exports = mongoose.model('User', userSchema);
