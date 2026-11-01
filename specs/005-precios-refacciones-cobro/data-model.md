# Modelo de datos: Precios de refacciones y cobro completo (Sprint 5)

Cambios sobre el modelo de los sprints 1 a 4. No se crean tablas nuevas; todo el cambio de esquema va en la
migración `database/migrations/005_sprint5_part_prices.sql`, aditiva y sin tocar los scripts anteriores.

## Cambios en `parts` (Refacción)

| Columna | Tipo | Nulo | Regla |
|---------|------|------|-------|
| `category` | `VARCHAR(60)` | sí | Texto libre; sin catálogo (spec FR-001) |
| `brand` | `VARCHAR(60)` | sí | Texto libre |
| `purchase_price` | `DECIMAL(10,2)` | sí | `CHECK (purchase_price IS NULL OR purchase_price >= 0)`; opcional |
| `sale_price` | `DECIMAL(10,2)` | sí | `CHECK (sale_price IS NULL OR sale_price > 0)`; `NULL` = «sin precio de venta» |

- Las refacciones existentes quedan con los cuatro campos en `NULL` (FR-015).
- Tope de 9 999 999.99 por el tipo y por la validación del servidor (FR-002).
- El precio de compra solo se selecciona en las rutas de refacciones del administrador (FR-013).
- Regla derivada `priceMissing = sale_price IS NULL`; se expone para la etiqueta del inventario.
- Una vez capturado, un precio de venta no puede borrarse (`null`), solo cambiarse.

## Cambios en `order_parts` (Línea de refacción de la orden)

| Columna | Tipo | Nulo | Regla |
|---------|------|------|-------|
| `unit_price` | `DECIMAL(10,2)` | no, por omisión `0` | `CHECK (unit_price >= 0)`; instantánea del precio de venta |

- Las líneas existentes reciben `0` por la migración (D-03 de la especificación): no suman al total.
- Toda línea nueva se inserta con el `sale_price` de la refacción en ese momento (siempre mayor a cero).
- `unit_price = 0` equivale a «línea anterior al sprint». No hay otra forma de que sea cero.
- La llave única `(order_id, part_id)` se conserva: una sola línea por refacción y orden.
- El precio de una línea no se edita (FR-024): para corregirlo se quita la línea y se vuelve a agregar.

## Valores derivados (no se guardan)

| Valor | Cálculo |
|-------|---------|
| Importe de una línea | `quantity × unit_price`, en centavos enteros (cantidad entera por dos decimales: sin redondeo) |
| Subtotal de refacciones | suma de los importes de las líneas |
| Total de la orden | servicios + mano de obra + refacciones |
| Total vigente | total de la orden calculado al registrar el pago |
| Diferencia por cobrar | total vigente − importe del pago Pagado (solo si difieren) |
| Pago desfasado | pago vigente cuyo importe ≠ total vigente |

## Reglas de validación

| Regla | Dónde se aplica |
|-------|-----------------|
| Precios numéricos, no negativos, a lo sumo dos decimales y ≤ 9 999 999.99 | `zod` y tipo de columna |
| Precio de venta > 0; precio de compra ≥ 0 u omitido | `zod` y restricciones `CHECK` |
| Categoría y marca ≤ 60 caracteres | `zod` y tipo de columna |
| Precio de venta < precio de compra exige `confirmBelowCost: true` | `partService` (`422 PRICE_BELOW_COST`) |
| Solo el administrador crea o edita precios | `authorize` en las rutas |
| No agregar una refacción sin precio de venta | `orderPartService` (`422 PART_PRICE_MISSING`) |
| Total de la orden ≤ 9 999 999.99 al agregar o aumentar | `orderTotals` (`422 ORDER_TOTAL_LIMIT`) |
| No aumentar la cantidad de una línea anterior (precio 0) | `orderPartService` (`422 LEGACY_LINE_LOCKED`) |
| No cambiar refacciones con un pago Pagado | `orderPartService` (`409 ORDER_ALREADY_PAID`) |
| No cambiar refacciones de una orden Entregada | regla existente (`409 ORDER_READ_ONLY`) |

## Matriz de edición de refacciones de una orden

| Estado de la orden | Pago vigente | ¿Agregar, quitar o cambiar cantidad? |
|--------------------|--------------|--------------------------------------|
| Recibido a Terminado | ninguno | Sí |
| Recibido a Terminado | Pendiente | Sí; el pago queda desfasado (FR-012) |
| Terminado | Pagado | No (`ORDER_ALREADY_PAID`) |
| Entregado | cualquiera | No (`ORDER_READ_ONLY`) |

Disminuir la cantidad de una línea anterior (precio 0) y quitarla están permitidos (con las reglas de arriba).

## Contenido del ticket (instantánea JSON, versión 2)

El contenido sigue en `tickets.content`; no cambia el esquema. Los tickets anteriores no tienen `formatVersion`
y se tratan como versión 1.

```json
{
  "formatVersion": 2,
  "parts": [ { "code": "FIL-ACE", "name": "Filtro de aceite", "unit": "pieza",
               "quantity": 2, "unitPrice": "180.00", "amount": "360.00" } ],
  "totals": { "services": "500.00", "labor": "300.00", "parts": "360.00", "total": "1160.00" }
}
```

- `totals.total` es el importe del pago registrado; no se recalcula al generar el ticket.
- Las líneas anteriores al sprint (precio 0) aparecen con `unitPrice` y `amount` en `"0.00"`.
- El resto del contenido (taller, cliente, vehículo, servicios, mano de obra, pago y fecha) no cambia.

## Relaciones

Sin relaciones nuevas. `order_parts.part_id` sigue apuntando a `parts.id` con `ON DELETE RESTRICT`; el precio
de la línea no depende de la refacción después de guardado.

## Datos de ejemplo (seed `005_part_prices.sql`)

- Categoría, marca y precios para las refacciones del seed 003, excepto `BOM-AGU` (queda sin precio de venta).
- Líneas con precio en una orden Terminada sin pago (orden cobrable con refacciones).
- Líneas con precio en la orden del pago de Mercado Pago pendiente (pago desfasado).
- Las líneas anteriores y los pagos y tickets del seed 004 no se modifican.
- Clave natural de las líneas: `(orden, refacción)`; repetir el seed no duplica.
