-- Seed 003 (Sprint 3): historial de servicios, refacciones con movimientos, refacciones usadas en órdenes
-- y mantenimientos de ejemplo.
-- Es idempotente: se puede ejecutar varias veces sin duplicar ni sobrescribir registros.
-- Requiere los seeds 001 (usuarios, clientes y vehículos) y 002 (citas y órdenes). Claves naturales:
--   refacciones -> código             órdenes históricas -> (placa, problema reportado)
--   movimientos -> (código, tipo, motivo, orden)           líneas de orden -> (orden, refacción)
--   mantenimientos -> (placa, descripción)
-- Las fechas se calculan relativas a NOW() solo al insertar. Al final, el stock de las refacciones se
-- recalcula como la suma de sus movimientos, así que el stock sembrado siempre es coherente.

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------------------------
-- Refacciones: suficientes, con stock bajo (en o bajo el mínimo), agotadas y una inactiva.
-- ---------------------------------------------------------------------------------------------
INSERT INTO parts (code, name, description, unit, stock, min_stock, active)
SELECT s.code, s.name, s.description, s.unit, 0, s.min_stock, s.active
FROM (
  SELECT 'ACE-5W30' AS code, 'Aceite sintético 5W-30' AS name, 'Aceite sintético para motores a gasolina' AS description, 'litro' AS unit, 8 AS min_stock, 1 AS active
  UNION ALL SELECT 'FIL-ACE', 'Filtro de aceite', NULL, 'pieza', 5, 1
  UNION ALL SELECT 'FIL-AIR', 'Filtro de aire', NULL, 'pieza', 3, 1
  UNION ALL SELECT 'BAL-DEL', 'Balatas delanteras', 'Juego de balatas cerámicas', 'juego', 3, 1
  UNION ALL SELECT 'BAL-TRA', 'Balatas traseras', 'Juego de balatas cerámicas', 'juego', 2, 1
  UNION ALL SELECT 'DIS-DEL', 'Disco de freno delantero', NULL, 'pieza', 2, 1
  UNION ALL SELECT 'BUJ-NGK', 'Bujía NGK', 'Bujía de iridio', 'pieza', 8, 1
  UNION ALL SELECT 'BAT-12V', 'Batería 12 V', NULL, 'pieza', 2, 1
  UNION ALL SELECT 'COR-DIS', 'Correa de distribución', NULL, 'pieza', 2, 1
  UNION ALL SELECT 'BOM-AGU', 'Bomba de agua', NULL, 'pieza', 2, 1
  UNION ALL SELECT 'EMP-CAR', 'Empaque de cárter', NULL, 'pieza', 2, 1
  UNION ALL SELECT 'LIQ-FRE', 'Líquido de frenos DOT 4', NULL, 'litro', 5, 1
  UNION ALL SELECT 'DIS-OLD', 'Disco de freno (modelo descontinuado)', 'Ya no se ofrece en nuevas órdenes', 'pieza', 1, 0
) AS s
WHERE NOT EXISTS (SELECT 1 FROM parts p WHERE p.code = s.code);

