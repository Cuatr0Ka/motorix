# Modelo de datos (Fase 1): Reportes, configuración, términos y seguridad (Sprint 7)

**Fecha**: 2026-11-21 | **Especificación**: [spec.md](./spec.md) | **Investigación**: [research.md](./research.md)

La migración `database/migrations/007_sprint7_settings_terms_audit.sql` es **aditiva**: crea cinco tablas nuevas y agrega
**dos columnas nulas** a tablas existentes (`order_services.service_type_id` y `users.last_activity_at`). No modifica ni
borra filas ni columnas existentes. Los reportes se **calculan** al consultar y no se guardan.

## Tablas nuevas

### `settings` (configuración del taller)

| Columna | Tipo | Reglas |
|---------|------|--------|
| `setting_key` | `VARCHAR(60)` | Llave primaria; una de las claves de la tabla «Claves de configuración» |
| `setting_value` | `VARCHAR(255)` | Obligatoria; texto (los números se guardan como texto y se validan al leer y al escribir) |
| `updated_by` | `INT UNSIGNED` | Nullable; llave foránea a `users(id)` con `ON DELETE RESTRICT`; quién hizo el último cambio |
| `updated_at` | `DATETIME` | Obligatoria; `DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` |

**Claves de configuración**

| Clave | Valor | Validación | Respaldo si no existe |
|-------|-------|------------|------------------------|
| `shop.name` | Nombre del taller | Obligatorio al guardar, de 1 a 100 caracteres | `SHOP_NAME` o «Motorix Taller Mecánico» |
| `shop.address` | Dirección | Hasta 200 caracteres (puede quedar vacía) | `SHOP_ADDRESS` o vacío |
| `shop.phone` | Teléfono | Hasta 20 caracteres; dígitos, espacios, `+`, `-` y paréntesis | `SHOP_PHONE` o vacío |
| `maintenance.warn_days` | Margen de «Próximo» en días | Entero de 1 a 365 | `MAINTENANCE_WARN_DAYS` o 30 |
| `maintenance.warn_km` | Margen de «Próximo» en kilómetros | Entero de 1 a 100 000 | `MAINTENANCE_WARN_KM` o 1 000 |

### `service_types` (catálogo de tipos de servicio)

| Columna | Tipo | Reglas |
|---------|------|--------|
| `id` | `INT UNSIGNED` | Llave primaria, autoincremental |
| `name` | `VARCHAR(100)` | Obligatoria; **única** (`uq_service_types_name`), sin distinguir mayúsculas |
| `interval_days` | `INT UNSIGNED` | Nullable; si existe, de 1 a 3 650 |
| `interval_km` | `INT UNSIGNED` | Nullable; si existe, de 1 a 1 000 000 |
| `active` | `TINYINT(1)` | Obligatoria; `DEFAULT 1` |
| `created_at`, `updated_at` | `DATETIME` | Obligatorias, con valores por omisión |

- Restricción `chk_service_types_interval`: `interval_days IS NOT NULL OR interval_km IS NOT NULL`.
- Restricciones `chk_service_types_days` e `chk_service_types_km`: los intervalos, si existen, son mayores a cero.
- **No hay borrado**: un tipo solo se desactiva. Un tipo desactivado no se ofrece en las líneas nuevas, pero las
  existentes lo conservan.

### `terms_versions` (versiones de los términos y del aviso de privacidad)

| Columna | Tipo | Reglas |
|---------|------|--------|
| `id` | `INT UNSIGNED` | Llave primaria, autoincremental |
| `version` | `VARCHAR(20)` | Obligatoria; **única** (`uq_terms_versions_version`), por ejemplo `1.0` |
| `title` | `VARCHAR(150)` | Obligatoria |
| `body` | `MEDIUMTEXT` | Obligatoria; texto de los términos y del aviso de privacidad |
| `published_at` | `DATETIME` | Obligatoria; `DEFAULT CURRENT_TIMESTAMP`; la versión vigente es la de mayor fecha (y, a igualdad, mayor `id`) |

