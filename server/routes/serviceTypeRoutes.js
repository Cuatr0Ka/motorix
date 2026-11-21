import { Router } from 'express';
import * as serviceTypeController from '../controllers/serviceTypeController.js';
import { authenticate } from '../middlewares/authenticate.js';
import { authorize, ROLES } from '../middlewares/authorize.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { idParams } from '../validators/common.js';
import { createServiceTypeSchema, listServiceTypesQuery, updateServiceTypeSchema } from '../validators/serviceTypeValidators.js';

const router = Router();

router.use(authenticate);

// Las opciones las usan el administrador y el mecánico al capturar una línea de servicio.
router.get('/options', authorize(ROLES.ADMIN, ROLES.MECHANIC), asyncHandler(serviceTypeController.options));

// La gestión del catálogo es solo del administrador. No existe DELETE: un tipo en uso se desactiva.
router.get('/', authorize(ROLES.ADMIN), validate({ query: listServiceTypesQuery }), asyncHandler(serviceTypeController.list));
router.post('/', authorize(ROLES.ADMIN), validate({ body: createServiceTypeSchema }), asyncHandler(serviceTypeController.create));
router.patch(
  '/:id',
  authorize(ROLES.ADMIN),
  validate({ params: idParams, body: updateServiceTypeSchema }),
  asyncHandler(serviceTypeController.update),
);

export default router;
