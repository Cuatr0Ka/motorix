import { Router } from 'express';
import * as authController from '../controllers/authController.js';
import { authenticate } from '../middlewares/authenticate.js';
import { validate } from '../middlewares/validate.js';
import { loginSchema } from '../validators/authValidators.js';
import { changePasswordSchema } from '../validators/userValidators.js';
import { asyncHandler } from '../utils/asyncHandler.js';

const router = Router();

router.post('/login', validate({ body: loginSchema }), asyncHandler(authController.login));
router.get('/me', authenticate, authController.me);
router.post(
  '/change-password',
  authenticate,
  validate({ body: changePasswordSchema }),
  asyncHandler(authController.changePassword),
);

export default router;
