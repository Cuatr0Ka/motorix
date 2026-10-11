import * as paymentService from '../services/paymentService.js';
import { created, ok, pageMeta } from '../utils/response.js';

export async function listMethods(req, res) {
  return ok(res, paymentService.listMethods());
}

export async function list(req, res) {
  const { page, pageSize } = req.validQuery;
  const { items, total } = await paymentService.list(req.validQuery);
  return ok(res, items, pageMeta(page, pageSize, total));
}

export async function getById(req, res) {
  return ok(res, await paymentService.getById(req.params.id));
}

export async function listByOrder(req, res) {
  return ok(res, await paymentService.listByOrder(req.params.id));
}

export async function createForOrder(req, res) {
  return created(res, await paymentService.create(req.params.id, req.body, req.user));
}

export async function refresh(req, res) {
  return ok(res, await paymentService.refresh(req.params.id));
}

export async function cancel(req, res) {
  return ok(res, await paymentService.cancel(req.params.id));
}
