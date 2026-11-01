# Contrato de la API REST (Sprint 5: precios de refacciones y cobro completo)

**Base**: `/api` | **Formato**: JSON UTF-8 | **Autenticación**: `Authorization: Bearer <token>` en todas las
rutas. Este contrato **amplía** los de los sprints 1 a 4; las convenciones de respuesta, paginación y errores
son las mismas (`{ data, meta? }` / `{ error: { code, message, details? } }`, mensajes en español y sin trazas).

## Convenciones

- Importes como cadenas decimales con dos decimales (`"180.00"`); en las solicitudes se acepta número o cadena
  decimal. Moneda: pesos mexicanos (MXN).
- Precio máximo y total máximo de una orden: `9999999.99`.
- Una línea de refacción anterior al sprint tiene `unitPrice: "0.00"` y `legacy: true`.

### Códigos de error nuevos

| Estado | Código | Cuándo |
|--------|--------|--------|
| 422 | `PRICE_BELOW_COST` | El precio de venta resultante es menor al de compra y falta `confirmBelowCost: true` (`details.salePrice`, `details.purchasePrice`) |
| 422 | `PART_PRICE_MISSING` | Agregar a una orden una refacción sin precio de venta |
| 422 | `ORDER_TOTAL_LIMIT` | La línea haría pasar el total de la orden de 9 999 999.99 (`details.limit`) |
| 422 | `LEGACY_LINE_LOCKED` | Aumentar la cantidad de una línea anterior al sprint (quitarla y volver a agregarla) |
| 409 | `ORDER_ALREADY_PAID` | Agregar, quitar o cambiar la cantidad de refacciones de una orden con pago Pagado |

Códigos existentes que siguen vigentes: `ORDER_READ_ONLY`, `PART_INACTIVE`, `INSUFFICIENT_STOCK`,
`PAYMENT_ALREADY_EXISTS`, `AMOUNT_MISMATCH`, `ORDER_NOT_PAYABLE`, `NOTHING_TO_CHARGE`. Los errores de formato
(precio negativo, no numérico, con más de dos decimales, venta igual a cero o categoría demasiado larga) usan
`400 VALIDATION_ERROR` con `details[]` por campo.

### Matriz de permisos y visibilidad de precios

| Información | ADMIN | RECEPTIONIST | MECHANIC |
|-------------|:-----:|:------------:|:--------:|
| Crear y editar categoría, marca y precios de una refacción | ✔ | ✘ | ✘ |
| Precio de compra (`purchasePrice`) | ✔ | ✘ | ✘ |
| Precio de venta de la refacción (`salePrice`) | ✔ | ✘ (no accede al catálogo) | ✘ |
| Precio y importe de las líneas de una orden (`unitPrice`, `amount`) | ✔ | ✔ | ✘ |
| Subtotal de refacciones y total con refacciones (`totals.parts`) | ✔ | ✔ | ✘ |
| Bloque de cobro (`billing`) con desglose | ✔ | ✔ | ✘ |
| Agregar, quitar o cambiar refacciones de una orden | ✔ | ✔ | ✔ (solo sus órdenes) |

## Refacciones (`/api/parts`)

### `GET /api/parts` (ADMIN, MECHANIC)

- **ADMIN**: cada ítem agrega `category`, `brand`, `purchasePrice`, `salePrice` y `priceMissing` (verdadero si
  `salePrice` es `null`). Los tres valores de precio son cadenas o `null`.
- **MECHANIC**: sin cambios (`id`, `code`, `name`, `unit`, `stock`, solo activas). **No incluye ningún precio.**
- El parámetro `search` busca también por categoría y marca.

### `GET /api/parts/:id`, `GET /api/parts/alerts` (ADMIN)

Incluyen los campos de precio del administrador, igual que el listado.

### `POST /api/parts` (ADMIN)

Acepta, además de los campos actuales, `category`, `brand`, `purchasePrice`, `salePrice` y `confirmBelowCost`
(todos opcionales). Respuestas: `201` con la refacción; `400 VALIDATION_ERROR`; `422 PRICE_BELOW_COST`.

```json
{ "code": "FIL-ACE", "name": "Filtro de aceite", "unit": "pieza", "minStock": 5, "initialStock": 10,
  "category": "Filtros", "brand": "Mann", "purchasePrice": "120.00", "salePrice": "180.00" }
```

### `PATCH /api/parts/:id` (ADMIN)

Acepta los mismos campos nuevos en edición parcial. Un precio de venta capturado no puede enviarse como `null`.
Cuando el cuerpo trae `salePrice` o `purchasePrice` y el precio de venta resultante (el enviado o el vigente) es menor al de compra resultante y falta
`confirmBelowCost: true`, responde `422 PRICE_BELOW_COST` y no guarda nada. Si el cuerpo no trae ningún precio (por ejemplo, solo cambia
el nombre), no se exige la confirmación aunque la refacción ya esté bajo el costo.

## Refacciones de la orden (`/api/orders/:id/parts`)

### `GET /api/orders/:id` → `data.parts[]` y `data.totals`

