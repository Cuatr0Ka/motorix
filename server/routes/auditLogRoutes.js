import { Router } from 'express';
import * as auditLogController from '../controllers/auditLogController.js';
import { authenticate } from '../middlewares/authenticate.js';
import { authorize, ROLES } from '../middlewares/authorize.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { auditLogQuery } from '../validators/auditValidators.js';

const router = Router();

// La bitácora es de solo lectura y solo del administrador: no existe ninguna ruta POST, PUT, PATCH ni DELETE.
router.get('/', authenticate, authorize(ROLES.ADMIN), validate({ query: auditLogQuery }), asyncHandler(auditLogController.list));

export default router;
