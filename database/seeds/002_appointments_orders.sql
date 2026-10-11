-- Seed 002 (Sprint 2): segundo mecánico, citas y órdenes de servicio de ejemplo.
-- Es idempotente: se puede ejecutar varias veces sin duplicar ni sobrescribir registros.
-- Requiere el seed 001 (usuarios, clientes y vehículos). Las claves naturales NO dependen de la fecha:
--   citas  -> (placa del vehículo, motivo)      órdenes -> (placa del vehículo, problema reportado)
-- Las fechas se calculan relativas a NOW() solo al insertar, así que repetir el seed no mueve lo ya sembrado.
-- La contraseña de mecanico2 se guarda SOLO como hash bcrypt (costo 10); válida únicamente para
-- entornos locales (ver docs/project-context.md).

SET NAMES utf8mb4;

-- Segundo mecánico: la clave única es username/email, así que una contraseña cambiada no se restablece.
INSERT IGNORE INTO users (username, name, email, password_hash, role, active) VALUES
  ('mecanico2', 'Segundo mecánico del taller', 'mecanico2@motorix.local',
   '$2a$10$/0fRHcZ/j.K1KKaVKjt1VeyxEBFwMC7IoQcRQe2JPbF3OIG3R7wbO', 'MECHANIC', 1);

