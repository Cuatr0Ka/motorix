import * as maintenanceService from '../services/maintenanceService.js';
import { created, ok, pageMeta } from '../utils/response.js';

export async function schedule(req, res) {
  return created(res, await maintenanceService.schedule(req.params.id, req.body, req.user));
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
