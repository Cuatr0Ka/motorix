/** Utilidades de normalización de datos de entrada y de mapeo de filas de la base. */

/** Recorta espacios; devuelve null si queda vacío o no es texto. */
export function cleanText(value) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed === '' ? null : trimmed;
}

/** Correo en minúsculas y sin espacios; vacío se guarda como null. */
export function normalizeEmail(value) {
  const text = cleanText(value);
  return text === null ? null : text.toLowerCase();
}

/** Placa recortada y en mayúsculas. */
export function normalizePlate(value) {
  const text = cleanText(value);
  return text === null ? null : text.toUpperCase();
}

/** VIN en mayúsculas; vacío se guarda como null. */
export function normalizeVin(value) {
  const text = cleanText(value);
  return text === null ? null : text.toUpperCase();
}

const snakeToCamel = (key) => key.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase());
const camelToSnake = (key) => key.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`);

/** Convierte las claves de una fila `snake_case` a `camelCase`. */
export function toCamel(row) {
  if (!row) return row;
  return Object.fromEntries(Object.entries(row).map(([key, value]) => [snakeToCamel(key), value]));
}

/** Convierte las claves de un objeto `camelCase` a `snake_case`. */
export function toSnake(object) {
  return Object.fromEntries(Object.entries(object).map(([key, value]) => [camelToSnake(key), value]));
}

/** TINYINT(1) → booleano. */
export function toBool(value) {
  return value === 1 || value === true;
}
