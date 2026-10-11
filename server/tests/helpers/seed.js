import fs from 'node:fs';
import path from 'node:path';
import mysql from 'mysql2/promise';
import { fileURLToPath } from 'node:url';
import { getConfig } from '../../config/env.js';

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..');

/** Ejecuta el seed SQL real del repositorio sobre la base de pruebas (puede repetirse). */
export async function runSeedFile(fileName = '001_initial_data.sql') {
  const { db } = getConfig();
  if (!db.database.endsWith('_test')) throw new Error('Los seeds de prueba solo se ejecutan en una base _test.');

  const sql = fs.readFileSync(path.join(rootDir, 'database', 'seeds', fileName), 'utf8');
  const connection = await mysql.createConnection({ ...db, charset: 'utf8mb4', multipleStatements: true });
  try {
    await connection.query(sql);
  } finally {
    await connection.end();
  }
}

/**
 * Lee las contraseñas del estándar del MVP desde docs/project-context.md, para no escribirlas
 * en texto plano en el código. Devuelve { admin: '...', recepcion: '...', mecanico: '...', mecanico2: '...' }.
 */
export function readStandardPasswords() {
  const doc = fs.readFileSync(path.join(rootDir, 'docs', 'project-context.md'), 'utf8');
  const passwords = {};
  for (const match of doc.matchAll(/^\|\s*[^|]+\|\s*`(admin|recepcion|mecanico2?)`\s*\|\s*`([^`]+)`\s*\|/gm)) {
    passwords[match[1]] = match[2];
  }
  return passwords;
}
