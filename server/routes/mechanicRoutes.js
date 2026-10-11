import { Router } from 'express';
import * as mechanicController from '../controllers/mechanicController.js';
import { authenticate } from '../middlewares/authenticate.js';
import { authorize, ROLES } from '../middlewares/authorize.js';
import { asyncHandler } from '../utils/asyncHandler.js';

const router = Router();

// Recepción y administración eligen mecánico sin acceder a la gestión de usuarios (/api/users).
router.use(authenticate, authorize(ROLES.ADMIN, ROLES.RECEPTIONIST));

router.get('/', asyncHandler(mechanicController.list));

export default router;
