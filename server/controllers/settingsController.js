import * as settingsService from '../services/settingsService.js';
import { ok } from '../utils/response.js';

export async function get(req, res) {
  return ok(res, await settingsService.getAll());
}

export async function update(req, res) {
  return ok(res, await settingsService.update(req.body, req.user));
}
