-- Migración 004 (Sprint 4): pagos y tickets.
-- Los scripts aplicados NO se editan: los cambios de esquema van en nuevos scripts numerados.
-- Nota: order_id es columna base de una columna generada almacenada, por eso su llave foránea usa
-- ON UPDATE RESTRICT (MySQL no admite CASCADE ahí); los identificadores no se modifican.
-- Ninguna columna guarda datos de tarjeta ni credenciales de Mercado Pago (RN-14).

CREATE TABLE payments (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id INT UNSIGNED NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  method ENUM('EFECTIVO','TARJETA','TRANSFERENCIA','MERCADO_PAGO') NOT NULL,
  status ENUM('PENDIENTE','PAGADO','RECHAZADO','CANCELADO') NOT NULL,
  -- Referencia capturada por la recepción (folio de terminal, clave de rastreo). Nunca datos de tarjeta.
  reference VARCHAR(100) NULL,
  -- Referencia que Motorix envía a Mercado Pago y datos de la operación del proveedor.
  external_reference VARCHAR(100) NULL,
  external_payment_id VARCHAR(40) NULL,
  checkout_url VARCHAR(500) NULL,
  last_checked_at DATETIME NULL,
  paid_at DATETIME NULL,
  -- Orden con pago vigente: NULL cuando el pago ya fue rechazado o cancelado (un solo pago vigente por orden).
  active_order_id INT UNSIGNED GENERATED ALWAYS AS (IF(status IN ('PENDIENTE','PAGADO'), order_id, NULL)) STORED,
  created_by INT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_payments_active_order (active_order_id),
  KEY idx_payments_order (order_id),
  KEY idx_payments_status (status, created_at),
  CONSTRAINT chk_payments_amount CHECK (amount > 0),
  -- Efectivo, tarjeta y transferencia nacen y permanecen en estado Pagado.
  CONSTRAINT chk_payments_method_status CHECK (method = 'MERCADO_PAGO' OR status = 'PAGADO'),
  CONSTRAINT chk_payments_paid_at CHECK (status <> 'PAGADO' OR paid_at IS NOT NULL),
  CONSTRAINT fk_payments_order FOREIGN KEY (order_id)
    REFERENCES service_orders (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_payments_user FOREIGN KEY (created_by)
    REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Comprobante de una orden cobrada. Solo lectura: no tiene updated_at ni operaciones de edición o borrado.
CREATE TABLE tickets (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id INT UNSIGNED NOT NULL,
  payment_id INT UNSIGNED NOT NULL,
  -- Instantánea del contenido tal como se generó (taller, cliente, vehículo, conceptos e importes).
  content JSON NOT NULL,
  generated_by INT UNSIGNED NOT NULL,
  generated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tickets_order (order_id),
  KEY idx_tickets_generated (generated_at),
  KEY idx_tickets_payment (payment_id),
  CONSTRAINT fk_tickets_order FOREIGN KEY (order_id)
    REFERENCES service_orders (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_tickets_payment FOREIGN KEY (payment_id)
    REFERENCES payments (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_tickets_user FOREIGN KEY (generated_by)
    REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
