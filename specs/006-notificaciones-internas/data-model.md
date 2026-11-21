# Modelo de datos (Fase 1): Notificaciones internas y clientes por avisar (Sprint 6)

**Fecha**: 2026-11-20 | **Especificación**: [spec.md](./spec.md) | **Investigación**: [research.md](./research.md)

La migración `database/migrations/006_sprint6_notices.sql` es **aditiva**: crea dos tablas nuevas y no modifica ni
borra filas ni columnas de las existentes. Todo lo demás (los avisos y la lista de clientes por avisar) se
**calcula** al consultar y no se guarda.

## Tablas nuevas

### `notification_reads` (lectura de avisos por usuario)

| Columna | Tipo | Reglas |
|---------|------|--------|
| `user_id` | `INT UNSIGNED` | Obligatoria; llave foránea a `users(id)`; parte de la llave primaria |
| `notice_key` | `VARCHAR(60)` | Obligatoria; clave del aviso (ver «Claves de aviso»); parte de la llave primaria |
| `read_at` | `DATETIME` | Obligatoria; `DEFAULT CURRENT_TIMESTAMP` |

- Llave primaria `(user_id, notice_key)`: una lectura por usuario y aviso, y la inserción repetida se ignora.
- Llave foránea `fk_notification_reads_user` con `ON DELETE CASCADE` (un usuario eliminado no deja lecturas
  huérfanas; en la práctica los usuarios solo se desactivan).
- Sin índices adicionales: toda consulta es por `user_id`.

### `client_notices` (avisos registrados a clientes)

| Columna | Tipo | Reglas |
|---------|------|--------|
| `id` | `INT UNSIGNED` | Llave primaria, autoincremental |
| `client_id` | `INT UNSIGNED` | Obligatoria; llave foránea a `clients(id)` |
| `reason` | `ENUM('ORDER_READY','APPT_TOMORROW','MAINT_UPCOMING','MAINT_OVERDUE')` | Obligatoria |
| `fact_id` | `INT UNSIGNED` | Obligatoria; identificador del hecho (orden, cita o mantenimiento según el motivo) |
| `notified_by` | `INT UNSIGNED` | Obligatoria; llave foránea a `users(id)`; quién avisó |
| `notified_at` | `DATETIME` | Obligatoria; `DEFAULT CURRENT_TIMESTAMP` |

- `UNIQUE KEY uq_client_notices_fact (reason, fact_id)`: un mismo hecho se avisa una sola vez, también con dos
  recepcionistas al mismo tiempo (FR-016, FR-021).
- `KEY idx_client_notices_client (client_id)`.
- Llaves foráneas con `ON DELETE RESTRICT` (los clientes y usuarios no se borran de forma ordinaria).
- **No** hay columna de nota (D-02) ni de canal: el sistema solo registra que la recepción avisó.
- `fact_id` no lleva llave foránea porque apunta a tres tablas según el motivo; el servicio valida el hecho al
  registrar (research R-08).

## Entidades calculadas (no se guardan)

### Aviso (notificación)

| Campo | Origen |
|-------|--------|
| `key` | Clave de aviso (tabla siguiente) |
| `type` | `MAINT_UPCOMING`, `MAINT_OVERDUE`, `APPT_TODAY`, `STOCK_LOW`, `STOCK_OUT` o `STALLED` |
| `read` | Existe una fila en `notification_reads` para `(usuario, key)` |
| `title` y `detail` | Texto armado con los datos del objeto (cliente, vehículo, folio, refacción, días) |
| `target` | `{ kind, id }` de la pantalla a abrir: `order`, `appointment`, `vehicle` o `part` |

### Claves de aviso

| Tipo | Clave | Se genera cuando |
|------|-------|------------------|
| `MAINT_UPCOMING` | `MAINT_UPCOMING:{maintenance.id}` | Mantenimiento pendiente con indicador `PROXIMO` |
| `MAINT_OVERDUE` | `MAINT_OVERDUE:{maintenance.id}` | Mantenimiento pendiente con indicador `VENCIDO` |
| `APPT_TODAY` | `APPT_TODAY:{appointment.id}` | Cita con fecha de hoy y estado `PENDIENTE` o `CONFIRMADA` |
| `STOCK_LOW` | `STOCK_LOW:{part.id}` | Refacción activa con `0 < stock <= min_stock` |
| `STOCK_OUT` | `STOCK_OUT:{part.id}` | Refacción activa con `stock = 0` |
| `STALLED` | `STALLED:{order.id}:{último id del historial o 0}` | Orden abierta con más de 3 días sin cambio de estado |

La clave nunca excede 60 caracteres (identificadores de hasta 10 dígitos).

### Cliente por avisar

| Campo | Origen |
|-------|--------|
| `reason` | `ORDER_READY`, `APPT_TOMORROW`, `MAINT_UPCOMING` o `MAINT_OVERDUE` |
| `factId` | Identificador de la orden, la cita o el mantenimiento |
| `client` | `{ id, name, phone }` de `clients` |
| `vehicle` | `{ id, brand, model, licensePlate }` de `vehicles` |
| `factDate` | Fecha de la cita o del mantenimiento; para una orden, la fecha en que quedó Terminada |
| Condición para aparecer | El hecho cumple el motivo **y** no existe una fila en `client_notices` con ese `(reason, fact_id)` |

## Reglas y transiciones

| Regla | Detalle |
|-------|---------|
| Orden detenida | Estados `RECIBIDO`, `DIAGNOSTICO`, `EN_REPARACION`, `ESPERANDO_REFACCION`; última fecha de cambio = mayor `changed_at` del historial (o `created_at` sin historial); más de 3 días calendario. Cualquier cambio de estado la saca de la condición y reinicia el conteo |
| Stock | Mismo criterio que `partModel.listAlerts` (activa y `stock <= min_stock`); `0` es agotada |
| Cita del día | `DATE(scheduled_at) = CURDATE()` y estado `PENDIENTE` o `CONFIRMADA` |
| Cita de mañana | `DATE(scheduled_at) = CURDATE() + 1` y estado `PENDIENTE` o `CONFIRMADA` |
| Mantenimiento próximo o vencido | `computeIndicator` con los márgenes de `getMaintenanceConfig()`; solo `status = 'PENDIENTE'` |
| Lectura | Pasa de «no leído» a «leído» una sola vez por `(usuario, clave)`; si la clave deja de existir, el aviso desaparece |
| Aviso al cliente | Pasa de «pendiente» a «avisado» una sola vez por `(motivo, hecho)`; no se deshace |
| Visibilidad | ADMIN todos los tipos; RECEPTIONIST todos menos `STOCK_*`; MECHANIC solo `STALLED` de sus órdenes asignadas |

## Impacto sobre datos existentes

- Ninguna tabla existente cambia de estructura ni de contenido (FR-025).
- Las órdenes, citas y mantenimientos anteriores se evalúan igual que los nuevos.
- Los seeds anteriores no se editan; el seed `006_notices.sql` solo agrega datos de ejemplo idempotentes.
