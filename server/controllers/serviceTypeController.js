import * as serviceTypeService from '../services/serviceTypeService.js';
import { created, ok } from '../utils/response.js';

export async function list(req, res) {
  const items = await serviceTypeService.list(req.validQuery);
  return ok(res, items, { total: items.length });
}

export async function options(req, res) {
  return ok(res, await serviceTypeService.listOptions());
}

export async function create(req, res) {
  return created(res, await serviceTypeService.create(req.body, req.user));
}

export async function update(req, res) {
  return ok(res, await serviceTypeService.update(req.params.id, req.body, req.user));
}
