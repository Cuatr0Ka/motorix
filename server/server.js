import { createApp } from './app.js';
import { getConfig } from './config/env.js';
import { closePool, getPool } from './config/db.js';

const config = getConfig();

// Comprueba la conexión antes de aceptar peticiones para fallar pronto con un mensaje claro.
try {
  await getPool().query('SELECT 1');
} catch (error) {
  console.error(`No se pudo conectar a MySQL (${error.code ?? 'error'}). Revisa las variables DB_* del archivo .env.`);
  process.exit(1);
}

const server = createApp().listen(config.port, () => {
  console.log(`API de Motorix escuchando en http://localhost:${config.port}/api`);
});

async function shutdown() {
  server.close(async () => {
    await closePool();
    process.exit(0);
  });
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
