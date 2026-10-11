import * as appointmentService from '../services/appointmentService.js';
import { created, ok, pageMeta } from '../utils/response.js';

export async function list(req, res) {
  const { page, pageSize } = req.validQuery;
  const { items, total } = await appointmentService.list(req.validQuery);
  return ok(res, items, pageMeta(page, pageSize, total));
}

export async function getById(req, res) {
  return ok(res, await appointmentService.getById(req.params.id));
}

export async function create(req, res) {
  return created(res, await appointmentService.create(req.body, req.user));
}

export async function update(req, res) {
  return ok(res, await appointmentService.update(req.params.id, req.body));
}

export async function confirm(req, res) {
  return ok(res, await appointmentService.confirm(req.params.id));
}

export async function cancel(req, res) {
  return ok(res, await appointmentService.cancel(req.params.id, req.body));
}