- La migración inserta la versión `1.0`. **No se edita** una versión publicada: una versión nueva es otra fila.

### `terms_acceptances` (aceptación por usuario)

| Columna | Tipo | Reglas |
|---------|------|--------|
| `id` | `INT UNSIGNED` | Llave primaria, autoincremental |
| `user_id` | `INT UNSIGNED` | Obligatoria; llave foránea a `users(id)` con `ON DELETE RESTRICT` |
| `terms_version_id` | `INT UNSIGNED` | Obligatoria; llave foránea a `terms_versions(id)` con `ON DELETE RESTRICT` |
| `accepted_at` | `DATETIME` | Obligatoria; `DEFAULT CURRENT_TIMESTAMP` |

- `UNIQUE KEY uq_terms_acceptances (user_id, terms_version_id)`: una aceptación por usuario y versión, también con
  solicitudes simultáneas (se inserta con `INSERT IGNORE`).
- `KEY idx_terms_acceptances_version (terms_version_id, accepted_at)` para la consulta del administrador.

### `audit_log` (bitácora de acciones sensibles)

| Columna | Tipo | Reglas |
|---------|------|--------|
| `id` | `INT UNSIGNED` | Llave primaria, autoincremental |
| `actor_user_id` | `INT UNSIGNED` | Nullable (un inicio de sesión fallido de una cuenta inexistente no tiene usuario); llave foránea a `users(id)` con `ON DELETE RESTRICT` |
| `action` | `VARCHAR(40)` | Obligatoria; una de las acciones de la tabla «Acciones de la bitácora» |
| `entity_type` | `VARCHAR(30)` | Nullable: `user`, `settings`, `service_type`, `part`, `payment` o `terms` |
| `entity_id` | `INT UNSIGNED` | Nullable |
| `summary` | `VARCHAR(255)` | Obligatoria; resumen sin datos reservados |
| `created_at` | `DATETIME` | Obligatoria; `DEFAULT CURRENT_TIMESTAMP` |

- Índices: `idx_audit_created (created_at)`, `idx_audit_actor (actor_user_id, created_at)` e
  `idx_audit_action (action, created_at)`.
- **Solo inserción**: no existe ninguna ruta ni servicio que actualice o borre filas.
- El `summary` **nunca** contiene contraseñas, hashes, tokens ni datos de tarjeta, ni el texto tecleado en un inicio de
  sesión fallido.

**Acciones de la bitácora**

| Acción | Cuándo se registra | Ejemplo de resumen |
|--------|--------------------|--------------------|
| `LOGIN_FAILED` | Credenciales incorrectas de una cuenta existente | `Intento fallido de inicio de sesión` (con `actor_user_id` de esa cuenta) |
| `ACCOUNT_LOCKED` | La cuenta se bloquea por intentos fallidos | `Cuenta bloqueada 15 minutos` |
| `PASSWORD_CHANGED` | Cambio de contraseña propia | `Cambió su contraseña` |
| `USER_CREATED` | Alta de usuario | `Alta de «recepcion2» con rol RECEPTIONIST` |
| `USER_DEACTIVATED` y `USER_ACTIVATED` | Baja o alta de la cuenta | `Baja de «recepcion2»` |
| `USER_ROLE_CHANGED` | Cambio de rol | `«recepcion2»: RECEPTIONIST → MECHANIC` |
| `SETTINGS_CHANGED` | Cambio de configuración | `Taller: nombre; Mantenimiento: margen en días 30 → 15` (solo nombres de campos y valores no reservados) |
| `SERVICE_TYPE_CHANGED` | Alta, edición o desactivación de un tipo de servicio | `Tipo «Cambio de aceite» creado` |
| `PART_PRICE_CHANGED` | Cambio del precio de compra o de venta | `Balatas delanteras: venta 780.00 → 820.00` |
| `PAYMENT_CANCELLED` | Cancelación de un pago | `Pago de la orden OS-000012 cancelado` |
| `TERMS_ACCEPTED` | Aceptación de una versión de los términos | `Aceptó los términos 1.0` |

