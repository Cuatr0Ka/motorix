import { Router } from 'express';
import * as dashboardController from '../controllers/dashboardController.js';
import { authenticate } from '../middlewares/authenticate.js';
import { authorize, ROLES } from '../middlewares/authorize.js';
import { asyncHandler } from '../utils/asyncHandler.js';

const router = Router();

// El panel es exclusivo de administración; recepción y mecánico reciben 403 aunque la solicitud no venga de la interfaz.
router.get('/', authenticate, authorize(ROLES.ADMIN), asyncHandler(dashboardController.get));

export default router;
