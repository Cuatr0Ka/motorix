import { Router } from 'express';
import * as settingsController from '../controllers/settingsController.js';
import { authenticate } from '../middlewares/authenticate.js';
import { authorize, ROLES } from '../middlewares/authorize.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { updateSettingsSchema } from '../validators/settingsValidators.js';

const router = Router();

// La configuración es exclusiva del administrador; los demás roles reciben 403 aunque la solicitud no venga de la interfaz.
router.use(authenticate, authorize(ROLES.ADMIN));

router.get('/', asyncHandler(settingsController.get));
router.put('/', validate({ body: updateSettingsSchema }), asyncHandler(settingsController.update));

export default router;
