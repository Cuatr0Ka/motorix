import { Router } from 'express';
import * as notificationController from '../controllers/notificationController.js';
import { authenticate } from '../middlewares/authenticate.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { readNoticesSchema } from '../validators/noticeValidators.js';

const router = Router();

// Cualquier usuario autenticado consulta sus avisos; el servicio decide cuáles le corresponden según su rol vigente.
router.use(authenticate);

router.get('/', asyncHandler(notificationController.list));

// Marcar como leído: solo registra los avisos vigentes del usuario; las claves ajenas o vencidas se ignoran sin error.
router.post('/read', validate({ body: readNoticesSchema }), asyncHandler(notificationController.markRead));

export default router;
