# Modelo de datos: Pagos, tickets y panel de control (Sprint 4)

**Motor**: MySQL 8.0, InnoDB, `utf8mb4` (intercolado `utf8mb4_0900_ai_ci`). Los identificadores de tabla y
columna van en inglés (`snake_case`); en la API se exponen en `camelCase`. Script:
`database/migrations/004_sprint4_payments_tickets.sql`. No se modifica ninguna tabla de los sprints
anteriores.

## Diagrama de relaciones

```text
service_orders 1 ───< payments          (a lo sumo uno vigente: PENDIENTE o PAGADO)
service_orders 1 ───0..1 tickets >─── 1 payments   (el pago PAGADO que originó el ticket)
users 1 ───< payments (created_by)      users 1 ───< tickets (generated_by)
```

- El panel de control **no tiene tablas**: se calcula con `service_orders`, `appointments`, `maintenance`,
  `parts`, `payments`, `order_status_history` e `inventory_movements`.
- Todas las llaves foráneas usan `ON DELETE RESTRICT`: pagos y tickets no se eliminan de forma ordinaria.

## Tabla `payments` (Pago)

| Columna | Tipo | Restricciones | Notas |
|---------|------|---------------|-------|
| `id` | INT UNSIGNED | PK, AUTO_INCREMENT | |
| `order_id` | INT UNSIGNED | NOT NULL, FK → `service_orders(id)` | RN-13: todo pago pertenece a una orden |
| `amount` | DECIMAL(10,2) | NOT NULL, CHECK (`amount > 0`) | Importe cobrado; se guarda con dos decimales |
| `method` | ENUM('EFECTIVO','TARJETA','TRANSFERENCIA','MERCADO_PAGO') | NOT NULL | |
| `status` | ENUM('PENDIENTE','PAGADO','RECHAZADO','CANCELADO') | NOT NULL | |
| `reference` | VARCHAR(100) | NULL | Referencia de la operación capturada por la recepción (folio de terminal, clave de rastreo). Nunca datos de tarjeta |
| `external_reference` | VARCHAR(100) | NULL | Referencia que Motorix envía a Mercado Pago (`motorix-pago-<id>`) |
| `external_payment_id` | VARCHAR(40) | NULL | Identificador de la operación en Mercado Pago, cuando está aprobada |
| `checkout_url` | VARCHAR(500) | NULL | Enlace de cobro de Mercado Pago |
| `last_checked_at` | DATETIME | NULL | Última consulta al proveedor |
| `paid_at` | DATETIME | NULL | Cuándo pasó a `PAGADO` |
| `active_order_id` | INT UNSIGNED | Generada: `IF(status IN ('PENDIENTE','PAGADO'), order_id, NULL)`, STORED, UNIQUE | Un solo pago vigente por orden |
| `created_by` | INT UNSIGNED | NOT NULL, FK → `users(id)` | Persona que lo registró |
| `created_at`, `updated_at` | DATETIME | NOT NULL | |

Restricciones: `CHECK (method = 'MERCADO_PAGO' OR status = 'PAGADO')` (efectivo, tarjeta y transferencia
nacen y permanecen `PAGADO`); `CHECK (status <> 'PAGADO' OR paid_at IS NOT NULL)`; `UNIQUE uq_payments_active_order
(active_order_id)`. Índices: `idx_payments_order (order_id)`, `idx_payments_status (status, created_at)`.
Sin columnas para número de tarjeta, vencimiento, código de seguridad ni credenciales (RN-14).

### Transiciones de estado

| Desde | Hacia | Quién / cuándo |
|-------|-------|----------------|
| (alta) | `PAGADO` | Efectivo, tarjeta o transferencia al registrarse |
| (alta) | `PENDIENTE` | Mercado Pago al crear el enlace de cobro |
| `PENDIENTE` | `PAGADO` | Consulta al proveedor con operación aprobada (guarda `external_payment_id`) |
| `PENDIENTE` | `RECHAZADO` | Consulta al proveedor con operación rechazada o cancelada |
| `PENDIENTE` | `CANCELADO` | Cancelación manual con confirmación |
| `PAGADO`, `RECHAZADO`, `CANCELADO` | — | Estados finales; no cambian ni se eliminan |

## Tabla `tickets` (Ticket)

| Columna | Tipo | Restricciones | Notas |
|---------|------|---------------|-------|
| `id` | INT UNSIGNED | PK, AUTO_INCREMENT | El folio es `TK-` + id con 6 dígitos |
| `order_id` | INT UNSIGNED | NOT NULL, FK → `service_orders(id)`, UNIQUE (`uq_tickets_order`) | A lo sumo un ticket por orden |
| `payment_id` | INT UNSIGNED | NOT NULL, FK → `payments(id)` | Pago `PAGADO` que lo originó |
| `content` | JSON | NOT NULL | Instantánea del contenido (ver abajo) |
| `generated_by` | INT UNSIGNED | NOT NULL, FK → `users(id)` | |
| `generated_at` | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | |

Sin `updated_at`: el ticket es de solo lectura. Índice: `idx_tickets_generated (generated_at)`.

### Estructura de `content` (instantánea)

```text
shop:        { name, address, phone }
customer:    { name, phone }
vehicle:     { plate, brand, model, year, mileage }       # mileage = kilometraje de entrada de la orden
order:       { folio, entryMileage, serviceMileage }
services:    [ { description, amount } ]
parts:       [ { code, name, unit, quantity } ]          # sin importe
labor:       [ { description, amount } ]
totals:      { services, labor, total }                    # cadenas decimales con dos decimales
payment:     { method, status, paidAt, reference }
generatedAt: fecha y hora de generación
```

## Reglas de integridad (resumen)

| Regla | Dónde se garantiza |
|-------|--------------------|
| Todo pago tiene orden | Llave foránea y `NOT NULL` |
| A lo sumo un pago vigente por orden | Índice único sobre `active_order_id` + bloqueo de la orden |
| Solo Mercado Pago puede ser Pendiente, Rechazado o Cancelado | `CHECK` de método/estado y `paymentRules` |
| Importe positivo | `CHECK (amount > 0)` y validación (importe igual al total vigente) |
| A lo sumo un ticket por orden | Índice único `uq_tickets_order` |
| Ticket solo con pago `PAGADO` | `ticketService` (valida el estado y que el pago sea de esa orden) |
| Pagos y tickets no se eliminan | Sin rutas `DELETE`; llaves foráneas `RESTRICT` |

## Validaciones de entrada (resumen)

| Campo | Regla |
|-------|-------|
| `method` | uno de `EFECTIVO`, `TARJETA`, `TRANSFERENCIA`, `MERCADO_PAGO` |
| `amount` (opcional) | decimal positivo con hasta dos decimales; si viene, debe ser igual al total vigente |
| `reference` | texto opcional de hasta 100 caracteres; se rechaza si contiene 13 a 19 dígitos seguidos que cumplan la verificación de Luhn (posible número de tarjeta) |
| `status` / `method` (filtros) | valores de las listas anteriores |
| `search` (listados) | hasta 100 caracteres: folio de orden o de ticket, cliente o placa |

## Datos de ejemplo (seed 004)

Idempotente (claves naturales, ver research D-13): pagos en los cuatro estados y con los cuatro métodos
sobre las órdenes entregadas de los sprints 2 y 3; un cobro de Mercado Pago Pendiente sobre la orden
Terminada del Sprint 2; tickets de las órdenes cobradas; y la información suficiente para que todos los
indicadores del panel muestren valores.
