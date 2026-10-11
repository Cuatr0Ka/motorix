/** Escapa los comodines de LIKE para que la búsqueda trate `%` y `_` como texto. */
export function likePattern(term) {
  return `%${term.replace(/[\\%_]/g, (char) => `\\${char}`)}%`;
}

/** Calcula `LIMIT` y `OFFSET` como enteros seguros (ya validados por zod) para interpolarlos en SQL. */
export function limitOffset(page, pageSize) {
  const limit = Math.max(1, Math.trunc(Number(pageSize)));
  const offset = Math.max(0, (Math.trunc(Number(page)) - 1) * limit);
  return { limit, offset };
}
