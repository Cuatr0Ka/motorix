import { Router } from 'express';
import * as clientNoticeController from '../controllers/clientNoticeController.js';
import { authenticate } from '../middlewares/authenticate.js';
import { authorize, ROLES } from '../middlewares/authorize.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { createClientNoticeSchema } from '../validators/noticeValidators.js';

const router = Router();

// La lista y el registro del aviso son solo de administración y recepción; el mecánico recibe 403 aunque la
// solicitud no venga de la interfaz. No hay ruta DELETE: un aviso registrado no se deshace.
router.use(authenticate, authorize(ROLES.ADMIN, ROLES.RECEPTIONIST));

router.get('/', asyncHandler(clientNoticeController.list));
router.post('/', validate({ body: createClientNoticeSchema }), asyncHandler(clientNoticeController.register));

export default router;
