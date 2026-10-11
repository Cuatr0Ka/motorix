import * as vehicleHistoryService from '../services/vehicleHistoryService.js';
import { ok, pageMeta } from '../utils/response.js';

export async function getHistory(req, res) {
  const { page, pageSize } = req.validQuery;
  const { data, total } = await vehicleHistoryService.getHistory(req.params.id, { page, pageSize });
  return ok(res, data, pageMeta(page, pageSize, total));
}
