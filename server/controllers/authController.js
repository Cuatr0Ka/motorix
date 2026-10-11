import * as authService from '../services/authService.js';
import { ok } from '../utils/response.js';

export async function login(req, res) {
  const { identifier, password } = req.body;
  const result = await authService.login(identifier, password);
  return ok(res, result);
}

export async function changePassword(req, res) {
  const { currentPassword, newPassword } = req.body;
  return ok(res, await authService.changePassword(req.user.id, currentPassword, newPassword));
}

export function me(req, res) {
  return ok(res, authService.getProfile(req.user));
}
