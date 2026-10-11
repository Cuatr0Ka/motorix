import { Router } from 'express';
import * as inventoryController from '../controllers/inventoryController.js';
import * as partController from '../controllers/partController.js';
import { authenticate } from '../middlewares/authenticate.js';
import { authorize, ROLES } from '../middlewares/authorize.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { idParams } from '../validators/common.js';
import {
  createPartSchema,
  listPartsQuery,
  movementSchema,
  movementsQuery,
  updatePartSchema,
} from '../validators/partValidators.js';

const router = Router();

// No existe ruta DELETE ni PUT: las refacciones se desactivan y los movimientos se conservan.
router.use(authenticate);

const admin = authorize(ROLES.ADMIN);

// El catálogo lo consultan administradores y mecánicos (el servicio decide la proyección según el rol).
router.get('/', authorize(ROLES.ADMIN, ROLES.MECHANIC), validate({ query: listPartsQuery }), asyncHandler(partController.list));

// Alertas de stock bajo: debe declararse ANTES de '/:id' para que 'alerts' no se interprete como identificador.
router.get('/alerts', admin, asyncHandler(partController.alerts));

router.post('/', admin, validate({ body: createPartSchema }), asyncHandler(partController.create));
router.get('/:id', admin, validate({ params: idParams }), asyncHandler(partController.getById));
router.patch('/:id', admin, validate({ params: idParams, body: updatePartSchema }), asyncHandler(partController.update));

router.get(
  '/:id/movements',
  admin,
  validate({ params: idParams, query: movementsQuery }),
  asyncHandler(inventoryController.listMovements),
);
router.post(
  '/:id/movements',
  admin,
  validate({ params: idParams, body: movementSchema }),
  asyncHandler(inventoryController.registerMovement),
);

export default router;
