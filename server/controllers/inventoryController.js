import * as inventoryService from '../services/inventoryService.js';
import * as partService from '../services/partService.js';
import { created, ok, pageMeta } from '../utils/response.js';

export async function listMovements(req, res) {
  const { page, pageSize } = req.validQuery;
  const { items, total } = await partService.listMovements(req.params.id, { page, pageSize });
  return ok(res, items, pageMeta(page, pageSize, total));
}

/** Entrada de mercancía o ajuste por conteo; el tipo `OUT` solo nace del uso en una orden. */
export async function registerMovement(req, res) {
  const { type, ...data } = req.body;
  const result =
    type === 'IN'
      ? await inventoryService.receive(req.params.id, data, req.user)
      : await inventoryService.adjust(req.params.id, data, req.user);
  return created(res, result);
}
