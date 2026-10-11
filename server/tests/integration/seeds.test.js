import { beforeEach, describe, expect, it } from '@jest/globals';
import { query } from '../../config/db.js';
import { resetDatabase } from '../helpers/factories.js';
import { runSeedFile } from '../helpers/seed.js';

const contar = async (tabla) => Number((await query(`SELECT COUNT(*) AS total FROM ${tabla}`))[0].total);

beforeEach(resetDatabase);

describe('seed inicial (CA-10, SC-006)', () => {
  it('test_crea_las_tres_cuentas_y_datos_de_ejemplo_suficientes', async () => {
    await runSeedFile();

    expect(await contar('users')).toBe(3);
    expect(await contar('clients')).toBeGreaterThanOrEqual(8);
    expect(await contar('vehicles')).toBeGreaterThanOrEqual(12);
    const roles = (await query('SELECT username, role FROM users ORDER BY username')).map((u) => `${u.username}:${u.role}`);
    expect(roles).toEqual(['admin:ADMIN', 'mecanico:MECHANIC', 'recepcion:RECEPTIONIST']);
  });

  it('test_es_idempotente_repetirlo_no_duplica_ni_rompe_referencias', async () => {
    await runSeedFile();
    const antes = [await contar('users'), await contar('clients'), await contar('vehicles')];

    await runSeedFile();
    await runSeedFile();

    expect([await contar('users'), await contar('clients'), await contar('vehicles')]).toEqual(antes);
    const huerfanos = await query(
      'SELECT v.id FROM vehicles v LEFT JOIN clients c ON c.id = v.client_id WHERE c.id IS NULL',
    );
    expect(huerfanos).toEqual([]);
  });

  it('test_todos_los_vehiculos_sembrados_tienen_propietario', async () => {
    await runSeedFile();

    const sinDueno = await query('SELECT id FROM vehicles WHERE client_id IS NULL');
    expect(sinDueno).toEqual([]);
  });

  it('test_incluye_un_cliente_sin_correo_dos_con_el_mismo_telefono_y_un_vehiculo_sin_vin_ni_kilometraje', async () => {
    await runSeedFile();

    expect((await query('SELECT id FROM clients WHERE email IS NULL')).length).toBeGreaterThanOrEqual(1);
    const repetidos = await query('SELECT phone FROM clients GROUP BY phone HAVING COUNT(*) > 1');
    expect(repetidos.length).toBeGreaterThanOrEqual(1);
    const incompleto = await query('SELECT id FROM vehicles WHERE vin IS NULL AND current_mileage IS NULL');
    expect(incompleto.length).toBeGreaterThanOrEqual(1);
  });

  it('test_repetir_el_seed_no_restablece_una_contrasena_ya_cambiada', async () => {
    await runSeedFile();
    await query("UPDATE users SET password_hash = 'hash-cambiado' WHERE username = 'admin'");

    await runSeedFile();

    const [admin] = await query("SELECT password_hash FROM users WHERE username = 'admin'");
    expect(admin.password_hash).toBe('hash-cambiado');
  });

  it('test_conserva_acentos_y_eñes_en_los_datos_de_ejemplo', async () => {
    await runSeedFile();

    const nombres = (await query('SELECT name FROM clients')).map((c) => c.name);
    expect(nombres).toContain('Carlos Hernández Ruiz');
    expect(nombres).toContain('María Fernanda López');
  });
});
