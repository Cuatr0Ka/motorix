-- Migración 002 (Sprint 2): citas, órdenes de servicio, servicios, mano de obra e historial de estados.
-- Los scripts aplicados NO se editan: los cambios de esquema van en nuevos scripts numerados.
-- Nota: vehicle_id es columna base de una columna generada almacenada, por eso sus llaves foráneas
-- usan ON UPDATE RESTRICT (MySQL no admite CASCADE ahí); los identificadores no se modifican.

CREATE TABLE appointments (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  client_id INT UNSIGNED NOT NULL,
  vehicle_id INT UNSIGNED NOT NULL,
  scheduled_at DATETIME NOT NULL,
  reason VARCHAR(255) NOT NULL,
  notes VARCHAR(1000) NULL,
  status ENUM('PENDIENTE','CONFIRMADA','EN_PROCESO','COMPLETADA','CANCELADA') NOT NULL DEFAULT 'PENDIENTE',
  cancel_reason VARCHAR(255) NULL,
  cancelled_at DATETIME NULL,
  -- Vehículo con cita activa: NULL cuando la cita ya terminó, para liberar el horario.
  active_vehicle_id INT UNSIGNED GENERATED ALWAYS AS (IF(status IN ('CANCELADA','COMPLETADA'), NULL, vehicle_id)) STORED,
  created_by INT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_appointments_active_slot (active_vehicle_id, scheduled_at),
  KEY idx_appointments_scheduled (scheduled_at),
  KEY idx_appointments_status (status),
  KEY idx_appointments_client (client_id),
  CONSTRAINT fk_appointments_client FOREIGN KEY (client_id)
    REFERENCES clients (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_appointments_vehicle FOREIGN KEY (vehicle_id)
    REFERENCES vehicles (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_appointments_created_by FOREIGN KEY (created_by)
    REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE service_orders (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  client_id INT UNSIGNED NOT NULL,
  vehicle_id INT UNSIGNED NOT NULL,
  appointment_id INT UNSIGNED NULL,
  mechanic_id INT UNSIGNED NULL,
  status ENUM('RECIBIDO','DIAGNOSTICO','EN_REPARACION','ESPERANDO_REFACCION','TERMINADO','ENTREGADO') NOT NULL DEFAULT 'RECIBIDO',
  reported_problem VARCHAR(1000) NOT NULL,
  entry_mileage INT UNSIGNED NOT NULL,
  mileage_correction TINYINT(1) NOT NULL DEFAULT 0,
  mileage_correction_reason VARCHAR(255) NULL,
  diagnosis TEXT NULL,
  observations TEXT NULL,
  recommendations TEXT NULL,
  -- Vehículo con orden abierta: NULL cuando la orden ya fue entregada (una sola orden abierta por vehículo).
  open_vehicle_id INT UNSIGNED GENERATED ALWAYS AS (IF(status = 'ENTREGADO', NULL, vehicle_id)) STORED,
  created_by INT UNSIGNED NOT NULL,
  delivered_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_orders_open_vehicle (open_vehicle_id),
  UNIQUE KEY uq_orders_appointment (appointment_id),
  KEY idx_orders_status (status),
  KEY idx_orders_mechanic_status (mechanic_id, status),
  KEY idx_orders_vehicle (vehicle_id),
  KEY idx_orders_client (client_id),
  CONSTRAINT fk_orders_client FOREIGN KEY (client_id)
    REFERENCES clients (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_orders_vehicle FOREIGN KEY (vehicle_id)
    REFERENCES vehicles (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_orders_appointment FOREIGN KEY (appointment_id)
    REFERENCES appointments (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_orders_mechanic FOREIGN KEY (mechanic_id)
    REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_orders_created_by FOREIGN KEY (created_by)
    REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE order_services (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id INT UNSIGNED NOT NULL,
  description VARCHAR(255) NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_order_services_order (order_id),
  CONSTRAINT chk_order_services_amount CHECK (amount >= 0),
  CONSTRAINT fk_order_services_order FOREIGN KEY (order_id)
    REFERENCES service_orders (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE order_labor (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id INT UNSIGNED NOT NULL,
  description VARCHAR(255) NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_order_labor_order (order_id),
  CONSTRAINT chk_order_labor_amount CHECK (amount >= 0),
  CONSTRAINT fk_order_labor_order FOREIGN KEY (order_id)
    REFERENCES service_orders (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE order_status_history (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id INT UNSIGNED NOT NULL,
  from_status ENUM('RECIBIDO','DIAGNOSTICO','EN_REPARACION','ESPERANDO_REFACCION','TERMINADO','ENTREGADO') NULL,
  to_status ENUM('RECIBIDO','DIAGNOSTICO','EN_REPARACION','ESPERANDO_REFACCION','TERMINADO','ENTREGADO') NOT NULL,
  changed_by INT UNSIGNED NOT NULL,
  changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_order_history_order (order_id, changed_at),
  CONSTRAINT fk_order_history_order FOREIGN KEY (order_id)
    REFERENCES service_orders (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_order_history_user FOREIGN KEY (changed_by)
    REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
