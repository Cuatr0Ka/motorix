# Contrato de la API REST (Sprint 2: citas y órdenes de servicio)

**Base**: `/api` | **Formato**: JSON UTF-8 | **Autenticación**: `Authorization: Bearer <token>` en todas
las rutas. Este contrato **amplía** el de `specs/001-base-clientes-vehiculos/contracts/api-rest.md`; las
convenciones de respuesta, paginación y errores son las mismas.

## Convenciones

- Respuesta exitosa `{ "data": …, "meta?": { "page", "pageSize", "total" } }`; error
  `{ "error": { "code", "message", "details?" } }` con mensajes en español y sin trazas.
- Fechas en ISO 8601 (por ejemplo `2026-10-12T15:30:00.000Z`). Importes como cadenas decimales con dos
  decimales (`"1250.00"`).
- Estados de cita: `PENDIENTE`, `CONFIRMADA`, `EN_PROCESO`, `COMPLETADA`, `CANCELADA`.
- Estados de orden: `RECIBIDO`, `DIAGNOSTICO`, `EN_REPARACION`, `ESPERANDO_REFACCION`, `TERMINADO`,
  `ENTREGADO`.
- Folio de orden: `OS-000012` (derivado del identificador).

### Códigos de error nuevos

| Estado | Código | Cuándo |
|--------|--------|--------|
| 404 | `NOT_FOUND` | Cita u orden inexistente, **o una orden que no está asignada al mecánico solicitante** |
| 409 | `APPOINTMENT_SLOT_TAKEN` | El vehículo ya tiene una cita activa en esa fecha y hora |
| 409 | `APPOINTMENT_NOT_EDITABLE` | Modificar, confirmar o cancelar una cita que no está Pendiente o Confirmada |
| 409 | `APPOINTMENT_NOT_AVAILABLE` | Crear una orden desde una cita cancelada, completada, en proceso o que ya tiene orden |
| 409 | `OPEN_ORDER_EXISTS` | El vehículo ya tiene una orden abierta (`details.orderId`, `details.folio`) |
| 409 | `ORDER_NOT_ASSIGNABLE` | Asignar o reasignar una orden Terminada o Entregada |
| 409 | `ORDER_READ_ONLY` | Modificar una orden Entregada (datos, trabajo, asignación o estado) |
| 409 | `STATE_CONFLICT` | El estado cambió mientras se intentaba la transición (`details.currentStatus`) |
| 422 | `APPOINTMENT_IN_PAST` | Fecha y hora de cita anteriores al momento actual |
| 422 | `VEHICLE_CLIENT_MISMATCH` | El vehículo no pertenece al cliente indicado |
| 422 | `VEHICLE_NOT_FOUND` | Cliente o vehículo inexistente al crear cita u orden |
| 422 | `MILEAGE_DECREASE` | Kilometraje de entrada menor al actual del vehículo sin corrección explícita |
| 422 | `MECHANIC_INVALID` | El usuario indicado no existe, está inactivo o no es mecánico |
| 422 | `INVALID_TRANSITION` | Transición fuera de la secuencia (`details.currentStatus`, `details.allowed[]`) |
| 422 | `ORDER_UNASSIGNED` | Intentar avanzar una orden sin mecánico asignado |

### Matriz de permisos

| Recurso / acción | ADMIN | RECEPTIONIST | MECHANIC |
|------------------|:-----:|:------------:|:--------:|
| Citas: listar, ver, crear, modificar, confirmar, cancelar | ✔ | ✔ | ✘ |
| Mecánicos asignables: listar | ✔ | ✔ | ✘ |
| Órdenes: listar todas y ver cualquiera | ✔ | ✔ | ✘ (solo las suyas) |
| Órdenes: crear | ✔ | ✔ | ✘ |
| Órdenes: asignar o reasignar mecánico | ✔ | ✔ | ✘ |
| Órdenes: registrar diagnóstico, observaciones, recomendaciones, servicios y mano de obra | ✔ | ✘ | ✔ (solo asignadas a él) |
| Órdenes: cambiar estado hasta TERMINADO | ✔ | ✘ | ✔ (solo asignadas a él) |
| Órdenes: pasar a ENTREGADO | ✔ | ✔ | ✘ |

## Mecánicos asignables (ADMIN, RECEPTIONIST)

### `GET /api/mechanics`

`200`: `{ id, name, username }[]` de usuarios activos con rol `MECHANIC`, ordenados por nombre.

