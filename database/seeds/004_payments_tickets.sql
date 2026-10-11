-- Seed 004 (Sprint 4): pagos y tickets de ejemplo.
-- Es idempotente: se puede ejecutar varias veces sin duplicar ni sobrescribir registros.
-- Requiere los seeds 001 a 003 (usuarios, vehículos, órdenes y sus servicios). Claves naturales:
--   pagos -> (orden, método)        tickets -> orden
-- Las órdenes se localizan por (placa del vehículo, problema reportado). Los importes se calculan a partir de los
-- servicios y la mano de obra de cada orden, así que siempre coinciden con el total vigente.
-- NO llama a Mercado Pago ni contiene credenciales: el cobro pendiente usa un enlace y referencias de ejemplo, y
-- ningún dato de tarjeta (solo folios de terminal ficticios).

SET NAMES utf8mb4;

CREATE TEMPORARY TABLE seed_payments (
  plate VARCHAR(15) NOT NULL,
  problem VARCHAR(1000) NOT NULL,
  method VARCHAR(15) NOT NULL,
  status VARCHAR(10) NOT NULL,
  reference VARCHAR(100) NULL,
  external_reference VARCHAR(100) NULL,
  external_payment_id VARCHAR(40) NULL,
  checkout_url VARCHAR(500) NULL,
  minutes_before_paid INT NOT NULL
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Pagos en los cuatro estados y con los cuatro métodos. A lo sumo uno vigente (Pendiente o Pagado) por orden.
INSERT INTO seed_payments (plate, problem, method, status, reference, external_reference, external_payment_id, checkout_url, minutes_before_paid) VALUES
  ('MNO-345-E', 'Cambio de aceite y filtros', 'EFECTIVO', 'PAGADO', NULL, NULL, NULL, NULL, 240),
  ('EFG-123-L', 'Cambio de llantas y alineación', 'TRANSFERENCIA', 'PAGADO', 'SPEI-EJEMPLO-0042', NULL, NULL, NULL, 480),
  ('ABC-123-A', 'Cambio de aceite y filtro de aceite', 'TARJETA', 'PAGADO', 'TERM-EJEMPLO-48213', NULL, NULL, NULL, 600),
  ('MNO-345-E', 'Servicio de 30,000 km', 'MERCADO_PAGO', 'PAGADO', NULL, 'motorix-ejemplo-30000', 'MP-EJEMPLO-0001', 'https://sandbox.mercadopago.com.mx/checkout/v1/redirect?pref_id=EJEMPLO-30000', 900),
  ('YZA-567-J', 'Servicio de frenos', 'MERCADO_PAGO', 'RECHAZADO', NULL, 'motorix-ejemplo-frenos', NULL, 'https://sandbox.mercadopago.com.mx/checkout/v1/redirect?pref_id=EJEMPLO-FRENOS', 1500),
  ('YZA-567-J', 'Servicio de frenos', 'EFECTIVO', 'PAGADO', NULL, NULL, NULL, NULL, 1400),
  ('VWX-234-H', 'Cambio de aceite', 'MERCADO_PAGO', 'CANCELADO', NULL, 'motorix-ejemplo-aceite', NULL, 'https://sandbox.mercadopago.com.mx/checkout/v1/redirect?pref_id=EJEMPLO-ACEITE', 1200),
  ('PQR-678-F', 'Cambio de bujías', 'EFECTIVO', 'PAGADO', NULL, NULL, NULL, NULL, 1000),
  ('STU-901-G', 'Servicio de 40,000 km', 'MERCADO_PAGO', 'PENDIENTE', NULL, 'motorix-ejemplo-40000', NULL, 'https://sandbox.mercadopago.com.mx/checkout/v1/redirect?pref_id=EJEMPLO-40000', 30);

INSERT INTO payments
  (order_id, amount, method, status, reference, external_reference, external_payment_id, checkout_url, paid_at, created_by, created_at)
SELECT o.id,
       (SELECT COALESCE(SUM(s.amount), 0) FROM order_services s WHERE s.order_id = o.id)
         + (SELECT COALESCE(SUM(l.amount), 0) FROM order_labor l WHERE l.order_id = o.id),
       sp.method, sp.status, sp.reference, sp.external_reference, sp.external_payment_id, sp.checkout_url,
       IF(sp.status = 'PAGADO', DATE_SUB(COALESCE(o.delivered_at, NOW()), INTERVAL sp.minutes_before_paid MINUTE), NULL),
       r.id,
       DATE_SUB(COALESCE(o.delivered_at, NOW()), INTERVAL sp.minutes_before_paid MINUTE)
FROM seed_payments sp
JOIN vehicles v ON v.license_plate = sp.plate
JOIN service_orders o ON o.vehicle_id = v.id AND o.reported_problem = sp.problem
JOIN users r ON r.username = 'recepcion'
WHERE (SELECT COALESCE(SUM(s.amount), 0) FROM order_services s WHERE s.order_id = o.id)
        + (SELECT COALESCE(SUM(l.amount), 0) FROM order_labor l WHERE l.order_id = o.id) > 0
  AND NOT EXISTS (
    SELECT 1 FROM payments x WHERE x.order_id = o.id AND x.method = sp.method
  )
  -- Un pago vigente por orden: si una orden ya tiene otro vigente (por ejemplo, creado a mano), no se agrega otro.
  AND (sp.status NOT IN ('PENDIENTE', 'PAGADO') OR NOT EXISTS (
    SELECT 1 FROM payments y WHERE y.order_id = o.id AND y.status IN ('PENDIENTE', 'PAGADO')
  ));

-- ---------------------------------------------------------------------------------------------
-- Tickets de las órdenes cobradas (con pago Pagado). La instantánea tiene la misma forma que arma el sistema.
-- Se omiten a propósito en 'PQR-678-F' para poder demostrar «Generar ticket» desde la interfaz.
-- ---------------------------------------------------------------------------------------------
INSERT INTO tickets (order_id, payment_id, content, generated_by, generated_at)
SELECT o.id, p.id,
       JSON_OBJECT(
         'shop', JSON_OBJECT('name', 'Motorix Taller Mecánico', 'address', 'Av. Principal 123, Col. Centro', 'phone', '5550000000'),
         'customer', JSON_OBJECT('name', c.name, 'phone', c.phone),
         'vehicle', JSON_OBJECT('plate', v.license_plate, 'brand', v.brand, 'model', v.model, 'year', v.year,
                                'mileage', COALESCE(o.service_mileage, o.entry_mileage)),
         'order', JSON_OBJECT('folio', CONCAT('OS-', LPAD(o.id, 6, '0')), 'entryMileage', o.entry_mileage,
                              'serviceMileage', o.service_mileage),
         'services', COALESCE((
           SELECT JSON_ARRAYAGG(JSON_OBJECT('description', s.description, 'amount', CAST(s.amount AS CHAR)))
             FROM (SELECT order_id, description, amount FROM order_services ORDER BY id) s WHERE s.order_id = o.id
         ), JSON_ARRAY()),
         'parts', COALESCE((
           SELECT JSON_ARRAYAGG(JSON_OBJECT('code', pt.code, 'name', pt.name, 'unit', pt.unit, 'quantity', op.quantity))
             FROM (SELECT order_id, part_id, quantity FROM order_parts ORDER BY id) op
             JOIN parts pt ON pt.id = op.part_id WHERE op.order_id = o.id
         ), JSON_ARRAY()),
         'labor', COALESCE((
           SELECT JSON_ARRAYAGG(JSON_OBJECT('description', l.description, 'amount', CAST(l.amount AS CHAR)))
             FROM (SELECT order_id, description, amount FROM order_labor ORDER BY id) l WHERE l.order_id = o.id
         ), JSON_ARRAY()),
         'totals', JSON_OBJECT(
           'services', CAST(CAST((SELECT COALESCE(SUM(s.amount), 0) FROM order_services s WHERE s.order_id = o.id) AS DECIMAL(10,2)) AS CHAR),
           'labor', CAST(CAST((SELECT COALESCE(SUM(l.amount), 0) FROM order_labor l WHERE l.order_id = o.id) AS DECIMAL(10,2)) AS CHAR),
           'total', CAST(CAST((SELECT COALESCE(SUM(s.amount), 0) FROM order_services s WHERE s.order_id = o.id)
                         + (SELECT COALESCE(SUM(l.amount), 0) FROM order_labor l WHERE l.order_id = o.id) AS DECIMAL(10,2)) AS CHAR)
         ),
         'payment', JSON_OBJECT('method', p.method, 'status', p.status,
                                'paidAt', DATE_FORMAT(DATE_ADD(p.paid_at, INTERVAL TIMESTAMPDIFF(SECOND, NOW(), UTC_TIMESTAMP()) SECOND), '%Y-%m-%dT%H:%i:%s.000Z'),
                                'reference', p.reference),
         'generatedAt', DATE_FORMAT(DATE_ADD(DATE_ADD(p.paid_at, INTERVAL 5 MINUTE), INTERVAL TIMESTAMPDIFF(SECOND, NOW(), UTC_TIMESTAMP()) SECOND), '%Y-%m-%dT%H:%i:%s.000Z')
       ),
       r.id,
       DATE_ADD(p.paid_at, INTERVAL 5 MINUTE)
FROM payments p
JOIN service_orders o ON o.id = p.order_id
JOIN vehicles v ON v.id = o.vehicle_id
JOIN clients c ON c.id = o.client_id
JOIN users r ON r.username = 'recepcion'
WHERE p.status = 'PAGADO'
  AND v.license_plate <> 'PQR-678-F'
  AND NOT EXISTS (SELECT 1 FROM tickets t WHERE t.order_id = o.id);

DROP TEMPORARY TABLE seed_payments;