-- ---------------------------------------------------------------------------------------------
-- Citas: una por cada estado (dos futuras: Pendiente y Confirmada).
-- ---------------------------------------------------------------------------------------------
CREATE TEMPORARY TABLE seed_appointments (
  plate VARCHAR(15) NOT NULL,
  reason VARCHAR(255) NOT NULL,
  notes VARCHAR(1000) NULL,
  status VARCHAR(12) NOT NULL,
  day_offset INT NOT NULL,
  time_of_day TIME NOT NULL,
  cancel_reason VARCHAR(255) NULL
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO seed_appointments (plate, reason, notes, status, day_offset, time_of_day, cancel_reason) VALUES
  ('HIJ-456-M', 'Revisión general antes de viaje', 'Saldrá a carretera el fin de semana.', 'PENDIENTE', 2, '10:00:00', NULL),
  ('PQR-678-F', 'Cambio de aceite y filtros', 'Trae su propio aceite sintético.', 'CONFIRMADA', 1, '09:30:00', NULL),
  ('ABC-123-A', 'Ruido al frenar', 'El cliente reporta vibración al frenar en bajada.', 'EN_PROCESO', 0, '08:30:00', NULL),
  ('STU-901-G', 'Servicio de 40,000 km', 'Unidad de reparto de la empresa.', 'COMPLETADA', -3, '09:00:00', NULL),
  ('VWX-234-H', 'Revisión de frenos', NULL, 'CANCELADA', 3, '11:00:00', 'El cliente reprogramó la visita.');

INSERT INTO appointments (client_id, vehicle_id, scheduled_at, reason, notes, status, cancel_reason, cancelled_at, created_by)
SELECT v.client_id, v.id, TIMESTAMP(DATE_ADD(CURDATE(), INTERVAL s.day_offset DAY), s.time_of_day), s.reason, s.notes, s.status, s.cancel_reason,
       IF(s.status = 'CANCELADA', DATE_SUB(NOW(), INTERVAL 1 DAY), NULL), r.id
FROM seed_appointments s
JOIN vehicles v ON v.license_plate = s.plate
JOIN users r ON r.username = 'recepcion'
WHERE NOT EXISTS (
  SELECT 1 FROM appointments a WHERE a.vehicle_id = v.id AND a.reason = s.reason
);

-- ---------------------------------------------------------------------------------------------
-- Órdenes: una por cada estado del flujo (cada una en un vehículo distinto, por la regla de una sola
-- orden abierta) y dos entregadas. Repartidas entre mecanico y mecanico2; una sin asignar.
-- ---------------------------------------------------------------------------------------------
CREATE TEMPORARY TABLE seed_orders (
  plate VARCHAR(15) NOT NULL,
  problem VARCHAR(1000) NOT NULL,
  status VARCHAR(20) NOT NULL,
  mechanic VARCHAR(50) NULL,
  entry_mileage INT NOT NULL,
  diagnosis TEXT NULL,
  observations TEXT NULL,
  recommendations TEXT NULL,
  appointment_reason VARCHAR(255) NULL,
  created_hours_ago INT NOT NULL,
  delivered_hours_ago INT NULL
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO seed_orders
  (plate, problem, status, mechanic, entry_mileage, diagnosis, observations, recommendations, appointment_reason, created_hours_ago, delivered_hours_ago)
VALUES
  ('BCD-890-K', 'Se enciende el testigo de aceite', 'RECIBIDO', NULL, 29800, NULL, NULL, NULL, NULL, 1, NULL),
  ('ABC-123-A', 'Ruido al frenar y vibración en el volante', 'DIAGNOSTICO', 'mecanico', 84500,
   'Balatas delanteras al límite y disco derecho alabeado.', 'El cliente comenta que el ruido empezó hace dos semanas.', NULL, 'Ruido al frenar', 2, NULL),
  ('DEF-456-B', 'Fuga de aceite en el motor', 'EN_REPARACION', 'mecanico2', 42300,
   'Empaque de cárter dañado; la fuga mancha el protector inferior.', NULL, 'Revisar nivel de aceite cada 1,000 km durante el primer mes.', NULL, 26, NULL),
  ('GHI-789-C', 'Sobrecalentamiento en tráfico lento', 'ESPERANDO_REFACCION', 'mecanico', 96100,
   'Bomba de agua con fuga y termostato lento.', 'Se pidió la bomba de agua al proveedor; llega mañana.', NULL, NULL, 50, NULL),
  ('STU-901-G', 'Servicio de 40,000 km', 'TERMINADO', 'mecanico2', 38900,
   'Servicio mayor sin hallazgos críticos.', 'Llantas traseras con desgaste irregular.', 'Programar alineación en el próximo servicio.', 'Servicio de 40,000 km', 72, NULL),
  ('MNO-345-E', 'Cambio de aceite y filtros', 'ENTREGADO', 'mecanico', 49800,
   'Servicio preventivo.', NULL, 'Próximo cambio de aceite a los 55,000 km.', NULL, 240, 232),
  ('EFG-123-L', 'Cambio de llantas y alineación', 'ENTREGADO', 'mecanico2', 105000,
   'Llantas con desgaste por debajo del límite legal.', 'Se conservó una llanta de refacción en buen estado.', 'Rotar llantas cada 10,000 km.', NULL, 480, 470);

-- INSERT IGNORE: si un vehículo ya tiene otra orden abierta creada a mano, esa orden de ejemplo se omite.
INSERT IGNORE INTO service_orders
  (client_id, vehicle_id, appointment_id, mechanic_id, status, reported_problem, entry_mileage,
   diagnosis, observations, recommendations, created_by, delivered_at, created_at)
SELECT v.client_id, v.id, a.id, m.id, s.status, s.problem, s.entry_mileage,
       s.diagnosis, s.observations, s.recommendations, r.id,
       IF(s.delivered_hours_ago IS NULL, NULL, DATE_SUB(NOW(), INTERVAL s.delivered_hours_ago HOUR)),
       DATE_SUB(NOW(), INTERVAL s.created_hours_ago HOUR)
FROM seed_orders s
JOIN vehicles v ON v.license_plate = s.plate
JOIN users r ON r.username = 'recepcion'
LEFT JOIN users m ON m.username = s.mechanic
LEFT JOIN appointments a ON a.vehicle_id = v.id AND a.reason = s.appointment_reason
WHERE NOT EXISTS (
  SELECT 1 FROM service_orders o WHERE o.vehicle_id = v.id AND o.reported_problem = s.problem
);

-- ---------------------------------------------------------------------------------------------
-- Servicios realizados y mano de obra (por orden y descripción).
-- ---------------------------------------------------------------------------------------------
CREATE TEMPORARY TABLE seed_lines (
  kind VARCHAR(10) NOT NULL,
  plate VARCHAR(15) NOT NULL,
  problem VARCHAR(1000) NOT NULL,
  description VARCHAR(255) NOT NULL,
  amount DECIMAL(10,2) NOT NULL
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO seed_lines (kind, plate, problem, description, amount) VALUES
  ('services', 'DEF-456-B', 'Fuga de aceite en el motor', 'Sustitución de empaque de cárter', 650.00),
  ('services', 'DEF-456-B', 'Fuga de aceite en el motor', 'Aceite sintético 5W-30 (4 L)', 780.00),
  ('labor',    'DEF-456-B', 'Fuga de aceite en el motor', 'Mano de obra por reparación de fuga', 900.00),
  ('services', 'GHI-789-C', 'Sobrecalentamiento en tráfico lento', 'Diagnóstico del sistema de enfriamiento', 350.00),
  ('labor',    'GHI-789-C', 'Sobrecalentamiento en tráfico lento', 'Revisión del sistema de enfriamiento', 300.00),
  ('services', 'STU-901-G', 'Servicio de 40,000 km', 'Cambio de aceite y filtro', 850.00),
  ('services', 'STU-901-G', 'Servicio de 40,000 km', 'Rotación y balanceo de llantas', 420.00),
  ('services', 'STU-901-G', 'Servicio de 40,000 km', 'Revisión de 40,000 km', 600.00),
  ('labor',    'STU-901-G', 'Servicio de 40,000 km', 'Mano de obra servicio de 40,000 km', 700.00),
  ('services', 'MNO-345-E', 'Cambio de aceite y filtros', 'Cambio de aceite sintético y filtro', 950.00),
  ('labor',    'MNO-345-E', 'Cambio de aceite y filtros', 'Mano de obra cambio de aceite', 250.00),
  ('services', 'EFG-123-L', 'Cambio de llantas y alineación', 'Juego de 4 llantas 265/65 R17', 8400.00),
  ('services', 'EFG-123-L', 'Cambio de llantas y alineación', 'Alineación y balanceo', 650.00),
  ('labor',    'EFG-123-L', 'Cambio de llantas y alineación', 'Mano de obra instalación de llantas', 500.00);

INSERT INTO order_services (order_id, description, amount)
SELECT o.id, l.description, l.amount
FROM seed_lines l
JOIN vehicles v ON v.license_plate = l.plate
JOIN service_orders o ON o.vehicle_id = v.id AND o.reported_problem = l.problem
WHERE l.kind = 'services'
  AND NOT EXISTS (SELECT 1 FROM order_services x WHERE x.order_id = o.id AND x.description = l.description);

INSERT INTO order_labor (order_id, description, amount)
SELECT o.id, l.description, l.amount
FROM seed_lines l
JOIN vehicles v ON v.license_plate = l.plate
JOIN service_orders o ON o.vehicle_id = v.id AND o.reported_problem = l.problem
WHERE l.kind = 'labor'
  AND NOT EXISTS (SELECT 1 FROM order_labor x WHERE x.order_id = o.id AND x.description = l.description);

-- ---------------------------------------------------------------------------------------------
-- Historial de estados coherente con el estado actual de cada orden.
-- ---------------------------------------------------------------------------------------------
CREATE TEMPORARY TABLE seed_history (
  plate VARCHAR(15) NOT NULL,
  problem VARCHAR(1000) NOT NULL,
  from_status VARCHAR(20) NULL,
  to_status VARCHAR(20) NOT NULL,
  who VARCHAR(50) NOT NULL,
  hours_ago INT NOT NULL
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO seed_history (plate, problem, from_status, to_status, who, hours_ago) VALUES
  ('BCD-890-K', 'Se enciende el testigo de aceite', NULL, 'RECIBIDO', 'recepcion', 1),

  ('ABC-123-A', 'Ruido al frenar y vibración en el volante', NULL, 'RECIBIDO', 'recepcion', 2),
  ('ABC-123-A', 'Ruido al frenar y vibración en el volante', 'RECIBIDO', 'DIAGNOSTICO', 'mecanico', 1),

  ('DEF-456-B', 'Fuga de aceite en el motor', NULL, 'RECIBIDO', 'recepcion', 26),
  ('DEF-456-B', 'Fuga de aceite en el motor', 'RECIBIDO', 'DIAGNOSTICO', 'mecanico2', 25),
  ('DEF-456-B', 'Fuga de aceite en el motor', 'DIAGNOSTICO', 'EN_REPARACION', 'mecanico2', 22),

  ('GHI-789-C', 'Sobrecalentamiento en tráfico lento', NULL, 'RECIBIDO', 'recepcion', 50),
  ('GHI-789-C', 'Sobrecalentamiento en tráfico lento', 'RECIBIDO', 'DIAGNOSTICO', 'mecanico', 49),
  ('GHI-789-C', 'Sobrecalentamiento en tráfico lento', 'DIAGNOSTICO', 'EN_REPARACION', 'mecanico', 46),
  ('GHI-789-C', 'Sobrecalentamiento en tráfico lento', 'EN_REPARACION', 'ESPERANDO_REFACCION', 'mecanico', 30),

  ('STU-901-G', 'Servicio de 40,000 km', NULL, 'RECIBIDO', 'recepcion', 72),
  ('STU-901-G', 'Servicio de 40,000 km', 'RECIBIDO', 'DIAGNOSTICO', 'mecanico2', 71),
  ('STU-901-G', 'Servicio de 40,000 km', 'DIAGNOSTICO', 'EN_REPARACION', 'mecanico2', 70),
  ('STU-901-G', 'Servicio de 40,000 km', 'EN_REPARACION', 'TERMINADO', 'mecanico2', 66),

  ('MNO-345-E', 'Cambio de aceite y filtros', NULL, 'RECIBIDO', 'recepcion', 240),
  ('MNO-345-E', 'Cambio de aceite y filtros', 'RECIBIDO', 'DIAGNOSTICO', 'mecanico', 239),
  ('MNO-345-E', 'Cambio de aceite y filtros', 'DIAGNOSTICO', 'EN_REPARACION', 'mecanico', 238),
  ('MNO-345-E', 'Cambio de aceite y filtros', 'EN_REPARACION', 'TERMINADO', 'mecanico', 234),
  ('MNO-345-E', 'Cambio de aceite y filtros', 'TERMINADO', 'ENTREGADO', 'recepcion', 232),

  ('EFG-123-L', 'Cambio de llantas y alineación', NULL, 'RECIBIDO', 'recepcion', 480),
  ('EFG-123-L', 'Cambio de llantas y alineación', 'RECIBIDO', 'DIAGNOSTICO', 'mecanico2', 479),
  ('EFG-123-L', 'Cambio de llantas y alineación', 'DIAGNOSTICO', 'EN_REPARACION', 'mecanico2', 478),
  ('EFG-123-L', 'Cambio de llantas y alineación', 'EN_REPARACION', 'TERMINADO', 'mecanico2', 472),
  ('EFG-123-L', 'Cambio de llantas y alineación', 'TERMINADO', 'ENTREGADO', 'recepcion', 470);

INSERT INTO order_status_history (order_id, from_status, to_status, changed_by, changed_at)
SELECT o.id, h.from_status, h.to_status, u.id, DATE_SUB(NOW(), INTERVAL h.hours_ago HOUR)
FROM seed_history h
JOIN vehicles v ON v.license_plate = h.plate
JOIN service_orders o ON o.vehicle_id = v.id AND o.reported_problem = h.problem
JOIN users u ON u.username = h.who
WHERE NOT EXISTS (
  SELECT 1 FROM order_status_history x
   WHERE x.order_id = o.id AND x.to_status = h.to_status AND x.from_status <=> h.from_status
);

DROP TEMPORARY TABLE seed_history;
DROP TEMPORARY TABLE seed_lines;
DROP TEMPORARY TABLE seed_orders;
DROP TEMPORARY TABLE seed_appointments;
