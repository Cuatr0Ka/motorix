import fs from 'node:fs';
import path from 'node:path';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import routes from './routes/index.js';
import { getCorsOrigins, getTrustProxy, getWebConfig } from './config/env.js';
import { errorHandler, notFoundHandler } from './middlewares/errorHandler.js';

/**
 * Política de contenido de la web de Flutter. La API conserva la política estricta de `helmet()`; la web necesita
 * ejecutar WebAssembly (CanvasKit), cargarlo desde el CDN de Flutter y usar fuentes de Google.
 */
const WEB_CSP = {
  useDefaults: false,
  directives: {
    defaultSrc: ["'self'"],
    scriptSrc: ["'self'", "'wasm-unsafe-eval'", 'https://www.gstatic.com'],
    connectSrc: ["'self'", 'https://www.gstatic.com', 'https://fonts.gstatic.com'],
    imgSrc: ["'self'", 'data:', 'blob:', 'https://www.gstatic.com'],
    fontSrc: ["'self'", 'data:', 'https://fonts.gstatic.com'],
    styleSrc: ["'self'", "'unsafe-inline'"],
    workerSrc: ["'self'", 'blob:'],
    objectSrc: ["'none'"],
    baseUri: ["'self'"],
    frameAncestors: ["'self'"],
  },
};

/**
 * Construye la aplicación Express sin escuchar un puerto (útil para las pruebas con supertest).
 * `web` y `trustProxy` salen del entorno, pero las pruebas pueden pasarlos directamente.
 */
export function createApp({ web = getWebConfig(), trustProxy = getTrustProxy(), corsOrigins = getCorsOrigins() } = {}) {
  const app = express();

  app.disable('x-powered-by');
  if (trustProxy) app.set('trust proxy', trustProxy);

  const serveWeb = web.serve && fs.existsSync(path.join(web.dir, 'index.html'));
  const apiHelmet = helmet();
  if (serveWeb) {
    const webHelmet = helmet({ contentSecurityPolicy: WEB_CSP });
    app.use((req, res, next) => (req.path.startsWith('/api') ? apiHelmet : webHelmet)(req, res, next));
    app.use(express.static(web.dir, { index: 'index.html' }));
  } else {
    app.use(apiHelmet);
  }
  // La app de escritorio no usa cookies. Sin CORS_ORIGIN queda abierto (cómodo en local); en producción se limita.
  app.use(cors(corsOrigins ? { origin: corsOrigins } : undefined));
  app.use(express.json({ limit: '100kb' }));

  app.use('/api', routes);

  // Rutas de la web (por ejemplo al recargar la página): se responde la aplicación y ella decide qué mostrar.
  if (serveWeb) {
    app.get(/^\/(?!api(\/|$)).*/, (req, res) => res.sendFile(path.join(web.dir, 'index.html')));
  }

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}

export default createApp;
