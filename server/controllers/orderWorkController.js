import * as orderWorkService from '../services/orderWorkService.js';
import { created, ok } from '../utils/response.js';

export async function updateWork(req, res) {
  return ok(res, await orderWorkService.updateWork(req.params.id, req.body, req.user));
}

export async function setServiceMileage(req, res) {
  return ok(res, await orderWorkService.setServiceMileage(req.params.id, req.body.serviceMileage, req.user));
}

/** Fábrica de controladores de líneas para 'services' (servicios realizados) y 'labor' (mano de obra). */
export function linesController(kind) {
  return {
    async add(req, res) {
      return created(res, await orderWorkService.addLine(kind, req.params.id, req.body, req.user));
    },
    async update(req, res) {
      return ok(res, await orderWorkService.updateLine(kind, req.params.id, req.params.lineId, req.body, req.user));
    },
    async remove(req, res) {
      return ok(res, await orderWorkService.removeLine(kind, req.params.id, req.params.lineId, req.user));
    },
  };
}
