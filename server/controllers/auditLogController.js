import * as auditService from '../services/auditService.js';
import { ok, pageMeta } from '../utils/response.js';

export async function list(req, res) {
  const { page, pageSize } = req.validQuery;
  const { items, total } = await auditService.list(req.validQuery);
  return ok(res, items, pageMeta(page, pageSize, total));
}
