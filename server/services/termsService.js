import * as termsModel from '../models/termsModel.js';
import { AppError } from '../utils/AppError.js';
import { ACTIONS, record } from './auditService.js';

const iso = (value) => (value instanceof Date ? value.toISOString() : value);

/** Versión vigente con la bandera `accepted` del usuario que consulta. */
export async function getCurrent(user) {
  const current = await termsModel.findCurrent();
  if (!current) throw AppError.notFound('Todavía no hay términos y condiciones publicados.');
  return {
    id: current.id,
    version: current.version,
    title: current.title,
    body: current.body,
    publishedAt: iso(current.publishedAt),
    accepted: await termsModel.hasAccepted(user.id, current.id),
  };
}

/** Acepta la versión vigente. Idempotente; una versión que ya no es la vigente responde 409. */
export async function accept(versionId, user) {
  const current = await termsModel.findCurrent();
  if (!current || current.id !== versionId) {
    throw AppError.conflict('TERMS_VERSION_OUTDATED', 'Esa versión de los términos ya no es la vigente. Vuelve a cargarla.', {
      currentVersionId: current?.id ?? null,
    });
  }
  const inserted = await termsModel.insertAcceptanceIgnore(user.id, current.id);
  // Solo la primera aceptación deja registro en la bitácora (las repetidas no duplican nada).
  if (inserted) {
    await record({
      actor: user,
      action: ACTIONS.TERMS_ACCEPTED,
      entityType: 'terms',
      entityId: current.id,
      summary: `Aceptó los términos y condiciones versión ${current.version}`,
    });
  }
  return {
    versionId: current.id,
    version: current.version,
    acceptedAt: iso(await termsModel.findAcceptance(user.id, current.id)),
  };
}

/** Aceptaciones de una versión (por omisión, la vigente) con el total y los usuarios activos pendientes. */
export async function listAcceptances({ versionId, page, pageSize }) {
  const version = versionId ? await termsModel.findById(versionId) : await termsModel.findCurrent();
  if (!version) throw AppError.notFound('La versión de los términos no existe.');
  const { items, total, pending } = await termsModel.listAcceptances(version.id, { page, pageSize });
  return {
    items: items.map((item) => ({ ...item, acceptedAt: iso(item.acceptedAt) })),
    total,
    pending,
    version: version.version,
  };
}
