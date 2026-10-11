import { Router } from 'express';
import * as orderController from '../controllers/orderController.js';
import * as orderWorkController from '../controllers/orderWorkController.js';
import { authenticate } from '../middlewares/authenticate.js';
import { authorize, ROLES } from '../middlewares/authorize.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { idParams } from '../validators/common.js';
import {
  assignMechanicSchema,
  changeStatusSchema,
  createLineSchema,
  createOrderSchema,
  lineParams,
  listOrdersQuery,
  updateLineSchema,
  updateWorkSchema,
} from '../validators/orderValidators.js';

const router = Router();

// Todos los roles autenticados consultan (el mecánico solo las suyas, lo resuelve el servicio).
// No existe ruta DELETE: las órdenes se conservan como historial (RN-9).
router.use(authenticate);

router.get('/', validate({ query: listOrdersQuery }), asyncHandler(orderController.list));
router.get('/:id', validate({ params: idParams }), asyncHandler(orderController.getById));
router.post(
  '/',
  authorize(ROLES.ADMIN, ROLES.RECEPTIONIST),
  validate({ body: createOrderSchema }),
  asyncHandler(orderController.create),
);

router.put(
  '/:id/mechanic',
  authorize(ROLES.ADMIN, ROLES.RECEPTIONIST),
  validate({ params: idParams, body: assignMechanicSchema }),
  asyncHandler(orderController.assignMechanic),
);

// Cambio de estado: la autorización fina (mecánico asignado, entrega) la resuelve el servicio.
router.post('/:id/status', validate({ params: idParams, body: changeStatusSchema }), asyncHandler(orderController.changeStatus));

// Trabajo de la orden: solo el mecánico asignado y el administrador (la pertenencia la valida el servicio).
const worker = authorize(ROLES.ADMIN, ROLES.MECHANIC);

router.patch(
  '/:id/work',
  worker,
  validate({ params: idParams, body: updateWorkSchema }),
  asyncHandler(orderWorkController.updateWork),
);

for (const [path, kind] of [
  ['services', 'services'],
  ['labor', 'labor'],
]) {
  const lines = orderWorkController.linesController(kind);
  router.post(`/:id/${path}`, worker, validate({ params: idParams, body: createLineSchema }), asyncHandler(lines.add));
  router.patch(
    `/:id/${path}/:lineId`,
    worker,
    validate({ params: lineParams, body: updateLineSchema }),
    asyncHandler(lines.update),
  );
  router.delete(`/:id/${path}/:lineId`, worker, validate({ params: lineParams }), asyncHandler(lines.remove));
}

export default router;
