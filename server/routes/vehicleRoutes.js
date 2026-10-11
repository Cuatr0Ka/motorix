import { Router } from 'express';
import * as vehicleController from '../controllers/vehicleController.js';
import { authenticate } from '../middlewares/authenticate.js';
import { authorize, ROLES } from '../middlewares/authorize.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { idParams } from '../validators/common.js';
import { createVehicleSchema, listVehiclesQuery, updateVehicleSchema } from '../validators/vehicleValidators.js';

const router = Router();

// Todos los roles pueden consultar; solo ADMIN y RECEPTIONIST pueden crear o editar.
router.use(authenticate);

router.get('/', validate({ query: listVehiclesQuery }), asyncHandler(vehicleController.list));
router.get('/:id', validate({ params: idParams }), asyncHandler(vehicleController.getById));
router.post(
  '/',
  authorize(ROLES.ADMIN, ROLES.RECEPTIONIST),
  validate({ body: createVehicleSchema }),
  asyncHandler(vehicleController.create),
);
router.patch(
  '/:id',
  authorize(ROLES.ADMIN, ROLES.RECEPTIONIST),
  validate({ params: idParams, body: updateVehicleSchema }),
  asyncHandler(vehicleController.update),
);

export default router;
