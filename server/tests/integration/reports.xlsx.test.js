import request from 'supertest';
import ExcelJS from 'exceljs';
import { beforeEach, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { query } from '../../config/db.js';
import { auth, createClientWithVehicle, createOrder, createOrderPart, createPart, createPayment, createUserWithToken, resetDatabase } from '../helpers/factories.js';
import { DENTRO, PERIODO, fecharPago, fecharTerminada, nuevoVehiculo } from '../helpers/reports.js';

const app = createApp();
const XLSX = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
let admin;
let recepcion;
let mecanico;

/** Descarga el reporte como Excel y lo abre con exceljs. */
async function descargar(nombre, q = PERIODO, token = admin.token) {
  const res = await request(app)
    .get(`/api/reports/${nombre}`)
    .query({ ...q, format: 'xlsx' })
    .set(auth(token))
    .buffer(true)
    .parse((r, cb) => {
      const trozos = [];
      r.on('data', (t) => trozos.push(t));
      r.on('end', () => cb(null, Buffer.concat(trozos)));
    });
  return res;
}

async function abrir(res) {
  const libro = new ExcelJS.Workbook();
  await libro.xlsx.load(res.body);
  return libro;
}

/** Texto de todas las celdas de la hoja, una fila por arreglo. */
const filas = (hoja) => {
  const salida = [];
  hoja.eachRow((fila) => salida.push(fila.values.slice(1)));
  return salida;
};

beforeEach(async () => {
  await resetDatabase();
  admin = await createUserWithToken('ADMIN');
  recepcion = await createUserWithToken('RECEPTIONIST');
  mecanico = await createUserWithToken('MECHANIC');

  // Dos pagos, una orden terminada con servicio y mano de obra, y una refacción con y sin costo.
  for (const [importe, metodo] of [['1000.50', 'EFECTIVO'], ['250.25', 'TARJETA']]) {
    const orden = await createOrder((await nuevoVehiculo()).id, recepcion.id, { mechanicId: mecanico.id, status: 'TERMINADO' });
    const pago = await createPayment(orden.id, recepcion.id, { amount: importe, method: metodo });
    await fecharPago(pago.id, DENTRO);
    await fecharTerminada(orden.id, recepcion.id, DENTRO);
    await query('INSERT INTO order_services (order_id, description, amount) VALUES (?, ?, ?)', [orden.id, '=SUMA(1+1)', '500.00']);
    await query('INSERT INTO order_labor (order_id, description, amount) VALUES (?, ?, ?)', [orden.id, 'Mano de obra', '120.40']);
    const conCosto = await createPart(admin.id, { name: `Con costo ${importe}`, purchasePrice: '100.00', salePrice: '150.00' });
    const sinCosto = await createPart(admin.id, { name: `Sin precio ${importe}`, purchasePrice: null, salePrice: '90.00' });
    await createOrderPart(orden.id, conCosto.id, mecanico.id, 2, 150);
    await createOrderPart(orden.id, sinCosto.id, mecanico.id, 1, 90);
    await query('UPDATE order_parts SET created_at = ? WHERE order_id = ?', [DENTRO, orden.id]);
  }
});

describe('exportación a Excel de los cinco reportes (US7, FR-022)', () => {
  it.each(['income', 'services', 'productivity', 'parts', 'rotation'])('test_%s_responde_un_xlsx_con_el_nombre_del_contrato', async (nombre) => {
    const res = await descargar(nombre);

    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toContain(XLSX);
    expect(res.headers['content-disposition']).toBe(`attachment; filename="reporte-${nombre}-2026-10-01_2026-10-31.xlsx"`);
    expect(res.body.subarray(0, 2).toString()).toBe('PK'); // un .xlsx es un zip
    const libro = await abrir(res);
    expect(libro.worksheets).toHaveLength(1);
  });

  it('test_el_contenido_de_ingresos_coincide_con_el_json_al_centavo', async () => {
    const json = (await request(app).get('/api/reports/income').query(PERIODO).set(auth(admin.token))).body.data;
    const hoja = (await abrir(await descargar('income'))).worksheets[0];
    const texto = JSON.stringify(filas(hoja));

    expect(json.total).toBe('1250.75');
    // Los importes son números reales de Excel, no texto.
    const celdaTotal = [];
    hoja.eachRow((fila) => fila.eachCell((celda) => celdaTotal.push(celda.value)));
    expect(celdaTotal).toContain(1250.75);
    expect(texto).toContain('Efectivo');
    expect(texto).toContain('Tarjeta');
    expect(texto).toContain('2026-10-15');
    expect(texto).toContain('Reporte de ingresos');
    expect(texto).toContain('del 2026-10-01 al 2026-10-31');
  });

  it('test_servicios_productividad_refacciones_y_rotacion_coinciden_con_su_json', async () => {
    const hojaDe = async (nombre) => (await abrir(await descargar(nombre))).worksheets[0];
    const celdas = (hoja) => {
      const valores = [];
      hoja.eachRow((fila) => fila.eachCell((celda) => valores.push(celda.value)));
      return valores;
    };

    const servicios = celdas(await hojaDe('services'));
    expect(servicios).toContain(2); // veces realizado
    expect(servicios).toContain(1000); // importe agrupado (2 × 500.00)

    const productividad = celdas(await hojaDe('productivity'));
    expect(productividad).toContain(240.8); // mano de obra: 2 × 120.40

    const partes = celdas(await hojaDe('parts'));
    expect(partes).toContain('Sin costo');
    expect(partes.some((v) => typeof v === 'string' && v.startsWith('Con costo'))).toBe(true);
  });

  it('test_una_celda_de_texto_que_parece_formula_se_guarda_como_texto', async () => {
    const hoja = (await abrir(await descargar('services'))).worksheets[0];
    let formula = null;
    hoja.eachRow((fila) => fila.eachCell((celda) => {
      if (celda.value === '=SUMA(1+1)') formula = celda;
    }));

    expect(formula).not.toBeNull();
    expect(formula.type).toBe(ExcelJS.ValueType.String); // texto, nunca una fórmula que se ejecute
  });

  it('test_el_diseno_usa_el_logo_los_colores_y_los_formatos_de_motorix', async () => {
    const hoja = (await abrir(await descargar('parts'))).worksheets[0];

    expect(hoja.getImages()).toHaveLength(1); // logo
    expect(hoja.getCell('B1').value).toBe('MOTORIX');
    expect(hoja.getCell('B1').font.color.argb).toBe('FF9B4F55');
    expect(hoja.getCell('A4').fill.fgColor.argb).toBe('FF9B4F55'); // franja de color primario
    expect(hoja.getCell('A1').fill.fgColor.argb).toBe('FFF5F2F1'); // fondo cálido del encabezado

    // Encabezado de la tabla: fondo vino con texto blanco en negritas.
    const encabezado = hoja.getCell('A6');
    expect(encabezado.value).toBe('Código');
    expect(encabezado.fill.fgColor.argb).toBe('FF9B4F55');
    expect(encabezado.font).toMatchObject({ bold: true, color: { argb: 'FFFFFFFF' } });

    // Importes con formato de moneda y porcentaje real; encabezado fijo y filtros.
    expect(hoja.getCell('D7').numFmt).toBe('"$"#,##0.00');
    expect(hoja.getCell('G7').numFmt).toBe('0.00"%"');
    expect(hoja.views[0]).toMatchObject({ state: 'frozen', ySplit: 6 });
    expect(hoja.autoFilter).toBeTruthy();
  });

  it('test_un_periodo_sin_datos_trae_encabezados_y_el_texto_de_vacio', async () => {
    const res = await descargar('services', { from: '2025-01-01', to: '2025-01-31' });
    const hoja = (await abrir(res)).worksheets[0];
    const texto = JSON.stringify(filas(hoja));

    expect(res.status).toBe(200);
    expect(texto).toContain('Servicio');
    expect(texto).toContain('No hay datos en este periodo');
  });

  it('test_un_periodo_invalido_responde_400_igual_que_en_json_y_los_otros_roles_403', async () => {
    const mala = await request(app).get('/api/reports/income').query({ from: '2026-10-31', to: '2026-10-01', format: 'xlsx' }).set(auth(admin.token));
    expect(mala.status).toBe(400);
    expect(mala.body.error.code).toBe('VALIDATION_ERROR');

    for (const u of [recepcion, mecanico]) {
      const res = await request(app).get('/api/reports/income').query({ ...PERIODO, format: 'xlsx' }).set(auth(u.token));
      expect(res.status).toBe(403);
    }
  });
});
