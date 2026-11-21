# Contrato de la API REST (Sprint 7: reportes, configuración, términos y seguridad)

**Base**: `/api` | **Formato**: JSON UTF-8 (salvo la exportación a Excel) | **Autenticación**: `Authorization: Bearer <token>`
en todas las rutas. Este contrato **amplía** los de los sprints 1 a 6; las convenciones de respuesta y errores son las
mismas (`{ data, meta? }` / `{ error: { code, message, details? } }`, mensajes en español y sin trazas).

## Convenciones

- Importes como cadenas decimales con dos decimales (`"1250.00"`), calculadas desde centavos enteros. Moneda: pesos
  mexicanos (MXN).
- Fechas de calendario como `AAAA-MM-DD`; fechas con hora en ISO 8601.
- **Periodo de los reportes**: `from` y `to` (`AAAA-MM-DD`, ambos obligatorios, `to >= from`, máximo 366 días). La
  interfaz arma los presets de día, semana y mes con esos dos parámetros.
- **Exportación**: cualquier reporte acepta `format=xlsx` y responde `200` con
  `Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` y
  `Content-Disposition: attachment; filename="reporte-<nombre>-<from>_<to>.xlsx"` (`<nombre>` es `income`, `services`,
  `productivity`, `parts` o `rotation`). Es un libro de Excel con el logo y los colores de Motorix; los importes son números con
  formato de moneda y las fechas `AAAA-MM-DD`. Un texto nunca se interpreta como fórmula. Un periodo inválido responde `400`
  igual que en JSON y cualquier otro valor de `format` también.
- Los rangos inválidos usan `400 VALIDATION_ERROR` con `details[]` por campo.

### Códigos de error nuevos

| Estado | Código | Cuándo |
|--------|--------|--------|
| 403 | `TERMS_NOT_ACCEPTED` | El usuario no aceptó la versión vigente de los términos (`details.version`, `details.versionId`) |
| 401 | `SESSION_INACTIVE` | La sesión superó los 30 minutos sin actividad |
| 422 | `PASSWORD_POLICY` | La contraseña no cumple la política (ahora, mínimo 10 caracteres con mayúscula, minúscula y número) |
| 409 | `SERVICE_TYPE_DUPLICATE` | Ya existe un tipo de servicio con ese nombre |
| 422 | `SERVICE_TYPE_INTERVAL_REQUIRED` | El tipo de servicio no tiene ningún intervalo |
| 422 | `SERVICE_TYPE_INACTIVE` | Se asigna a una línea de servicio un tipo desactivado |
| 400 | `VALIDATION_ERROR` | Datos de configuración, tipo de servicio, rango o filtros inválidos |

Siguen vigentes `UNAUTHENTICATED` (401), `FORBIDDEN` (403) y `NOT_FOUND` (404).

### Matriz de permisos

| Recurso | ADMIN | RECEPTIONIST | MECHANIC |
|---------|:-----:|:------------:|:--------:|
| `GET/PUT /settings` | ✔ | ✘ | ✘ |
| `GET /service-types` y `POST/PATCH /service-types` | ✔ | ✘ | ✘ |
| `GET /service-types/options` | ✔ | ✘ | ✔ |
| `GET /orders/:id/maintenance/suggestion` | ✔ | ✘ | ✔ (solo sus órdenes) |
| `GET /reports/*` (JSON y Excel) | ✔ | ✘ | ✘ |
| `GET /audit-log` | ✔ | ✘ | ✘ |
| `GET /terms/acceptances` | ✔ | ✘ | ✘ |
| `GET /terms/current` y `POST /terms/accept` | ✔ | ✔ | ✔ |

La aceptación vigente de los términos es **requisito de toda ruta autenticada**, salvo `GET /terms/current`,
`POST /terms/accept` y `GET /auth/me`.

## Configuración (`/api/settings`) — solo ADMIN

### `GET /api/settings`

**200**:

```json
{
  "data": {
    "shop": { "name": "Motorix Taller Mecánico", "address": "Av. Juárez 120, Huauchinango", "phone": "7761234567" },
    "maintenance": { "warnDays": 30, "warnKm": 1000 },
    "sources": { "shop.name": "STORED", "shop.address": "ENV", "shop.phone": "DEFAULT", "maintenance.warn_days": "STORED", "maintenance.warn_km": "STORED" }
  }
}
```

`sources` indica de dónde sale cada valor: `STORED` (guardado), `ENV` (variable de entorno de respaldo) o `DEFAULT`.

### `PUT /api/settings`

Guarda solo los campos enviados (los demás no cambian). **Solicitud** (todos opcionales, al menos uno):

```json
{ "shop": { "name": "Taller Los Pinos", "address": "Calle 5 #10", "phone": "7761112233" }, "maintenance": { "warnDays": 15, "warnKm": 800 } }
```

