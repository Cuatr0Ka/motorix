import { Router } from 'express';
import appointmentRoutes from './appointmentRoutes.js';
import authRoutes from './authRoutes.js';
import clientRoutes from './clientRoutes.js';
import mechanicRoutes from './mechanicRoutes.js';
import orderRoutes from './orderRoutes.js';
import userRoutes from './userRoutes.js';
import vehicleRoutes from './vehicleRoutes.js';

// Los routers de cada módulo se montan aquí a medida que se implementan las historias.
const router = Router();

router.get('/health', (req, res) => {
  res.json({ data: { status: 'ok' } });
});

router.use('/auth', authRoutes);
router.use('/clients', clientRoutes);
router.use('/vehicles', vehicleRoutes);
router.use('/users', userRoutes);
router.use('/appointments', appointmentRoutes);
router.use('/orders', orderRoutes);
router.use('/mechanics', mechanicRoutes);

export default router;
