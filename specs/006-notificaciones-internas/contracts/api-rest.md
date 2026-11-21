# Contrato de la API REST (Sprint 6: notificaciones internas y clientes por avisar)

**Base**: `/api` | **Formato**: JSON UTF-8 | **Autenticación**: `Authorization: Bearer <token>` en todas las
rutas. Este contrato **amplía** los de los sprints 1 a 5; las convenciones de respuesta y errores son las mismas
(`{ data, meta? }` / `{ error: { code, message, details? } }`, mensajes en español y sin trazas). No hay rutas
`DELETE`: ni las lecturas ni los avisos a clientes se deshacen.

## Convenciones

- Fechas de calendario como `YYYY-MM-DD`; fechas con hora como ISO 8601.
- `type` de un aviso: `MAINT_UPCOMING`, `MAINT_OVERDUE`, `APPT_TODAY`, `STOCK_LOW`, `STOCK_OUT`, `STALLED`.
- `reason` de un cliente por avisar: `ORDER_READY`, `APPT_TOMORROW`, `MAINT_UPCOMING`, `MAINT_OVERDUE`.
- Ningún endpoint de este sprint envía mensajes al cliente.

### Códigos de error nuevos

| Estado | Código | Cuándo |
|--------|--------|--------|
| 409 | `NOTICE_NOT_APPLICABLE` | Se intenta marcar como avisado un hecho que ya no cumple su motivo (por ejemplo, la orden ya se entregó) |
| 400 | `VALIDATION_ERROR` | Motivo o identificador inválidos, o claves de aviso mal formadas |

Siguen vigentes `UNAUTHENTICATED` (401) y `FORBIDDEN` (403).

### Matriz de permisos

| Recurso | ADMIN | RECEPTIONIST | MECHANIC |
|---------|:-----:|:------------:|:--------:|
| `GET /notifications` | ✔ todos los tipos | ✔ sin `STOCK_*` | ✔ solo `STALLED` de sus órdenes |
| `POST /notifications/read` | ✔ | ✔ | ✔ (solo sus avisos) |
| `GET /client-notices` | ✔ | ✔ | ✘ (403) |
| `POST /client-notices` | ✔ | ✔ | ✘ (403) |
| Teléfono del cliente en las respuestas | ✔ (solo en `/client-notices`) | ✔ (solo en `/client-notices`) | ✘ nunca |

## Notificaciones (`/api/notifications`)

### `GET /api/notifications` (cualquier usuario autenticado)

Calcula los avisos del usuario en ese momento. No tiene parámetros. Cada tipo devuelve como máximo 50 avisos; el
total real de cada tipo va en `groups[].total`.

**200**:

```json
{
  "data": {
    "unread": 3,
    "total": 5,
    "generatedAt": "2026-11-20T15:04:05.000Z",
    "groups": [
      {
        "type": "MAINT_OVERDUE",
        "total": 1,
        "unread": 1,
        "items": [
          {
            "key": "MAINT_OVERDUE:7",
            "type": "MAINT_OVERDUE",
            "read": false,
            "title": "Mantenimiento vencido",
            "detail": "Cambio de aceite · Nissan Versa ABC-123 · Juan Pérez",
            "dueDate": "2026-11-10",
            "target": { "kind": "vehicle", "id": 4 }
          }
        ]
      }
    ]
  }
}
```

- `groups` incluye solo los tipos que el rol puede ver **y** que tienen avisos; un usuario sin avisos recibe
  `unread: 0`, `total: 0` y `groups: []`.
- `unread` y `total` cuentan todos los avisos (no solo los 50 listados); `unread` es el número de la campana.
- Orden de los grupos: `MAINT_OVERDUE`, `STOCK_OUT`, `STALLED`, `APPT_TODAY`, `MAINT_UPCOMING`, `STOCK_LOW`.
- `target.kind`: `order`, `appointment`, `vehicle` o `part`.
- Campos extra por tipo en cada ítem: `APPT_TODAY` → `scheduledAt`; `STALLED` → `folio`, `status`, `daysStalled`;
  `STOCK_LOW` y `STOCK_OUT` → `stock`, `minStock`; mantenimientos → `dueDate` y `dueMileage` (los que existan).
