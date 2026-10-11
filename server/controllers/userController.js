import * as userService from '../services/userService.js';
import { created, ok, pageMeta } from '../utils/response.js';

export async function list(req, res) {
  const { search, role, active, page, pageSize } = req.validQuery;
  const { items, total } = await userService.list({ search, role, active, page, pageSize });
  return ok(res, items, pageMeta(page, pageSize, total));
}

export async function getById(req, res) {
  return ok(res, await userService.getById(req.params.id));
}

export async function create(req, res) {
  return created(res, await userService.create(req.body));
}

export async function update(req, res) {
  return ok(res, await userService.update(req.params.id, req.body));
}
