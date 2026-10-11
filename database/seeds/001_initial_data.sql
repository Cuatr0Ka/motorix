-- Seed 001 (Sprint 1): cuentas iniciales, clientes y vehículos de ejemplo.
-- Es idempotente: se puede ejecutar varias veces sin duplicar ni sobrescribir registros.
-- Las contraseñas se guardan SOLO como hash bcrypt (costo 10); nunca en texto plano.
-- Cuentas iniciales válidas únicamente para entornos locales (ver docs/project-context.md).

SET NAMES utf8mb4;

-- Usuarios: la clave única es username/email, así que una contraseña cambiada no se restablece.
INSERT IGNORE INTO users (username, name, email, password_hash, role, active) VALUES
  ('admin', 'Administrador del taller', 'admin@motorix.local',
   '$2a$10$H5/8J0U2v5fhEm6IJ4xSY.AYE7wK0LFWFyiESF1i5IloIvQCeSU2m', 'ADMIN', 1),
  ('recepcion', 'Recepción del taller', 'recepcion@motorix.local',
   '$2a$10$NlmpTPaFpXWGardr/dmDUujse.2rDZ4bx1c0JizZNy2MY1wbT046C', 'RECEPTIONIST', 1),
  ('mecanico', 'Mecánico del taller', 'mecanico@motorix.local',
   '$2a$10$X4wR/cMCT5IGej5GfZCcN.I1yssBfKVRZ1Rk/iYVHW40qENWn42gy', 'MECHANIC', 1);

-- Clientes: se insertan solo si no existe otro con el mismo nombre y teléfono.
-- Incluye uno sin correo y dos que comparten teléfono (para ver la advertencia de duplicado).
INSERT INTO clients (name, phone, email, address)
SELECT v.name, v.phone, v.email, v.address
FROM (
  SELECT 'Carlos Hernández Ruiz' AS name, '5512345601' AS phone, 'carlos.hernandez@example.com' AS email, 'Calle Hidalgo 120, Centro' AS address
  UNION ALL SELECT 'María Fernanda López', '5512345602', 'maria.lopez@example.com', 'Av. Reforma 455, Col. Juárez'
  UNION ALL SELECT 'Jorge Ramírez Soto', '5512345603', 'jorge.ramirez@example.com', NULL
  UNION ALL SELECT 'Ana Morales Díaz', '5512345604', 'ana.morales@example.com', 'Privada Los Pinos 8'
  UNION ALL SELECT 'Luis Morales Díaz', '5512345604', 'luis.morales@example.com', 'Privada Los Pinos 8'
  UNION ALL SELECT 'Transportes del Norte S.A.', '5512345606', 'contacto@transportesnorte.example.com', 'Parque Industrial Norte, Nave 4'
  UNION ALL SELECT 'Patricia Gómez Vega', '5512345607', NULL, 'Calle Morelos 33'
  UNION ALL SELECT 'Roberto Sánchez Cruz', '5512345608', 'roberto.sanchez@example.com', NULL
) AS v
WHERE NOT EXISTS (
  SELECT 1 FROM clients c WHERE c.name = v.name AND c.phone = v.phone
);

-- Vehículos: la placa es única. El propietario se busca por nombre y teléfono,
-- sin depender de identificadores fijos. Si el cliente no existe, no se inserta nada.
INSERT IGNORE INTO vehicles (client_id, brand, model, year, license_plate, vin, color, current_mileage)
SELECT c.id, v.brand, v.model, v.year, v.license_plate, v.vin, v.color, v.current_mileage
FROM (
  SELECT 'Carlos Hernández Ruiz' AS cname, '5512345601' AS cphone, 'Nissan' AS brand, 'Versa' AS model, 2019 AS year, 'ABC-123-A' AS license_plate, '3N1CN7AP5KL812345' AS vin, 'Gris' AS color, 84500 AS current_mileage
  UNION ALL SELECT 'Carlos Hernández Ruiz', '5512345601', 'Toyota', 'Hilux', 2021, 'DEF-456-B', '3TMCZ5AN8MM123456', 'Blanco', 42300
  UNION ALL SELECT 'María Fernanda López', '5512345602', 'Volkswagen', 'Jetta', 2018, 'GHI-789-C', '3VW2B7AJ5JM234567', 'Rojo', 96100
  UNION ALL SELECT 'Jorge Ramírez Soto', '5512345603', 'Chevrolet', 'Aveo', 2016, 'JKL-012-D', NULL, NULL, NULL
  UNION ALL SELECT 'Ana Morales Díaz', '5512345604', 'Honda', 'Civic', 2020, 'MNO-345-E', '2HGFC2F59LH345678', 'Azul', 51200
  UNION ALL SELECT 'Luis Morales Díaz', '5512345604', 'Mazda', 'Mazda 3', 2017, 'PQR-678-F', 'JM1BM1U79H1456789', 'Negro', 73800
  UNION ALL SELECT 'Transportes del Norte S.A.', '5512345606', 'Nissan', 'NP300', 2022, 'STU-901-G', '3N6CD33B2NK567890', 'Blanco', 38900
  UNION ALL SELECT 'Transportes del Norte S.A.', '5512345606', 'Ford', 'Transit', 2020, 'VWX-234-H', 'WF0XXXTTGXLA67890', 'Blanco', 120400
  UNION ALL SELECT 'Transportes del Norte S.A.', '5512345606', 'Chevrolet', 'Express', 2019, 'YZA-567-J', '1GCWGAFP5K1678901', 'Blanco', 98700
  UNION ALL SELECT 'Patricia Gómez Vega', '5512345607', 'Kia', 'Rio', 2021, 'BCD-890-K', '3KPA24AD6ME789012', 'Plata', 29800
  UNION ALL SELECT 'Roberto Sánchez Cruz', '5512345608', 'Ford', 'Ranger', 2018, 'EFG-123-L', '8AFER13N5J6890123', 'Verde', 110250
  UNION ALL SELECT 'Roberto Sánchez Cruz', '5512345608', 'Seat', 'Ibiza', 2015, 'HIJ-456-M', 'VSSZZZ6JZFR901234', 'Gris', 142000
) AS v
JOIN clients c ON c.name = v.cname AND c.phone = v.cphone;
