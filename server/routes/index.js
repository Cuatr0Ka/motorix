import { Router } from 'express';
import appointmentRoutes from './appointmentRoutes.js';
import authRoutes from './authRoutes.js';
import clientNoticeRoutes from './clientNoticeRoutes.js';
import clientRoutes from './clientRoutes.js';
import dashboardRoutes from './dashboardRoutes.js';
import maintenanceRoutes from './maintenanceRoutes.js';
import mechanicRoutes from './mechanicRoutes.js';
import notificationRoutes from './notificationRoutes.js';
import orderRoutes from './orderRoutes.js';
import partRoutes from './partRoutes.js';
import paymentRoutes from './paymentRoutes.js';
import settingsRoutes from './settingsRoutes.js';
import ticketRoutes from './ticketRoutes.js';
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
router.use('/maintenance', maintenanceRoutes);
router.use('/parts', partRoutes);
router.use('/payments', paymentRoutes);
router.use('/tickets', ticketRoutes);
router.use('/dashboard', dashboardRoutes);
router.use('/notifications', notificationRoutes);
router.use('/client-notices', clientNoticeRoutes);
router.use('/settings', settingsRoutes);

export default router;
