/**
 * Restablece la contraseña de una cuenta (por ejemplo, para reemplazar las contraseñas de prueba del estándar del MVP
 * antes de publicar el sistema). La contraseña nueva debe cumplir la política vigente (mínimo 10 caracteres con
 * mayúscula, minúscula y número) y se lee de la variable de entorno NEW_PASSWORD, nunca de un argumento, para que no
 * quede en el historial del shell ni escrita en ningún archivo.
 *
 * Uso (desde server/), por ejemplo en PowerShell:
 *   $env:NEW_PASSWORD = '<tu contraseña nueva>'; node scripts/restablecerContrasena.js admin
 *   Remove-Item Env:NEW_PASSWORD
 *
 * Usa la base configurada en el entorno (DB_*). También desbloquea la cuenta y reinicia sus intentos fallidos.
 */
import bcrypt from 'bcryptjs';
import { closePool } from '../config/db.js';
import * as userModel from '../models/userModel.js';
import { assertPasswordPolicy } from '../services/userService.js';

const identifier = process.argv[2];
const password = process.env.NEW_PASSWORD;

if (!identifier || !password) {
  console.error('Uso: define NEW_PASSWORD y ejecuta: node scripts/restablecerContrasena.js <usuario o correo>');
  process.exit(1);
}

try {
  assertPasswordPolicy(password);
  const record = await userModel.findByIdentifier(identifier);
  if (!record) {
    console.error('No existe una cuenta con ese usuario o correo.');
    process.exitCode = 2;
  } else {
    await userModel.updatePassword(record.user.id, await bcrypt.hash(password, 10));
    await userModel.resetFailures(record.user.id);
    console.log(`Contraseña restablecida para "${record.user.username}".`);
  }
} catch (error) {
  console.error(error.message ?? error);
  process.exitCode = 3;
} finally {
  await closePool();
}
