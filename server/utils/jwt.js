import jwt from 'jsonwebtoken';
import { getJwtConfig } from '../config/env.js';

/** Firma un token HS256 de 8 horas. Solo lleva el id del usuario (`sub`); el rol se consulta en cada petición. */
export function signToken(userId) {
  const { jwtSecret, jwtExpiresInSeconds } = getJwtConfig();
  return jwt.sign({ sub: String(userId) }, jwtSecret, {
    algorithm: 'HS256',
    expiresIn: jwtExpiresInSeconds,
  });
}

/** Verifica el token y devuelve el id de usuario; lanza si es inválido o expiró. */
export function verifyToken(token) {
  const { jwtSecret } = getJwtConfig();
  const payload = jwt.verify(token, jwtSecret, { algorithms: ['HS256'] });
  const userId = Number(payload.sub);
  if (!Number.isInteger(userId) || userId <= 0) throw new Error('Token sin usuario válido.');
  return userId;
}
