import { Router } from 'express';
import * as paymentController from '../controllers/paymentController.js';
import { authenticate } from '../middlewares/authenticate.js';
import { authorize, ROLES } from '../middlewares/authorize.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { idParams } from '../validators/common.js';
import { listPaymentsQuery } from '../validators/paymentValidators.js';

const router = Router();

// Los pagos son de recepción y administración; el mecánico no accede a ninguna ruta.
// No existen rutas DELETE, PUT ni PATCH: los pagos se cancelan y se conservan como historial.
router.use(authenticate, authorize(ROLES.ADMIN, ROLES.RECEPTIONIST));

// 'methods' se declara ANTES de '/:id' para que no se interprete como identificador.
router.get('/methods', asyncHandler(paymentController.listMethods));
router.get('/', validate({ query: listPaymentsQuery }), asyncHandler(paymentController.list));
router.get('/:id', validate({ params: idParams }), asyncHandler(paymentController.getById));
router.post('/:id/refresh', validate({ params: idParams }), asyncHandler(paymentController.refresh));
router.post('/:id/cancel', validate({ params: idParams }), asyncHandler(paymentController.cancel));

export default router;
