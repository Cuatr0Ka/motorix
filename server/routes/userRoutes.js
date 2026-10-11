import { Router } from 'express';
import * as userController from '../controllers/userController.js';
import { authenticate } from '../middlewares/authenticate.js';
import { authorize, ROLES } from '../middlewares/authorize.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { idParams } from '../validators/common.js';
import { createUserSchema, listUsersQuery, updateUserSchema } from '../validators/userValidators.js';

const router = Router();

// La gestión de usuarios es exclusiva del administrador.
router.use(authenticate, authorize(ROLES.ADMIN));

router.get('/', validate({ query: listUsersQuery }), asyncHandler(userController.list));
router.get('/:id', validate({ params: idParams }), asyncHandler(userController.getById));
router.post('/', validate({ body: createUserSchema }), asyncHandler(userController.create));
router.patch(
  '/:id',
  validate({ params: idParams, body: updateUserSchema }),
  asyncHandler(userController.update),
);

export default router;
