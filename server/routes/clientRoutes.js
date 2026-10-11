import { Router } from 'express';
import * as clientController from '../controllers/clientController.js';
import { authenticate } from '../middlewares/authenticate.js';
import { authorize, ROLES } from '../middlewares/authorize.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { createClientSchema, listClientsQuery, updateClientSchema } from '../validators/clientValidators.js';
import { idParams } from '../validators/common.js';

const router = Router();

// Todos los roles pueden consultar; solo ADMIN y RECEPTIONIST pueden crear o editar.
router.use(authenticate);

router.get('/', validate({ query: listClientsQuery }), asyncHandler(clientController.list));
router.get('/:id', validate({ params: idParams }), asyncHandler(clientController.getById));
router.post(
  '/',
  authorize(ROLES.ADMIN, ROLES.RECEPTIONIST),
  validate({ body: createClientSchema }),
  asyncHandler(clientController.create),
);
router.patch(
  '/:id',
  authorize(ROLES.ADMIN, ROLES.RECEPTIONIST),
  validate({ params: idParams, body: updateClientSchema }),
  asyncHandler(clientController.update),
);

export default router;
