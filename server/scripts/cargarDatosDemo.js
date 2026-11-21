/**
 * Reemplaza los datos de negocio de la base de DESARROLLO (`motorix`) por un conjunto de ejemplo completo y coherente, con
 * fechas de octubre y noviembre de 2026 y citas y mantenimientos hasta el 5 de diciembre, para ver las gráficas y las listas.
 *
 * Borra: clientes, vehículos, citas, órdenes (con sus servicios, mano de obra, refacciones e historial), refacciones y sus
 * movimientos, pagos, tickets, mantenimientos y avisos. CONSERVA: usuarios y sus contraseñas, configuración, tipos de servicio,
 * términos y aceptaciones y la bitácora.
 *
 * Uso (desde server/):  node scripts/cargarDatosDemo.js            -> solo muestra el resumen de lo que cargaría
 *                       node scripts/cargarDatosDemo.js --confirmar -> borra y carga (haz antes un respaldo)
 */
import { withTransaction, query } from '../config/db.js';
import { getConfig } from '../config/env.js';
import { buildTicketContent } from '../services/ticketContent.js';

const CONFIRMAR = process.argv.includes('--confirmar');

// ----------------------------------------------------------------------------------------------------------------------------
// Utilidades de fecha y dinero
// ----------------------------------------------------------------------------------------------------------------------------
const pad = (n) => String(n).padStart(2, '0');
/** `AAAA-MM-DD` + `HH:mm` (+ minutos) → texto `AAAA-MM-DD HH:mm:ss` en hora local. */
function at(day, time = '09:00', plusMinutes = 0) {
  const [y, m, d] = day.split('-').map(Number);
  const [h, mi] = time.split(':').map(Number);
  const date = new Date(y, m - 1, d, h, mi + plusMinutes, 0);
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:00`;
}
/** Suma días a un `AAAA-MM-DD`. */
function addDays(day, days) {
  const [y, m, d] = day.split('-').map(Number);
  const date = new Date(y, m - 1, d + days);
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}
const cents = (value) => Math.round(Number(value) * 100);
const money = (c) => (c / 100).toFixed(2);

// ----------------------------------------------------------------------------------------------------------------------------
// Catálogos de ejemplo
// ----------------------------------------------------------------------------------------------------------------------------
const CLIENTS = [
  ['Ana Morales Pérez', '7761234501', 'ana.morales@correo.mx', 'Av. Hidalgo 120, Huauchinango, Puebla'],
  ['Luis Hernández Ríos', '7761234502', 'luis.hernandez@correo.mx', 'Calle Juárez 45, Huauchinango, Puebla'],
  ['María Fernanda Cruz', '7761234503', 'mafer.cruz@correo.mx', 'Blvd. Las Palmas 310, Huauchinango, Puebla'],
  ['José Antonio Ramírez', '7761234504', null, 'Calle Morelos 88, Xicotepec de Juárez, Puebla'],
  ['Sofía Delgado Vega', '7761234505', 'sofia.delgado@correo.mx', 'Av. Reforma 15, Huauchinango, Puebla'],
  ['Ricardo Salazar Mora', '7761234506', 'ricardo.salazar@correo.mx', 'Calle 5 de Mayo 200, Huauchinango, Puebla'],
  ['Transportes Sierra Norte', '7761234507', 'contacto@sierranorte.mx', 'Carretera Huauchinango-Tulancingo km 3'],
  ['Patricia Navarro León', '7761234508', 'paty.navarro@correo.mx', 'Calle Allende 67, Huauchinango, Puebla'],
  ['Jorge Luna Aguilar', '7761234509', null, 'Av. Juárez 410, Xicotepec de Juárez, Puebla'],
  ['Carmen Ortiz Solís', '7761234510', 'carmen.ortiz@correo.mx', 'Calle Hidalgo 33, Huauchinango, Puebla'],
  ['Fernando Castillo Díaz', '7761234511', 'fernando.castillo@correo.mx', 'Calle Zaragoza 150, Huauchinango, Puebla'],
  ['Laura Mendoza Ibarra', '7761234512', 'laura.mendoza@correo.mx', 'Av. Independencia 90, Huauchinango, Puebla'],
];

// [cliente, marca, modelo, año, placa, color, kilometraje base antes de octubre]
const VEHICLES = [
  [0, 'Nissan', 'Versa', 2019, 'PUE-481-A', 'Gris', 84200],
  [1, 'Chevrolet', 'Aveo', 2017, 'PUE-512-B', 'Blanco', 112300],
  [2, 'Volkswagen', 'Jetta', 2020, 'PUE-733-C', 'Negro', 58100],
  [3, 'Toyota', 'Hilux', 2018, 'PUE-204-D', 'Plata', 97800],
  [4, 'Honda', 'Civic', 2021, 'PUE-865-E', 'Rojo', 41200],
  [5, 'Ford', 'Ranger', 2016, 'PUE-317-F', 'Azul', 139500],
  [6, 'Nissan', 'NP300', 2015, 'PUE-640-G', 'Blanco', 186400],
  [7, 'Mazda', 'Mazda 3', 2019, 'PUE-958-H', 'Gris', 73900],
  [8, 'Kia', 'Rio', 2020, 'PUE-126-J', 'Blanco', 52300],
  [9, 'Chevrolet', 'Spark', 2018, 'PUE-379-K', 'Amarillo', 88700],
  [10, 'Hyundai', 'Tucson', 2022, 'PUE-847-L', 'Negro', 29600],
  [11, 'Toyota', 'Corolla', 2017, 'PUE-592-M', 'Plata', 121000],
  [6, 'Ford', 'Transit', 2014, 'PUE-418-N', 'Blanco', 203700],
  [2, 'Seat', 'Ibiza', 2016, 'PUE-275-P', 'Rojo', 96500],
  [7, 'Suzuki', 'Swift', 2021, 'PUE-704-R', 'Azul', 38800],
  [3, 'Volkswagen', 'Vento', 2019, 'PUE-361-S', 'Gris', 67200],
];

// [código, nombre, categoría, marca, unidad, mínimo, precio de compra, precio de venta, existencia final deseada]
const PARTS = [
  ['ACE-5W30', 'Aceite sintético 5W-30', 'Lubricantes', 'Mobil', 'litro', 12, 95, 140, 20],
  ['ACE-10W40', 'Aceite 10W-40', 'Lubricantes', 'Castrol', 'litro', 8, 70, 105, 6],
  ['FIL-ACE', 'Filtro de aceite', 'Filtros', 'Fram', 'pieza', 10, 55, 95, 14],
  ['FIL-AIRE', 'Filtro de aire', 'Filtros', 'Fram', 'pieza', 6, 80, 150, 5],
  ['BAL-DEL', 'Balatas delanteras', 'Frenos', 'Brembo', 'juego', 4, 520, 820, 3],
  ['BAL-TRA', 'Balatas traseras', 'Frenos', 'Brembo', 'juego', 3, 430, 690, 6],
  ['DIS-DEL', 'Disco de freno delantero', 'Frenos', 'Bosch', 'pieza', 2, 640, 980, 0],
  ['BUJ-IRI', 'Bujía de iridio', 'Encendido', 'NGK', 'pieza', 12, 120, 210, 20],
  ['BAT-12V', 'Batería 12V', 'Eléctrico', 'LTH', 'pieza', 2, 1350, 1890, 1],
  ['AMO-TRA', 'Amortiguador trasero', 'Suspensión', 'Monroe', 'pieza', 4, 780, 1190, 8],
  ['BAN-DIS', 'Kit de banda de distribución', 'Motor', 'Gates', 'kit', 2, 890, 1350, 2],
  ['ANT-5L', 'Anticongelante', 'Lubricantes', 'Prestone', 'litro', 10, 38, 70, 15],
  ['LIM-INY', 'Limpiador de inyectores', 'Aditivos', 'Wynn\'s', 'pieza', 3, null, 160, 7],
  ['KIT-EMB', 'Kit de embrague', 'Transmisión', 'Sachs', 'kit', 1, 1800, 2650, 1],
];
// Resurtidos (entradas de inventario) después del stock inicial: [código, día, cantidad]
const RESTOCK = [
  ['ACE-5W30', '2026-10-22', 12],
  ['FIL-ACE', '2026-11-05', 10],
  ['BAL-TRA', '2026-11-08', 4],
  ['ANT-5L', '2026-10-15', 10],
];

// Servicios de ejemplo: clave → [descripción, importe, tipo de servicio del catálogo o null]
const SVC = {
  aceite: ['Cambio de aceite y filtro', 650, 'Cambio de aceite'],
  afin: ['Afinación mayor', 1400, 'Afinación'],
  frenos: ['Cambio de balatas delanteras', 850, 'Revisión de frenos'],
  frenosT: ['Cambio de balatas traseras', 700, 'Revisión de frenos'],
  discos: ['Rectificado y cambio de discos', 900, 'Revisión de frenos'],
  alin: ['Alineación y balanceo', 750, 'Alineación y balanceo'],
  rev: ['Revisión general de 30 puntos', 450, 'Revisión general'],
  susp: ['Cambio de amortiguadores traseros', 1800, null],
  bat: ['Cambio de batería', 400, null],
  clima: ['Recarga de aire acondicionado', 900, null],
  diag: ['Diagnóstico con escáner', 350, null],
  embr: ['Cambio de kit de embrague', 3200, null],
  banda: ['Cambio de banda de distribución', 1500, null],
  anti: ['Cambio de anticongelante', 380, null],
};

// ----------------------------------------------------------------------------------------------------------------------------
// Órdenes. Entregadas: se cobran y generan ticket. Abiertas: la última etapa indica en qué estado quedan.
// Campos: día de recepción, vehículo (índice), mecánico, problema, servicios, mano de obra, refacciones [código, cantidad], cobro
// ----------------------------------------------------------------------------------------------------------------------------
const DELIVERED = [
  { d: '2026-10-01', v: 0, m: 'mecanico', p: 'Cambio de aceite programado', s: ['aceite'], l: [['Mano de obra mecánica', 250]], r: [['ACE-5W30', 4], ['FIL-ACE', 1]], pay: 'EFECTIVO' },
  { d: '2026-10-02', v: 1, m: 'mecanico2', p: 'Ruido al frenar', s: ['frenos'], l: [['Mano de obra frenos', 400]], r: [['BAL-DEL', 1]], pay: 'TARJETA' },
  { d: '2026-10-03', v: 5, m: 'mecanico', p: 'Revisión antes de viaje', s: ['rev', 'alin'], l: [['Mano de obra mecánica', 300]], r: [], pay: 'TRANSFERENCIA' },
  { d: '2026-10-06', v: 2, m: 'mecanico', p: 'Afinación de 60 000 km', s: ['afin'], l: [['Mano de obra afinación', 500]], r: [['BUJ-IRI', 4], ['FIL-AIRE', 1], ['ACE-5W30', 4], ['FIL-ACE', 1]], pay: 'MERCADO_PAGO' },
  { d: '2026-10-07', v: 3, m: 'mecanico2', p: 'Vibración en el volante', s: ['alin', 'diag'], l: [['Mano de obra suspensión', 350]], r: [], pay: 'EFECTIVO' },
  { d: '2026-10-08', v: 6, m: 'mecanico', p: 'Camioneta de reparto: cambio de aceite', s: ['aceite'], l: [['Mano de obra mecánica', 250]], r: [['ACE-10W40', 6], ['FIL-ACE', 1]], pay: 'TRANSFERENCIA' },
  { d: '2026-10-10', v: 4, m: 'mecanico2', p: 'Revisión general y aire acondicionado', s: ['rev', 'clima'], l: [['Mano de obra eléctrica', 300]], r: [], pay: 'TARJETA' },
  { d: '2026-10-13', v: 7, m: 'mecanico', p: 'Se siente dura la suspensión trasera', s: ['susp'], l: [['Mano de obra suspensión', 600]], r: [['AMO-TRA', 2]], pay: 'EFECTIVO' },
  { d: '2026-10-14', v: 8, m: 'mecanico2', p: 'Cambio de aceite y revisión', s: ['aceite', 'rev'], l: [['Mano de obra mecánica', 250]], r: [['ACE-5W30', 4], ['FIL-ACE', 1]], pay: 'EFECTIVO' },
  { d: '2026-10-16', v: 9, m: 'mecanico', p: 'No arranca por las mañanas', s: ['bat', 'diag'], l: [['Mano de obra eléctrica', 250]], r: [['BAT-12V', 1]], pay: 'TARJETA' },
  { d: '2026-10-17', v: 1, m: 'mecanico2', p: 'Frenos traseros con ruido', s: ['frenosT'], l: [['Mano de obra frenos', 350]], r: [['BAL-TRA', 1]], pay: 'EFECTIVO' },
  { d: '2026-10-20', v: 10, m: 'mecanico', p: 'Primer servicio de 30 000 km', s: ['aceite', 'rev'], l: [['Mano de obra mecánica', 300]], r: [['ACE-5W30', 5], ['FIL-ACE', 1], ['FIL-AIRE', 1]], pay: 'MERCADO_PAGO' },
  { d: '2026-10-21', v: 11, m: 'mecanico2', p: 'Cambio de banda de distribución', s: ['banda', 'anti'], l: [['Mano de obra motor', 700]], r: [['BAN-DIS', 1], ['ANT-5L', 4]], pay: 'TRANSFERENCIA' },
  { d: '2026-10-23', v: 12, m: 'mecanico', p: 'Camioneta de reparto: frenos y alineación', s: ['frenos', 'alin'], l: [['Mano de obra frenos', 400]], r: [['BAL-DEL', 1], ['DIS-DEL', 2]], pay: 'TRANSFERENCIA' },
  { d: '2026-10-24', v: 0, m: 'mecanico2', p: 'Luz del motor encendida', s: ['diag'], l: [['Mano de obra diagnóstico', 200]], r: [['LIM-INY', 1]], pay: 'EFECTIVO' },
  { d: '2026-10-27', v: 13, m: 'mecanico', p: 'Cambio de aceite', s: ['aceite'], l: [['Mano de obra mecánica', 250]], r: [['ACE-5W30', 4], ['FIL-ACE', 1]], pay: 'EFECTIVO' },
  { d: '2026-10-29', v: 14, m: 'mecanico2', p: 'Revisión de frenos', s: ['frenos'], l: [['Mano de obra frenos', 400]], r: [['BAL-DEL', 1]], pay: 'TARJETA' },
  { d: '2026-10-30', v: 15, m: 'mecanico', p: 'Afinación y alineación', s: ['afin', 'alin'], l: [['Mano de obra afinación', 500]], r: [['BUJ-IRI', 4], ['FIL-AIRE', 1], ['ACE-5W30', 4], ['FIL-ACE', 1]], pay: 'MERCADO_PAGO' },
  { d: '2026-11-03', v: 2, m: 'mecanico2', p: 'Revisión general', s: ['rev'], l: [['Mano de obra mecánica', 200]], r: [], pay: 'EFECTIVO' },
  { d: '2026-11-04', v: 3, m: 'mecanico', p: 'Cambio de aceite de la camioneta', s: ['aceite'], l: [['Mano de obra mecánica', 250]], r: [['ACE-5W30', 5], ['FIL-ACE', 1]], pay: 'TARJETA' },
  { d: '2026-11-05', v: 5, m: 'mecanico2', p: 'Frenos y discos', s: ['frenos', 'discos'], l: [['Mano de obra frenos', 500]], r: [['BAL-DEL', 1], ['DIS-DEL', 2]], pay: 'TRANSFERENCIA' },
  { d: '2026-11-07', v: 7, m: 'mecanico', p: 'Cambio de anticongelante', s: ['anti', 'rev'], l: [['Mano de obra mecánica', 250]], r: [['ANT-5L', 5]], pay: 'EFECTIVO' },
  { d: '2026-11-10', v: 8, m: 'mecanico2', p: 'Ruido en la suspensión delantera', s: ['alin', 'diag'], l: [['Mano de obra suspensión', 350]], r: [], pay: 'MERCADO_PAGO' },
  { d: '2026-11-11', v: 6, m: 'mecanico', p: 'Camioneta de reparto: embrague', s: ['embr'], l: [['Mano de obra transmisión', 1200]], r: [['KIT-EMB', 1]], pay: 'TRANSFERENCIA' },
  { d: '2026-11-12', v: 9, m: 'mecanico2', p: 'Cambio de aceite', s: ['aceite'], l: [['Mano de obra mecánica', 250]], r: [['ACE-10W40', 4], ['FIL-ACE', 1]], pay: 'EFECTIVO' },
  { d: '2026-11-13', v: 4, m: 'mecanico', p: 'Frenos traseros', s: ['frenosT'], l: [['Mano de obra frenos', 350]], r: [['BAL-TRA', 1]], pay: 'TARJETA' },
  { d: '2026-11-14', v: 10, m: 'mecanico2', p: 'Revisión por ruido en el motor', s: ['diag', 'rev'], l: [['Mano de obra diagnóstico', 250]], r: [['LIM-INY', 2]], pay: 'EFECTIVO' },
  { d: '2026-11-17', v: 0, m: 'mecanico', p: 'Cambio de aceite y filtros', s: ['aceite'], l: [['Mano de obra mecánica', 250]], r: [['ACE-5W30', 4], ['FIL-ACE', 1], ['FIL-AIRE', 1]], pay: 'EFECTIVO' },
  { d: '2026-11-18', v: 13, m: 'mecanico2', p: 'Suspensión trasera golpeando', s: ['susp'], l: [['Mano de obra suspensión', 600]], r: [['AMO-TRA', 2]], pay: 'TARJETA' },
  { d: '2026-11-19', v: 14, m: 'mecanico', p: 'Alineación y balanceo', s: ['alin'], l: [['Mano de obra mecánica', 150]], r: [], pay: 'EFECTIVO' },
];

// Órdenes abiertas hoy (21 de noviembre). Cada una usa un vehículo distinto (solo se permite una orden abierta por vehículo).
const OPEN = [
  { d: '2026-11-12', v: 11, m: 'mecanico2', p: 'Pierde potencia al subir', status: 'EN_REPARACION', s: ['diag', 'afin'], l: [['Mano de obra afinación', 500]], r: [['BUJ-IRI', 4]], note: 'Detenida: espera autorización del cliente' },
  { d: '2026-11-18', v: 1, m: 'mecanico', p: 'Cambio de amortiguadores', status: 'ESPERANDO_REFACCION', s: ['susp'], l: [['Mano de obra suspensión', 600]], r: [['AMO-TRA', 2]], note: 'Se espera el segundo amortiguador' },
  { d: '2026-11-19', v: 12, m: 'mecanico2', p: 'Frenos y revisión', status: 'EN_REPARACION', s: ['frenos', 'rev'], l: [['Mano de obra frenos', 400]], r: [['BAL-DEL', 1]], note: null },
  { d: '2026-11-20', v: 15, m: 'mecanico', p: 'Ruido raro al encender', status: 'DIAGNOSTICO', s: ['diag'], l: [], r: [], note: null },
  { d: '2026-11-21', v: 7, m: 'mecanico2', p: 'Cambio de aceite', status: 'RECIBIDO', s: [], l: [], r: [], note: null },
  { d: '2026-11-18', v: 5, m: 'mecanico', p: 'Aire acondicionado sin enfriar', status: 'TERMINADO', s: ['clima'], l: [['Mano de obra eléctrica', 300]], r: [], pay: 'PENDIENTE_MP' },
  { d: '2026-11-19', v: 8, m: 'mecanico2', p: 'Cambio de aceite y filtro', status: 'TERMINADO', s: ['aceite'], l: [['Mano de obra mecánica', 250]], r: [['ACE-5W30', 4], ['FIL-ACE', 1]], pay: null },
];

// Citas futuras (hasta el 5 de diciembre) [día, hora, vehículo, motivo, estado]
const FUTURE_APPOINTMENTS = [
  ['2026-11-21', '16:30', 2, 'Revisión general', 'CONFIRMADA'],
  ['2026-11-22', '09:30', 3, 'Cambio de aceite', 'PENDIENTE'],
  ['2026-11-22', '11:00', 4, 'Revisión de frenos', 'CONFIRMADA'],
  ['2026-11-24', '10:00', 0, 'Servicio de 90 000 km', 'PENDIENTE'],
  ['2026-11-25', '09:00', 10, 'Revisión por ruido', 'PENDIENTE'],
  ['2026-11-26', '12:00', 13, 'Alineación y balanceo', 'CONFIRMADA'],
  ['2026-11-27', '10:30', 14, 'Cambio de aceite', 'PENDIENTE'],
  ['2026-11-28', '09:30', 9, 'Revisión de batería', 'PENDIENTE'],
  ['2026-12-01', '10:00', 6, 'Servicio de la camioneta de reparto', 'CONFIRMADA'],
  ['2026-12-02', '11:30', 2, 'Afinación', 'PENDIENTE'],
  ['2026-12-03', '09:00', 3, 'Cambio de anticongelante', 'PENDIENTE'],
  ['2026-12-04', '12:30', 4, 'Revisión general', 'PENDIENTE'],
  ['2026-12-05', '10:00', 0, 'Alineación y balanceo', 'PENDIENTE'],
];
// Citas pasadas canceladas [día, hora, vehículo, motivo, razón de cancelación]
const CANCELLED_APPOINTMENTS = [
  ['2026-10-09', '11:00', 9, 'Cambio de aceite', 'El cliente no pudo asistir'],
  ['2026-11-06', '10:00', 12, 'Revisión de frenos', 'Reprogramada por el cliente'],
];

// Mantenimientos pendientes por vehículo (uno por vehículo): [vehículo, descripción, fecha límite o null, kilometraje límite o null]
const PENDING_MAINTENANCE = [
  [0, 'Cambio de aceite y filtro', '2026-11-28', null], // próximo
  [2, 'Servicio de afinación', '2027-04-06', 70000], // normal
  [3, 'Cambio de aceite', '2026-12-03', null], // próximo
  [4, 'Revisión de frenos', '2026-12-05', null], // próximo
  [5, 'Revisión de suspensión', '2026-11-08', null], // vencido
  [6, 'Cambio de aceite y filtro', '2026-10-30', null], // vencido
  [7, 'Cambio de anticongelante', '2027-05-07', null], // normal
  [9, 'Cambio de aceite', '2026-12-04', null], // próximo
  [10, 'Revisión de 40 000 km', null, 0], // por kilometraje (se calcula abajo)
  [13, 'Cambio de aceite', '2027-04-27', null], // normal
];

// ----------------------------------------------------------------------------------------------------------------------------
// Construcción del conjunto de datos en memoria
// ----------------------------------------------------------------------------------------------------------------------------
function build(users) {
  const partByCode = Object.fromEntries(PARTS.map((p) => [p[0], { code: p[0], name: p[1], category: p[2], brand: p[3], unit: p[4], min: p[5], buy: p[6], sale: p[7], finalStock: p[8] }]));
  const mileage = VEHICLES.map((v) => v[6]);
  const orders = [];
  const all = [
    ...DELIVERED.map((o) => ({ ...o, final: 'ENTREGADO' })),
    ...OPEN.map((o) => ({ ...o, final: o.status })),
  ].sort((a, b) => a.d.localeCompare(b.d));

  all.forEach((spec, index) => {
    const id = index + 1;
    const mechanicId = users[spec.m];
    const entry = mileage[spec.v] + 120 + ((id * 37) % 380); // kilometraje de entrada creciente por vehículo
    const serviceMileage = entry + ((id * 7) % 20);
    mileage[spec.v] = Math.max(mileage[spec.v], serviceMileage);
    const history = [[null, 'RECIBIDO', users.recepcion, at(spec.d, '09:00')]];
    const steps = {
      DIAGNOSTICO: ['DIAGNOSTICO', users[spec.m], at(spec.d, '09:00', 50)],
      EN_REPARACION: ['EN_REPARACION', users[spec.m], at(spec.d, '09:00', 130)],
      ESPERANDO: ['ESPERANDO_REFACCION', users[spec.m], at(spec.d, '14:00')],
    };
    const finalIdx = ['RECIBIDO', 'DIAGNOSTICO', 'EN_REPARACION', 'ESPERANDO_REFACCION', 'TERMINADO', 'ENTREGADO'].indexOf(spec.final);
    if (finalIdx >= 1) history.push([history.at(-1)[1], ...steps.DIAGNOSTICO]);
    if (finalIdx >= 2) history.push([history.at(-1)[1], ...steps.EN_REPARACION]);
    if (spec.final === 'ESPERANDO_REFACCION') history.push([history.at(-1)[1], ...steps.ESPERANDO]);
    let finishedAt = null;
    let deliveredAt = null;
    if (finalIdx >= 4) {
      finishedAt = spec.final === 'ENTREGADO' && id % 3 === 0 ? at(addDays(spec.d, 1), '12:10') : at(spec.d, '17:00');
      history.push([history.at(-1)[1], 'TERMINADO', users[spec.m], finishedAt]);
    }
    if (spec.final === 'ENTREGADO') {
      const day = addDays(finishedAt.slice(0, 10), id % 4 === 0 ? 1 : 0);
      deliveredAt = at(day, '18:05', id % 4 === 0 ? -470 : 0);
      history.push(['TERMINADO', 'ENTREGADO', users.recepcion, deliveredAt]);
    }
    const lastChange = history.at(-1)[3];
    const services = spec.s.map((key) => ({ key, desc: SVC[key][0], amount: SVC[key][1], type: SVC[key][2] }));
    const labor = spec.l.map(([desc, amount]) => ({ desc, amount }));
    const parts = spec.r.map(([code, qty]) => ({ ...partByCode[code], qty }));
    const total = services.reduce((t, s) => t + cents(s.amount), 0) + labor.reduce((t, l) => t + cents(l.amount), 0) + parts.reduce((t, p) => t + p.qty * cents(p.sale), 0);
    orders.push({
      id, spec, mechanicId, entry, serviceMileage: finalIdx >= 4 ? serviceMileage : null, history, finishedAt, deliveredAt, lastChange,
      services, labor, parts, totalCents: total, status: spec.final, openedAt: at(spec.d, '09:00'),
      partsAt: at(spec.d, '12:00'), linesAt: at(spec.d, '15:00'),
    });
  });
  return { orders, mileage, partByCode };
}

function plan(users) {
  const { orders, mileage, partByCode } = build(users);

  // Pagos y tickets
  const payments = [];
  const methodsRef = { TARJETA: 'TERM', TRANSFERENCIA: 'SPEI', EFECTIVO: null, MERCADO_PAGO: 'MP' };
  for (const order of orders) {
    const pay = order.spec.pay;
    if (order.status === 'ENTREGADO') {
      const paidAt = at(order.deliveredAt.slice(0, 10), order.deliveredAt.slice(11, 16), -6);
      // Un pago cancelado antes del pagado en un par de órdenes (para ver el estado en la lista).
      if (order.id % 11 === 0) {
        payments.push({ order, amount: order.totalCents, method: 'MERCADO_PAGO', status: 'CANCELADO', paidAt: null, createdAt: at(order.deliveredAt.slice(0, 10), '10:00'), reference: null });
      }
      payments.push({
        order, amount: order.totalCents, method: pay, status: 'PAGADO', paidAt, createdAt: paidAt,
        reference: methodsRef[pay] ? `${methodsRef[pay]}-${String(40000 + order.id * 137).slice(0, 5)}` : null, mp: pay === 'MERCADO_PAGO',
      });
    } else if (pay === 'PENDIENTE_MP') {
      payments.push({ order, amount: order.totalCents, method: 'MERCADO_PAGO', status: 'PENDIENTE', paidAt: null, createdAt: at('2026-11-20', '12:00'), reference: null, mp: true });
    }
  }

  // Mantenimientos: pendientes (uno por vehículo) y atendidos (de órdenes anteriores)
  const lastDelivered = {};
  const maintenance = [];
  for (const order of orders) if (order.status === 'ENTREGADO') (lastDelivered[order.spec.v] ??= []).push(order);
  for (const [vehicle, description, dueDate, dueKm] of PENDING_MAINTENANCE) {
    const orderList = lastDelivered[vehicle] ?? [];
    const order = orderList.at(-1);
    if (!order) continue;
    const km = dueKm === 0 ? mileage[vehicle] + 700 : dueKm; // «Revisión de 40 000 km»: faltan 700 km
    maintenance.push({ vehicle, order, description, dueDate, dueKm: km, status: 'PENDIENTE', attendedAt: null });
    // El anterior, ya atendido, cuando el vehículo tuvo una orden previa.
    if (orderList.length >= 2) {
      const previous = orderList.at(-2);
      maintenance.push({ vehicle, order: previous, description: 'Servicio programado anterior', dueDate: addDays(previous.spec.d, 150), dueKm: null, status: 'ATENDIDO', attendedAt: order.openedAt });
    }
  }

  // Movimientos de inventario: stock inicial, resurtidos y salidas por orden
  const usage = {};
  const movements = [];
  for (const order of orders) {
    if (order.status === 'RECIBIDO' || order.status === 'DIAGNOSTICO') continue;
    for (const part of order.parts) {
      usage[part.code] = (usage[part.code] ?? 0) + part.qty;
      movements.push({ code: part.code, type: 'OUT', quantity: -part.qty, reason: `Uso en la orden OS-${String(order.id).padStart(6, '0')}`, orderId: order.id, user: order.mechanicId, at: order.partsAt });
    }
  }
  const restockByCode = {};
  for (const [code, day, qty] of RESTOCK) {
    restockByCode[code] = (restockByCode[code] ?? 0) + qty;
    movements.push({ code, type: 'IN', quantity: qty, reason: 'Compra a proveedor', orderId: null, user: users.admin, at: at(day, '10:00') });
  }
  const parts = PARTS.map((p) => {
    const initial = (usage[p[0]] ?? 0) + p[8] - (restockByCode[p[0]] ?? 0);
    if (initial < 0) throw new Error(`La existencia final deseada de ${p[0]} no es alcanzable (${initial}).`);
    if (initial > 0) movements.push({ code: p[0], type: 'IN', quantity: initial, reason: 'Existencia inicial', orderId: null, user: users.admin, at: at('2026-10-01', '08:30') });
    return { code: p[0], name: p[1], category: p[2], brand: p[3], unit: p[4], min: p[5], buy: p[6], sale: p[7], stock: p[8] };
  });

  return { orders, mileage, payments, maintenance, movements, parts };
}

// ----------------------------------------------------------------------------------------------------------------------------
// Ejecución
// ----------------------------------------------------------------------------------------------------------------------------
async function loadUsers() {
  const rows = await query("SELECT id, username FROM users WHERE username IN ('admin', 'recepcion', 'mecanico', 'mecanico2')");
  const users = Object.fromEntries(rows.map((r) => [r.username, r.id]));
  for (const name of ['admin', 'recepcion', 'mecanico', 'mecanico2']) {
    if (!users[name]) throw new Error(`Falta el usuario «${name}»: aplica antes los seeds con database/scripts/aplicar-seeds.ps1.`);
  }
  return users;
}

async function main() {
  const { db } = getConfig();
  if (db.database !== 'motorix') throw new Error(`Solo se carga la base de desarrollo «motorix» (esta es «${db.database}»).`);
  const users = await loadUsers();
  const data = plan(users);

  const paid = data.payments.filter((p) => p.status === 'PAGADO');
  const resumen = {
    clientes: CLIENTS.length,
    vehiculos: VEHICLES.length,
    ordenes: data.orders.length,
    ordenesEntregadas: data.orders.filter((o) => o.status === 'ENTREGADO').length,
    ordenesAbiertas: data.orders.filter((o) => o.status !== 'ENTREGADO').length,
    pagosPagados: paid.length,
    ingresosOctubre: money(paid.filter((p) => p.paidAt.startsWith('2026-10')).reduce((t, p) => t + p.amount, 0)),
    ingresosNoviembre: money(paid.filter((p) => p.paidAt.startsWith('2026-11')).reduce((t, p) => t + p.amount, 0)),
    refacciones: data.parts.length,
    movimientos: data.movements.length,
    mantenimientos: data.maintenance.length,
    citasFuturas: FUTURE_APPOINTMENTS.length,
  };
  console.log('Resumen de lo que se cargaría:', resumen);
  if (!CONFIRMAR) {
    console.log('\nNo se cambió nada. Para borrar los datos de ejemplo anteriores y cargar estos: node scripts/cargarDatosDemo.js --confirmar');
    return;
  }

  const settings = Object.fromEntries((await query('SELECT setting_key, setting_value FROM settings')).map((r) => [r.setting_key, r.setting_value]));
  const shop = { name: settings['shop.name'] ?? 'Motorix Taller Mecánico', address: settings['shop.address'] ?? '', phone: settings['shop.phone'] ?? '' };

  await withTransaction(async (c) => {
    const run = (sql, params = []) => c.execute(sql, params);

    // 1. Borrar los datos de negocio (en el orden de las llaves foráneas). Se conservan usuarios, configuración, tipos de
    //    servicio, términos y bitácora.
    for (const table of ['notification_reads', 'client_notices', 'tickets', 'payments', 'inventory_movements', 'order_parts', 'maintenance',
      'parts', 'order_status_history', 'order_labor', 'order_services', 'service_orders', 'appointments', 'vehicles', 'clients']) {
      await run(`DELETE FROM ${table}`);
    }

    // 2. Clientes y vehículos
    for (const [i, [name, phone, email, address]] of CLIENTS.entries()) {
      await run('INSERT INTO clients (id, name, phone, email, address, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)', [i + 1, name, phone, email, address, at('2026-09-20', '10:00', i * 40), at('2026-09-20', '10:00', i * 40)]);
    }
    for (const [i, [client, brand, model, year, plate, color]] of VEHICLES.entries()) {
      await run('INSERT INTO vehicles (id, client_id, brand, model, year, license_plate, color, current_mileage, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [i + 1, client + 1, brand, model, year, plate, color, data.mileage[i], at('2026-09-21', '09:00', i * 25), at('2026-09-21', '09:00', i * 25)]);
    }

    // 3. Refacciones (con su existencia final); sus movimientos se cargan después de las órdenes
    const partId = {};
    for (const [i, p] of data.parts.entries()) {
      partId[p.code] = i + 1;
      await run('INSERT INTO parts (id, code, name, category, brand, unit, stock, min_stock, purchase_price, sale_price, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [i + 1, p.code, p.name, p.category, p.brand, p.unit, p.stock, p.min, p.buy, p.sale, at('2026-09-25', '10:00'), at('2026-11-20', '18:00')]);
    }

    // 4. Citas: las que originan órdenes, las canceladas y las futuras
    let appointmentId = 0;
    const appointmentOf = {};
    for (const order of data.orders) {
      const hasAppointment = order.id % 3 === 1 || order.status === 'RECIBIDO' || order.status === 'DIAGNOSTICO';
      if (!hasAppointment) continue;
      appointmentId += 1;
      appointmentOf[order.id] = appointmentId;
      const status = order.status === 'ENTREGADO' || order.status === 'TERMINADO' ? 'COMPLETADA' : 'EN_PROCESO';
      await run('INSERT INTO appointments (id, client_id, vehicle_id, scheduled_at, reason, status, created_by, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [appointmentId, VEHICLES[order.spec.v][0] + 1, order.spec.v + 1, at(order.spec.d, '09:00'), order.spec.p, status, users.recepcion, at(addDays(order.spec.d, -3), '12:00'), order.openedAt]);
    }
    for (const [day, time, v, reason, why] of CANCELLED_APPOINTMENTS) {
      appointmentId += 1;
      await run('INSERT INTO appointments (id, client_id, vehicle_id, scheduled_at, reason, status, cancel_reason, cancelled_at, created_by, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [appointmentId, VEHICLES[v][0] + 1, v + 1, at(day, time), reason, 'CANCELADA', why, at(addDays(day, -1), '17:00'), users.recepcion, at(addDays(day, -5), '12:00'), at(addDays(day, -1), '17:00')]);
    }
    for (const [day, time, v, reason, status] of FUTURE_APPOINTMENTS) {
      appointmentId += 1;
      await run('INSERT INTO appointments (id, client_id, vehicle_id, scheduled_at, reason, status, created_by, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [appointmentId, VEHICLES[v][0] + 1, v + 1, at(day, time), reason, status, users.recepcion, at('2026-11-18', '11:00', appointmentId), at('2026-11-18', '11:00', appointmentId)]);
    }

    // 5. Órdenes con su historial, servicios, mano de obra y refacciones
    const typeId = Object.fromEntries((await query('SELECT id, name FROM service_types')).map((t) => [t.name, t.id]));
    for (const o of data.orders) {
      const v = VEHICLES[o.spec.v];
      await run(
        `INSERT INTO service_orders (id, client_id, vehicle_id, appointment_id, mechanic_id, status, reported_problem, entry_mileage, service_mileage, diagnosis, observations, recommendations, created_by, delivered_at, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [o.id, v[0] + 1, o.spec.v + 1, appointmentOf[o.id] ?? null, o.mechanicId, o.status, o.spec.p, o.entry, o.serviceMileage,
          o.status === 'RECIBIDO' ? null : `Revisión inicial: ${o.spec.p.toLowerCase()}.`, o.spec.note ?? null,
          o.status === 'ENTREGADO' ? 'Programar el siguiente servicio en la fecha indicada.' : null, users.recepcion, o.deliveredAt, o.openedAt, o.lastChange],
      );
      for (const [from, to, by, when] of o.history) {
        await run('INSERT INTO order_status_history (order_id, from_status, to_status, changed_by, changed_at) VALUES (?, ?, ?, ?, ?)', [o.id, from, to, by, when]);
      }
      for (const s of o.services) {
        await run('INSERT INTO order_services (order_id, service_type_id, description, amount, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)', [o.id, s.type ? typeId[s.type] ?? null : null, s.desc, s.amount, o.linesAt, o.linesAt]);
      }
      for (const l of o.labor) await run('INSERT INTO order_labor (order_id, description, amount, created_at, updated_at) VALUES (?, ?, ?, ?, ?)', [o.id, l.desc, l.amount, o.linesAt, o.linesAt]);
      for (const p of o.parts) {
        await run('INSERT INTO order_parts (order_id, part_id, quantity, unit_price, created_by, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)', [o.id, partId[p.code], p.qty, p.sale, o.mechanicId, o.partsAt, o.partsAt]);
      }
    }

    // Movimientos de inventario (después de las órdenes, a las que hacen referencia)
    for (const m of data.movements.sort((a, b) => a.at.localeCompare(b.at))) {
      await run('INSERT INTO inventory_movements (part_id, type, quantity, reason, order_id, created_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)', [partId[m.code], m.type, m.quantity, m.reason, m.orderId, m.user, m.at]);
    }

    // 6. Pagos y tickets (el ticket usa el mismo generador que la aplicación)
    const paymentIds = new Map();
    for (const p of data.payments) {
      const [result] = await run(
        `INSERT INTO payments (order_id, amount, method, status, reference, external_reference, external_payment_id, paid_at, created_by, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [p.order.id, money(p.amount), p.method, p.status, p.reference, p.mp ? `MOTORIX-OS-${p.order.id}` : null, p.mp && p.status === 'PAGADO' ? String(1320000000 + p.order.id * 91) : null,
          p.paidAt, users.recepcion, p.createdAt, p.paidAt ?? p.createdAt],
      );
      if (p.status === 'PAGADO') paymentIds.set(p.order.id, { id: result.insertId, payment: p });
    }
    const pendingByOrder = Object.fromEntries(data.maintenance.filter((m) => m.status === 'PENDIENTE').map((m) => [m.order.id, m]));
    for (const [orderId, { id: paymentId, payment }] of paymentIds) {
      const o = data.orders.find((x) => x.id === orderId);
      const v = VEHICLES[o.spec.v];
      const next = pendingByOrder[orderId];
      const generatedAt = at(payment.paidAt.slice(0, 10), payment.paidAt.slice(11, 16), 8);
      const content = buildTicketContent({
        shop,
        order: { id: o.id, entryMileage: o.entry, serviceMileage: o.serviceMileage },
        customer: { name: CLIENTS[v[0]][0], phone: CLIENTS[v[0]][1] },
        vehicle: { licensePlate: v[4], brand: v[1], model: v[2], year: v[3] },
        services: o.services.map((s) => ({ description: s.desc, amount: money(cents(s.amount)) })),
        parts: o.parts.map((p) => ({ code: p.code, name: p.name, unit: p.unit, quantity: p.qty, unitPrice: money(cents(p.sale)), amount: money(p.qty * cents(p.sale)) })),
        labor: o.labor.map((l) => ({ description: l.desc, amount: money(cents(l.amount)) })),
        payment: { amount: money(payment.amount), method: payment.method, status: 'PAGADO', paidAt: new Date(payment.paidAt.replace(' ', 'T')), reference: payment.reference },
        nextService: next ? { dueDate: next.dueDate, dueMileage: next.dueKm, description: next.description } : null,
        now: new Date(generatedAt.replace(' ', 'T')),
      });
      await run('INSERT INTO tickets (order_id, payment_id, content, generated_by, generated_at) VALUES (?, ?, ?, ?, ?)', [orderId, paymentId, JSON.stringify(content), users.recepcion, generatedAt]);
    }

    // 7. Mantenimientos y un aviso ya hecho
    for (const m of data.maintenance) {
      await run('INSERT INTO maintenance (vehicle_id, order_id, description, due_date, due_mileage, status, attended_at, created_by, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [m.vehicle + 1, m.order.id, m.description, m.dueDate, m.dueKm, m.status, m.attendedAt, m.order.mechanicId, m.order.deliveredAt ?? m.order.openedAt, m.attendedAt ?? m.order.deliveredAt ?? m.order.openedAt]);
    }
    const readyOrders = data.orders.filter((o) => o.status === 'TERMINADO');
    if (readyOrders.length > 0) {
      // Se avisó al cliente de la primera orden lista; la otra queda pendiente en «Clientes por avisar».
      await run('INSERT INTO client_notices (client_id, reason, fact_id, notified_by, notified_at) VALUES (?, ?, ?, ?, ?)', [VEHICLES[readyOrders[0].spec.v][0] + 1, 'ORDER_READY', readyOrders[0].id, users.recepcion, at('2026-11-20', '13:15')]);
    }
  });

  console.log('\nListo: los datos de ejemplo anteriores se reemplazaron por los nuevos.');
}

main()
  .catch((error) => {
    console.error('\nError:', error.message);
    process.exitCode = 1;
  })
  .finally(() => process.exit());
