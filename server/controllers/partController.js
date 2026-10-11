import * as partService from '../services/partService.js';
import { created, ok, pageMeta } from '../utils/response.js';

export async function list(req, res) {
  const { page, pageSize } = req.validQuery;
  const { items, total } = await partService.list(req.validQuery, req.user);
  return ok(res, items, pageMeta(page, pageSize, total));
}

export async function getById(req, res) {
  return ok(res, await partService.getById(req.params.id));
}

export async function create(req, res) {
  return created(res, await partService.create(req.body, req.user));
}

export async function update(req, res) {
  return ok(res, await partService.update(req.params.id, req.body));
}

export async function alerts(req, res) {
  return ok(res, await partService.alerts());
}
