import { Router } from 'express';
import * as appointmentController from '../controllers/appointmentController.js';
import { authenticate } from '../middlewares/authenticate.js';
import { authorize, ROLES } from '../middlewares/authorize.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import {
  cancelAppointmentSchema,
  createAppointmentSchema,
  listAppointmentsQuery,
  updateAppointmentSchema,
} from '../validators/appointmentValidators.js';
import { idParams } from '../validators/common.js';

const router = Router();

// Las citas son solo de ADMIN y RECEPTIONIST. No existe ruta DELETE: las citas se cancelan.
router.use(authenticate, authorize(ROLES.ADMIN, ROLES.RECEPTIONIST));

router.get('/', validate({ query: listAppointmentsQuery }), asyncHandler(appointmentController.list));
router.post('/', validate({ body: createAppointmentSchema }), asyncHandler(appointmentController.create));
router.get('/:id', validate({ params: idParams }), asyncHandler(appointmentController.getById));
router.patch(
  '/:id',
  validate({ params: idParams, body: updateAppointmentSchema }),
  asyncHandler(appointmentController.update),
);
router.post('/:id/confirm', validate({ params: idParams }), asyncHandler(appointmentController.confirm));
router.post(
  '/:id/cancel',
  validate({ params: idParams, body: cancelAppointmentSchema }),
  asyncHandler(appointmentController.cancel),
);

export default router;
