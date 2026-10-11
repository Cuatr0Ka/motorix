import * as dashboardService from '../services/dashboardService.js';
import { ok } from '../utils/response.js';

export async function get(req, res) {
  return ok(res, await dashboardService.getDashboard(req.user));
}
