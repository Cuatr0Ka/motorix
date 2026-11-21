import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from '@jest/globals';

const raiz = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..');

// Línea base de dependencias (antes del Sprint 7) y la única dependencia nueva aprobada por la persona responsable el
// 2026-11-21: `exceljs`, para exportar los reportes a Excel con el diseño de Motorix.
const SERVIDOR = ['bcryptjs', 'cors', 'dotenv', 'express', 'helmet', 'jsonwebtoken', 'mysql2', 'zod'];
const SERVIDOR_NUEVAS = ['exceljs'];
const SERVIDOR_DEV = ['cross-env', 'jest', 'supertest'];

const leerDependenciasDart = (seccion) => {
  const texto = fs.readFileSync(path.join(raiz, 'client', 'pubspec.yaml'), 'utf8');
  const bloque = texto.split(new RegExp(`^${seccion}:`, 'm'))[1].split(/^\S/m)[0];
  return [...bloque.matchAll(/^ {2}([a-z_0-9]+):/gm)].map((m) => m[1]).filter((n) => n !== 'flutter' && n !== 'sdk');
};

describe('dependencias del proyecto (FR-032)', () => {
  const paquete = JSON.parse(fs.readFileSync(path.join(raiz, 'server', 'package.json'), 'utf8'));

  it('test_el_servidor_solo_agrega_exceljs_a_la_linea_base', () => {
    expect(Object.keys(paquete.dependencies).sort()).toEqual([...SERVIDOR, ...SERVIDOR_NUEVAS].sort());
    expect(Object.keys(paquete.devDependencies).sort()).toEqual([...SERVIDOR_DEV].sort());
  });

  it('test_ninguna_otra_dependencia_es_de_pdf_ni_de_mensajeria', () => {
    const todas = Object.keys({ ...paquete.dependencies, ...paquete.devDependencies });
    for (const nombre of todas) expect(nombre).not.toMatch(/pdf|nodemailer|twilio|sendgrid|whatsapp|sms|csv|xlsx$/i);
  });

  it('test_el_cliente_no_agrega_dependencias_respecto_de_la_linea_base', () => {
    const base = ['cupertino_icons', 'data_table_2', 'fl_chart', 'google_fonts', 'http', 'pdf', 'printing', 'provider', 'url_launcher'];
    const actuales = leerDependenciasDart('dependencies');
    expect(actuales.sort()).toEqual(base.sort());
  });
});
