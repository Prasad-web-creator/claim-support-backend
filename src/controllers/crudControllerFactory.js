const mongoose = require('mongoose');
const ActivityLog = require('../models/ActivityLog');
const AnalysisReport = require('../models/AnalysisReport');
const StoredFile = require('../models/StoredFile');
const logger = require('../utils/logger');

const escapeRegex = (string) => string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const crudControllerFactory = (Model, entityName, searchableFields = []) => {
  return {
    create: async (req, res) => {
      try {
        const reqBody = { ...req.body };
        
        // Securely inject server-side timestamp and accepted flag if agreement is present
        if (reqBody.agreement && reqBody.agreement.termsAccepted) {
          reqBody.agreement.accepted = true;
          reqBody.agreement.acceptedAt = new Date();
        }

        const doc = new Model({
          ...reqBody,
          userId: req.user.id,
          createdBy: req.user.id,
        });
        await doc.save();
        
        await ActivityLog.create({
          userId: req.user.id,
          action: `You uploaded the ${entityName.toLowerCase()}`,
          entityType: entityName,
          entityId: doc._id,
        });

        res.status(201).json(doc);
      } catch (error) {
        logger.error(`[crudControllerFactory.create] Error creating ${entityName}: ${error.message}`, { stack: error.stack });
        res.status(500).json({ message: `Error creating ${entityName}` });
      }
    },

    getById: async (req, res) => {
      try {
        const doc = await Model.findOne({ _id: req.params.id, userId: req.user.id, isDeleted: false });
        if (!doc) return res.status(404).json({ message: `${entityName} not found` });
        res.json(doc);
      } catch (error) {
        logger.error(`[crudControllerFactory.getById] Error retrieving ${entityName}: ${error.message}`, { stack: error.stack });
        res.status(500).json({ message: `Error retrieving ${entityName}` });
      }
    },

    update: async (req, res) => {
      try {
        const doc = await Model.findOneAndUpdate(
          { _id: req.params.id, userId: req.user.id, isDeleted: false },
          { ...req.body, updatedBy: req.user.id },
          { new: true }
        );
        if (!doc) return res.status(404).json({ message: `${entityName} not found` });

        await ActivityLog.create({
          userId: req.user.id,
          action: `Updated ${entityName}`,
          entityType: entityName,
          entityId: doc._id,
        });

        res.json(doc);
      } catch (error) {
        logger.error(`[crudControllerFactory.update] Error updating ${entityName}: ${error.message}`, { stack: error.stack });
        res.status(500).json({ message: `Error updating ${entityName}` });
      }
    },

    delete: async (req, res) => {
      const session = await mongoose.startSession();
      try {
        let doc;
        await session.withTransaction(async () => {
          // Soft Delete Main Entity
          doc = await Model.findOneAndUpdate(
            { _id: req.params.id, userId: req.user.id, isDeleted: false },
            { isDeleted: true, updatedBy: req.user.id },
            { new: true, session }
          );
          
          if (!doc) {
            throw new Error('NOT_FOUND');
          }

          // Cascade Soft Deletes
          if (entityName === 'Policy' || entityName === 'Prescription') {
            const childQuery = entityName === 'Policy' ? { policyId: doc._id } : { prescriptionId: doc._id };
            await AnalysisReport.updateMany(
              { ...childQuery, userId: req.user.id, isDeleted: false },
              { isDeleted: true, updatedBy: req.user.id },
              { session }
            );

            await StoredFile.updateMany(
              { documentId: doc._id, userId: req.user.id, isDeleted: false },
              { isDeleted: true },
              { session }
            );
          }

          await ActivityLog.create([{
            userId: req.user.id,
            action: `Deleted ${entityName}`,
            entityType: entityName,
            entityId: doc._id,
          }], { session });
        });
        
        session.endSession();
        res.json({ message: `${entityName} deleted successfully` });
      } catch (error) {
        await session.abortTransaction();
        session.endSession();
        logger.error(`[crudControllerFactory.delete] Error deleting ${entityName}: ${error.message}`, { stack: error.stack });
        if (error.message === 'NOT_FOUND') {
          return res.status(404).json({ message: `${entityName} not found` });
        }
        res.status(500).json({ message: `Error deleting ${entityName}` });
      }
    },

    list: async (req, res) => {
      try {
        const { page = 1, limit = 10, search, sortBy = 'createdAt', sortOrder = 'desc', ...filters } = req.query;
        
        let query = { isDeleted: false, userId: req.user.id };

        // Apply filters
        Object.keys(filters).forEach(key => {
          if (filters[key]) {
            query[key] = filters[key];
          }
        });

        // Escape regex to prevent ReDoS
        const safeSearch = search ? escapeRegex(search) : '';

        // Apply search
        if (safeSearch) {
          const orConditions = [];

          // String fields
          if (searchableFields && searchableFields.length > 0) {
            orConditions.push(...searchableFields.map(field => ({
              [field]: { $regex: safeSearch, $options: 'i' }
            })));
          }

          // Search by ID if valid
          if (mongoose.Types.ObjectId.isValid(search)) {
            orConditions.push({ _id: search });
          }

          // Search by Date (createdAt) using indexed range if search is a valid date
          const parsedDate = Date.parse(search);
          if (!isNaN(parsedDate)) {
            const startOfDay = new Date(parsedDate);
            startOfDay.setHours(0, 0, 0, 0);
            
            const endOfDay = new Date(parsedDate);
            endOfDay.setHours(23, 59, 59, 999);
            
            orConditions.push({
              createdAt: { $gte: startOfDay, $lte: endOfDay }
            });
          }

          if (orConditions.length > 0) {
            query.$or = orConditions;
          }
        }

        const parsedLimit = parseInt(limit, 10) || 10;
        const safeLimit = Math.min(Math.max(parsedLimit, 1), 100);

        const options = {
          page: parseInt(page, 10),
          limit: safeLimit,
          sort: { [sortBy]: sortOrder === 'desc' ? -1 : 1 }
        };

        const result = await Model.paginate(query, options);
        res.json(result);
      } catch (error) {
        logger.error(`[crudControllerFactory.getAll] Error retrieving ${entityName}s: ${error.message}`, { stack: error.stack });
        res.status(500).json({ message: `Error retrieving ${entityName}s` });
      }
    }
  };
};

module.exports = crudControllerFactory;
