-- Migración 005 (Sprint 5): precios de refacciones y cobro completo.
-- Los scripts aplicados NO se editan: los cambios de esquema van en nuevos scripts numerados.
-- Es aditiva: solo agrega columnas con valores nulos o por omisión. No modifica ni borra filas de
-- `payments` ni de `tickets`, y no cambia el importe de ningún pago ni el contenido de ningún ticket.
-- Cada ALTER TABLE es atómico en MySQL, así que una falla no deja una tabla a medias.

-- Refacciones: categoría, marca y precios. Las refacciones existentes quedan con los cuatro campos en NULL;
-- sale_price NULL significa «sin precio de venta» (no se puede agregar a una orden hasta capturarlo).
ALTER TABLE parts
  ADD COLUMN category VARCHAR(60) NULL AFTER description,
  ADD COLUMN brand VARCHAR(60) NULL AFTER category,
  ADD COLUMN purchase_price DECIMAL(10,2) NULL AFTER min_stock,
  ADD COLUMN sale_price DECIMAL(10,2) NULL AFTER purchase_price,
  ADD CONSTRAINT chk_parts_purchase_price CHECK (purchase_price IS NULL OR purchase_price >= 0),
  ADD CONSTRAINT chk_parts_sale_price CHECK (sale_price IS NULL OR sale_price > 0);

-- Líneas de refacción de la orden: instantánea del precio de venta al agregarlas. Las líneas existentes
-- quedan en 0 (anteriores a los precios) y no suman al total; toda línea nueva guarda un precio mayor a cero.
ALTER TABLE order_parts
  ADD COLUMN unit_price DECIMAL(10,2) NOT NULL DEFAULT 0 AFTER quantity,
  ADD CONSTRAINT chk_order_parts_unit_price CHECK (unit_price >= 0);
