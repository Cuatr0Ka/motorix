# Contrato de la API REST (Sprint 3: historial, mantenimientos e inventario)

**Base**: `/api` | **Formato**: JSON UTF-8 | **Autenticación**: `Authorization: Bearer <token>` en todas
las rutas. Este contrato **amplía** los de `specs/001-base-clientes-vehiculos/contracts/api-rest.md` y
`specs/002-citas-ordenes-servicio/contracts/api-rest.md`; las convenciones de respuesta, paginación y
errores son las mismas.

## Convenciones

- Respuesta exitosa `{ "data": …, "meta?": { "page", "pageSize", "total" } }`; error
  `{ "error": { "code", "message", "details?" } }` con mensajes en español y sin trazas.
- Fechas y horas en ISO 8601; fechas sin hora (`dueDate`) como `YYYY-MM-DD`.
- Tipos de movimiento: `IN` (entrada), `OUT` (salida), `ADJUSTMENT` (ajuste). `quantity` en la
  respuesta lleva signo (entrada positiva, salida negativa, ajuste con la diferencia).
- Indicadores de mantenimiento: `NORMAL`, `PROXIMO`, `VENCIDO`. Estados de seguimiento:
  `PENDIENTE`, `ATENDIDO`.
- Estado de stock de una refacción: `SUFICIENTE`, `BAJO`, `AGOTADO`.

### Códigos de error nuevos

| Estado | Código | Cuándo |
|--------|--------|--------|
| 404 | `NOT_FOUND` | Vehículo, refacción, línea, mantenimiento u orden inexistente, **o una orden que no está asignada al mecánico solicitante** |
| 409 | `PART_CODE_TAKEN` | Ya existe una refacción con ese código |
| 409 | `PART_INACTIVE` | Usar en una orden o registrar una entrada en una refacción desactivada |
| 409 | `INSUFFICIENT_STOCK` | La salida o el aumento supera el stock (`details.available`, `details.requested`) |
| 409 | `ORDER_READ_ONLY` | Modificar refacciones o kilometraje de servicio de una orden Entregada |
| 409 | `ORDER_NOT_FINISHED` | Registrar kilometraje de servicio con la orden fuera de Terminado, o programar mantenimiento con la orden aún no Terminada |
| 409 | `MAINTENANCE_NOT_EDITABLE` | Editar o atender un mantenimiento que ya está Atendido |
| 422 | `NO_ADJUSTMENT_DIFFERENCE` | La cantidad contada es igual al stock actual |
| 422 | `SERVICE_MILEAGE_TOO_LOW` | Kilometraje de servicio menor al de entrada de la orden |
| 422 | `MAINTENANCE_TARGET_REQUIRED` | Mantenimiento sin fecha ni kilometraje objetivo |
| 422 | `MAINTENANCE_DATE_IN_PAST` | Fecha objetivo anterior a hoy |
| 422 | `MAINTENANCE_MILEAGE_TOO_LOW` | Kilometraje objetivo menor o igual al actual del vehículo |

Los errores de formato (cantidad no entera, código inválido, etc.) usan `400 VALIDATION_ERROR` con
`details[]` por campo.

### Matriz de permisos

| Recurso / acción | ADMIN | RECEPTIONIST | MECHANIC |
|------------------|:-----:|:------------:|:--------:|
| Historial de un vehículo: consultar | ✔ | ✔ | ✔ |
| Mantenimientos: lista general con datos del cliente | ✔ | ✔ | ✘ |
| Mantenimientos: programar, editar y marcar Atendido | ✔ | ✘ | ✔ (solo órdenes asignadas) |
| Kilometraje del servicio: registrar | ✔ | ✘ | ✔ (solo órdenes asignadas) |
| Refacciones de la orden: agregar, corregir y quitar | ✔ | ✘ | ✔ (solo órdenes asignadas) |
| Catálogo: consulta reducida (código, nombre, unidad, existencia; solo activas) | ✔ | ✘ | ✔ |
| Catálogo: consulta completa, detalle y movimientos | ✔ | ✘ | ✘ |
| Catálogo: alta, edición, activar y desactivar | ✔ | ✘ | ✘ |
| Entradas y ajustes de inventario | ✔ | ✘ | ✘ |
| Alertas de stock bajo | ✔ | ✘ | ✘ |

## Historial del vehículo (todos los roles)

### `GET /api/vehicles/:id/history?page=&pageSize=`

