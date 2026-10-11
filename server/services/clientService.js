import * as clientModel from '../models/clientModel.js';
import { AppError } from '../utils/AppError.js';

const duplicateEmail = () =>
  AppError.conflict('EMAIL_DUPLICATE', 'Ya existe un cliente con ese correo electrónico.');

/** Convierte la condición de carrera sobre el índice único del correo en el mismo error de negocio. */
function translateDuplicate(error) {
  if (error?.code === 'ER_DUP_ENTRY') return duplicateEmail();
  return error;
}

export async function list(filters) {
  return clientModel.list(filters);
}

export async function getById(id) {
  const client = await clientModel.findById(id);
  if (!client) throw AppError.notFound('El cliente no existe.');
  return client;
}

const digitsOf = (phone) => phone.replace(/\D/g, '');

/**
 * Edita un cliente con las mismas reglas de duplicados que el alta, ignorando al propio registro.
 * El aviso de teléfono solo aplica si el teléfono cambió (varios clientes pueden compartirlo).
 */
export async function update(id, data) {
  const { confirmDuplicatePhone, ...fields } = data;

  const current = await clientModel.findById(id);
  if (!current) throw AppError.notFound('El cliente no existe.');

  if (fields.email && (await clientModel.findByEmail(fields.email, id))) throw duplicateEmail();

  const phoneChanged = fields.phone !== undefined && digitsOf(fields.phone) !== digitsOf(current.phone);
  if (phoneChanged && !confirmDuplicatePhone) {
    const matches = await clientModel.findByPhone(fields.phone, id);
    if (matches.length > 0) {
      throw AppError.conflict(
        'PHONE_DUPLICATE',
        'Ya existe un cliente con ese teléfono. Confirma si quieres guardarlo de todos modos.',
        { matches },
      );
    }
  }

  try {
    await clientModel.update(id, fields);
    return await clientModel.findById(id);
  } catch (error) {
    throw translateDuplicate(error);
  }
}

/**
 * Registra un cliente. El correo es único (se rechaza si ya existe). Un teléfono ya registrado
 * genera una advertencia que se puede confirmar con `confirmDuplicatePhone`.
 */
export async function create(data) {
  const { confirmDuplicatePhone, ...fields } = data;

  if (fields.email && (await clientModel.findByEmail(fields.email))) throw duplicateEmail();

  if (!confirmDuplicatePhone) {
    const matches = await clientModel.findByPhone(fields.phone);
    if (matches.length > 0) {
      throw AppError.conflict(
        'PHONE_DUPLICATE',
        'Ya existe un cliente con ese teléfono. Confirma si quieres guardarlo de todos modos.',
        { matches },
      );
    }
  }

  try {
    const id = await clientModel.create(fields);
    return await clientModel.findById(id);
  } catch (error) {
    throw translateDuplicate(error);
  }
}
