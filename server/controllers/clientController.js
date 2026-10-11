import * as clientService from '../services/clientService.js';
import { created, ok, pageMeta } from '../utils/response.js';

export async function list(req, res) {
  const { search, page, pageSize } = req.validQuery;
  const { items, total } = await clientService.list({ search, page, pageSize });
  return ok(res, items, pageMeta(page, pageSize, total));
}

export async function getById(req, res) {
  return ok(res, await clientService.getById(req.params.id));
}

export async function create(req, res) {
  return created(res, await clientService.create(req.body));
}

export async function update(req, res) {
  return ok(res, await clientService.update(req.params.id, req.body));
}
