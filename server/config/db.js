import mysql from 'mysql2/promise';
import { getConfig } from './env.js';

let pool;

/** Devuelve el pool de conexiones (se crea al primer uso). */
export function getPool() {
  if (!pool) {
    const { db } = getConfig();
    pool = mysql.createPool({
      host: db.host,
      port: db.port,
      user: db.user,
      password: db.password,
      database: db.database,
      charset: 'utf8mb4',
      waitForConnections: true,
      connectionLimit: 10,
      // Las fechas del bloqueo se calculan con NOW() en SQL, así que no dependen de la zona horaria de Node.
      dateStrings: false,
    });
  }
  return pool;
}

/** Ejecuta una consulta parametrizada y devuelve las filas. */
export async function query(sql, params = [], connection = getPool()) {
  const [rows] = await connection.execute(sql, params);
  return rows;
}

/** Ejecuta `work(connection)` dentro de una transacción; hace rollback si falla. */
export async function withTransaction(work) {
  const connection = await getPool().getConnection();
  try {
    await connection.beginTransaction();
    const result = await work(connection);
    await connection.commit();
    return result;
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

export async function closePool() {
  if (pool) {
    await pool.end();
    pool = undefined;
  }
}
