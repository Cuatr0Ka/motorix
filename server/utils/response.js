/** Respuesta exitosa uniforme: { data, meta? }. */
export function ok(res, data, meta, status = 200) {
  const body = { data };
  if (meta) body.meta = meta;
  return res.status(status).json(body);
}

export function created(res, data) {
  return ok(res, data, undefined, 201);
}

/** Construye el bloque `meta` de un listado paginado. */
export function pageMeta(page, pageSize, total) {
  return { page, pageSize, total };
}
