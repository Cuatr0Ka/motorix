/** Folio legible de una orden de servicio, derivado de su identificador (no se guarda en la base). */

/** Ejemplo: 12 → "OS-000012". */
export function formatFolio(id) {
  return `OS-${String(id).padStart(6, '0')}`;
}

/**
 * Interpreta el texto de una búsqueda por folio. Acepta "OS-12", "os-000012" o "12".
 * Devuelve el identificador numérico o null si el texto no es un folio.
 */
export function parseFolioSearch(text) {
  if (typeof text !== 'string') return null;
  const match = text.trim().match(/^(?:os-?)?(\d{1,9})$/i);
  if (!match) return null;
  const id = Number(match[1]);
  return id > 0 ? id : null;
}
