import { AppError } from '../utils/AppError.js';

/** Un periodo de reporte no puede pasar de un año (366 días, contando los dos extremos). */
export const MAX_RANGE_DAYS = 366;

const pad = (n) => String(n).padStart(2, '0');

/** Fecha local → `AAAA-MM-DD`. */
export function toIsoDate(date) {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

/** `AAAA-MM-DD` → fecha local a las 00:00, o null si no es una fecha real (el 31 de febrero no existe). */
function parseDay(text) {
  if (typeof text !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(text)) return null;
  const [year, month, day] = text.split('-').map(Number);
  const date = new Date(year, month - 1, day);
  return date.getFullYear() === year && date.getMonth() === month - 1 && date.getDate() === day ? date : null;
}

const invalid = (field, message, extra = {}) =>
  AppError.validation('Revisa los campos marcados.', [{ field, message, ...extra }]);

/**
 * Valida el periodo (`from` y `to` son fechas reales `AAAA-MM-DD`, `to >= from` y a lo más 366 días) y calcula sus extremos
 * con la fecha local del servidor: `startSql` es el inicio del día de `from` y `endSql` el inicio del día SIGUIENTE a `to`
 * (intervalo semiabierto: los dos días extremos quedan incluidos completos).
 */
export function parseRange({ from, to }) {
  const start = parseDay(from);
  if (!start) return throwInvalid('from', 'La fecha inicial debe ser una fecha válida con el formato AAAA-MM-DD.');
  const end = parseDay(to);
  if (!end) return throwInvalid('to', 'La fecha final debe ser una fecha válida con el formato AAAA-MM-DD.');
  if (end < start) return throwInvalid('to', 'La fecha final no puede ser anterior a la inicial.');

  const days = Math.round((end - start) / 86400000) + 1;
  if (days > MAX_RANGE_DAYS) {
    return throwInvalid('to', 'El periodo no puede pasar de un año.', { limit: MAX_RANGE_DAYS });
  }
  const next = new Date(end.getFullYear(), end.getMonth(), end.getDate() + 1);
  return { from, to, days, startSql: `${from} 00:00:00`, endSql: `${toIsoDate(next)} 00:00:00` };
}

function throwInvalid(field, message, extra) {
  throw invalid(field, message, extra);
}

/** Periodos rápidos: hoy, esta semana (del lunes a hoy) y este mes (del día 1 a hoy). */
export function presetRange(name, now = new Date()) {
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  if (name === 'today') return { from: toIsoDate(today), to: toIsoDate(today) };
  if (name === 'week') {
    const sinceMonday = (today.getDay() + 6) % 7;
    return { from: toIsoDate(new Date(today.getFullYear(), today.getMonth(), today.getDate() - sinceMonday)), to: toIsoDate(today) };
  }
  if (name === 'month') return { from: toIsoDate(new Date(today.getFullYear(), today.getMonth(), 1)), to: toIsoDate(today) };
  throw new Error(`Periodo rápido desconocido: ${name}`);
}

/** Importe decimal ("850.50") o número → centavos enteros, sin errores de redondeo al sumar. */
export function toCents(value) {
  return Math.round(Number(value) * 100);
}

/** Centavos enteros → cadena con dos decimales. */
export function fromCents(cents) {
  return (cents / 100).toFixed(2);
}
