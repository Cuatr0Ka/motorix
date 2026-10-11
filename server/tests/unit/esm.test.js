import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from '@jest/globals';

const serverDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

function archivosJs(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    if (entry.name === 'node_modules' || entry.name === 'coverage') return [];
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return archivosJs(full);
    return entry.name.endsWith('.js') ? [full] : [];
  });
}

describe('módulos del backend (CA-5)', () => {
  it('test_package_json_declara_type_module', () => {
    const pkg = JSON.parse(fs.readFileSync(path.join(serverDir, 'package.json'), 'utf8'));
    expect(pkg.type).toBe('module');
  });

  it('test_ningun_archivo_usa_commonjs', () => {
    const esteArchivo = fileURLToPath(import.meta.url);
    const infractores = archivosJs(serverDir)
      .filter((archivo) => archivo !== esteArchivo)
      .filter((archivo) => /\brequire\s*\(|\bmodule\.exports\b/.test(fs.readFileSync(archivo, 'utf8')))
      .map((archivo) => path.relative(serverDir, archivo));
    expect(infractores).toEqual([]);
  });
});
