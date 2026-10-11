import crypto from 'node:crypto';
import { afterAll } from '@jest/globals';
import { closePool } from '../../config/db.js';

// Las pruebas siempre corren en modo test: la base usada es DB_NAME_TEST (debe terminar en _test).
process.env.NODE_ENV = 'test';

// Secreto aleatorio por ejecución cuando no hay .env: así no hay ningún secreto escrito en el código.
if (!process.env.JWT_SECRET) {
  process.env.JWT_SECRET = crypto.randomBytes(32).toString('hex');
}

afterAll(async () => {
  await closePool();
});
