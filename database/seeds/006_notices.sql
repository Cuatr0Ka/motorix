-- Seed 006 (Sprint 6): casos de ejemplo de las notificaciones internas y de los clientes por avisar.
-- Es idempotente: se puede ejecutar varias veces sin duplicar ni sobrescribir registros. Requiere los seeds 001 a 005.
-- NO envía ningún mensaje ni llama a ningún servicio externo: solo deja datos para que el centro de notificaciones y la
-- lista de clientes por avisar muestren información al arrancar. No modifica pagos, tickets ni órdenes entregadas.
--
-- Los avisos NO se guardan: se calculan al consultar. Con los seeds 001 a 005 ya existen, al momento de sembrar:
--   * mantenimientos Próximo y Vencido (seed 003) y refacciones con stock bajo (BUJ-NGK) y agotado (COR-DIS y BOM-AGU);
--   * una cita de mañana (PQR-678-F, seed 002) y órdenes Terminadas sin entregar (STU-901-G y VWX-234-H).
-- Este seed agrega lo que depende del paso del tiempo y por eso no puede venir de los seeds anteriores:
--   * una cita para HOY (Confirmada) y otra para mañana (Pendiente), con fechas relativas a CURDATE();
--   * una orden abierta DETENIDA: su último cambio de estado fue hace 5 días (más de los 3 que marcan una orden detenida);
--   * un aviso a cliente ya registrado (la orden Terminada de VWX-234-H), para mostrar quién avisó y cuándo.

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------------------------
-- 1. Citas de hoy y de mañana (aviso «cita del día» y motivo «cita de mañana»).
--    La clave natural es (vehículo, motivo), así que repetir el seed no mueve lo ya sembrado.
-- ---------------------------------------------------------------------------------------------
CREATE TEMPORARY TABLE seed_s6_appointments (
  plate VARCHAR(15) NOT NULL,
  reason VARCHAR(255) NOT NULL,
  notes VARCHAR(1000) NULL,
  status VARCHAR(12) NOT NULL,
  day_offset INT NOT NULL,
  time_of_day TIME NOT NULL
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO seed_s6_appointments (plate, reason, notes, status, day_offset, time_of_day) VALUES
  ('YZA-567-J', 'Revisión de rutina del día (ejemplo Sprint 6)', 'Unidad de reparto: revisión de niveles y llantas.', 'CONFIRMADA', 0, '16:00:00'),
  ('MNO-345-E', 'Revisión previa al viaje (ejemplo Sprint 6)', 'Saldrá a carretera pasado mañana.', 'PENDIENTE', 1, '10:30:00');

INSERT INTO appointments (client_id, vehicle_id, scheduled_at, reason, notes, status, created_by)
SELECT v.client_id, v.id, TIMESTAMP(DATE_ADD(CURDATE(), INTERVAL s.day_offset DAY), s.time_of_day), s.reason, s.notes, s.status, r.id
FROM seed_s6_appointments s
JOIN vehicles v ON v.license_plate = s.plate
JOIN users r ON r.username = 'recepcion'
WHERE NOT EXISTS (
  SELECT 1 FROM appointments a WHERE a.vehicle_id = v.id AND a.reason = s.reason
);

DROP TEMPORARY TABLE seed_s6_appointments;

-- ---------------------------------------------------------------------------------------------
-- 2. Orden abierta detenida (aviso «orden detenida»): En reparación desde hace 5 días, asignada a mecanico.
--    Va en un vehículo sin ninguna orden (JKL-012-D), por la regla de una sola orden abierta por vehículo.
-- ---------------------------------------------------------------------------------------------
INSERT INTO service_orders (client_id, vehicle_id, mechanic_id, status, reported_problem, entry_mileage, diagnosis, created_by, created_at)
SELECT v.client_id, v.id, m.id, 'EN_REPARACION', 'Falla de arranque en frío (ejemplo Sprint 6)',
       COALESCE(v.current_mileage, 0),
       'Se sospecha del motor de arranque; se espera el diagnóstico completo.',
       r.id, DATE_SUB(NOW(), INTERVAL 7 DAY)
FROM vehicles v
JOIN users m ON m.username = 'mecanico'
JOIN users r ON r.username = 'recepcion'
WHERE v.license_plate = 'JKL-012-D'
  AND NOT EXISTS (
    SELECT 1 FROM service_orders o WHERE o.vehicle_id = v.id AND o.reported_problem = 'Falla de arranque en frío (ejemplo Sprint 6)'
  )
  AND NOT EXISTS (
    SELECT 1 FROM service_orders o WHERE o.vehicle_id = v.id AND o.status <> 'ENTREGADO'
  );

-- Historial de la orden detenida: su último cambio de estado fue hace 5 días. Solo se inserta si la orden aún no
-- tiene historial, para no duplicar filas al repetir el seed.
INSERT INTO order_status_history (order_id, from_status, to_status, changed_by, changed_at)
SELECT h.order_id, h.from_status, h.to_status, h.changed_by, h.changed_at
FROM (
  SELECT o.id AS order_id, CAST(NULL AS CHAR(20)) AS from_status, 'RECIBIDO' AS to_status, o.created_by AS changed_by, DATE_SUB(NOW(), INTERVAL 7 DAY) AS changed_at
    FROM service_orders o JOIN vehicles v ON v.id = o.vehicle_id
   WHERE v.license_plate = 'JKL-012-D' AND o.reported_problem = 'Falla de arranque en frío (ejemplo Sprint 6)'
  UNION ALL
  SELECT o.id, 'RECIBIDO', 'DIAGNOSTICO', o.mechanic_id, DATE_SUB(NOW(), INTERVAL 6 DAY)
    FROM service_orders o JOIN vehicles v ON v.id = o.vehicle_id
   WHERE v.license_plate = 'JKL-012-D' AND o.reported_problem = 'Falla de arranque en frío (ejemplo Sprint 6)'
  UNION ALL
  SELECT o.id, 'DIAGNOSTICO', 'EN_REPARACION', o.mechanic_id, DATE_SUB(NOW(), INTERVAL 5 DAY)
    FROM service_orders o JOIN vehicles v ON v.id = o.vehicle_id
   WHERE v.license_plate = 'JKL-012-D' AND o.reported_problem = 'Falla de arranque en frío (ejemplo Sprint 6)'
) h
WHERE NOT EXISTS (SELECT 1 FROM order_status_history x WHERE x.order_id = h.order_id);

-- ---------------------------------------------------------------------------------------------
-- 3. Aviso a cliente ya registrado: la recepción ya avisó que la orden Terminada de VWX-234-H está lista.
--    La clave única (motivo, hecho) hace idempotente el INSERT IGNORE. La orden Terminada de STU-901-G queda por avisar.
-- ---------------------------------------------------------------------------------------------
INSERT IGNORE INTO client_notices (client_id, reason, fact_id, notified_by, notified_at)
SELECT o.client_id, 'ORDER_READY', o.id, r.id, DATE_SUB(NOW(), INTERVAL 2 HOUR)
FROM service_orders o
JOIN vehicles v ON v.id = o.vehicle_id
JOIN users r ON r.username = 'recepcion'
WHERE v.license_plate = 'VWX-234-H' AND o.status = 'TERMINADO';