-- ---------------------------------------------------------------------------------------------
-- Órdenes históricas ya entregadas (varios vehículos) con kilometraje del servicio.
-- ---------------------------------------------------------------------------------------------
CREATE TEMPORARY TABLE seed_hist_orders (
  plate VARCHAR(15) NOT NULL,
  problem VARCHAR(1000) NOT NULL,
  mechanic VARCHAR(50) NOT NULL,
  entry_mileage INT NOT NULL,
  service_mileage INT NOT NULL,
  diagnosis TEXT NULL,
  recommendations TEXT NULL,
  days_ago INT NOT NULL
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO seed_hist_orders (plate, problem, mechanic, entry_mileage, service_mileage, diagnosis, recommendations, days_ago) VALUES
  ('ABC-123-A', 'Cambio de aceite y filtro de aceite', 'mecanico', 78200, 78260, 'Servicio preventivo sin hallazgos.', 'Próximo cambio de aceite en 5,000 km.', 120),
  ('MNO-345-E', 'Servicio de 30,000 km', 'mecanico', 46500, 46540, 'Servicio mayor sin hallazgos críticos.', NULL, 75),
  ('EFG-123-L', 'Cambio de batería', 'mecanico2', 98000, 98030, 'La batería no retenía carga.', 'Revisar el alternador en el siguiente servicio.', 150),
  ('YZA-567-J', 'Servicio de frenos', 'mecanico2', 96000, 96090, 'Balatas delanteras gastadas y discos al límite.', 'Revisar los frenos en 3,500 km.', 30),
  ('VWX-234-H', 'Cambio de aceite', 'mecanico', 118000, 118070, 'Servicio preventivo.', NULL, 50),
  ('PQR-678-F', 'Cambio de bujías', 'mecanico2', 71000, 71045, 'Bujías desgastadas; el motor fallaba en frío.', NULL, 90),
  ('HIJ-456-M', 'Cambio de correa de distribución', 'mecanico', 135000, 135060, 'Correa agrietada y bomba de agua con fuga.', 'Revisar la correa de accesorios.', 200);

INSERT IGNORE INTO service_orders
  (client_id, vehicle_id, mechanic_id, status, reported_problem, entry_mileage, service_mileage,
   diagnosis, recommendations, created_by, delivered_at, created_at)
SELECT v.client_id, v.id, m.id, 'ENTREGADO', s.problem, s.entry_mileage, s.service_mileage,
       s.diagnosis, s.recommendations, r.id,
       DATE_SUB(NOW(), INTERVAL (s.days_ago * 24 - 8) HOUR),
       DATE_SUB(NOW(), INTERVAL (s.days_ago * 24 + 3) HOUR)
FROM seed_hist_orders s
JOIN vehicles v ON v.license_plate = s.plate
JOIN users r ON r.username = 'recepcion'
JOIN users m ON m.username = s.mechanic
WHERE NOT EXISTS (
  SELECT 1 FROM service_orders o WHERE o.vehicle_id = v.id AND o.reported_problem = s.problem
);

-- Kilometraje del servicio de las órdenes terminadas o entregadas del Sprint 2 (solo si aún no lo tienen).
UPDATE service_orders o
JOIN vehicles v ON v.id = o.vehicle_id
SET o.service_mileage = CASE
  WHEN v.license_plate = 'MNO-345-E' AND o.reported_problem = 'Cambio de aceite y filtros' THEN 49860
  WHEN v.license_plate = 'EFG-123-L' AND o.reported_problem = 'Cambio de llantas y alineación' THEN 105040
  WHEN v.license_plate = 'STU-901-G' AND o.reported_problem = 'Servicio de 40,000 km' THEN 38940
  ELSE o.service_mileage
END
WHERE o.service_mileage IS NULL AND o.status IN ('TERMINADO', 'ENTREGADO');

-- Servicios y mano de obra de las órdenes históricas.
CREATE TEMPORARY TABLE seed_hist_lines (
  kind VARCHAR(10) NOT NULL,
  plate VARCHAR(15) NOT NULL,
  problem VARCHAR(1000) NOT NULL,
  description VARCHAR(255) NOT NULL,
  amount DECIMAL(10,2) NOT NULL
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO seed_hist_lines (kind, plate, problem, description, amount) VALUES
  ('services', 'ABC-123-A', 'Cambio de aceite y filtro de aceite', 'Cambio de aceite sintético y filtro', 950.00),
  ('labor',    'ABC-123-A', 'Cambio de aceite y filtro de aceite', 'Mano de obra cambio de aceite', 250.00),
  ('services', 'MNO-345-E', 'Servicio de 30,000 km', 'Servicio de 30,000 km (aceite, filtros y revisión)', 1450.00),
  ('labor',    'MNO-345-E', 'Servicio de 30,000 km', 'Mano de obra servicio mayor', 600.00),
  ('services', 'EFG-123-L', 'Cambio de batería', 'Suministro e instalación de batería 12 V', 2300.00),
  ('labor',    'EFG-123-L', 'Cambio de batería', 'Mano de obra instalación de batería', 200.00),
  ('services', 'YZA-567-J', 'Servicio de frenos', 'Cambio de balatas y discos delanteros', 3200.00),
  ('labor',    'YZA-567-J', 'Servicio de frenos', 'Mano de obra de frenos', 700.00),
  ('services', 'VWX-234-H', 'Cambio de aceite', 'Cambio de aceite y filtro', 1250.00),
  ('labor',    'VWX-234-H', 'Cambio de aceite', 'Mano de obra cambio de aceite', 250.00),
  ('services', 'PQR-678-F', 'Cambio de bujías', 'Cambio de juego de bujías y filtro de aire', 1100.00),
  ('labor',    'PQR-678-F', 'Cambio de bujías', 'Mano de obra afinación', 450.00),
  ('services', 'HIJ-456-M', 'Cambio de correa de distribución', 'Cambio de correa de distribución y bomba de agua', 3900.00),
  ('labor',    'HIJ-456-M', 'Cambio de correa de distribución', 'Mano de obra distribución', 1800.00);

INSERT INTO order_services (order_id, description, amount)
SELECT o.id, l.description, l.amount
FROM seed_hist_lines l
JOIN vehicles v ON v.license_plate = l.plate
JOIN service_orders o ON o.vehicle_id = v.id AND o.reported_problem = l.problem
WHERE l.kind = 'services'
  AND NOT EXISTS (SELECT 1 FROM order_services x WHERE x.order_id = o.id AND x.description = l.description);

INSERT INTO order_labor (order_id, description, amount)
SELECT o.id, l.description, l.amount
FROM seed_hist_lines l
JOIN vehicles v ON v.license_plate = l.plate
JOIN service_orders o ON o.vehicle_id = v.id AND o.reported_problem = l.problem
WHERE l.kind = 'labor'
  AND NOT EXISTS (SELECT 1 FROM order_labor x WHERE x.order_id = o.id AND x.description = l.description);

-- Historial de estados de las órdenes históricas (recibida → ... → entregada).
CREATE TEMPORARY TABLE seed_hist_steps (
  from_status VARCHAR(20) NULL,
  to_status VARCHAR(20) NOT NULL,
  who VARCHAR(10) NOT NULL,
  hours_after_created INT NOT NULL
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO seed_hist_steps (from_status, to_status, who, hours_after_created) VALUES
  (NULL, 'RECIBIDO', 'recepcion', 0),
  ('RECIBIDO', 'DIAGNOSTICO', 'mecanico', 1),
  ('DIAGNOSTICO', 'EN_REPARACION', 'mecanico', 2),
  ('EN_REPARACION', 'TERMINADO', 'mecanico', 6),
  ('TERMINADO', 'ENTREGADO', 'recepcion', 11);

-- 'mecanico' en la columna `who` significa «el mecánico de la orden».
INSERT INTO order_status_history (order_id, from_status, to_status, changed_by, changed_at)
SELECT o.id, st.from_status, st.to_status,
       IF(st.who = 'mecanico', o.mechanic_id, r.id),
       DATE_ADD(o.created_at, INTERVAL st.hours_after_created HOUR)
FROM service_orders o
JOIN vehicles v ON v.id = o.vehicle_id
JOIN seed_hist_orders s ON s.plate = v.license_plate AND s.problem = o.reported_problem
JOIN users r ON r.username = 'recepcion'
JOIN seed_hist_steps st
WHERE NOT EXISTS (
  SELECT 1 FROM order_status_history x
   WHERE x.order_id = o.id AND x.to_status = st.to_status AND x.from_status <=> st.from_status
);

-- ---------------------------------------------------------------------------------------------
-- Refacciones usadas por orden (históricas y del Sprint 2).
-- ---------------------------------------------------------------------------------------------
CREATE TEMPORARY TABLE seed_order_parts (
  plate VARCHAR(15) NOT NULL,
  problem VARCHAR(1000) NOT NULL,
  code VARCHAR(40) NOT NULL,
  quantity INT NOT NULL
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO seed_order_parts (plate, problem, code, quantity) VALUES
  ('ABC-123-A', 'Cambio de aceite y filtro de aceite', 'ACE-5W30', 4),
  ('ABC-123-A', 'Cambio de aceite y filtro de aceite', 'FIL-ACE', 1),
  ('MNO-345-E', 'Servicio de 30,000 km', 'ACE-5W30', 4),
  ('MNO-345-E', 'Servicio de 30,000 km', 'FIL-ACE', 1),
  ('MNO-345-E', 'Servicio de 30,000 km', 'FIL-AIR', 1),
  ('EFG-123-L', 'Cambio de batería', 'BAT-12V', 1),
  ('YZA-567-J', 'Servicio de frenos', 'BAL-DEL', 1),
  ('YZA-567-J', 'Servicio de frenos', 'DIS-DEL', 2),
  ('YZA-567-J', 'Servicio de frenos', 'LIQ-FRE', 1),
  ('VWX-234-H', 'Cambio de aceite', 'ACE-5W30', 6),
  ('VWX-234-H', 'Cambio de aceite', 'FIL-ACE', 1),
  ('PQR-678-F', 'Cambio de bujías', 'BUJ-NGK', 4),
  ('PQR-678-F', 'Cambio de bujías', 'FIL-AIR', 1),
  ('HIJ-456-M', 'Cambio de correa de distribución', 'COR-DIS', 1),
  ('HIJ-456-M', 'Cambio de correa de distribución', 'BOM-AGU', 1),
  ('DEF-456-B', 'Fuga de aceite en el motor', 'EMP-CAR', 1),
  ('DEF-456-B', 'Fuga de aceite en el motor', 'ACE-5W30', 4),
  ('STU-901-G', 'Servicio de 40,000 km', 'ACE-5W30', 4),
  ('STU-901-G', 'Servicio de 40,000 km', 'FIL-ACE', 1),
  ('MNO-345-E', 'Cambio de aceite y filtros', 'ACE-5W30', 4),
  ('MNO-345-E', 'Cambio de aceite y filtros', 'FIL-ACE', 1);

INSERT INTO order_parts (order_id, part_id, quantity, created_by)
SELECT o.id, p.id, s.quantity, COALESCE(o.mechanic_id, a.id)
FROM seed_order_parts s
JOIN vehicles v ON v.license_plate = s.plate
JOIN service_orders o ON o.vehicle_id = v.id AND o.reported_problem = s.problem
JOIN parts p ON p.code = s.code
JOIN users a ON a.username = 'admin'
WHERE NOT EXISTS (SELECT 1 FROM order_parts x WHERE x.order_id = o.id AND x.part_id = p.id);

-- ---------------------------------------------------------------------------------------------
-- Movimientos de inventario: stock inicial, compras, ajustes y una salida por cada refacción usada.
-- ---------------------------------------------------------------------------------------------
CREATE TEMPORARY TABLE seed_movements (
  code VARCHAR(40) NOT NULL,
  type VARCHAR(12) NOT NULL,
  quantity INT NOT NULL,
  reason VARCHAR(255) NOT NULL,
  days_ago INT NOT NULL
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO seed_movements (code, type, quantity, reason, days_ago) VALUES
  ('ACE-5W30', 'IN', 60, 'Stock inicial', 220),
  ('ACE-5W30', 'IN', 20, 'Compra a proveedor', 40),
  ('FIL-ACE', 'IN', 30, 'Stock inicial', 220),
  ('FIL-ACE', 'IN', 10, 'Compra a proveedor', 40),
  ('FIL-AIR', 'IN', 12, 'Stock inicial', 220),
  ('BAL-DEL', 'IN', 8, 'Stock inicial', 220),
  ('BAL-DEL', 'ADJUSTMENT', -1, 'Conteo físico: pieza dañada en almacén', 20),
  ('BAL-TRA', 'IN', 4, 'Stock inicial', 220),
  ('BAL-TRA', 'ADJUSTMENT', -2, 'Merma por humedad en almacén', 15),
  ('DIS-DEL', 'IN', 6, 'Stock inicial', 220),
  ('BUJ-NGK', 'IN', 10, 'Stock inicial', 220),
  ('BAT-12V', 'IN', 6, 'Stock inicial', 220),
  ('COR-DIS', 'IN', 1, 'Stock inicial', 220),
  ('BOM-AGU', 'IN', 1, 'Stock inicial', 220),
  ('EMP-CAR', 'IN', 4, 'Stock inicial', 220),
  ('LIQ-FRE', 'IN', 5, 'Stock inicial', 220),
  ('DIS-OLD', 'IN', 2, 'Stock inicial', 220);

-- Entradas y ajustes (sin orden): los registra el administrador.
INSERT INTO inventory_movements (part_id, type, quantity, reason, order_id, created_by, created_at)
SELECT p.id, s.type, s.quantity, s.reason, NULL, a.id, DATE_SUB(NOW(), INTERVAL s.days_ago DAY)
FROM seed_movements s
JOIN parts p ON p.code = s.code
JOIN users a ON a.username = 'admin'
WHERE NOT EXISTS (
  SELECT 1 FROM inventory_movements m
   WHERE m.part_id = p.id AND m.type = s.type AND m.reason = s.reason AND m.order_id IS NULL
);

-- Salidas por uso en órdenes: una por línea sembrada, ligada a su orden (motivo «Uso en OS-000012»).
INSERT INTO inventory_movements (part_id, type, quantity, reason, order_id, created_by, created_at)
SELECT op.part_id, 'OUT', -op.quantity, CONCAT('Uso en OS-', LPAD(op.order_id, 6, '0')), op.order_id,
       COALESCE(o.mechanic_id, a.id), DATE_ADD(o.created_at, INTERVAL 1 HOUR)
FROM order_parts op
JOIN service_orders o ON o.id = op.order_id
JOIN parts p ON p.id = op.part_id
JOIN users a ON a.username = 'admin'
WHERE p.code IN ('ACE-5W30', 'FIL-ACE', 'FIL-AIR', 'BAL-DEL', 'BAL-TRA', 'DIS-DEL', 'BUJ-NGK', 'BAT-12V',
                 'COR-DIS', 'BOM-AGU', 'EMP-CAR', 'LIQ-FRE', 'DIS-OLD')
  AND NOT EXISTS (
    SELECT 1 FROM inventory_movements m
     WHERE m.part_id = op.part_id AND m.type = 'OUT' AND m.order_id = op.order_id
  );

-- El stock de las refacciones sembradas es la suma de sus movimientos (idempotente y siempre coherente).
UPDATE parts p
SET p.stock = (SELECT COALESCE(SUM(m.quantity), 0) FROM inventory_movements m WHERE m.part_id = p.id)
WHERE p.code IN ('ACE-5W30', 'FIL-ACE', 'FIL-AIR', 'BAL-DEL', 'BAL-TRA', 'DIS-DEL', 'BUJ-NGK', 'BAT-12V',
                 'COR-DIS', 'BOM-AGU', 'EMP-CAR', 'LIQ-FRE', 'DIS-OLD');

-- ---------------------------------------------------------------------------------------------
-- Mantenimientos: pendientes en Normal, Próximo y Vencido (el indicador se calcula) y atendidos.
-- A lo sumo uno pendiente por vehículo.
-- ---------------------------------------------------------------------------------------------
CREATE TEMPORARY TABLE seed_maintenance (
  plate VARCHAR(15) NOT NULL,
  origin_problem VARCHAR(1000) NOT NULL,
  description VARCHAR(255) NOT NULL,
  due_days INT NULL,
  due_mileage INT NULL,
  status VARCHAR(10) NOT NULL,
  attended_days_ago INT NULL
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO seed_maintenance (plate, origin_problem, description, due_days, due_mileage, status, attended_days_ago) VALUES
  -- Vencidos: el kilometraje actual ya rebasó el objetivo / la fecha ya pasó.
  ('ABC-123-A', 'Cambio de aceite y filtro de aceite', 'Cambio de aceite y filtro', NULL, 83260, 'PENDIENTE', NULL),
  ('VWX-234-H', 'Cambio de aceite', 'Cambio de aceite y filtro', -10, 124000, 'PENDIENTE', NULL),
  -- Próximos: dentro del margen de aviso (30 días o 1,000 km).
  ('MNO-345-E', 'Cambio de aceite y filtros', 'Cambio de aceite y filtro', 20, 55000, 'PENDIENTE', NULL),
  ('YZA-567-J', 'Servicio de frenos', 'Revisión de frenos', 25, 99500, 'PENDIENTE', NULL),
  -- Normales.
  ('EFG-123-L', 'Cambio de llantas y alineación', 'Rotación de llantas', 120, 115000, 'PENDIENTE', NULL),
  ('PQR-678-F', 'Cambio de bujías', 'Revisión de bujías y bobinas', 200, 85000, 'PENDIENTE', NULL),
  -- Atendidos (ya no aparecen en la lista de pendientes, pero sí en el historial del vehículo).
  ('HIJ-456-M', 'Cambio de correa de distribución', 'Revisión de la correa de accesorios', -20, 142000, 'ATENDIDO', 15),
  ('ABC-123-A', 'Cambio de aceite y filtro de aceite', 'Revisión general de suspensión', -60, 80000, 'ATENDIDO', 45);

INSERT IGNORE INTO maintenance
  (vehicle_id, order_id, description, due_date, due_mileage, status, attended_at, created_by)
SELECT v.id, o.id, s.description,
       IF(s.due_days IS NULL, NULL, DATE_ADD(CURDATE(), INTERVAL s.due_days DAY)),
       s.due_mileage, s.status,
       IF(s.attended_days_ago IS NULL, NULL, DATE_SUB(NOW(), INTERVAL s.attended_days_ago DAY)),
       COALESCE(o.mechanic_id, a.id)
FROM seed_maintenance s
JOIN vehicles v ON v.license_plate = s.plate
JOIN service_orders o ON o.vehicle_id = v.id AND o.reported_problem = s.origin_problem
JOIN users a ON a.username = 'admin'
WHERE NOT EXISTS (
  SELECT 1 FROM maintenance x WHERE x.vehicle_id = v.id AND x.description = s.description
);

DROP TEMPORARY TABLE seed_maintenance;
DROP TEMPORARY TABLE seed_movements;
DROP TEMPORARY TABLE seed_order_parts;
DROP TEMPORARY TABLE seed_hist_steps;
DROP TEMPORARY TABLE seed_hist_lines;
DROP TEMPORARY TABLE seed_hist_orders;
