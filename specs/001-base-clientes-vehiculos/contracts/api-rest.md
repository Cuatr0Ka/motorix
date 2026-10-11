# Contrato de la API REST (Sprint 1)

**Base**: `/api` | **Formato**: JSON UTF-8 | **Autenticación**: `Authorization: Bearer <token>` en
todas las rutas salvo `POST /api/auth/login`.

## Convenciones

**Respuesta exitosa**

```json
{ "data": { }, "meta": { "page": 1, "pageSize": 20, "total": 134 } }
```

`meta` solo aparece en listados. Las fechas viajan en ISO 8601 (UTC).

**Respuesta de error** (sin trazas internas; mensajes en español)

```json
{ "error": { "code": "VALIDATION_ERROR", "message": "Revisa los campos marcados.", "details": [ { "field": "email", "message": "El correo no es válido." } ] } }
```

| Estado | Uso |
|--------|-----|
| 200 / 201 | Operación correcta / recurso creado |
| 400 | Cuerpo o parámetros inválidos (`VALIDATION_ERROR`) |
| 401 | Credenciales inválidas, token ausente, inválido o expirado, o cuenta desactivada (`UNAUTHENTICATED`, `INVALID_CREDENTIALS`) |
| 403 | Rol sin permiso (`FORBIDDEN`) |
| 404 | Recurso inexistente (`NOT_FOUND`) |
| 409 | Duplicado o conflicto de negocio (`EMAIL_DUPLICATE`, `PHONE_DUPLICATE`, `USERNAME_DUPLICATE`, `PLATE_DUPLICATE`, `VIN_DUPLICATE`, `LAST_ADMIN`) |
| 422 | Regla de negocio incumplida (`OWNER_NOT_FOUND`, `MILEAGE_DECREASE`, `PASSWORD_POLICY`, `SAME_PASSWORD`) |
| 423 | Cuenta bloqueada temporalmente (`ACCOUNT_LOCKED`) |
| 500 | Error interno genérico (`INTERNAL_ERROR`) |

**Matriz de permisos**

| Recurso / acción | ADMIN | RECEPTIONIST | MECHANIC |
|------------------|:-----:|:------------:|:--------:|
| Auth: login, perfil, cambiar contraseña propia | ✔ | ✔ | ✔ |
| Usuarios: listar, ver, crear, editar rol/estado | ✔ | ✘ | ✘ |
| Clientes: listar y ver | ✔ | ✔ | ✔ |
| Clientes: crear y editar | ✔ | ✔ | ✘ |
| Vehículos: listar y ver | ✔ | ✔ | ✔ |
| Vehículos: crear y editar (incluye cambio de propietario) | ✔ | ✔ | ✘ |

## Autenticación

### `POST /api/auth/login`

Cuerpo: `{ "identifier": "recepcion", "password": "..." }` — `identifier` es usuario o correo.

- `200`: `{ "data": { "token": "...", "expiresIn": 28800, "user": { "id", "username", "name", "email", "role" } } }`
- `401 INVALID_CREDENTIALS`: mensaje genérico, también para cuentas inexistentes o desactivadas.
- `423 ACCOUNT_LOCKED`: tras 5 fallos consecutivos; incluye `details.retryAfterSeconds`.

### `GET /api/auth/me`

`200`: `{ "data": { "id", "username", "name", "email", "role" } }` con el rol vigente.

### `POST /api/auth/change-password`

Cuerpo: `{ "currentPassword": "...", "newPassword": "..." }`

- `200`: `{ "data": { "changed": true } }`
- `401 INVALID_CREDENTIALS` si la contraseña actual es incorrecta; `422 PASSWORD_POLICY` si la
  nueva no cumple la política; `422 SAME_PASSWORD` si es igual a la actual.

## Usuarios (solo ADMIN)

### `GET /api/users?search=&role=&active=&page=&pageSize=`

`200`: lista de usuarios `{ id, username, name, email, role, active, createdAt }`.

### `POST /api/users`

Cuerpo: `{ "username", "name", "email", "role", "password" }`. `201` con el usuario creado.
Errores: `409 USERNAME_DUPLICATE` / `EMAIL_DUPLICATE`, `422 PASSWORD_POLICY`.

### `GET /api/users/:id` — `200` con el usuario; `404`.

### `PATCH /api/users/:id`

Cuerpo parcial: `{ "name?", "email?", "role?", "active?" }`. `200` con el usuario actualizado.
Errores: `409 LAST_ADMIN` si dejaría el sistema sin administrador activo; `409 EMAIL_DUPLICATE`.
El cambio de rol o estado rige desde la siguiente petición de esa persona.

## Clientes

### `GET /api/clients?search=&page=&pageSize=`

`search` filtra por nombre o teléfono. `200`: `{ id, name, phone, email, address, vehicleCount, createdAt }[]`.

### `POST /api/clients` (ADMIN, RECEPTIONIST)

Cuerpo: `{ "name", "phone", "email?", "address?", "confirmDuplicatePhone?": false }`

- `201`: cliente creado.
- `409 PHONE_DUPLICATE`: `details.matches = [{ id, name, phone }]`; se repite con
  `"confirmDuplicatePhone": true` para guardar de todos modos.
- `409 EMAIL_DUPLICATE`: no se puede confirmar.

### `GET /api/clients/:id`

`200`: cliente con sus vehículos:

```json
{ "data": { "id": 1, "name": "…", "phone": "…", "email": null, "address": null,
            "vehicles": [ { "id": 3, "brand": "…", "model": "…", "year": 2019, "licensePlate": "ABC123", "currentMileage": 84500 } ] } }
```

### `PATCH /api/clients/:id` (ADMIN, RECEPTIONIST)

Cuerpo parcial con los mismos campos y la misma regla de duplicados (`confirmDuplicatePhone`).
`200` con el cliente actualizado; un cambio inválido no modifica nada.

## Vehículos

### `GET /api/vehicles?search=&clientId=&page=&pageSize=`

`search` filtra por placa, marca, modelo o nombre del propietario.
`200`: `{ id, brand, model, year, licensePlate, vin, color, currentMileage, client: { id, name } }[]`.

### `POST /api/vehicles` (ADMIN, RECEPTIONIST)

Cuerpo: `{ "clientId", "brand", "model", "year", "licensePlate", "vin?", "color?", "currentMileage?" }`

- `201`: vehículo creado.
- `422 OWNER_NOT_FOUND`: `clientId` ausente o inexistente.
- `409 PLATE_DUPLICATE` / `VIN_DUPLICATE`.

### `GET /api/vehicles/:id`

`200`: vehículo con `client: { id, name, phone }`; `404`.

### `PATCH /api/vehicles/:id` (ADMIN, RECEPTIONIST)

Cuerpo parcial; `clientId` cambia el propietario (debe existir: `422 OWNER_NOT_FOUND`).
`currentMileage` menor al actual → `422 MILEAGE_DECREASE`, salvo con `"mileageCorrection": true`.
`200` con el vehículo actualizado.

## Pruebas de contrato

Cada endpoint tiene al menos una prueba que verifica: forma de la respuesta exitosa, un caso de
error de validación, y el rechazo `401` sin token y `403` para un rol no autorizado. Las pruebas
viven en `server/tests/contract/` y se ejecutan contra `motorix_test`.
