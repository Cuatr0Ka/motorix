# Modelo de datos: Historial, mantenimiento e inventario (Sprint 3)

**Motor**: MySQL 8.0, InnoDB, `utf8mb4` (intercolado `utf8mb4_0900_ai_ci`). Los identificadores de
tabla y columna van en inglés (`snake_case`); en la API se exponen en `camelCase`. Script:
`database/migrations/003_sprint3_maintenance_inventory.sql`. No se modifica ningún script anterior;
la única alteración a una tabla existente (`service_orders.service_mileage`) va en esta migración.

## Diagrama de relaciones

```text
vehicles 1 ───< service_orders 1 ───< order_parts >─── 1 parts 1 ───< inventory_movements
    │                 │  (service_mileage nuevo)                              │
    │                 └──────────< inventory_movements (order_id opcional) ───┘
    └───< maintenance >─── origin: service_orders (order_id)
```

- El historial del vehículo **no es una tabla**: se calcula con las órdenes `TERMINADO` o `ENTREGADO`
  (research D-01).
- Una refacción tiene muchos movimientos; una orden tiene cero o más refacciones (una línea por
  refacción); un vehículo tiene a lo sumo un mantenimiento pendiente.
- Todas las llaves foráneas usan `ON DELETE RESTRICT`: nada se elimina de forma ordinaria.

## Alteración de `service_orders`

| Columna | Tipo | Restricciones | Notas |
|---------|------|---------------|-------|
| `service_mileage` | INT UNSIGNED | NULL | Kilometraje al terminar el servicio. Solo se asigna con la orden en `TERMINADO`; ≥ `entry_mileage` y ≤ 2 000 000 (validado en servicio) |

## Tabla `parts` (Refacción)

| Columna | Tipo | Restricciones | Notas |
|---------|------|---------------|-------|
| `id` | INT UNSIGNED | PK, AUTO_INCREMENT | |
| `code` | VARCHAR(40) | NOT NULL, UNIQUE (`uq_parts_code`) | Se normaliza a mayúsculas y sin espacios en los extremos |
| `name` | VARCHAR(120) | NOT NULL | |
| `description` | VARCHAR(500) | NULL | |
| `unit` | VARCHAR(20) | NOT NULL | Texto libre breve: pieza, litro, juego… |
| `stock` | INT UNSIGNED | NOT NULL, DEFAULT 0, CHECK (`stock >= 0`) | Igual a `SUM(inventory_movements.quantity)`; solo lo cambia `inventoryService` |
| `min_stock` | INT UNSIGNED | NOT NULL, DEFAULT 0 | Umbral de alerta |
| `active` | TINYINT(1) | NOT NULL, DEFAULT 1 | Las refacciones no se eliminan; se desactivan |
| `created_at`, `updated_at` | DATETIME | NOT NULL | |

Índices: `idx_parts_name (name)`, `idx_parts_stock (active, stock, min_stock)` para alertas.

Estado de stock derivado: **Agotada** si `stock = 0`; **Bajo** si `stock > 0` y `stock <= min_stock`;
**Suficiente** en otro caso. Una refacción con `min_stock = 0` solo alerta al llegar a cero.

## Tabla `inventory_movements` (Movimiento de inventario)

| Columna | Tipo | Restricciones | Notas |
|---------|------|---------------|-------|
| `id` | BIGINT UNSIGNED | PK, AUTO_INCREMENT | |
| `part_id` | INT UNSIGNED | NOT NULL, FK → `parts(id)` | |
| `type` | ENUM('IN','OUT','ADJUSTMENT') | NOT NULL | Entrada, Salida, Ajuste |
| `quantity` | INT | NOT NULL | **Con signo**: IN > 0, OUT < 0, ADJUSTMENT ≠ 0 |
| `reason` | VARCHAR(255) | NULL | Obligatorio en `ADJUSTMENT` (≥ 5 caracteres); descriptivo en el resto |
| `order_id` | INT UNSIGNED | NULL, FK → `service_orders(id)` | Presente en usos y devoluciones por orden |
| `created_by` | INT UNSIGNED | NOT NULL, FK → `users(id)` | Persona que lo originó |
| `created_at` | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | |

Restricciones: `CHECK ((type = 'IN' AND quantity > 0) OR (type = 'OUT' AND quantity < 0) OR (type = 'ADJUSTMENT' AND quantity <> 0))`
y `CHECK (ABS(quantity) <= 100000)`. Índices: `idx_movements_part (part_id, created_at)`,
`idx_movements_order (order_id)`. La tabla es de solo agregar: no hay operaciones de edición ni
borrado.

Uso de cada tipo:

| Tipo | Origen | Signo | Ejemplo |
|------|--------|:-----:|---------|
| `IN` | Stock inicial, entrada de mercancía o devolución al quitar/reducir en una orden | + | `reason`: "Stock inicial", "Compra a proveedor", "Devolución desde OS-000012" |
| `OUT` | Uso en una orden (agregar o aumentar cantidad) | − | `order_id` obligatorio |
| `ADJUSTMENT` | Conteo físico, merma o corrección | ± | `reason` obligatorio; guarda `contado − stock` |

## Tabla `order_parts` (Refacción de la orden)

