const express = require('express');
const router = express.Router();
const Prescription = require('../models/Prescription');
const crudControllerFactory = require('../controllers/crudControllerFactory');
const auth = require('../middleware/authMiddleware');

const controller = crudControllerFactory(Prescription, 'Prescription', ['hospitalName', 'doctorName', 'diagnosis']);

router.use(auth);

router.post('/', controller.create);
router.get('/', controller.list);
router.get('/:id', controller.getById);
router.put('/:id', controller.update);
router.delete('/:id', controller.delete);

module.exports = router;
