import * as orderPartService from '../services/orderPartService.js';
import { created, ok } from '../utils/response.js';

export async function add(req, res) {
  return created(res, await orderPartService.add(req.params.id, req.body, req.user));
}

export async function updateQuantity(req, res) {
  return ok(res, await orderPartService.updateQuantity(req.params.id, req.params.lineId, req.body.quantity, req.user));
}

export async function remove(req, res) {
  return ok(res, await orderPartService.remove(req.params.id, req.params.lineId, req.user));
}