## Columnas nuevas en tablas existentes

| Tabla | Columna | Tipo | Reglas |
|-------|---------|------|--------|
| `order_services` | `service_type_id` | `INT UNSIGNED NULL` | Llave foránea a `service_types(id)` con `ON DELETE RESTRICT`; las líneas existentes quedan en `NULL`; `KEY idx_order_services_type (service_type_id)` |
| `users` | `last_activity_at` | `DATETIME NULL` | Última actividad autenticada; `NULL` se trata como activa; la actualiza `authenticate` como máximo una vez por minuto |

## Entidades calculadas (no se guardan)

### Reportes

Todos reciben `from` y `to` (`AAAA-MM-DD`, `to >= from`, máximo 366 días, fecha local del servidor) y devuelven los
importes como cadenas con dos decimales calculadas desde centavos enteros.

| Reporte | Filas y totales |
|---------|-----------------|
| **Ingresos** | Pagos `PAGADO` con `paid_at` en el rango: `total`, `paymentsCount`, `byMethod[]` (método, pagos, total) y `byDay[]` (día, pagos, total) |
| **Servicios frecuentes** | Servicios de órdenes terminadas en el rango, agrupados por tipo (o por descripción si no tienen tipo): `name`, `times`, `amount` |
| **Productividad** | Por mecánico: `ordersFinished`, `laborAmount`; las órdenes sin mecánico no se atribuyen |
| **Refacciones** | Por refacción: `units`, `revenue` (suma de `quantity × unit_price`), `cost` (suma de `quantity × purchase_price` actual), `margin`, `marginPercent` y `noCost` (verdadero si no hay precio de compra); `totals` sin las líneas «Sin costo» en el margen |
| **Rotación** | Por refacción: `out` (suma de salidas `OUT`), `stockStart`, `stockEnd`, `averageStock` y `rotation` (`out / averageStock`, nulo si el promedio es cero) |

**Fecha de una orden terminada**: la del último cambio a `TERMINADO` del historial (o `updated_at` si no hay historial).

### Próximo mantenimiento propuesto

`{ dueDate, dueMileage, basedOn[] }`: de los tipos de servicio con intervalo de las líneas de la orden, el intervalo más
corto de cada eje; `dueDate = hoy + interval_days`; `dueMileage = kilometraje del servicio (o actual) + interval_km`.

### Ticket con próximo servicio

`tickets.content` (`formatVersion: 3`) agrega `nextService: { dueDate, dueMileage, description }` solo si la orden tiene un
mantenimiento pendiente propio al emitir el ticket. Los tickets de versión 1 y 2 no cambian.

## Reglas y transiciones

| Regla | Detalle |
|-------|---------|
| Configuración | Se guarda por clave; guardar un campo no cambia los demás; sin valor guardado se usa `.env` o el predeterminado |
| Tipo de servicio | `activo → desactivado → activo`; nunca se borra; el nombre es único sin distinguir mayúsculas |
| Términos | La versión vigente es la más reciente; un usuario está «al día» si tiene aceptación de esa versión; publicar una versión nueva deja a todos «sin aceptar» |
| Sesión | Inactiva si `last_activity_at` es anterior a 30 minutos; el inicio de sesión la fija |
| Bitácora | Solo inserción; se consulta por fecha, usuario y acción, de la más reciente a la más antigua |
| Visibilidad | Configuración, catálogo (gestión), reportes, bitácora y aceptaciones: solo ADMIN; términos vigentes y aceptar: todo usuario autenticado; tipos activos para las líneas: ADMIN y MECHANIC |

## Impacto sobre datos existentes

- Ninguna fila existente cambia; las dos columnas nuevas quedan en `NULL`.
- Todos los usuarios existentes quedan sin aceptación de la versión `1.0` y la aceptan en su siguiente ingreso.
- Los pagos, tickets, órdenes y mantenimientos anteriores se leen igual en los reportes y en las pantallas.
