-- Migración 005 (Sprint 5): precios de refacciones y cobro completo.
-- Los scripts aplicados NO se editan: los cambios de esquema van en nuevos scripts numerados.
-- Única excepción (2026-11-25): se dividieron los ALTER TABLE para que corra también en TiDB; el esquema resultante es idéntico.
-- Es aditiva: solo agrega columnas con valores nulos o por omisión. No modifica ni borra filas de
-- `payments` ni de `tickets`, y no cambia el importe de ningún pago ni el contenido de ningún ticket.
-- Cada cambio va en su propio ALTER TABLE (compatible con MySQL y con TiDB, que no admite referirse a una columna recién
-- agregada, por ejemplo con AFTER, dentro de la misma sentencia). Todos son aditivos: si uno falla, las filas siguen intactas.

-- Refacciones: categoría, marca y precios. Las refacciones existentes quedan con los cuatro campos en NULL;
-- sale_price NULL significa «sin precio de venta» (no se puede agregar a una orden hasta capturarlo).
ALTER TABLE parts ADD COLUMN category VARCHAR(60) NULL AFTER description;
ALTER TABLE parts ADD COLUMN brand VARCHAR(60) NULL AFTER category;
ALTER TABLE parts ADD COLUMN purchase_price DECIMAL(10,2) NULL AFTER min_stock;
ALTER TABLE parts ADD COLUMN sale_price DECIMAL(10,2) NULL AFTER purchase_price;
ALTER TABLE parts ADD CONSTRAINT chk_parts_purchase_price CHECK (purchase_price IS NULL OR purchase_price >= 0);
ALTER TABLE parts ADD CONSTRAINT chk_parts_sale_price CHECK (sale_price IS NULL OR sale_price > 0);

-- Líneas de refacción de la orden: instantánea del precio de venta al agregarlas. Las líneas existentes
-- quedan en 0 (anteriores a los precios) y no suman al total; toda línea nueva guarda un precio mayor a cero.
ALTER TABLE order_parts ADD COLUMN unit_price DECIMAL(10,2) NOT NULL DEFAULT 0 AFTER quantity;
ALTER TABLE order_parts ADD CONSTRAINT chk_order_parts_unit_price CHECK (unit_price >= 0);
