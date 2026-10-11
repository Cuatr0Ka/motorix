import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import routes from './routes/index.js';
import { errorHandler, notFoundHandler } from './middlewares/errorHandler.js';

/** Construye la aplicación Express sin escuchar un puerto (útil para las pruebas con supertest). */
export function createApp() {
  const app = express();

  app.disable('x-powered-by');
  app.use(helmet());
  // La app de escritorio no usa cookies; CORS abierto solo facilita probar desde web en local.
  app.use(cors());
  app.use(express.json({ limit: '100kb' }));

  app.use('/api', routes);

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}

export default createApp;
