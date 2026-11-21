import * as termsService from '../services/termsService.js';
import { ok, pageMeta } from '../utils/response.js';

export async function current(req, res) {
  return ok(res, await termsService.getCurrent(req.user));
}

export async function accept(req, res) {
  return ok(res, await termsService.accept(req.body.versionId, req.user));
}

export async function acceptances(req, res) {
  const { page, pageSize } = req.validQuery;
  const { items, total, pending, version } = await termsService.listAcceptances(req.validQuery);
  return ok(res, items, { ...pageMeta(page, pageSize, total), pending, version });
}
