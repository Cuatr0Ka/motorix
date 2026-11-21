import { query } from '../../config/db.js';
import { createClientWithVehicle } from './factories.js';

let placa = 0;
/** Una orden abierta por vehículo: cada orden de estas pruebas usa un vehículo nuevo. */
export async function nuevoVehiculo() {
  placa += 1;
  return (await createClientWithVehicle({ licensePlate: `RPT-${String(placa).padStart(3, '0')}-Z` })).vehicle;
}

export const PERIODO = { from: '2026-10-01', to: '2026-10-31' };
export const DENTRO = '2026-10-15 10:00:00';

/** Fija la fecha de un pago ya creado. */
export const fecharPago = (id, fecha) => query('UPDATE payments SET paid_at = ? WHERE id = ?', [fecha, id]);

/** Marca la orden como terminada en la fecha indicada (último cambio a TERMINADO del historial). */
export const fecharTerminada = (orderId, userId, fecha) =>
  query("INSERT INTO order_status_history (order_id, from_status, to_status, changed_by, changed_at) VALUES (?, 'EN_REPARACION', 'TERMINADO', ?, ?)", [orderId, userId, fecha]);

export const consulta = (ruta, extra = {}) => ({ ...PERIODO, ...extra, ruta });