## Citas (ADMIN, RECEPTIONIST)

Objeto cita:

```json
{ "id": 7, "status": "PENDIENTE", "scheduledAt": "2026-10-12T15:30:00.000Z",
  "reason": "Servicio de 50 000 km", "notes": null, "cancelReason": null, "cancelledAt": null,
  "client": { "id": 1, "name": "…", "phone": "…" },
  "vehicle": { "id": 3, "brand": "…", "model": "…", "year": 2019, "licensePlate": "ABC-123-A" },
  "order": null }
```

`order` es `{ "id", "folio", "status" }` cuando la cita originó una orden.

### `GET /api/appointments?search=&status=&from=&to=&page=&pageSize=`

`search` filtra por nombre del cliente o placa; `from` y `to` (ISO 8601) acotan `scheduledAt`.
`200`: lista de citas ordenada por fecha ascendente, con `meta`.

### `POST /api/appointments`

Cuerpo: `{ "clientId", "vehicleId", "scheduledAt", "reason", "notes?" }`.

- `201`: cita en estado `PENDIENTE`.
- `400 VALIDATION_ERROR`; `422 VEHICLE_NOT_FOUND`, `VEHICLE_CLIENT_MISMATCH`, `APPOINTMENT_IN_PAST`;
  `409 APPOINTMENT_SLOT_TAKEN`.

### `GET /api/appointments/:id` — `200` con la cita; `404`.

### `PATCH /api/appointments/:id`

Cuerpo parcial: `{ "scheduledAt?", "reason?", "notes?" }` (el cliente y el vehículo no cambian).
`200` con la cita. Errores: `409 APPOINTMENT_NOT_EDITABLE`, `APPOINTMENT_SLOT_TAKEN`;
`422 APPOINTMENT_IN_PAST`.

### `POST /api/appointments/:id/confirm`

Sin cuerpo. `200` con la cita `CONFIRMADA`. Solo desde `PENDIENTE`; si no, `409 APPOINTMENT_NOT_EDITABLE`.

### `POST /api/appointments/:id/cancel`

Cuerpo opcional: `{ "reason?" }` (hasta 255 caracteres). `200` con la cita `CANCELADA`. Solo desde
`PENDIENTE` o `CONFIRMADA`; si no, `409 APPOINTMENT_NOT_EDITABLE`. La interfaz pide confirmación.

> No existe `DELETE` para citas.

## Órdenes de servicio

Resumen de orden (listados):

```json
{ "id": 12, "folio": "OS-000012", "status": "DIAGNOSTICO", "reportedProblem": "Ruido al frenar",
  "entryMileage": 84500, "createdAt": "2026-10-10T14:00:00.000Z",
  "client": { "id": 1, "name": "…" },
  "vehicle": { "id": 3, "brand": "…", "model": "…", "licensePlate": "ABC-123-A" },
  "mechanic": { "id": 3, "name": "…" } }
```

`mechanic` es `null` si no hay asignación. Detalle de orden (`GET /api/orders/:id`): el resumen más

```json
{ "diagnosis": null, "observations": null, "recommendations": null,
  "mileageCorrection": false, "mileageCorrectionReason": null,
  "appointment": { "id": 7, "status": "EN_PROCESO" },
  "services": [ { "id": 1, "description": "Cambio de balatas", "amount": "850.00" } ],
  "labor": [ { "id": 1, "description": "Mano de obra frenos", "amount": "400.00" } ],
  "totals": { "services": "850.00", "labor": "400.00", "total": "1250.00" },
  "allowedTransitions": ["EN_REPARACION", "ESPERANDO_REFACCION"],
  "statusHistory": [ { "fromStatus": null, "toStatus": "RECIBIDO", "changedBy": { "id": 2, "name": "…" }, "changedAt": "…" } ],
  "deliveredAt": null }
```

`allowedTransitions` ya filtra por el rol y la pertenencia de quien consulta, y por tanto la
interfaz no necesita duplicar la regla.

### `GET /api/orders?search=&status=&mechanicId=&page=&pageSize=`

- ADMIN y RECEPTIONIST: todas las órdenes; filtros `status` y `mechanicId` opcionales; `search`
  por folio (`OS-12`, `12`), cliente o placa. Orden: más recientes primero.
- MECHANIC: solo las asignadas a él (`mechanicId` se ignora). Sin `status`, excluye `ENTREGADO`;
  con `status=ENTREGADO` las muestra.
