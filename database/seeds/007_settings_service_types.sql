-- Seed 007 (Sprint 7): configuración inicial del taller y catálogo de tipos de servicio.
-- Es idempotente: se puede ejecutar varias veces sin duplicar ni sobrescribir nada (INSERT IGNORE sobre las claves únicas).
-- NO edita seeds anteriores y NO toca órdenes, pagos ni tickets existentes. La versión 1.0 de los términos y condiciones la
-- entrega la migración 007, no este seed.

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------------------------
-- 1. Configuración inicial (los datos del taller y los márgenes de «Próximo»). Si ya hay un valor guardado, no se cambia.
-- ---------------------------------------------------------------------------------------------
INSERT IGNORE INTO settings (setting_key, setting_value) VALUES
  ('shop.name', 'Motorix Taller Mecánico'),
  ('shop.address', ''),
  ('shop.phone', ''),
  ('maintenance.warn_days', '30'),
  ('maintenance.warn_km', '1000');

-- ---------------------------------------------------------------------------------------------
-- 2. Tipos de servicio con sus intervalos (días y kilómetros). El nombre es único.
-- ---------------------------------------------------------------------------------------------
INSERT IGNORE INTO service_types (name, interval_days, interval_km, active) VALUES
  ('Cambio de aceite', 180, 5000, 1),
  ('Afinación', 365, 10000, 1),
  ('Revisión de frenos', 365, 20000, 1),
  ('Alineación y balanceo', 180, 10000, 1),
  ('Revisión general', 180, NULL, 1);
