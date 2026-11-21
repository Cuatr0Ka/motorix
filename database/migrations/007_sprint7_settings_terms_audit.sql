-- Migración 007 (Sprint 7): configuración, tipos de servicio, términos y condiciones, bitácora y actividad de la sesión.
-- Los scripts aplicados NO se editan: los cambios de esquema van en nuevos scripts numerados.
-- Es aditiva: crea cinco tablas nuevas y agrega dos columnas nulas. No modifica ni borra filas ni columnas existentes.
-- Los reportes (ingresos, servicios, productividad, refacciones y rotación) NO se guardan: se calculan al consultar.

SET NAMES utf8mb4;

-- Configuración del taller: pares de clave y valor (datos del taller y márgenes de mantenimiento).
-- Claves: shop.name, shop.address, shop.phone, maintenance.warn_days y maintenance.warn_km.
-- Sin valor guardado, el sistema usa la variable de entorno de respaldo o el valor predeterminado.
CREATE TABLE settings (
  setting_key VARCHAR(60) NOT NULL,
  setting_value VARCHAR(255) NOT NULL,
  updated_by INT UNSIGNED NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (setting_key),
  CONSTRAINT fk_settings_user FOREIGN KEY (updated_by)
    REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Catálogo de tipos de servicio con su intervalo de mantenimiento. Un tipo no se borra: solo se desactiva.
CREATE TABLE service_types (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  interval_days INT UNSIGNED NULL,
  interval_km INT UNSIGNED NULL,
  active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_service_types_name (name),
  CONSTRAINT chk_service_types_interval CHECK (interval_days IS NOT NULL OR interval_km IS NOT NULL),
  CONSTRAINT chk_service_types_days CHECK (interval_days IS NULL OR interval_days > 0),
  CONSTRAINT chk_service_types_km CHECK (interval_km IS NULL OR interval_km > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Versiones de los términos y condiciones y del aviso de privacidad. Una versión publicada no se edita: una versión
-- nueva es otra fila, y la vigente es la de mayor fecha de publicación.
CREATE TABLE terms_versions (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  version VARCHAR(20) NOT NULL,
  title VARCHAR(150) NOT NULL,
  body MEDIUMTEXT NOT NULL,
  published_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_terms_versions_version (version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Aceptación de una versión por un usuario: una sola por usuario y versión, también con solicitudes simultáneas.
CREATE TABLE terms_acceptances (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id INT UNSIGNED NOT NULL,
  terms_version_id INT UNSIGNED NOT NULL,
  accepted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_terms_acceptances (user_id, terms_version_id),
  KEY idx_terms_acceptances_version (terms_version_id, accepted_at),
  CONSTRAINT fk_terms_acceptances_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_terms_acceptances_version FOREIGN KEY (terms_version_id)
    REFERENCES terms_versions (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Bitácora de acciones sensibles. Es de solo inserción: no existe ninguna ruta ni servicio que edite o borre filas.
-- El resumen nunca contiene contraseñas, hashes, tokens ni datos de tarjeta.
CREATE TABLE audit_log (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  actor_user_id INT UNSIGNED NULL,
  action VARCHAR(40) NOT NULL,
  entity_type VARCHAR(30) NULL,
  entity_id INT UNSIGNED NULL,
  summary VARCHAR(255) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_audit_created (created_at),
  KEY idx_audit_actor (actor_user_id, created_at),
  KEY idx_audit_action (action, created_at),
  CONSTRAINT fk_audit_actor FOREIGN KEY (actor_user_id)
    REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Las líneas de servicio de una orden pueden enlazarse, de forma opcional, a un tipo de servicio.
-- Las líneas existentes quedan en NULL y siguen funcionando como texto libre.
ALTER TABLE order_services
  ADD COLUMN service_type_id INT UNSIGNED NULL AFTER order_id,
  ADD KEY idx_order_services_type (service_type_id),
  ADD CONSTRAINT fk_order_services_type FOREIGN KEY (service_type_id)
    REFERENCES service_types (id) ON DELETE RESTRICT ON UPDATE CASCADE;

-- Última actividad autenticada de cada usuario (cierre de sesión por inactividad). NULL se trata como activa.
ALTER TABLE users
  ADD COLUMN last_activity_at DATETIME NULL;

-- Versión 1.0 de los términos y condiciones y del aviso de privacidad. Es una plantilla que el taller debe revisar con
-- quien corresponda; no constituye asesoría legal. Todos los usuarios existentes quedan sin aceptarla y la aceptan
-- en su siguiente inicio de sesión.
INSERT INTO terms_versions (version, title, body) VALUES (
  '1.0',
  'Términos y condiciones y aviso de privacidad',
  'TÉRMINOS Y CONDICIONES DE USO DE MOTORIX

1. Uso permitido del sistema
Motorix es una herramienta de trabajo del taller. Úsala solo para las actividades de tu puesto: registrar y consultar clientes, vehículos, citas, órdenes de servicio, refacciones, pagos y tickets, según el rol que tengas asignado. No intentes acceder a información o funciones que tu rol no permite, ni uses el sistema para fines personales o ajenos al taller.

2. Confidencialidad de los datos de clientes y vehículos
La información de los clientes (nombre, teléfono, correo y domicilio) y de sus vehículos (placas, kilometraje e historial de servicios) es confidencial. No la copies, la compartas ni la uses fuera de lo necesario para atender al cliente. Los precios de compra de las refacciones son información reservada de la administración. Esta obligación continúa aunque dejes de trabajar en el taller.

3. Responsabilidad de las cuentas personales
Tu cuenta es personal e intransferible. No compartas tu usuario ni tu contraseña, usa una contraseña de al menos 10 caracteres con mayúscula, minúscula y número, y cierra tu sesión cuando te alejes del equipo. Las acciones realizadas con tu cuenta se consideran hechas por ti y las acciones sensibles quedan registradas en una bitácora. Si sospechas que alguien más usó tu cuenta, avisa de inmediato a la administración.

4. Aviso de privacidad
El taller es responsable del tratamiento de los datos personales que se capturan en este sistema. Los datos se usan únicamente para prestar y documentar el servicio automotriz, cobrar, emitir comprobantes y recordar al cliente su próximo mantenimiento mediante una llamada o un aviso en persona del personal; el sistema no envía mensajes al cliente. No se almacenan datos de tarjeta. Los datos solo se comparten con las personas del taller autorizadas y no se venden ni se transfieren a terceros. El cliente puede solicitar al taller el acceso, la corrección o la eliminación de sus datos personales.

5. Aceptación
Al aceptar estos términos confirmas que los leíste y que te comprometes a cumplirlos. Si no los aceptas, no podrás usar el sistema. Cuando se publique una nueva versión, deberás aceptarla para seguir trabajando.'
);
