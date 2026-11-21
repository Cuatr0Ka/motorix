import { Router } from 'express';
import * as termsController from '../controllers/termsController.js';
import { authenticate } from '../middlewares/authenticate.js';
import { authorize, ROLES } from '../middlewares/authorize.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { acceptTermsSchema, acceptancesQuery } from '../validators/termsValidators.js';

const router = Router();

router.use(authenticate);

// Cualquier usuario autenticado, aun sin haber aceptado (son las rutas que permiten aceptar).
router.get('/current', asyncHandler(termsController.current));
router.post('/accept', validate({ body: acceptTermsSchema }), asyncHandler(termsController.accept));

// Quién aceptó y quién falta: solo administración.
router.get('/acceptances', authorize(ROLES.ADMIN), validate({ query: acceptancesQuery }), asyncHandler(termsController.acceptances));

export default router;
