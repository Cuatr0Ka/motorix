import { Router } from 'express';
import * as notificationController from '../controllers/notificationController.js';
import { authenticate } from '../middlewares/authenticate.js';
import { asyncHandler } from '../utils/asyncHandler.js';

const router = Router();

// Cualquier usuario autenticado consulta sus avisos; el servicio decide cuáles le corresponden según su rol vigente.
router.use(authenticate);

router.get('/', asyncHandler(notificationController.list));

export default router;