- `200`: lista de resúmenes con `meta`.

### `POST /api/orders` (ADMIN, RECEPTIONIST)

Cuerpo (directa): `{ "vehicleId", "entryMileage", "reportedProblem", "mechanicId?", "mileageCorrection?", "mileageCorrectionReason?" }`

Cuerpo (desde cita): `{ "appointmentId", "entryMileage", "reportedProblem?", "mechanicId?", "mileageCorrection?", "mileageCorrectionReason?" }`
— toma cliente y vehículo de la cita y, si se omite, el problema reportado es el motivo de la cita.
Debe enviarse `vehicleId` o `appointmentId` (no ambos).

- `201`: detalle de la orden en `RECIBIDO`; actualiza el kilometraje del vehículo y, si viene de una
  cita, la pasa a `EN_PROCESO`.
- `400 VALIDATION_ERROR` (por ejemplo, kilometraje ausente o corrección sin motivo).
- `422 VEHICLE_NOT_FOUND`, `MILEAGE_DECREASE`, `MECHANIC_INVALID`.
- `409 OPEN_ORDER_EXISTS`, `APPOINTMENT_NOT_AVAILABLE`.

### `GET /api/orders/:id`

`200` con el detalle. Un mecánico que pide una orden ajena recibe `404 NOT_FOUND`.

### `PUT /api/orders/:id/mechanic` (ADMIN, RECEPTIONIST)

Cuerpo: `{ "mechanicId": 3 }` (el valor `null` quita la asignación mientras la orden siga en
`RECIBIDO`). `200` con el detalle. Errores: `422 MECHANIC_INVALID`; `409 ORDER_NOT_ASSIGNABLE`
(Terminada o Entregada), `ORDER_READ_ONLY` (Entregada).

### `PATCH /api/orders/:id/work` (ADMIN, mecánico asignado)

Cuerpo parcial: `{ "diagnosis?", "observations?", "recommendations?" }` (texto o `null`). `200` con el
detalle. Errores: `409 ORDER_READ_ONLY`; `404` si la orden no es del mecánico.

### Servicios realizados (ADMIN, mecánico asignado)

- `POST /api/orders/:id/services` — `{ "description", "amount" }` → `201` con la línea creada.
- `PATCH /api/orders/:id/services/:serviceId` — cuerpo parcial → `200` con la línea.
- `DELETE /api/orders/:id/services/:serviceId` — `200` con `{ "deleted": true }`.

La respuesta de cada operación incluye `totals` recalculados: `{ "data": { "item": {…}, "totals": {…} } }`
(en `DELETE`, solo `deleted` y `totals`). Errores: `400`, `404`, `409 ORDER_READ_ONLY`.

### Mano de obra (ADMIN, mecánico asignado)

Mismas operaciones y formas en `/api/orders/:id/labor` y `/api/orders/:id/labor/:laborId`.

### `POST /api/orders/:id/status`

Cuerpo: `{ "status": "DIAGNOSTICO" }`.

- `200`: detalle de la orden con el nuevo estado y un registro más en `statusHistory`. Si pasa a
  `TERMINADO` y viene de una cita, la cita pasa a `COMPLETADA`.
- Autorización: hasta `TERMINADO`, ADMIN o mecánico asignado; a `ENTREGADO`, ADMIN o RECEPTIONIST.
  Rol sin permiso: `403 FORBIDDEN`. Mecánico con orden ajena: `404 NOT_FOUND`.
- `422 INVALID_TRANSITION` con `details.currentStatus` y `details.allowed[]`; `422 ORDER_UNASSIGNED`
  si la orden sin mecánico intenta salir de `RECIBIDO`; `409 ORDER_READ_ONLY` (Entregada);
  `409 STATE_CONFLICT` si el estado cambió durante la operación.

> No existe `DELETE /api/orders/:id`: las órdenes se conservan (RN-9).

## Pruebas de contrato

Cada endpoint tiene al menos una prueba que verifica la forma de la respuesta exitosa, un error de
validación o de regla de negocio, y el rechazo `401` sin token y `403` (o `404` para pertenencia) para
un rol no autorizado. Se agregan además pruebas unitarias de la tabla de transiciones. Viven en
`server/tests/contract/`, `server/tests/integration/` y `server/tests/unit/`, y se ejecutan contra
`motorix_test`.
