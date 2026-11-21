-- Migración 006 (Sprint 6): notificaciones internas y clientes por avisar.
-- Los scripts aplicados NO se editan: los cambios de esquema van en nuevos scripts numerados.
-- Es aditiva: solo crea dos tablas nuevas. No modifica ni borra filas ni columnas de las tablas existentes.
-- Los avisos (mantenimientos, citas, stock y órdenes detenidas) NO se guardan: se calculan al consultar.

-- Lectura de avisos por usuario: único estado que se guarda de las notificaciones.
-- La clave del aviso tiene la forma TIPO:id o TIPO:id:variante (por ejemplo STOCK_LOW:12 o STALLED:5:31).
CREATE TABLE notification_reads (
  user_id INT UNSIGNED NOT NULL,
  notice_key VARCHAR(60) NOT NULL,
  read_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, notice_key),
  CONSTRAINT fk_notification_reads_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Avisos registrados a clientes: la recepción avisa por teléfono o en persona y el sistema solo lo registra.
-- No hay columna de nota ni de canal: el sistema no envía mensajes al cliente.
-- fact_id apunta a la orden, la cita o el mantenimiento según el motivo, por eso no lleva llave foránea.
-- La unicidad (reason, fact_id) garantiza un solo aviso por hecho, también con dos personas a la vez.
CREATE TABLE client_notices (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  client_id INT UNSIGNED NOT NULL,
  reason ENUM('ORDER_READY','APPT_TOMORROW','MAINT_UPCOMING','MAINT_OVERDUE') NOT NULL,
  fact_id INT UNSIGNED NOT NULL,
  notified_by INT UNSIGNED NOT NULL,
  notified_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_client_notices_fact (reason, fact_id),
  KEY idx_client_notices_client (client_id),
  CONSTRAINT fk_client_notices_client FOREIGN KEY (client_id)
    REFERENCES clients (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_client_notices_user FOREIGN KEY (notified_by)
    REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
