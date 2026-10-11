import * as vehicleService from '../services/vehicleService.js';
import { created, ok, pageMeta } from '../utils/response.js';

export async function list(req, res) {
  const { search, clientId, page, pageSize } = req.validQuery;
  const { items, total } = await vehicleService.list({ search, clientId, page, pageSize });
  return ok(res, items, pageMeta(page, pageSize, total));
}

export async function getById(req, res) {
  return ok(res, await vehicleService.getById(req.params.id));
}

export async function create(req, res) {
  return created(res, await vehicleService.create(req.body));
}

export async function update(req, res) {
  return ok(res, await vehicleService.update(req.params.id, req.body));
}
