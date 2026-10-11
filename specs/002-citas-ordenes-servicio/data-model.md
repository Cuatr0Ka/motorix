# Modelo de datos: Citas y órdenes de servicio (Sprint 2)

**Motor**: MySQL 8.0, InnoDB, `utf8mb4` (intercolado `utf8mb4_0900_ai_ci`). Los identificadores de
tabla y columna van en inglés (`snake_case`); en la API se exponen en `camelCase`. Script:
`database/migrations/002_sprint2_appointments_service_orders.sql`. No se modifica ninguna tabla del
Sprint 1.

## Diagrama de relaciones

```text
clients 1 ───< vehicles 1 ───< appointments 1 ───0..1 service_orders
                    │                                     │
                    └──────────────< service_orders >─────┤ (mechanic_id → users, opcional)
                                          │
                                          ├──< order_services
                                          ├──< order_labor
                                          └──< order_status_history  (changed_by → users)
```

- Una cita pertenece a un cliente y a un vehículo de ese cliente; origina a lo sumo una orden.
- Una orden pertenece a un cliente y a un vehículo, tiene cita de origen opcional y mecánico
  asignado opcional.
- Servicios, mano de obra e historial de estados dependen de la orden (`ON DELETE RESTRICT`: no se
  borran órdenes de forma ordinaria).

## Tabla `appointments` (Cita)

| Columna | Tipo | Restricciones | Notas |
|---------|------|---------------|-------|
| `id` | INT UNSIGNED | PK, AUTO_INCREMENT | |
| `client_id` | INT UNSIGNED | NOT NULL, FK → `clients.id` | `ON DELETE RESTRICT ON UPDATE CASCADE` |
| `vehicle_id` | INT UNSIGNED | NOT NULL, FK → `vehicles.id` | Debe pertenecer a `client_id` (se valida en el servicio) |
| `scheduled_at` | DATETIME | NOT NULL | Hora local del taller; no puede estar en el pasado al crear |
| `reason` | VARCHAR(255) | NOT NULL | Motivo de la visita |
| `notes` | VARCHAR(1000) | NULL | Observaciones opcionales |
| `status` | ENUM('PENDIENTE','CONFIRMADA','EN_PROCESO','COMPLETADA','CANCELADA') | NOT NULL, DEFAULT 'PENDIENTE' | |
| `cancel_reason` | VARCHAR(255) | NULL | Motivo opcional de la cancelación |
| `cancelled_at` | DATETIME | NULL | Se fija al cancelar |
| `active_vehicle_id` | INT UNSIGNED | GENERADA ALMACENADA | `IF(status IN ('CANCELADA','COMPLETADA'), NULL, vehicle_id)` |
| `created_by` | INT UNSIGNED | NOT NULL, FK → `users.id` | Quién la registró |
| `created_at` / `updated_at` | DATETIME | igual que en el Sprint 1 | |

**Índices**: `UNIQUE uq_appointments_active_slot (active_vehicle_id, scheduled_at)`,
`idx_appointments_scheduled (scheduled_at)`, `idx_appointments_status (status)`,
`idx_appointments_client (client_id)`.

**Reglas**
- No se acepta una cita con `scheduled_at` pasado ni con un vehículo ajeno al cliente (FR-006).
- Solo se pueden modificar o cancelar citas `PENDIENTE` o `CONFIRMADA` (FR-004, FR-005).
- El índice único impide dos citas activas del mismo vehículo en el mismo horario.
- Las citas no se eliminan.

**Transiciones de estado**

```text
PENDIENTE ──confirmar──▶ CONFIRMADA
PENDIENTE / CONFIRMADA ──cancelar──▶ CANCELADA          (terminal)
PENDIENTE / CONFIRMADA ──crear orden──▶ EN_PROCESO
EN_PROCESO ──la orden llega a TERMINADO──▶ COMPLETADA   (terminal)
```

## Tabla `service_orders` (Orden de servicio)

| Columna | Tipo | Restricciones | Notas |
|---------|------|---------------|-------|
| `id` | INT UNSIGNED | PK, AUTO_INCREMENT | El folio es `OS-` + id con 6 dígitos (no se guarda) |
| `client_id` | INT UNSIGNED | NOT NULL, FK → `clients.id` | Se toma del propietario del vehículo |
| `vehicle_id` | INT UNSIGNED | NOT NULL, FK → `vehicles.id` | |
| `appointment_id` | INT UNSIGNED | NULL, UNIQUE, FK → `appointments.id` | Cita de origen opcional |
| `mechanic_id` | INT UNSIGNED | NULL, FK → `users.id` | Usuario activo con rol MECHANIC al asignar |
| `status` | ENUM('RECIBIDO','DIAGNOSTICO','EN_REPARACION','ESPERANDO_REFACCION','TERMINADO','ENTREGADO') | NOT NULL, DEFAULT 'RECIBIDO' | |
| `reported_problem` | VARCHAR(1000) | NOT NULL | Problema reportado por el cliente |
| `entry_mileage` | INT UNSIGNED | NOT NULL | 0 a 2 000 000 |
| `mileage_correction` | TINYINT(1) | NOT NULL, DEFAULT 0 | 1 si se aceptó un kilometraje menor al previo |
| `mileage_correction_reason` | VARCHAR(255) | NULL | Obligatorio si `mileage_correction = 1` |
| `diagnosis` | TEXT | NULL | |
| `observations` | TEXT | NULL | |
| `recommendations` | TEXT | NULL | |
| `open_vehicle_id` | INT UNSIGNED | GENERADA ALMACENADA | `IF(status = 'ENTREGADO', NULL, vehicle_id)` |
| `created_by` | INT UNSIGNED | NOT NULL, FK → `users.id` | |
| `delivered_at` | DATETIME | NULL | Se fija al pasar a ENTREGADO |
| `created_at` / `updated_at` | DATETIME | igual que en el Sprint 1 | |