- `shop.name`: 1 a 100 caracteres; `shop.address`: hasta 200; `shop.phone`: hasta 20 (dígitos, espacios, `+`, `-` y
  paréntesis); `maintenance.warnDays`: entero de 1 a 365; `maintenance.warnKm`: entero de 1 a 100 000.
- **200**: el mismo cuerpo de `GET /api/settings` con los valores nuevos. Registra `SETTINGS_CHANGED` en la bitácora.
- **400** `VALIDATION_ERROR` con `details[]` por campo; campos desconocidos se rechazan.
- Los tickets ya emitidos **no cambian**.

## Tipos de servicio (`/api/service-types`)

### `GET /api/service-types` (ADMIN)

Lista todos los tipos, incluidos los desactivados. Parámetro opcional `active` (`true` o `false`).

**200**: `{ "data": [ { "id": 1, "name": "Cambio de aceite", "intervalDays": 180, "intervalKm": 5000, "active": true, "inUse": 12 } ], "meta": { "total": 1 } }`
(`inUse` es el número de líneas de servicio que lo usan).

### `GET /api/service-types/options` (ADMIN y MECHANIC)

Solo los tipos **activos**, para elegirlos en una línea de servicio: `[ { "id", "name", "intervalDays", "intervalKm" } ]`.

### `POST /api/service-types` (ADMIN)

**Solicitud**: `{ "name": "Afinación mayor", "intervalDays": 365, "intervalKm": 10000 }` (al menos un intervalo).

| Estado | Resultado |
|--------|-----------|
| 201 | El tipo creado |
| 400 | `VALIDATION_ERROR` (nombre vacío o de más de 100, intervalo no entero o fuera de rango) |
| 409 | `SERVICE_TYPE_DUPLICATE` |
| 422 | `SERVICE_TYPE_INTERVAL_REQUIRED` |

### `PATCH /api/service-types/:id` (ADMIN)

Edita `name`, `intervalDays`, `intervalKm` y `active` (desactivar o reactivar). Un tipo no se borra: **no existe `DELETE`**.
Los intervalos aceptan `null` para quitar uno, siempre que quede al menos uno. Registra `SERVICE_TYPE_CHANGED`.

## Servicios de la orden: tipo opcional

`POST /api/orders/:id/services` y `PATCH /api/orders/:id/services/:lineId` aceptan el campo opcional `serviceTypeId`
(entero o `null`). Un tipo inexistente responde `404`; uno desactivado, `422 SERVICE_TYPE_INACTIVE`. Cada línea de servicio de las
respuestas agrega `serviceType: { id, name } | null`. Las líneas existentes llegan con `serviceType: null`.

## Próximo mantenimiento propuesto

### `GET /api/orders/:id/maintenance/suggestion` (ADMIN, MECHANIC de la orden)

**200**:

```json
{ "data": { "dueDate": "2027-05-20", "dueMileage": 55000, "basedOn": [ { "serviceTypeId": 1, "name": "Cambio de aceite" } ] } }
```

- Toma los tipos con intervalo de las líneas de la orden y propone el intervalo más corto de cada eje.
- **204** si ninguna línea tiene un tipo con intervalo; **404** si la orden no existe o no es del mecánico.
- Es solo una propuesta: `POST /api/orders/:id/maintenance` conserva sus validaciones y el usuario puede corregir.

## Reportes (`/api/reports`) — solo ADMIN

Todos reciben `from` y `to` y aceptan `format=xlsx`.

### `GET /api/reports/income`

```json
{ "data": { "from": "2026-11-01", "to": "2026-11-30", "total": "18450.00", "paymentsCount": 14,
            "byMethod": [ { "method": "EFECTIVO", "payments": 6, "total": "7200.00" } ],
            "byDay": [ { "day": "2026-11-03", "payments": 2, "total": "1850.00" } ] } }
```

Solo cuentan los pagos `PAGADO` con `paid_at` en el rango. La suma de `byMethod` y la de `byDay` es igual a `total`.

### `GET /api/reports/services`

`{ "data": { "from", "to", "items": [ { "name": "Cambio de aceite", "times": 9, "amount": "4500.00" } ] } }`, de mayor a menor
frecuencia. Agrupa por tipo de servicio si lo tiene y por descripción si no.

### `GET /api/reports/productivity`

`{ "data": { "from", "to", "items": [ { "mechanicId": 3, "name": "Segundo mecánico", "ordersFinished": 7, "laborAmount": "3150.00" } ] } }`.
Las órdenes sin mecánico no se atribuyen a nadie.

### `GET /api/reports/parts`

```json
{ "data": { "from", "to",
  "items": [ { "partId": 4, "code": "BAL-DEL", "name": "Balatas delanteras", "units": 6, "revenue": "4680.00",
               "cost": "3120.00", "margin": "1560.00", "marginPercent": "33.33", "noCost": false } ],
  "totals": { "revenue": "4680.00", "cost": "3120.00", "margin": "1560.00", "marginPercent": "33.33", "noCostLines": 0 } } }
```

