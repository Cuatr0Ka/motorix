import * as maintenanceService from '../services/maintenanceService.js';
import { created, ok, pageMeta } from '../utils/response.js';

export async function schedule(req, res) {
  return created(res, await maintenanceService.schedule(req.params.id, req.body, req.user));
}

/** Próximo mantenimiento propuesto desde los tipos de servicio de la orden: 204 si no hay intervalo. */
export async function suggest(req, res) {
  const suggestion = await maintenanceService.suggest(req.params.id, req.user);
  if (!suggestion) return res.status(204).end();
  return ok(res, suggestion);
}

export async function list(req, res) {
  const { page, pageSize } = req.validQuery;
  const { items, total } = await maintenanceService.list(req.validQuery, req.user);
  return ok(res, items, pageMeta(page, pageSize, total));
}

export async function update(req, res) {
  return ok(res, await maintenanceService.update(req.params.id, req.body, req.user));
}

export async function attend(req, res) {
  return ok(res, await maintenanceService.attend(req.params.id, req.user));
}
