-- Seed 005 (Sprint 5): precios de refacciones y casos de compatibilidad.
-- Es idempotente: se puede ejecutar varias veces sin duplicar ni sobrescribir registros. Requiere los seeds 001 a 004.
-- NO llama a Mercado Pago ni contiene credenciales, y no modifica pagos, tickets, líneas de refacción anteriores a los
-- precios ni órdenes entregadas o con un pago Pagado.
--
-- Deja a la vista los casos del sprint:
--   * refacciones con categoría, marca y precios, y una (BOM-AGU) sin precio de venta, que no se puede agregar a una orden;
--   * una orden Terminada NUEVA y cobrable, con servicios, mano de obra y refacciones con precio (los seeds anteriores
--     solo dejan una orden Terminada y esa ya tiene un pago pendiente);
--   * la orden Terminada con el pago de Mercado Pago pendiente, a la que se agrega una refacción con precio: el pago queda
--     desfasado y convive con sus líneas anteriores (precio 0, que no suman).

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------------------------
-- 1. Categoría, marca y precios de las refacciones (solo donde todavía no tienen precio de venta).
-- ---------------------------------------------------------------------------------------------
CREATE TEMPORARY TABLE seed_s5_prices (
  code VARCHAR(40) NOT NULL,
  category VARCHAR(60) NOT NULL,
  brand VARCHAR(60) NOT NULL,
  purchase_price DECIMAL(10,2) NOT NULL,
  sale_price DECIMAL(10,2) NOT NULL
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- BOM-AGU queda sin precio de venta a propósito (demuestra el bloqueo de agregarla a una orden).
INSERT INTO seed_s5_prices (code, category, brand, purchase_price, sale_price) VALUES
  ('ACE-5W30', 'Lubricantes', 'Mobil 1', 145.00, 210.00),
  ('FIL-ACE', 'Filtros', 'Mann', 90.00, 140.00),
  ('FIL-AIR', 'Filtros', 'Mann', 110.00, 175.00),
  ('BAL-DEL', 'Frenos', 'Brembo', 520.00, 780.00),
  ('BAL-TRA', 'Frenos', 'Brembo', 430.00, 650.00),
  ('DIS-DEL', 'Frenos', 'Brembo', 640.00, 950.00),
  ('BUJ-NGK', 'Encendido', 'NGK', 95.00, 150.00),
  ('BAT-12V', 'Eléctrico', 'LTH', 1400.00, 1950.00),
  ('COR-DIS', 'Distribución', 'Gates', 780.00, 1150.00),
  ('EMP-CAR', 'Motor', 'Victor Reinz', 160.00, 260.00),
  ('LIQ-FRE', 'Frenos', 'Bosch', 70.00, 115.00),
  ('DIS-OLD', 'Frenos', 'Genérica', 400.00, 600.00);

UPDATE parts p
JOIN seed_s5_prices s ON s.code = p.code
SET p.category = s.category, p.brand = s.brand, p.purchase_price = s.purchase_price, p.sale_price = s.sale_price
WHERE p.sale_price IS NULL;

-- ---------------------------------------------------------------------------------------------
-- 2. Orden Terminada nueva y cobrable (vehículo que solo tiene órdenes entregadas, por la regla de una sola orden
--    abierta por vehículo).
-- ---------------------------------------------------------------------------------------------
INSERT INTO service_orders
  (client_id, vehicle_id, appointment_id, mechanic_id, status, reported_problem, entry_mileage,
   diagnosis, observations, recommendations, created_by, delivered_at, created_at)
SELECT v.client_id, v.id, NULL, m.id, 'TERMINADO', 'Mantenimiento con refacciones (ejemplo Sprint 5)', 118500,
       'Balatas delanteras al límite, aceite degradado y filtro saturado.', NULL,
       'Revisar el sistema de frenos en el siguiente servicio.', r.id, NULL, DATE_SUB(NOW(), INTERVAL 30 HOUR)
FROM vehicles v
JOIN users r ON r.username = 'recepcion'
JOIN users m ON m.username = 'mecanico'
WHERE v.license_plate = 'VWX-234-H'
  AND NOT EXISTS (
    SELECT 1 FROM service_orders o
     WHERE o.vehicle_id = v.id AND o.reported_problem = 'Mantenimiento con refacciones (ejemplo Sprint 5)'
  )
  AND NOT EXISTS (SELECT 1 FROM service_orders o WHERE o.vehicle_id = v.id AND o.status <> 'ENTREGADO');

-- Historial de estados de la orden nueva (recibida → diagnóstico → en reparación → terminada).
CREATE TEMPORARY TABLE seed_s5_steps (
  from_status VARCHAR(20) NULL,
  to_status VARCHAR(20) NOT NULL,
  who VARCHAR(10) NOT NULL,
  hours_after_created INT NOT NULL
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO seed_s5_steps (from_status, to_status, who, hours_after_created) VALUES
  (NULL, 'RECIBIDO', 'recepcion', 0),
  ('RECIBIDO', 'DIAGNOSTICO', 'mecanico', 1),
  ('DIAGNOSTICO', 'EN_REPARACION', 'mecanico', 2),
  ('EN_REPARACION', 'TERMINADO', 'mecanico', 6);

INSERT INTO order_status_history (order_id, from_status, to_status, changed_by, changed_at)
SELECT o.id, st.from_status, st.to_status,
       IF(st.who = 'mecanico', o.mechanic_id, r.id),
       DATE_ADD(o.created_at, INTERVAL st.hours_after_created HOUR)
FROM service_orders o
JOIN vehicles v ON v.id = o.vehicle_id
JOIN users r ON r.username = 'recepcion'
JOIN seed_s5_steps st
WHERE v.license_plate = 'VWX-234-H'
  AND o.reported_problem = 'Mantenimiento con refacciones (ejemplo Sprint 5)'
  AND NOT EXISTS (
    SELECT 1 FROM order_status_history x
     WHERE x.order_id = o.id AND x.to_status = st.to_status AND x.from_status <=> st.from_status
  );

-- Servicios y mano de obra de la orden nueva.
INSERT INTO order_services (order_id, description, amount)
SELECT o.id, s.description, s.amount
FROM service_orders o
JOIN vehicles v ON v.id = o.vehicle_id
JOIN (
  SELECT 'Cambio de balatas delanteras' AS description, 600.00 AS amount
  UNION ALL SELECT 'Cambio de aceite y filtro de aceite', 250.00
) s
WHERE v.license_plate = 'VWX-234-H'
  AND o.reported_problem = 'Mantenimiento con refacciones (ejemplo Sprint 5)'
  AND NOT EXISTS (SELECT 1 FROM order_services x WHERE x.order_id = o.id AND x.description = s.description);

INSERT INTO order_labor (order_id, description, amount)
SELECT o.id, 'Mano de obra de mantenimiento', 450.00
FROM service_orders o
JOIN vehicles v ON v.id = o.vehicle_id
WHERE v.license_plate = 'VWX-234-H'
  AND o.reported_problem = 'Mantenimiento con refacciones (ejemplo Sprint 5)'
  AND NOT EXISTS (SELECT 1 FROM order_labor x WHERE x.order_id = o.id AND x.description = 'Mano de obra de mantenimiento');

-- ---------------------------------------------------------------------------------------------
-- 3. Refacciones con precio: las de la orden nueva y una más en la orden con el pago de Mercado Pago pendiente.
--    `unit_price` es el precio de venta vigente (instantánea). Clave natural de las líneas: (orden, refacción); la
--    refacción que se agrega a la orden con pago pendiente no está ya en ella, así que no se mezcla con sus líneas
--    anteriores.
-- ---------------------------------------------------------------------------------------------
CREATE TEMPORARY TABLE seed_s5_lines (
  plate VARCHAR(15) NOT NULL,
  problem VARCHAR(1000) NOT NULL,
  code VARCHAR(40) NOT NULL,
  quantity INT NOT NULL
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO seed_s5_lines (plate, problem, code, quantity) VALUES
  ('VWX-234-H', 'Mantenimiento con refacciones (ejemplo Sprint 5)', 'BAL-DEL', 1),
  ('VWX-234-H', 'Mantenimiento con refacciones (ejemplo Sprint 5)', 'FIL-ACE', 1),
  ('VWX-234-H', 'Mantenimiento con refacciones (ejemplo Sprint 5)', 'ACE-5W30', 4),
  ('STU-901-G', 'Servicio de 40,000 km', 'FIL-AIR', 1);

INSERT INTO order_parts (order_id, part_id, quantity, unit_price, created_by)
SELECT o.id, p.id, s.quantity, p.sale_price, COALESCE(o.mechanic_id, a.id)
FROM seed_s5_lines s
JOIN vehicles v ON v.license_plate = s.plate
JOIN service_orders o ON o.vehicle_id = v.id AND o.reported_problem = s.problem
JOIN parts p ON p.code = s.code
JOIN users a ON a.username = 'admin'
WHERE o.status <> 'ENTREGADO'
  AND p.sale_price IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM payments pg WHERE pg.order_id = o.id AND pg.status = 'PAGADO')
  AND NOT EXISTS (SELECT 1 FROM order_parts x WHERE x.order_id = o.id AND x.part_id = p.id);

-- Salida de inventario ligada a la orden por cada línea sembrada (motivo «Uso en OS-000012»).
INSERT INTO inventory_movements (part_id, type, quantity, reason, order_id, created_by, created_at)
SELECT op.part_id, 'OUT', -op.quantity, CONCAT('Uso en OS-', LPAD(op.order_id, 6, '0')), op.order_id,
       COALESCE(o.mechanic_id, a.id), DATE_ADD(o.created_at, INTERVAL 1 HOUR)
FROM seed_s5_lines s
JOIN vehicles v ON v.license_plate = s.plate
JOIN service_orders o ON o.vehicle_id = v.id AND o.reported_problem = s.problem
JOIN parts p ON p.code = s.code
JOIN order_parts op ON op.order_id = o.id AND op.part_id = p.id
JOIN users a ON a.username = 'admin'
WHERE op.unit_price > 0
  AND NOT EXISTS (
    SELECT 1 FROM inventory_movements m WHERE m.part_id = op.part_id AND m.type = 'OUT' AND m.order_id = op.order_id
  );

-- El stock de las refacciones afectadas vuelve a ser la suma de sus movimientos (idempotente y siempre coherente).
UPDATE parts p
SET p.stock = (SELECT COALESCE(SUM(m.quantity), 0) FROM inventory_movements m WHERE m.part_id = p.id)
WHERE p.code IN ('BAL-DEL', 'FIL-ACE', 'ACE-5W30', 'FIL-AIR');

DROP TEMPORARY TABLE seed_s5_lines;
DROP TEMPORARY TABLE seed_s5_steps;
DROP TEMPORARY TABLE seed_s5_prices;
