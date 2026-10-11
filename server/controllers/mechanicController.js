import * as userModel from '../models/userModel.js';
import { ok } from '../utils/response.js';

/** Mecánicos activos que se pueden asignar a una orden (sin correo ni datos sensibles). */
export async function list(req, res) {
  return ok(res, await userModel.listActiveMechanics());
}