| Columna | Tipo | Restricciones | Notas |
|---------|------|---------------|-------|
| `id` | INT UNSIGNED | PK, AUTO_INCREMENT | |
| `order_id` | INT UNSIGNED | NOT NULL, FK → `service_orders(id)` | |
| `part_id` | INT UNSIGNED | NOT NULL, FK → `parts(id)` | |
| `quantity` | INT UNSIGNED | NOT NULL, CHECK (`quantity > 0`) | Cantidad total usada en la orden |
| `created_by` | INT UNSIGNED | NOT NULL, FK → `users(id)` | |
| `created_at`, `updated_at` | DATETIME | NOT NULL | |

Índice único `uq_order_parts_line (order_id, part_id)`: una línea por refacción y orden. La orden
conserva el movimiento aunque se quite la línea (el movimiento guarda `order_id`).

## Tabla `maintenance` (Mantenimiento)

| Columna | Tipo | Restricciones | Notas |
|---------|------|---------------|-------|
| `id` | INT UNSIGNED | PK, AUTO_INCREMENT | |
| `vehicle_id` | INT UNSIGNED | NOT NULL, FK → `vehicles(id)` (`ON UPDATE RESTRICT`) | |
| `order_id` | INT UNSIGNED | NOT NULL, FK → `service_orders(id)` | Orden de origen (de ahí sale el mecánico responsable) |
| `description` | VARCHAR(255) | NOT NULL | Servicio por realizar |
| `due_date` | DATE | NULL | Fecha objetivo |
| `due_mileage` | INT UNSIGNED | NULL | Kilometraje objetivo |
| `status` | ENUM('PENDIENTE','ATENDIDO') | NOT NULL, DEFAULT 'PENDIENTE' | Seguimiento; el indicador se calcula |
| `attended_at` | DATETIME | NULL | Fecha en que pasó a Atendido |
| `pending_vehicle_id` | INT UNSIGNED | Generada: `IF(status = 'PENDIENTE', vehicle_id, NULL)`, STORED, UNIQUE | Un solo pendiente por vehículo |
| `created_by` | INT UNSIGNED | NOT NULL, FK → `users(id)` | |
| `created_at`, `updated_at` | DATETIME | NOT NULL | |

Restricciones: `CHECK (due_date IS NOT NULL OR due_mileage IS NOT NULL)`. Índices:
`uq_maintenance_pending (pending_vehicle_id)`, `idx_maintenance_vehicle (vehicle_id)`,
`idx_maintenance_due (status, due_date)`. Nota: `vehicle_id` es columna base de una columna
generada, por lo que su llave foránea usa `ON UPDATE RESTRICT` (igual que en el Sprint 2).

### Indicador calculado (no se guarda)

Para un mantenimiento `PENDIENTE` de un vehículo con kilometraje actual `K` y fecha de hoy `H`:

| Indicador | Condición |
|-----------|-----------|
| **Vencido** | `due_date < H` **o** `K >= due_mileage` (basta una de las condiciones definidas) |
| **Próximo** | no vencido y (`due_date − H <= MAINTENANCE_WARN_DAYS` **o** `due_mileage − K <= MAINTENANCE_WARN_KM`) |
| **Normal** | en cualquier otro caso |

Si el vehículo no tiene kilometraje actual, la condición por kilometraje no se evalúa.

## Transiciones y reglas de integridad

- **Programar mantenimiento**: orden en `TERMINADO` o `ENTREGADO`; requiere al menos `due_date` o
  `due_mileage`; `due_date >= H`; `due_mileage > K`. En la misma transacción, el pendiente anterior
  del vehículo pasa a `ATENDIDO` (con `attended_at`).
- **Pendiente → Atendido**: acción explícita; un Atendido no vuelve a Pendiente ni se edita.
- **Agregar/aumentar refacción a una orden**: bloquea la orden y la refacción; `UPDATE parts SET stock = stock - :n WHERE id = :id AND stock >= :n`;
  inserta/actualiza `order_parts`; inserta movimiento `OUT` con `order_id`. Todo o nada.
- **Reducir/quitar refacción**: movimiento `IN` con `order_id` por la diferencia y actualización de
  la línea (o su eliminación si se quita).
- **Ajuste**: bloquea la refacción, `delta = contado − stock`; rechaza `delta = 0`; movimiento
  `ADJUSTMENT`.
- **Orden `ENTREGADO`**: no admite cambios en `order_parts` ni en `service_mileage`.

## Validaciones de entrada (resumen)

| Campo | Regla |
|-------|-------|
| `code` | 2–40 caracteres, letras, números, guion y guion bajo; único sin distinguir mayúsculas |
| `name` | 2–120 caracteres |
| `unit` | 1–20 caracteres |
| `minStock`, `initialStock` | entero ≥ 0 y ≤ 1 000 000 |
| `quantity` (movimiento/orden) | entero positivo ≤ 100 000 |
| `countedQuantity` | entero ≥ 0 y ≤ 1 000 000 |
| `reason` (ajuste) | 5–255 caracteres |
| `serviceMileage` | entero ≥ `entry_mileage` y ≤ 2 000 000 |
| `dueDate` | fecha `YYYY-MM-DD` ≥ hoy |
| `dueMileage` | entero > kilometraje actual y ≤ 2 000 000 |
| `description` (mantenimiento) | 3–255 caracteres |

## Datos de ejemplo (seed 003)

Idempotente (claves naturales, ver research D-13): ~10 refacciones (suficientes, bajas y agotadas);
entradas, salidas y ajustes; líneas de refacciones en órdenes de ejemplo; órdenes históricas
Terminadas y Entregadas de varios vehículos con kilometraje de servicio; y mantenimientos Normal,
Próximo, Vencido y Atendido. El stock sembrado se recalcula como la suma de los movimientos.
