# Contrato de la API REST (Sprint 4: pagos, tickets y panel de control)

**Base**: `/api` | **Formato**: JSON UTF-8 | **Autenticación**: `Authorization: Bearer <token>` en todas las
rutas. Este contrato **amplía** los de los sprints 1 a 3; las convenciones de respuesta, paginación y
errores son las mismas (`{ data, meta? }` / `{ error: { code, message, details? } }`, mensajes en español y
sin trazas).

## Convenciones

- Importes como cadenas decimales con dos decimales (`"1250.00"`); en las solicitudes se aceptan número o
  cadena decimal.
- Métodos de pago: `EFECTIVO`, `TARJETA`, `TRANSFERENCIA`, `MERCADO_PAGO`.
- Estados de pago: `PENDIENTE`, `PAGADO`, `RECHAZADO`, `CANCELADO`.
- Estado de cobro de una orden (`collectionStatus`): `SIN_COBRAR`, `PENDIENTE`, `PAGADO`.
- Folio de ticket: `TK-000012` (derivado del identificador).
- Ninguna respuesta incluye datos de tarjeta, el token de Mercado Pago ni cuerpos crudos del proveedor.

### Códigos de error nuevos

| Estado | Código | Cuándo |
|--------|--------|--------|
| 404 | `NOT_FOUND` | Orden, pago o ticket inexistente |
| 409 | `ORDER_NOT_PAYABLE` | Cobrar una orden que no está Terminada ni Entregada |
| 409 | `PAYMENT_ALREADY_EXISTS` | La orden ya tiene un pago vigente (Pendiente o Pagado), incluso por solicitudes simultáneas (`details.paymentId`, `details.status`) |
| 409 | `PAYMENT_NOT_CANCELLABLE` | Cancelar un pago que no está Pendiente |
| 409 | `TICKET_REQUIRES_PAYMENT` | Generar el ticket de una orden sin pago Pagado |
| 422 | `NOTHING_TO_CHARGE` | La orden tiene total cero |
| 422 | `AMOUNT_MISMATCH` | El importe enviado no es igual al total vigente (`details.total`) |
| 502 | `PROVIDER_ERROR` | Mercado Pago falló o no respondió; no queda pago a medias |
| 503 | `PROVIDER_NOT_CONFIGURED` | Faltan las credenciales de Mercado Pago |

Los errores de formato (método desconocido, importe no numérico, referencia que parece número de tarjeta,
etc.) usan `400 VALIDATION_ERROR` con `details[]` por campo.

### Matriz de permisos

| Recurso / acción | ADMIN | RECEPTIONIST | MECHANIC |
|------------------|:-----:|:------------:|:--------:|
| Bloque de cobro en el detalle de la orden (`billing`) | ✔ | ✔ | ✘ (no se incluye) |
| Pagos: listar, ver, registrar, consultar estado y cancelar | ✔ | ✔ | ✘ |
| Métodos de pago disponibles | ✔ | ✔ | ✘ |
| Tickets: generar, ver y listar | ✔ | ✔ | ✘ |
| Panel de control | ✔ | ✘ | ✘ |

## Cobro de una orden (ADMIN, RECEPTIONIST)

### Bloque `billing` en `GET /api/orders/:id`

Para ADMIN y RECEPTIONIST el detalle de la orden añade:

```json
{ "billing": {
    "total": "1250.00", "paidAmount": "1250.00", "collectionStatus": "PAGADO",
    "amountOutdated": false, "canCharge": false,
    "payments": [ { …objeto pago… } ],
    "ticket": { "id": 4, "folio": "TK-000004" } } }
```

`canCharge` es verdadero si la orden está Terminada o Entregada, el total es mayor a cero y no hay pago
vigente. `amountOutdated` es verdadero si el total actual difiere del importe del pago vigente.

### `GET /api/payments/methods`

`200`: `{ "methods": [ { "method": "EFECTIVO", "available": true }, …, { "method": "MERCADO_PAGO", "available": false,
"reason": "Mercado Pago no está configurado." } ] }`. Permite a la interfaz deshabilitar Mercado Pago.

### `POST /api/orders/:id/payments`

Cuerpo: `{ "method", "amount?", "reference?" }`. El importe cobrado siempre es el total vigente de la orden;
si se envía `amount` debe coincidir.

- Efectivo, tarjeta y transferencia → `201` con el pago en estado `PAGADO`.
- `MERCADO_PAGO` → `201` con el pago `PENDIENTE` y su `checkoutUrl`.
- Errores: `400 VALIDATION_ERROR`; `404`; `409 ORDER_NOT_PAYABLE`, `PAYMENT_ALREADY_EXISTS`;
  `422 NOTHING_TO_CHARGE`, `AMOUNT_MISMATCH`; `502 PROVIDER_ERROR`, `503 PROVIDER_NOT_CONFIGURED` (solo
  Mercado Pago).

Objeto pago:

```json
{ "id": 7, "orderId": 12, "orderFolio": "OS-000012", "amount": "1250.00", "method": "MERCADO_PAGO",
  "status": "PENDIENTE", "reference": null, "externalPaymentId": null,
  "checkoutUrl": "https://sandbox.mercadopago.com.mx/…", "lastCheckedAt": null, "paidAt": null,
  "createdAt": "2026-10-11T15:00:00.000Z", "createdBy": { "id": 2, "name": "…" },
  "client": { "id": 1, "name": "…" }, "vehicle": { "id": 3, "licensePlate": "ABC-123-A" } }
```

