import * as settingsModel from '../models/settingsModel.js';
import { ACTIONS, record } from './auditService.js';

/**
 * Configuración del taller (Sprint 7). El valor guardado gana; si no hay, se usa la variable de entorno de respaldo
 * (`SHOP_*` y `MAINTENANCE_WARN_*`) y, si tampoco existe, el predeterminado (FR-003). Se lee de la base en CADA llamada:
 * una lectura por consulta es barata y evita valores desfasados.
 */

export const KEYS = Object.freeze({
  SHOP_NAME: 'shop.name',
  SHOP_ADDRESS: 'shop.address',
  SHOP_PHONE: 'shop.phone',
  WARN_DAYS: 'maintenance.warn_days',
  WARN_KM: 'maintenance.warn_km',
});

export const DEFAULTS = Object.freeze({
  shopName: 'Motorix Taller Mecánico',
  shopAddress: '',
  shopPhone: '',
  warnDays: 30,
  warnKm: 1000,
});

const ENV_NAMES = {
  [KEYS.SHOP_NAME]: 'SHOP_NAME',
  [KEYS.SHOP_ADDRESS]: 'SHOP_ADDRESS',
  [KEYS.SHOP_PHONE]: 'SHOP_PHONE',
  [KEYS.WARN_DAYS]: 'MAINTENANCE_WARN_DAYS',
  [KEYS.WARN_KM]: 'MAINTENANCE_WARN_KM',
};

const envText = (key) => (process.env[ENV_NAMES[key]] ?? '').trim();

/** Entero positivo de una variable de entorno, o null si no existe o no es válida (no rompe el sistema). */
function envPositiveInt(key) {
  const raw = envText(key);
  if (!/^\d+$/.test(raw) || Number(raw) <= 0) return null;
  return Number(raw);
}

/** Valor efectivo y su origen: STORED (guardado), ENV (variable de entorno) o DEFAULT (predeterminado). */
function resolve(stored, key, fallback, parse) {
  if (stored[key] !== undefined) return { value: parse(stored[key]), source: 'STORED' };
  const fromEnv = parse === Number ? envPositiveInt(key) : envText(key) || null;
  if (fromEnv !== null && fromEnv !== undefined) return { value: fromEnv, source: 'ENV' };
  return { value: fallback, source: 'DEFAULT' };
}

const asText = (value) => String(value);

/** Configuración completa con el origen de cada valor. */
export async function getAll() {
  const stored = await settingsModel.getAll();
  const name = resolve(stored, KEYS.SHOP_NAME, DEFAULTS.shopName, asText);
  const address = resolve(stored, KEYS.SHOP_ADDRESS, DEFAULTS.shopAddress, asText);
  const phone = resolve(stored, KEYS.SHOP_PHONE, DEFAULTS.shopPhone, asText);
  const warnDays = resolve(stored, KEYS.WARN_DAYS, DEFAULTS.warnDays, Number);
  const warnKm = resolve(stored, KEYS.WARN_KM, DEFAULTS.warnKm, Number);
  return {
    shop: { name: name.value, address: address.value, phone: phone.value },
    maintenance: { warnDays: warnDays.value, warnKm: warnKm.value },
    sources: {
      [KEYS.SHOP_NAME]: name.source,
      [KEYS.SHOP_ADDRESS]: address.source,
      [KEYS.SHOP_PHONE]: phone.source,
      [KEYS.WARN_DAYS]: warnDays.source,
      [KEYS.WARN_KM]: warnKm.source,
    },
  };
}

/** Datos del taller para el ticket: `{ name, address, phone }`. */
export async function getShop() {
  return (await getAll()).shop;
}

/** Márgenes de «Próximo» del mantenimiento: `{ warnDays, warnKm }`. Se piden una vez por petición. */
export async function getMaintenanceMargins() {
  return (await getAll()).maintenance;
}

const SHOP_LABELS = { name: 'nombre', address: 'dirección', phone: 'teléfono' };
const MARGIN_LABELS = { warnDays: 'margen en días', warnKm: 'margen en km' };

/**
 * Guarda solo los campos enviados en una sola sentencia atómica y registra `SETTINGS_CHANGED` con los NOMBRES de los
 * campos cambiados (y, en los márgenes, el valor anterior y el nuevo); nunca el texto de los datos del taller.
 */
export async function update(fields, actor) {
  const before = await getAll();
  const entries = {};
  const changes = [];

  const shop = fields.shop ?? {};
  const shopKeys = { name: KEYS.SHOP_NAME, address: KEYS.SHOP_ADDRESS, phone: KEYS.SHOP_PHONE };
  const shopChanged = [];
  for (const [field, key] of Object.entries(shopKeys)) {
    if (shop[field] === undefined) continue;
    entries[key] = shop[field];
    if (shop[field] !== before.shop[field]) shopChanged.push(SHOP_LABELS[field]);
  }
  if (shopChanged.length > 0) changes.push(`Taller: ${shopChanged.join(', ')}`);

  const maintenance = fields.maintenance ?? {};
  const marginKeys = { warnDays: KEYS.WARN_DAYS, warnKm: KEYS.WARN_KM };
  const marginsChanged = [];
  for (const [field, key] of Object.entries(marginKeys)) {
    if (maintenance[field] === undefined) continue;
    entries[key] = maintenance[field];
    if (maintenance[field] !== before.maintenance[field]) {
      marginsChanged.push(`${MARGIN_LABELS[field]} ${before.maintenance[field]} → ${maintenance[field]}`);
    }
  }
  if (marginsChanged.length > 0) changes.push(`Mantenimiento: ${marginsChanged.join(', ')}`);

  await settingsModel.upsertMany(entries, actor.id);

  await record({
    actor,
    action: ACTIONS.SETTINGS_CHANGED,
    entityType: 'settings',
    summary: changes.length > 0 ? changes.join('; ') : 'Se guardó la configuración sin cambios',
  });
  return getAll();
}
