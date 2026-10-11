# Modelo de datos: Base del sistema, clientes y vehículos (Sprint 1)

**Motor**: MySQL 8.0, InnoDB, `utf8mb4` (intercolado `utf8mb4_0900_ai_ci`, no distingue mayúsculas
ni acentos). Los identificadores de tabla y columna van en inglés (`snake_case`); en la API se
exponen en `camelCase`. Script: `database/migrations/001_sprint1_users_clients_vehicles.sql`.

## Diagrama de relaciones

```text
users                       (sin relaciones en el Sprint 1)

clients 1 ───────< vehicles   (un cliente tiene cero o más vehículos;
                               un vehículo pertenece a exactamente un cliente)

schema_migrations           (control interno de migraciones aplicadas)
```

## Tabla `users` (Usuario)

| Columna | Tipo | Restricciones | Notas |
|---------|------|---------------|-------|
| `id` | INT UNSIGNED | PK, AUTO_INCREMENT | |
| `username` | VARCHAR(50) | NOT NULL, UNIQUE | 3–50 caracteres; letras, números, `.`, `_`, `-`; sin `@` para no confundirse con un correo |
| `name` | VARCHAR(120) | NOT NULL | Nombre para mostrar |
| `email` | VARCHAR(254) | NOT NULL, UNIQUE | Formato de correo válido; se guarda en minúsculas |
| `password_hash` | VARCHAR(100) | NOT NULL | Hash bcrypt; nunca se devuelve en la API |
| `role` | ENUM('ADMIN','RECEPTIONIST','MECHANIC') | NOT NULL | |
| `active` | TINYINT(1) | NOT NULL, DEFAULT 1 | Los usuarios se desactivan, no se eliminan |
| `failed_login_attempts` | TINYINT UNSIGNED | NOT NULL, DEFAULT 0 | Contador de fallos consecutivos |
| `locked_until` | DATETIME | NULL | Bloqueo temporal por fallos |
| `created_at` | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | |
| `updated_at` | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | |

**Reglas de validación**
- Contraseña: mínimo 8 caracteres con al menos una mayúscula, una minúscula y un número (FR-007);
  aplica a altas y cambios, no a las cuentas iniciales sembradas.
- Un cambio de contraseña exige la contraseña actual y que la nueva sea distinta.
- Siempre debe existir al menos un usuario `ADMIN` activo (FR-017).
- Cuentas con `active = 0` no pueden iniciar sesión ni usar un token vigente.

**Transiciones de estado**
- `active`: 1 ⇄ 0 (solo ADMIN). `role`: cualquier cambio entre los tres roles (solo ADMIN).
- `locked_until`: se fija a ahora + 15 min al llegar a 5 fallos; se limpia con un acceso correcto.

## Tabla `clients` (Cliente)

| Columna | Tipo | Restricciones | Notas |
|---------|------|---------------|-------|
| `id` | INT UNSIGNED | PK, AUTO_INCREMENT | |
| `name` | VARCHAR(120) | NOT NULL | Nombre completo |
| `phone` | VARCHAR(20) | NOT NULL | Dígitos con `+`, espacios, guiones o paréntesis; mínimo 7 dígitos. **No único**: un duplicado genera advertencia |
| `email` | VARCHAR(254) | NULL, UNIQUE | Opcional; vacío se guarda como `NULL`; minúsculas |
| `address` | VARCHAR(255) | NULL | Opcional |
| `active` | TINYINT(1) | NOT NULL, DEFAULT 1 | Reservado; no hay baja en este sprint |
| `created_at` / `updated_at` | DATETIME | igual que `users` | |

**Índices**: `idx_clients_name (name)`, `idx_clients_phone (phone)`.

**Reglas**
- Teléfono ya presente en otro cliente → advertencia y confirmación (D-10).
- Correo ya presente → rechazo.
- Sin eliminación en este sprint.

## Tabla `vehicles` (Vehículo)

| Columna | Tipo | Restricciones | Notas |
|---------|------|---------------|-------|
| `id` | INT UNSIGNED | PK, AUTO_INCREMENT | |
| `client_id` | INT UNSIGNED | NOT NULL, FK → `clients(id)` ON DELETE RESTRICT ON UPDATE CASCADE | Propietario obligatorio (RN-1) |
| `brand` | VARCHAR(60) | NOT NULL | |
| `model` | VARCHAR(60) | NOT NULL | |
| `year` | SMALLINT UNSIGNED | NOT NULL | De 1950 al año actual + 1 |
| `license_plate` | VARCHAR(15) | NOT NULL, UNIQUE | Recortada y en mayúsculas |
| `vin` | VARCHAR(17) | NULL, UNIQUE | Opcional; 17 caracteres alfanuméricos sin I, O, Q; único si se captura |
| `color` | VARCHAR(40) | NULL | Opcional |
| `current_mileage` | INT UNSIGNED | NULL | Opcional; ver regla de kilometraje |
| `created_at` / `updated_at` | DATETIME | igual que `users` | |

**Índices**: `idx_vehicles_client (client_id)` (lo crea la FK), `idx_vehicles_brand_model (brand, model)`.

**Reglas**
- No existe vehículo sin propietario ni con propietario inexistente (la FK y el servicio lo garantizan).
- Cambiar `client_id` mueve el vehículo al nuevo cliente; el anterior deja de listarlo.
- `current_mileage` no puede disminuir salvo corrección explícita (`mileageCorrection`) (D-11).
- Sin eliminación en este sprint.

## Tabla `schema_migrations` (control interno)

| Columna | Tipo | Restricciones |
|---------|------|---------------|
| `version` | VARCHAR(100) | PK (nombre del script, por ejemplo `001_sprint1_users_clients_vehicles`) |
| `applied_at` | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP |

## Datos de ejemplo (`database/seeds/001_initial_data.sql`)

Idempotentes mediante las claves únicas (`username`, `email`, `license_plate`):

- **Usuarios**: `admin` (ADMIN), `recepcion` (RECEPTIONIST) y `mecanico` (MECHANIC), con los
  correos de ejemplo `admin@motorix.local`, `recepcion@motorix.local` y `mecanico@motorix.local` y
  el hash bcrypt de la contraseña del estándar (nunca texto plano).
- **Clientes**: al menos 8 clientes de ejemplo, incluyendo uno sin correo y dos que comparten
  teléfono, para ejercitar la advertencia de duplicado.
- **Vehículos**: al menos 12 vehículos repartidos entre los clientes (uno con varios vehículos y
  uno sin VIN ni kilometraje).
- Cada vehículo se vincula a su cliente por una búsqueda de su correo o teléfono único de ejemplo
  dentro del propio script, sin depender de identificadores fijos.