`checkoutUrl` solo existe en pagos de Mercado Pago; `client` y `vehicle` aparecen en los listados.

### `GET /api/orders/:id/payments`

`200`: lista de pagos de la orden, del más reciente al más antiguo (todos los estados).

### `GET /api/payments?status=&method=&search=&page=&pageSize=`

`search` por folio de la orden, cliente o placa. `200`: lista paginada con `meta`, del más reciente al más
antiguo.

### `GET /api/payments/:id` — `200` con el pago; `404`.

### `POST /api/payments/:id/refresh`

Sin cuerpo. Consulta a Mercado Pago el estado de un pago `PENDIENTE` y lo actualiza (`PAGADO`, `RECHAZADO` o
sigue `PENDIENTE`, siempre con `lastCheckedAt`). Un pago ya resuelto (o no de Mercado Pago) responde `200` sin
cambios. Errores: `502 PROVIDER_ERROR`, `503 PROVIDER_NOT_CONFIGURED`; `404`.

### `POST /api/payments/:id/cancel`

Sin cuerpo (la interfaz pide confirmación). `200` con el pago `CANCELADO`. Solo desde `PENDIENTE`; si no,
`409 PAYMENT_NOT_CANCELLABLE`.

> No existen `DELETE` ni `PUT`/`PATCH` para pagos.

## Tickets (ADMIN, RECEPTIONIST)

Objeto ticket:

```json
{ "id": 4, "folio": "TK-000004", "orderId": 12, "orderFolio": "OS-000012", "paymentId": 7,
  "generatedAt": "2026-10-11T15:10:00.000Z", "generatedBy": { "id": 2, "name": "…" },
  "content": { "shop": { "name": "…", "address": "…", "phone": "…" },
               "customer": { "name": "…", "phone": "…" },
               "vehicle": { "plate": "ABC-123-A", "brand": "…", "model": "…", "year": 2019, "mileage": 84500 },
               "order": { "folio": "OS-000012", "entryMileage": 84500, "serviceMileage": 84620 },
               "services": [ { "description": "…", "amount": "850.00" } ],
               "parts": [ { "code": "BAL-DEL", "name": "…", "unit": "juego", "quantity": 1 } ],
               "labor": [ { "description": "…", "amount": "400.00" } ],
               "totals": { "services": "850.00", "labor": "400.00", "total": "1250.00" },
               "payment": { "method": "EFECTIVO", "status": "PAGADO", "paidAt": "…", "reference": null },
               "generatedAt": "…" } }
```

En los listados `content` se omite.

### `POST /api/orders/:id/ticket`

Sin cuerpo. Genera el ticket de la orden: `201` con `{ "ticket": {…}, "created": true }`. Si la orden ya tiene
ticket: `200` con `{ "ticket": {…}, "created": false }` (no se crea otro). Errores: `404`;
`409 TICKET_REQUIRES_PAYMENT`.

### `GET /api/orders/:id/ticket` — `200` con el ticket de la orden; `404` si no tiene.

### `GET /api/tickets?search=&page=&pageSize=`

reciente al más antiguo. Cada elemento trae los datos del ticket sin su contenido, más `client.name`, `vehicle.licensePlate` y `total` (importe total de la instantánea, o `null` si no estuviera disponible).
reciente al más antiguo.

### `GET /api/tickets/:id` — `200` con el ticket completo; `404`.

> No existen `DELETE` ni `PUT`/`PATCH` para tickets.

## Panel de control (solo ADMIN)

### `GET /api/dashboard`

`200`:

```json
{ "data": {
    "generatedAt": "2026-10-11T15:20:00.000Z",
    "orders": { "attendedLast30Days": 6, "inRepair": 2, "pending": 4, "finishedAwaitingDelivery": 1 },
    "appointments": { "upcoming": 3 },
    "maintenance": { "upcoming": 2, "overdue": 2 },
    "inventory": { "lowStock": 5, "outOfStock": 2 },
    "payments": { "ordersAwaitingPayment": 1, "pendingMercadoPago": 1 },
    "recentActivity": {
      "orderChanges": [ { "orderId": 12, "folio": "OS-000012", "toStatus": "TERMINADO", "changedBy": "…", "changedAt": "…" } ],
      "payments": [ { "id": 7, "orderFolio": "OS-000012", "amount": "1250.00", "method": "EFECTIVO", "status": "PAGADO", "createdAt": "…" } ],
      "inventoryMovements": [ { "id": 31, "partCode": "ACE-5W30", "type": "OUT", "quantity": -4, "createdAt": "…" } ] } } }
```

Definiciones (mismo criterio que los listados): `attendedLast30Days` = vehículos distintos con orden
Entregada en los últimos 30 días; `inRepair` = órdenes En reparación o Esperando refacción; `pending` =
órdenes que no están Terminadas ni Entregadas; `finishedAwaitingDelivery` = órdenes Terminadas;
`appointments.upcoming` = citas Pendientes o Confirmadas en los próximos 7 días; `maintenance.*` = total de
la lista de Mantenimientos con ese indicador; `inventory.*` = alertas de stock bajo y agotadas;
`ordersAwaitingPayment` = órdenes Terminadas sin pago Pagado; `pendingMercadoPago` = pagos Pendientes.
Cada lista de actividad trae como máximo 5 elementos, del más reciente al más antiguo.