**Índices**: `UNIQUE uq_orders_open_vehicle (open_vehicle_id)`, `UNIQUE uq_orders_appointment (appointment_id)`,
`idx_orders_status (status)`, `idx_orders_mechanic_status (mechanic_id, status)`,
`idx_orders_vehicle (vehicle_id)`, `idx_orders_client (client_id)`.

**Reglas**
- No se crea una orden para un vehículo inexistente (RN-2); `client_id` se deriva del vehículo.
- `entry_mileage` es obligatorio. No puede ser menor a `vehicles.current_mileage` salvo corrección
  explícita con motivo (RN-3, RN-4); al crear la orden, `vehicles.current_mileage` se actualiza.
- Un vehículo tiene a lo sumo una orden no `ENTREGADO` (índice `uq_orders_open_vehicle`).
- Solo se asigna un usuario activo con rol `MECHANIC`; no se reasigna en `TERMINADO` ni `ENTREGADO`.
- Una orden sin mecánico no puede salir de `RECIBIDO`.
- Una orden `ENTREGADO` es de solo lectura y no se elimina (RN-9).
- Totales (calculados, no almacenados): `servicesTotal`, `laborTotal`, `total`.

**Transiciones de estado**

```text
RECIBIDO ─▶ DIAGNOSTICO ─▶ EN_REPARACION ─▶ TERMINADO ─▶ ENTREGADO
                │               │  ▲
                └──▶ ESPERANDO_REFACCION ──┘    (solo regresa a EN_REPARACION)
```

| Desde | Hacia permitido | Quién |
|-------|-----------------|-------|
| RECIBIDO | DIAGNOSTICO | mecánico asignado, ADMIN |
| DIAGNOSTICO | EN_REPARACION, ESPERANDO_REFACCION | mecánico asignado, ADMIN |
| EN_REPARACION | TERMINADO, ESPERANDO_REFACCION | mecánico asignado, ADMIN |
| ESPERANDO_REFACCION | EN_REPARACION | mecánico asignado, ADMIN |
| TERMINADO | ENTREGADO | RECEPTIONIST, ADMIN |
| ENTREGADO | (ninguna) | — |

## Tabla `order_services` (Servicio de la orden)

| Columna | Tipo | Restricciones | Notas |
|---------|------|---------------|-------|
| `id` | INT UNSIGNED | PK, AUTO_INCREMENT | |
| `order_id` | INT UNSIGNED | NOT NULL, FK → `service_orders.id` | `ON DELETE RESTRICT` |
| `description` | VARCHAR(255) | NOT NULL | |
| `amount` | DECIMAL(10,2) | NOT NULL, CHECK `amount >= 0` | |
| `created_at` / `updated_at` | DATETIME | igual que en el Sprint 1 | |

**Índice**: `idx_order_services_order (order_id)`.

## Tabla `order_labor` (Mano de obra de la orden)

Misma estructura que `order_services` (`id`, `order_id`, `description`, `amount`,
`created_at`, `updated_at`), con `idx_order_labor_order (order_id)`.

## Tabla `order_status_history` (Cambio de estado)

| Columna | Tipo | Restricciones | Notas |
|---------|------|---------------|-------|
| `id` | INT UNSIGNED | PK, AUTO_INCREMENT | |
| `order_id` | INT UNSIGNED | NOT NULL, FK → `service_orders.id` | |
| `from_status` | ENUM (estados de la orden) | NULL | NULL en el registro inicial de la creación |
| `to_status` | ENUM (estados de la orden) | NOT NULL | |
| `changed_by` | INT UNSIGNED | NOT NULL, FK → `users.id` | |
| `changed_at` | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | |

**Índice**: `idx_order_history_order (order_id, changed_at)`.

## Validaciones (nivel API)

- Cita: `clientId` y `vehicleId` enteros positivos; `scheduledAt` ISO 8601 futuro; `reason` 1–255
  caracteres; `notes` hasta 1 000.
- Orden: `vehicleId` o `appointmentId` (al menos uno); `entryMileage` entero 0–2 000 000;
  `reportedProblem` 1–1 000 caracteres (se toma el motivo de la cita si se omite al crear desde
  ella); `mechanicId` opcional; `mileageCorrection` y `mileageCorrectionReason` (5–255 caracteres)
  juntos.
- Servicio y mano de obra: `description` 1–255; `amount` entre 0 y 9 999 999.99 con hasta dos
  decimales.
- Diagnóstico, observaciones y recomendaciones: hasta 5 000 caracteres; vacío se guarda como `NULL`.

## Datos de ejemplo (seed 002)

- Un segundo mecánico (`mecanico2`) además de `mecanico`.
- Citas en cada estado: dos futuras (Pendiente y Confirmada), una En proceso, una Completada y una
  Cancelada.
- Órdenes: una por cada estado del flujo (`RECIBIDO`, `DIAGNOSTICO`, `EN_REPARACION`,
  `ESPERANDO_REFACCION`, `TERMINADO`), cada una en un vehículo distinto, y dos `ENTREGADO`, repartidas
  entre ambos mecánicos, con servicios, mano de obra, recomendaciones e historial de estados.
- Idempotencia por claves naturales (research D-15).
