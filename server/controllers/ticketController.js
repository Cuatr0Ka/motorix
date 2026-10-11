import * as ticketService from '../services/ticketService.js';
import { ok, pageMeta } from '../utils/response.js';

export async function list(req, res) {
  const { page, pageSize } = req.validQuery;
  const { items, total } = await ticketService.list(req.validQuery);
  return ok(res, items, pageMeta(page, pageSize, total));
}

export async function getById(req, res) {
  return ok(res, await ticketService.getById(req.params.id));
}

export async function getByOrder(req, res) {
  return ok(res, await ticketService.getByOrder(req.params.id));
}

/** Genera el ticket de la orden: 201 si se creó y 200 con el existente si ya lo tenía. */
export async function generate(req, res) {
  const { ticket, created } = await ticketService.generate(req.params.id, req.user);
  return res.status(created ? 201 : 200).json({ data: { ticket, created } });
}
