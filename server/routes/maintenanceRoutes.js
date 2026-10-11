import { Router } from 'express';
import * as maintenanceController from '../controllers/maintenanceController.js';
import { authenticate } from '../middlewares/authenticate.js';
import { authorize, ROLES } from '../middlewares/authorize.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { idParams } from '../validators/common.js';
import { listMaintenanceQuery, updateMaintenanceSchema } from '../validators/maintenanceValidators.js';

const router = Router();

// No existe ruta DELETE: los mantenimientos se conservan (se marcan como Atendidos).
router.use(authenticate);

// Lista general con datos del cliente: solo recepción y administración.
router.get(
  '/',
  authorize(ROLES.ADMIN, ROLES.RECEPTIONIST),
  validate({ query: listMaintenanceQuery }),
  asyncHandler(maintenanceController.list),
);

// Edición y cierre: administrador y mecánico de la orden de origen (la pertenencia la valida el servicio).
const editor = authorize(ROLES.ADMIN, ROLES.MECHANIC);

router.patch(
  '/:id',
  editor,
  validate({ params: idParams, body: updateMaintenanceSchema }),
  asyncHandler(maintenanceController.update),
);
router.post('/:id/attend', editor, validate({ params: idParams }), asyncHandler(maintenanceController.attend));

export default router;
