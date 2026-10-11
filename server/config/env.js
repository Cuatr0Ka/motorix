import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';

// El .env vive en la raíz del repositorio (un nivel arriba de server/).
const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
dotenv.config({ path: path.join(rootDir, '.env') });

const isTest = process.env.NODE_ENV === 'test';

/**
 * Lee y valida la configuración. Se exporta como función para poder probar los errores
 * con distintos entornos sin depender del estado global.
 */
export function loadConfig(source = process.env) {
  const testing = source.NODE_ENV === 'test';
  const dbName = testing ? source.DB_NAME_TEST || 'motorix_test' : source.DB_NAME;

  const missing = ['DB_USER', 'DB_PASSWORD', 'JWT_SECRET'].filter((key) => !source[key]);
  if (!dbName) missing.push(testing ? 'DB_NAME_TEST' : 'DB_NAME');
  if (missing.length > 0) {
    throw new Error(`Faltan variables de entorno: ${missing.join(', ')}. Revisa tu archivo .env.`);
  }

  if (source.DB_USER.toLowerCase() === 'root') {
    throw new Error('La aplicación no debe usar el usuario root de MySQL. Usa un usuario dedicado.');
  }

  // Protección: las pruebas nunca deben tocar la base principal.
  if (testing && !dbName.endsWith('_test')) {
    throw new Error(`En pruebas la base debe terminar en "_test" (recibida: "${dbName}").`);
  }

  return {
    isTest: testing,
    port: Number(source.PORT) || 3000,
    jwtSecret: source.JWT_SECRET,
    jwtExpiresInSeconds: 8 * 60 * 60,
    db: {
      host: source.DB_HOST || 'localhost',
      port: Number(source.DB_PORT) || 3306,
      user: source.DB_USER,
      password: source.DB_PASSWORD,
      database: dbName,
    },
  };
}

/** Configuración de JWT por separado: no exige las variables de la base (útil en pruebas unitarias). */
export function getJwtConfig(source = process.env) {
  if (!source.JWT_SECRET) {
    throw new Error('Falta la variable de entorno JWT_SECRET. Revisa tu archivo .env.');
  }
  return { jwtSecret: source.JWT_SECRET, jwtExpiresInSeconds: 8 * 60 * 60 };
}

/**
 * Márgenes de aviso «Próximo» de los mantenimientos (RN-12: configurables, sin valores universales).
 * Variables opcionales: MAINTENANCE_WARN_DAYS (30) y MAINTENANCE_WARN_KM (1000).
 */
export function getMaintenanceConfig(source = process.env) {
  const read = (name, fallback) => {
    const raw = source[name];
    if (raw === undefined || raw === '') return fallback;
    if (!/^\d+$/.test(String(raw)) || Number(raw) <= 0) {
      throw new Error(`La variable de entorno ${name} debe ser un entero positivo (recibida: "${raw}").`);
    }
    return Number(raw);
  };
  return { warnDays: read('MAINTENANCE_WARN_DAYS', 30), warnKm: read('MAINTENANCE_WARN_KM', 1000) };
}

/**
 * Configuración de Mercado Pago (modo de pruebas). El token solo se lee del entorno y nunca se imprime
 * ni se devuelve. Sin token, el método Mercado Pago queda no disponible.
 */
export function getMercadoPagoConfig(source = process.env) {
  return {
    accessToken: (source.MERCADOPAGO_ACCESS_TOKEN ?? '').trim(),
    apiUrl: (source.MERCADOPAGO_API_URL || 'https://api.mercadopago.com').trim().replace(/\/+$/, ''),
  };
}

/** Datos del taller que aparecen en el ticket (configurables sin tocar el código). */
export function getShopConfig(source = process.env) {
  return {
    name: (source.SHOP_NAME || 'Motorix Taller Mecánico').trim(),
    address: (source.SHOP_ADDRESS ?? '').trim(),
    phone: (source.SHOP_PHONE ?? '').trim(),
  };
}

// Configuración perezosa: se valida al primer uso para que las pruebas unitarias de módulos
// que no tocan la base no necesiten un .env completo.
let cached;
export function getConfig() {
  if (!cached) cached = loadConfig();
  return cached;
}

export { isTest, rootDir };
