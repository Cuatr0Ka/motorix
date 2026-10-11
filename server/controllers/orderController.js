import * as orderService from '../services/orderService.js';
import { created, ok, pageMeta } from '../utils/response.js';

export async function list(req, res) {
  const { page, pageSize } = req.validQuery;
  const { items, total } = await orderService.list(req.validQuery, req.user);
  return ok(res, items, pageMeta(page, pageSize, total));
}

export async function getById(req, res) {
  return ok(res, await orderService.getById(req.params.id, req.user));
}

export async function create(req, res) {
  return created(res, await orderService.create(req.body, req.user));
}

export async function assignMechanic(req, res) {
  return ok(res, await orderService.assignMechanic(req.params.id, req.body.mechanicId, req.user));
}

export async function changeStatus(req, res) {
  return ok(res, await orderService.changeStatus(req.params.id, req.body.status, req.user));
}
