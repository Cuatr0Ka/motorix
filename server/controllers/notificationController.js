import * as notificationService from '../services/notificationService.js';
import { ok } from '../utils/response.js';

export async function list(req, res) {
  return ok(res, await notificationService.list(req.user));
}