Órdenes del vehículo en `TERMINADO` o `ENTREGADO`, más reciente primero. `200` con `meta`:

```json
{ "data": {
    "vehicle": { "id": 3, "brand": "…", "model": "…", "year": 2019, "licensePlate": "ABC-123-A", "currentMileage": 84900 },
    "entries": [
      { "orderId": 12, "folio": "OS-000012", "status": "ENTREGADO",
        "serviceDate": "2026-09-20T18:00:00.000Z", "mileage": 84900,
        "reportedProblem": "Ruido al frenar", "diagnosis": "Balatas desgastadas",
        "services": [ { "description": "Cambio de balatas", "amount": "850.00" } ],
        "labor": [ { "description": "Mano de obra frenos", "amount": "400.00" } ],
        "parts": [ { "partId": 4, "code": "BAL-DEL", "name": "Balatas delanteras", "unit": "juego", "quantity": 1 } ],
        "mechanic": { "id": 3, "name": "…" },
        "maintenance": { "id": 5, "description": "Cambio de aceite", "dueDate": "2027-03-20", "dueMileage": 94900,
                         "status": "PENDIENTE", "indicator": "NORMAL" } }
    ],
    "pendingMaintenance": null } ,
  "meta": { "page": 1, "pageSize": 20, "total": 3 } }
```

`mileage` es el kilometraje del servicio si existe y, si no, el de entrada. `maintenance` es el
programado desde esa orden (o `null`); `pendingMaintenance` es el vigente del vehículo.
`404` si el vehículo no existe. Un vehículo sin servicios devuelve `entries: []`.

## Kilometraje del servicio (ADMIN, MECHANIC)

### `PUT /api/orders/:id/service-mileage`

Cuerpo: `{ "serviceMileage": 85400 }`. `200` con el detalle de la orden. Actualiza el kilometraje actual
del vehículo si es mayor. Errores: `409 ORDER_NOT_FINISHED`, `ORDER_READ_ONLY`; `422 SERVICE_MILEAGE_TOO_LOW`;
`400 VALIDATION_ERROR` (no entero, negativo o mayor a 2 000 000); `404` (mecánico no asignado).

## Mantenimientos

Objeto mantenimiento:

```json
{ "id": 5, "description": "Cambio de aceite y filtro", "dueDate": "2027-03-20", "dueMileage": 94900,
  "status": "PENDIENTE", "indicator": "PROXIMO", "attendedAt": null,
  "orderId": 12, "orderFolio": "OS-000012",
  "vehicle": { "id": 3, "brand": "…", "model": "…", "licensePlate": "ABC-123-A", "currentMileage": 94000 },
  "client": { "id": 1, "name": "…", "phone": "…" } }
```

`indicator` es `null` cuando el estado es `ATENDIDO`. Para el mecánico, `client` se omite.

### `POST /api/orders/:id/maintenance` (ADMIN, MECHANIC)

Cuerpo: `{ "description", "dueDate?", "dueMileage?" }` (al menos uno de los dos objetivos).
`201` con el mantenimiento. Marca como `ATENDIDO` el pendiente anterior del vehículo. Errores:
`409 ORDER_NOT_FINISHED` (orden anterior a Terminado); `422 MAINTENANCE_TARGET_REQUIRED`,
`MAINTENANCE_DATE_IN_PAST`, `MAINTENANCE_MILEAGE_TOO_LOW`; `404` (mecánico no asignado).

### `GET /api/maintenance?status=&indicator=&search=&page=&pageSize=` (ADMIN, RECEPTIONIST)

`status` por defecto `PENDIENTE`; `indicator` filtra `NORMAL`, `PROXIMO` o `VENCIDO`; `search` por
cliente o placa. Orden: Vencidos, Próximos y Normales; dentro de cada grupo, por fecha objetivo
ascendente. `200` con lista de mantenimientos y `meta`.

### `PATCH /api/maintenance/:id` (ADMIN, MECHANIC de la orden de origen)

Cuerpo parcial: `{ "description?", "dueDate?", "dueMileage?" }`. Mismas validaciones que al crear.
`200` con el mantenimiento. Errores: `409 MAINTENANCE_NOT_EDITABLE`; `404`.

### `POST /api/maintenance/:id/attend` (ADMIN, MECHANIC de la orden de origen)

Sin cuerpo. `200` con el mantenimiento `ATENDIDO`. Error: `409 MAINTENANCE_NOT_EDITABLE`. La interfaz
pide confirmación.

> No existe `DELETE` para mantenimientos.

