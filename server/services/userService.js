import bcrypt from 'bcryptjs';
import { withTransaction } from '../config/db.js';
import * as userModel from '../models/userModel.js';
import { AppError } from '../utils/AppError.js';
import { checkPasswordPolicy } from '../utils/passwordPolicy.js';

const BCRYPT_COST = 10;

const usernameDuplicate = () => AppError.conflict('USERNAME_DUPLICATE', 'Ya existe un usuario con ese nombre de usuario.');
const emailDuplicate = () => AppError.conflict('EMAIL_DUPLICATE', 'Ya existe un usuario con ese correo electrónico.');
const lastAdmin = () =>
  AppError.conflict(
    'LAST_ADMIN',
    'No se puede desactivar ni cambiar el rol del único administrador activo. Crea o activa otro administrador primero.',
  );

/** Usuario tal como viaja por la API: sin hash ni datos de bloqueo. */
export function toApiUser(user) {
  return {
    id: user.id,
    username: user.username,
    name: user.name,
    email: user.email,
    role: user.role,
    active: user.active,
    createdAt: user.createdAt,
  };
}

function translateDbError(error) {
  if (error?.code === 'ER_DUP_ENTRY') {
    return String(error.message).includes('uq_users_username') ? usernameDuplicate() : emailDuplicate();
  }
  return error;
}

export function assertPasswordPolicy(password) {
  const problem = checkPasswordPolicy(password);
  if (problem) throw AppError.unprocessable('PASSWORD_POLICY', problem);
}

export async function list(filters) {
  const { items, total } = await userModel.list(filters);
  return { items: items.map(toApiUser), total };
}

export async function getById(id) {
  const user = await userModel.findById(id);
  if (!user) throw AppError.notFound('El usuario no existe.');
  return toApiUser(user);
}

/** Alta de usuario por un administrador: usuario y correo únicos, contraseña con la política mínima. */
export async function create({ username, name, email, role, password }) {
  assertPasswordPolicy(password);
  if (await userModel.findByUsername(username)) throw usernameDuplicate();
  if (await userModel.findByEmail(email)) throw emailDuplicate();

  const passwordHash = await bcrypt.hash(password, BCRYPT_COST);
  try {
    const id = await userModel.create({ username, name, email, passwordHash, role });
    return toApiUser(await userModel.findById(id));
  } catch (error) {
    throw translateDbError(error);
  }
}

/**
 * Edita nombre, correo, rol y estado. Nunca deja el sistema sin un administrador activo: el cambio y la
 * comprobación ocurren en una transacción que bloquea las filas de los administradores activos.
 */
export async function update(id, fields) {
  try {
    return await withTransaction(async (connection) => {
      // Primero las filas de administradores (en orden de id) y después la del usuario: sin interbloqueos.
      const activeAdminIds = await userModel.lockActiveAdmins(connection);
      const current = await userModel.findByIdForUpdate(id, connection);
      if (!current) throw AppError.notFound('El usuario no existe.');

      const losesAdmin =
        current.role === 'ADMIN' &&
        current.active &&
        ((fields.role !== undefined && fields.role !== 'ADMIN') || fields.active === false);
      if (losesAdmin && activeAdminIds.filter((adminId) => adminId !== current.id).length === 0) {
        throw lastAdmin();
      }

      if (fields.email && (await userModel.findByEmail(fields.email, id))) throw emailDuplicate();

      await userModel.update(id, fields, connection);
      return toApiUser(await userModel.findById(id, connection));
    });
  } catch (error) {
    throw translateDbError(error);
  }
}