- Una refacción sin precio de compra (nulo o cero) llega con `noCost: true`, `cost: null`, `margin: null`,
  `marginPercent: null` y **no entra** en `totals.cost` ni `totals.margin`; cuenta en `totals.noCostLines`.
- El costo usa el precio de compra **actual** de la refacción. Esta respuesta es exclusiva del administrador.

### `GET /api/reports/rotation`

`{ "data": { "from", "to", "items": [ { "partId", "code", "name", "out": 12, "stockStart": 20, "stockEnd": 8, "averageStock": "14.00", "rotation": "0.86" } ] } }`
(`rotation` es `null` si el promedio es cero).

### Errores y límites

| Estado | Resultado |
|--------|-----------|
| 400 | `VALIDATION_ERROR`: falta `from` o `to`, fecha inválida, `to < from` o más de 366 días (`details.limit`) |
| 401 / 403 | Sin sesión; rol distinto de ADMIN |

## Términos y condiciones (`/api/terms`)

### `GET /api/terms/current` (cualquier usuario autenticado, aun sin aceptar)

**200**: `{ "data": { "id": 1, "version": "1.0", "title": "Términos y condiciones y aviso de privacidad", "body": "...", "publishedAt": "2026-11-21T00:00:00.000Z", "accepted": false } }`

### `POST /api/terms/accept` (cualquier usuario autenticado, aun sin aceptar)

**Solicitud**: `{ "versionId": 1 }` (debe ser la versión vigente).

| Estado | Resultado |
|--------|-----------|
| 200 | Aceptada (o ya estaba aceptada: idempotente): `{ "data": { "versionId": 1, "version": "1.0", "acceptedAt": "..." } }` |
| 409 | `TERMS_VERSION_OUTDATED`: la versión enviada ya no es la vigente (`details.currentVersionId`) |
| 400 | `VALIDATION_ERROR` |

Registra `TERMS_ACCEPTED` en la bitácora. Dos solicitudes simultáneas dejan una sola aceptación.

### `GET /api/terms/acceptances` (ADMIN)

Parámetros: `versionId` (por omisión, la vigente), `page` y `pageSize`.

**200**: `{ "data": [ { "userId": 2, "username": "recepcion", "name": "Recepción", "acceptedAt": "..." } ], "meta": { "page": 1, "pageSize": 20, "total": 3, "pending": 1, "version": "1.0" } }`
(`pending` es el número de usuarios activos que todavía no aceptan esa versión).

### Efecto sobre el resto de la API

Un usuario sin aceptación vigente recibe `403 TERMS_NOT_ACCEPTED` en cualquier ruta autenticada, salvo las tres de arriba.

## Bitácora (`/api/audit-log`) — solo ADMIN

### `GET /api/audit-log`

Parámetros: `from`, `to` (fechas), `userId`, `action` (una de las acciones del modelo de datos), `page` y `pageSize` (hasta 100).

**200**:

```json
{ "data": [ { "id": 31, "createdAt": "2026-11-21T15:10:00.000Z", "action": "PART_PRICE_CHANGED",
              "actor": { "id": 1, "username": "admin", "name": "Administrador" },
              "entityType": "part", "entityId": 4, "summary": "Balatas delanteras: venta 780.00 → 820.00" } ],
  "meta": { "page": 1, "pageSize": 20, "total": 1 } }
```

- De la más reciente a la más antigua. `actor` siempre trae el usuario que hizo la acción o al que se atribuye (los intentos
  de inicio de sesión con cuentas inexistentes no se registran).
- **No existe** `POST`, `PUT`, `PATCH` ni `DELETE`: la bitácora no se edita ni se borra desde la aplicación.
- Ningún registro contiene contraseñas, hashes, tokens ni datos de tarjeta.

## Efectos sobre contratos existentes

| Contrato | Cambio |
|----------|--------|
| Autenticación | Mínimo de contraseña de 10 caracteres en alta de usuario, edición con contraseña y cambio propio (`PASSWORD_POLICY`); `SESSION_INACTIVE` tras 30 minutos sin actividad; `TERMS_NOT_ACCEPTED` sin aceptación vigente |
| Tickets | El contenido nuevo (`formatVersion: 3`) agrega `nextService` cuando la orden tiene un próximo mantenimiento propio; los tickets de versión 1 y 2 no cambian |
| Servicios de la orden | Campo opcional `serviceTypeId` y `serviceType` en la respuesta |
| Mantenimientos, panel y avisos | Usan los márgenes guardados (antes, `.env`); la respuesta no cambia de forma |
| Usuarios, refacciones y pagos | Sin cambio de forma; las altas, bajas, cambios de rol, cambios de precio y cancelaciones quedan en la bitácora |