## Refacciones (catálogo)

Objeto refacción (ADMIN):

```json
{ "id": 4, "code": "BAL-DEL", "name": "Balatas delanteras", "description": null, "unit": "juego",
  "stock": 6, "minStock": 3, "active": true, "stockStatus": "SUFICIENTE" }
```

Proyección del mecánico: `{ "id", "code", "name", "unit", "stock" }` (solo refacciones activas).

### `GET /api/parts?search=&stockStatus=&active=&page=&pageSize=` (ADMIN, MECHANIC)

`search` por código o nombre. ADMIN: `stockStatus` y `active` opcionales; ordenada por nombre. MECHANIC:
ignora `stockStatus` y `active` y solo recibe activas con la proyección reducida. `200` con `meta`.

### `GET /api/parts/alerts` (ADMIN)

Refacciones activas con `stock <= minStock`, las Agotadas primero. `200`:
`{ "data": { "count": 3, "outOfStock": 1, "items": [ … objeto refacción … ] } }`.

### `POST /api/parts` (ADMIN)

Cuerpo: `{ "code", "name", "description?", "unit", "minStock", "initialStock" }`. `201` con la
refacción; si `initialStock > 0` crea el movimiento `IN` "Stock inicial". Errores: `409 PART_CODE_TAKEN`;
`400 VALIDATION_ERROR`.

### `GET /api/parts/:id` (ADMIN)

`200` con la refacción y sus últimos movimientos; `404`.

### `PATCH /api/parts/:id` (ADMIN)

Cuerpo parcial: `{ "name?", "description?", "unit?", "minStock?", "active?" }`. El código y el stock no
cambian por esta vía. `200` con la refacción. La interfaz pide confirmación para desactivar.

### `GET /api/parts/:id/movements?page=&pageSize=` (ADMIN)

Movimientos, más reciente primero:

```json
{ "id": 31, "type": "OUT", "quantity": -2, "reason": "Uso en OS-000012", "createdAt": "…",
  "order": { "id": 12, "folio": "OS-000012" }, "createdBy": { "id": 3, "name": "…" } }
```

### `POST /api/parts/:id/movements` (ADMIN)

Entrada: `{ "type": "IN", "quantity": 10, "reason?": "Compra a proveedor" }`.
Ajuste: `{ "type": "ADJUSTMENT", "countedQuantity": 7, "reason": "Conteo físico de octubre" }`.
`201` con `{ "movement": {…}, "part": {…} }`. Errores: `409 PART_INACTIVE` (solo en entradas);
`422 NO_ADJUSTMENT_DIFFERENCE`; `400 VALIDATION_ERROR` (tipo `OUT` no permitido por esta vía, motivo
corto, cantidades no enteras). La interfaz pide confirmación para ajustes.

> No existe `DELETE` ni `PUT` para refacciones ni movimientos.

## Refacciones de la orden (ADMIN, MECHANIC)

Línea de refacción de la orden (también incluida como `parts[]` y `serviceMileage` en
`GET /api/orders/:id`, visible para todos los roles que ven la orden):

```json
{ "id": 9, "partId": 4, "code": "BAL-DEL", "name": "Balatas delanteras", "unit": "juego", "quantity": 1 }
```

### `POST /api/orders/:id/parts`

Cuerpo: `{ "partId": 4, "quantity": 2 }`. Suma sobre la línea existente si la hay. Genera el movimiento
`OUT` y descuenta el stock en la misma transacción. `201` con `{ "item": {…}, "part": {…} }`.
Errores: `409 INSUFFICIENT_STOCK`, `PART_INACTIVE`, `ORDER_READ_ONLY`; `404` (orden o refacción);
`400 VALIDATION_ERROR` (cantidad cero, negativa, decimal o no numérica).

### `PATCH /api/orders/:id/parts/:lineId`

Cuerpo: `{ "quantity": 3 }` (cantidad nueva total). Genera `OUT` por el aumento o `IN` ("Devolución")
por la disminución. `200` con `{ "item", "part" }`. Mismos errores que el alta.

### `DELETE /api/orders/:id/parts/:lineId`

Quita la línea y devuelve su cantidad al inventario con un movimiento `IN` ligado a la orden. `200`
con `{ "deleted": true, "part": {…} }`. La interfaz pide confirmación. Error `409 ORDER_READ_ONLY`.

> Este `DELETE` solo elimina la línea de uso (igual que con servicios y mano de obra); los
> movimientos y la orden se conservan.
