import { Router } from 'express';
import { reportController } from '../controllers/reportController.js';
import { authenticate } from '../middlewares/authenticate.js';
import { authorize, ROLES } from '../middlewares/authorize.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { reportQuery } from '../validators/reportValidators.js';

const router = Router();

// Los reportes (con costos y márgenes) son exclusivos del administrador.
router.use(authenticate, authorize(ROLES.ADMIN));

for (const name of ['income', 'services', 'productivity', 'parts', 'rotation']) {
  router.get(`/${name}`, validate({ query: reportQuery }), asyncHandler(reportController(name)));
}

export default router;
