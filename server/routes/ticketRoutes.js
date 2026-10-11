import { Router } from 'express';
import * as ticketController from '../controllers/ticketController.js';
import { authenticate } from '../middlewares/authenticate.js';
import { authorize, ROLES } from '../middlewares/authorize.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { idParams } from '../validators/common.js';
import { listTicketsQuery } from '../validators/ticketValidators.js';

const router = Router();

// Los tickets son de recepción y administración; el mecánico no accede a ninguna ruta.
// No existen rutas DELETE, PUT ni PATCH: los tickets se conservan como comprobante.
router.use(authenticate, authorize(ROLES.ADMIN, ROLES.RECEPTIONIST));

router.get('/', validate({ query: listTicketsQuery }), asyncHandler(ticketController.list));
router.get('/:id', validate({ params: idParams }), asyncHandler(ticketController.getById));

export default router;
