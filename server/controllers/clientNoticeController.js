import * as clientNoticeService from '../services/clientNoticeService.js';
import { created, ok } from '../utils/response.js';

export async function list(req, res) {
  const { items, total } = await clientNoticeService.listPending(req.user);
  return ok(res, items, { total });
}

export async function register(req, res) {
  const result = await clientNoticeService.register(req.body, req.user);
  // 201 si esta llamada creó el registro; 200 si ya existía (no es un error).
  return result.created ? created(res, result.notice) : ok(res, result.notice);
}