| Rol | Cada línea | `totals` |
|-----|-----------|----------|
| ADMIN, RECEPTIONIST | `id`, `partId`, `code`, `name`, `unit`, `quantity`, `unitPrice`, `amount`, `legacy` | `services`, `labor`, `parts`, `total` |
| MECHANIC | `id`, `partId`, `code`, `name`, `unit`, `quantity` | `services`, `labor`, `total` (solo servicios y mano de obra; sin `parts`) |

### `POST /api/orders/:id/parts` (todos los roles de trabajo)

Cuerpo: `{ partId, quantity }`. Reglas, en este orden: orden Entregada (`409 ORDER_READ_ONLY`); pago Pagado
(`409 ORDER_ALREADY_PAID`); refacción desactivada (`409 PART_INACTIVE`); sin precio de venta
(`422 PART_PRICE_MISSING`); stock insuficiente (`409 INSUFFICIENT_STOCK`); tope del total
(`422 ORDER_TOTAL_LIMIT`). La línea guarda el `sale_price` vigente. Si la refacción ya está en la orden, la
cantidad se suma a esa línea y esta conserva su precio guardado; si la línea es anterior (`legacy`), responde
`422 LEGACY_LINE_LOCKED`. La respuesta sigue la proyección de la tabla anterior según el rol.

### `PATCH /api/orders/:id/parts/:lineId` (todos los roles de trabajo)

Cuerpo: `{ quantity }`. Disminuir se permite siempre que la orden no esté Entregada ni tenga pago Pagado.
Aumentar aplica las reglas del alta (`ORDER_TOTAL_LIMIT`, `LEGACY_LINE_LOCKED`, `INSUFFICIENT_STOCK`). El precio
de la línea no cambia.

### `DELETE /api/orders/:id/parts/:lineId` (todos los roles de trabajo)

Sin cambios, salvo `409 ORDER_ALREADY_PAID` si la orden tiene un pago Pagado.

## Cobro (`/api/orders/:id/payments`, `billing`; ADMIN, RECEPTIONIST)

### Bloque `billing` en `GET /api/orders/:id`

Se agregan el desglose y la diferencia por cobrar:

```json
{ "billing": {
    "total": "1160.00", "paidAmount": "0.00", "collectionStatus": "SIN_COBRAR",
    "amountOutdated": false, "amountDifference": "0.00", "canCharge": true,
    "breakdown": {
      "services": [ { "id": 3, "description": "Cambio de aceite", "amount": "500.00" } ],
      "labor":    [ { "id": 2, "description": "Mano de obra", "amount": "300.00" } ],
      "parts":    [ { "id": 5, "code": "FIL-ACE", "name": "Filtro de aceite", "unit": "pieza",
                      "quantity": 2, "unitPrice": "180.00", "amount": "360.00", "legacy": false } ],
      "subtotals": { "services": "500.00", "labor": "300.00", "parts": "360.00" }
    },
    "payments": [], "ticket": null } }
```

- `total` ya incluye las refacciones. `canCharge` es verdadero si la orden está Terminada o Entregada, el total es
  mayor a cero (una orden con solo refacciones es cobrable) y no hay pago vigente.
- `amountDifference` es el total vigente menos el pago Pagado cuando difieren (por ejemplo, tras una aprobación
  tardía de Mercado Pago); `"0.00"` en otro caso. No se crea ni se cobra la diferencia.
- Las líneas anteriores aparecen con `legacy: true` y `amount: "0.00"` en el desglose.

### `POST /api/orders/:id/payments`

El pago se registra por el **total calculado al registrar** (con refacciones). Un `amount` distinto responde
`422 AMOUNT_MISMATCH` con `details.total`. Una orden sin servicios ni mano de obra pero con refacciones con
precio es cobrable; el total cero responde `422 NOTHING_TO_CHARGE` (mensaje: «La orden no tiene nada que cobrar:
el total es cero.»). Si ya hay un pago pendiente, `409 PAYMENT_ALREADY_EXISTS` agrega `details.outdated: true`
cuando su importe ya no coincide con el total. Mercado Pago recibe el importe con refacciones.

### `POST /api/payments/:id/refresh` y `POST /api/payments/:id/cancel`

Sin cambios de forma. Un pago pendiente y desfasado que el proveedor reporta aprobado pasa a `PAGADO` con su
importe original; `billing.amountDifference` muestra la diferencia. Cancelar un pago pendiente sigue siendo de
recepción y administración.

## Tickets (`/api/orders/:id/ticket`, `/api/tickets`; ADMIN, RECEPTIONIST)

El contenido del ticket nuevo es la versión 2 (ver [data-model.md](../data-model.md)): `formatVersion: 2`,
`parts[].unitPrice` y `parts[].amount`, y `totals.parts`. `totals.total` es el importe del pago registrado. Los
tickets anteriores se devuelven tal como se emitieron (sin `formatVersion`).

## Sin cambios

- Panel de control (`/api/dashboard`): sus importes salen de los pagos registrados y no agrega indicadores.
- Historial del vehículo, mantenimientos e inventario (movimientos): no exponen precios.
- Autenticación y usuarios.