- **MECHANIC**: los ítems no traen nombre de cliente ni teléfono; `detail` se limita al folio, el vehículo y el
  estado.
- **ADMIN y RECEPTIONIST**: los ítems traen el nombre del cliente en `detail`, nunca el teléfono.
- El resultado depende del rol vigente en la base, no del que traiga el token.

### `POST /api/notifications/read` (cualquier usuario autenticado)

Marca avisos como leídos para el usuario que llama.

**Solicitud**: `{ "keys": ["STOCK_LOW:12", "STALLED:5:31"] }` (entre 1 y 50 claves de hasta 60 caracteres, con el
formato de clave del [modelo de datos](../data-model.md)).

**200**: `{ "data": { "marked": 1, "unread": 2 } }`

- `marked` es el número de claves que correspondían a avisos vigentes del usuario. Las demás se **ignoran sin
  error**, por ejemplo un aviso que desapareció mientras el panel estaba abierto.
- Repetir la solicitud o enviarla en paralelo con otra igual no falla ni duplica filas.
- No es posible marcar avisos que el rol no puede ver: sus claves se ignoran igual.
- `400 VALIDATION_ERROR` si `keys` está vacío, supera 50 o contiene un texto que no tiene el formato de clave.

## Clientes por avisar (`/api/client-notices`)

### `GET /api/client-notices` (ADMIN, RECEPTIONIST)

Lista los hechos que todavía no se han avisado, ordenados por motivo y fecha. Sin parámetros de paginación: se
limita a 200 filas.

**200**:

```json
{
  "data": [
    {
      "reason": "ORDER_READY",
      "factId": 31,
      "factDate": "2026-11-19",
      "folio": "OS-000031",
      "description": "Orden terminada, lista para entregar",
      "client": { "id": 9, "name": "Ana Torres", "phone": "7761234567" },
      "vehicle": { "id": 14, "brand": "Chevrolet", "model": "Aveo", "licensePlate": "XYZ-987" }
    }
  ],
  "meta": { "total": 1 }
}
```

- `folio` solo aparece en `ORDER_READY`; `factDate` es la fecha de la cita, la del mantenimiento o la fecha en
  que la orden quedó Terminada.
- Un cliente con dos motivos aparece una vez por motivo.
- Un cliente sin teléfono (dato antiguo o vacío) llega con `phone: ""` y la pantalla muestra «Sin teléfono
  registrado».
- Una fila ya avisada no aparece.
- `meta.total` es el total real aunque se limiten las filas a 200.

### `POST /api/client-notices` (ADMIN, RECEPTIONIST)

Registra que la recepción avisó al cliente de un hecho. No envía ningún mensaje.

**Solicitud**: `{ "reason": "ORDER_READY", "factId": 31 }`

| Estado | Resultado |
|--------|-----------|
| 201 | Se creó el registro: `{ "data": { "id": 5, "reason": "ORDER_READY", "factId": 31, "clientId": 9, "notifiedBy": 2, "notifiedAt": "2026-11-20T15:10:00.000Z" } }` |
| 200 | Ya estaba avisado (por ejemplo, otra persona lo marcó un instante antes): mismo cuerpo con el registro existente; no es un error |
| 409 | `NOTICE_NOT_APPLICABLE`: el hecho ya no cumple su motivo (la orden se entregó, la cita se canceló o el mantenimiento se atendió) |
| 400 | `VALIDATION_ERROR`: motivo desconocido o `factId` que no es un entero positivo |
| 403 | El usuario es MECHANIC |
| 404 | El hecho no existe |

- El cuerpo **no acepta nota ni otros campos** (D-02): los campos desconocidos se rechazan con
  `VALIDATION_ERROR`.
- El registro guarda quién avisó (el usuario autenticado) y cuándo (hora del servidor).

## Efectos sobre contratos existentes

Ninguno: no cambian rutas, parámetros ni respuestas de los sprints 1 a 5.
