-- Migración 003 (Sprint 3): kilometraje del servicio, refacciones, movimientos de inventario,
-- refacciones usadas por orden y mantenimientos.
-- Los scripts aplicados NO se editan: los cambios de esquema van en nuevos scripts numerados.
-- Nota: vehicle_id es columna base de una columna generada almacenada, por eso su llave foránea
-- usa ON UPDATE RESTRICT (MySQL no admite CASCADE ahí); los identificadores no se modifican.

ALTER TABLE service_orders
  ADD COLUMN service_mileage INT UNSIGNED NULL AFTER entry_mileage;

CREATE TABLE parts (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  code VARCHAR(40) NOT NULL,
  name VARCHAR(120) NOT NULL,
  description VARCHAR(500) NULL,
  unit VARCHAR(20) NOT NULL,
  -- Igual a la suma de inventory_movements.quantity; solo lo cambia el servicio de inventario.
  stock INT UNSIGNED NOT NULL DEFAULT 0,
  min_stock INT UNSIGNED NOT NULL DEFAULT 0,
  active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_parts_code (code),
  KEY idx_parts_name (name),
  KEY idx_parts_stock (active, stock, min_stock),
  CONSTRAINT chk_parts_stock CHECK (stock >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Tabla de solo agregar: los movimientos no se editan ni se eliminan.
-- quantity lleva signo: entrada (+), salida (-), ajuste (diferencia, distinta de cero).
CREATE TABLE inventory_movements (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  part_id INT UNSIGNED NOT NULL,
  type ENUM('IN','OUT','ADJUSTMENT') NOT NULL,
  quantity INT NOT NULL,
  reason VARCHAR(255) NULL,
  order_id INT UNSIGNED NULL,
  created_by INT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_movements_part (part_id, created_at),
  KEY idx_movements_order (order_id),
  CONSTRAINT chk_movements_sign CHECK (
    (type = 'IN' AND quantity > 0) OR (type = 'OUT' AND quantity < 0) OR (type = 'ADJUSTMENT' AND quantity <> 0)
  ),
  CONSTRAINT chk_movements_max CHECK (ABS(quantity) <= 100000),
  CONSTRAINT fk_movements_part FOREIGN KEY (part_id)
    REFERENCES parts (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_movements_order FOREIGN KEY (order_id)
    REFERENCES service_orders (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_movements_user FOREIGN KEY (created_by)
    REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE order_parts (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id INT UNSIGNED NOT NULL,
  part_id INT UNSIGNED NOT NULL,
  quantity INT UNSIGNED NOT NULL,
  created_by INT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  -- Una sola línea por refacción y orden.
  UNIQUE KEY uq_order_parts_line (order_id, part_id),
  KEY idx_order_parts_part (part_id),
  CONSTRAINT chk_order_parts_quantity CHECK (quantity > 0),
  CONSTRAINT fk_order_parts_order FOREIGN KEY (order_id)
    REFERENCES service_orders (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_order_parts_part FOREIGN KEY (part_id)
    REFERENCES parts (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_order_parts_user FOREIGN KEY (created_by)
    REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE maintenance (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  vehicle_id INT UNSIGNED NOT NULL,
  order_id INT UNSIGNED NOT NULL,
  description VARCHAR(255) NOT NULL,
  due_date DATE NULL,
  due_mileage INT UNSIGNED NULL,
  status ENUM('PENDIENTE','ATENDIDO') NOT NULL DEFAULT 'PENDIENTE',
  attended_at DATETIME NULL,
  -- Vehículo con mantenimiento pendiente: NULL cuando ya fue atendido (un solo pendiente por vehículo).
  pending_vehicle_id INT UNSIGNED GENERATED ALWAYS AS (IF(status = 'PENDIENTE', vehicle_id, NULL)) STORED,
  created_by INT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_maintenance_pending (pending_vehicle_id),
  KEY idx_maintenance_vehicle (vehicle_id),
  KEY idx_maintenance_order (order_id),
  KEY idx_maintenance_due (status, due_date),
  CONSTRAINT chk_maintenance_target CHECK (due_date IS NOT NULL OR due_mileage IS NOT NULL),
  CONSTRAINT fk_maintenance_vehicle FOREIGN KEY (vehicle_id)
    REFERENCES vehicles (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_maintenance_order FOREIGN KEY (order_id)
    REFERENCES service_orders (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_maintenance_user FOREIGN KEY (created_by)
    REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
