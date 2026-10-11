---

description: "Lista de tareas del Sprint 1: base del sistema, clientes y vehÃ­culos"
---

# Tareas: Base del sistema, clientes y vehÃ­culos (Sprint 1)

**Entrada**: Documentos de diseÃ±o en `specs/001-base-clientes-vehiculos/`

**Requisitos previos**: plan.md, spec.md, research.md, data-model.md, contracts/ (api-rest.md e interfaz.md), quickstart.md

**Pruebas**: INCLUIDAS. La constituciÃ³n (Principio VII) exige pruebas para la lÃ³gica de negocio y los permisos; las del backend usan Jest + supertest contra `motorix_test` y las del frontend `flutter test`.

**OrganizaciÃ³n**: Las tareas se agrupan por historia de usuario para poder implementar y probar cada una de forma independiente.

## Formato: `[ID] [P?] [Historia] DescripciÃ³n`

- **[P]**: se puede ejecutar en paralelo (archivos distintos, sin dependencias pendientes)
- **[USn]**: historia de usuario a la que pertenece la tarea (US1 a US6 de spec.md)
- Todas las rutas son relativas a la raÃ­z del repositorio (`D:\sdd\motorix`)

## Convenciones de rutas

- Backend: `server/` (capas directamente en la raÃ­z de `server/`, sin carpeta `src/`)
- Frontend: `client/lib/` y `client/test/`
- Base de datos: `database/`
- El cÃ³digo backend usa ES Modules (`import`/`export`); los identificadores van en inglÃ©s y los comentarios, mensajes y nombres de pruebas en espaÃ±ol

## Orden de las historias (prioridad)

P1: US1 (iniciar sesiÃ³n), US3 (registrar y consultar clientes), US5 (registrar vehÃ­culos), US6 (asociar vehÃ­culo con propietario). P2: US2 (usuarios y roles), US4 (editar clientes).

---

## Fase 1: PreparaciÃ³n (infraestructura compartida)

**PropÃ³sito**: inicializaciÃ³n del proyecto y estructura base

- [X] T001 Crear la estructura de carpetas del plan: `client/`, `server/{config,controllers,models,routes,services,middlewares,validators,utils,tests/unit,tests/integration,tests/contract}`, `database/{migrations,seeds,scripts}` (con archivos `.gitkeep` donde estÃ©n vacÃ­as)
- [X] T002 [P] Crear `.gitignore` (ignorar `.env`, `node_modules/`, `database/data/`, `client/build/`, `server/coverage/`) y `.env.example` con `DB_HOST=localhost`, `DB_PORT=3306`, `DB_USER=motorix_app`, `DB_PASSWORD=`, `DB_NAME=motorix`, `DB_NAME_TEST=motorix_test`, `JWT_SECRET=` y `PORT=3000`, sin valores sensibles
- [X] T003 [P] Crear `server/package.json` con `"type": "module"`, dependencias `express`, `mysql2`, `jsonwebtoken`, `bcryptjs`, `zod`, `cors`, `helmet`, `dotenv`, dependencias de desarrollo `jest`, `supertest`, y scripts `dev`, `start` y `test` (`node --experimental-vm-modules node_modules/jest/bin/jest.js`)
- [X] T004 [P] Crear `server/jest.config.js` (ESM, `testEnvironment: node`, `setupFilesAfterEnv` apuntando a `server/tests/helpers/setup.js`, ejecuciÃ³n en serie con `maxWorkers: 1` porque comparten `motorix_test`)
- [X] T005 [P] Crear el proyecto Flutter en `client/` con soporte de Windows (`flutter create --platforms=windows client`) y declarar en `client/pubspec.yaml` las dependencias `provider`, `http`, `google_fonts` y `data_table_2` (versiÃ³n compatible con Flutter 3.47; verificar al instalar)
- [X] T006 [P] Crear `README.md` en la raÃ­z en espaÃ±ol con descripciÃ³n del proyecto, requisitos previos y enlace a `specs/001-base-clientes-vehiculos/quickstart.md`
- [X] T007 Actualizar `specs/001-base-clientes-vehiculos/spec.md` para aÃ±adir el bloqueo temporal de cuenta (5 intentos fallidos consecutivos, 15 minutos) a FR-008, segÃºn research.md D-09

---

## Fase 2: Fundamentos (requisitos bloqueantes)

**PropÃ³sito**: infraestructura central que DEBE estar completa antes de cualquier historia de usuario

**âš ï¸ CRÃTICO**: ninguna historia puede empezar hasta terminar esta fase

### Base de datos

- [X] T008 Crear `database/migrations/001_sprint1_users_clients_vehicles.sql` con las tablas InnoDB `utf8mb4` de data-model.md: `users` (`username` VARCHAR(50) NOT NULL UNIQUE; `name` VARCHAR(120) NOT NULL; `email` VARCHAR(254) NOT NULL UNIQUE; `password_hash` VARCHAR(100) NOT NULL; `role` ENUM('ADMIN','RECEPTIONIST','MECHANIC') NOT NULL; `active` TINYINT(1) NOT NULL DEFAULT 1; `failed_login_attempts` TINYINT UNSIGNED NOT NULL DEFAULT 0; `locked_until` DATETIME NULL), `clients` (`name` VARCHAR(120) NOT NULL; `phone` VARCHAR(20) NOT NULL no Ãºnico; `email` VARCHAR(254) NULL UNIQUE; `address` VARCHAR(255) NULL; `active` TINYINT(1) NOT NULL DEFAULT 1; Ã­ndices `idx_clients_name` e `idx_clients_phone`) y `vehicles` (`client_id` INT UNSIGNED NOT NULL FK â†’ `clients(id)` ON DELETE RESTRICT ON UPDATE CASCADE; `brand` VARCHAR(60) NOT NULL; `model` VARCHAR(60) NOT NULL; `year` SMALLINT UNSIGNED NOT NULL; `license_plate` VARCHAR(15) NOT NULL UNIQUE; `vin` VARCHAR(17) NULL UNIQUE; `color` VARCHAR(40) NULL; `current_mileage` INT UNSIGNED NULL; Ã­ndice `idx_vehicles_brand_model`), todas con `id` INT UNSIGNED AUTO_INCREMENT, `created_at` y `updated_at` DATETIME NOT NULL con `DEFAULT CURRENT_TIMESTAMP` (y `ON UPDATE CURRENT_TIMESTAMP` en `updated_at`)
- [X] T009 [P] Crear `database/scripts/crear-entorno.ps1`: crea las bases `motorix` y `motorix_test` con `utf8mb4` y el usuario dedicado `motorix_app` (NUNCA `root`) con permisos solo sobre ellas; pide la contraseÃ±a por consola, sin guardarla en archivos versionados
- [X] T010 Crear `database/scripts/aplicar-migraciones.ps1` con parÃ¡metro `-Base`: crea `schema_migrations` (`version` VARCHAR(100) PK, `applied_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP), aplica en orden los scripts de `database/migrations/` no registrados y es idempotente
- [X] T011 Generar con `bcryptjs` (costo 10) el hash de las contraseÃ±as del estÃ¡ndar de `docs/project-context.md` Â§5 (sin escribirlas en ningÃºn archivo del repositorio) y crear `database/seeds/001_initial_data.sql`, idempotente por claves Ãºnicas (`username`, `email`, `license_plate`): usuarios `admin`, `recepcion` y `mecanico` con correos `admin@motorix.local`, `recepcion@motorix.local`, `mecanico@motorix.local`; al menos 8 clientes (uno sin correo, dos con el mismo telÃ©fono); al menos 12 vehÃ­culos repartidos entre ellos (uno con varios vehÃ­culos y otro sin VIN ni kilometraje), vinculados por bÃºsqueda de correo o telÃ©fono, sin identificadores fijos
- [X] T012 [P] Crear `database/scripts/aplicar-seeds.ps1` con parÃ¡metro `-Base` que ejecuta los seeds de `database/seeds/` de forma repetible
- [X] T013 [P] Crear `database/scripts/reiniciar-local.ps1` que elimina y recrea la base indicada, aplica migraciones y seeds
- [X] T014 [P] Crear `database/README.md` en espaÃ±ol: cÃ³mo crear, migrar, sembrar y reiniciar la base local, y la regla de no editar scripts ya aplicados

### Backend base

- [X] T015 Crear `server/config/env.js`: carga `dotenv`, valida `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `JWT_SECRET`, `PORT`; con `NODE_ENV=test` usa `DB_NAME_TEST` y aborta si el nombre de la base no termina en `_test`; rechaza `DB_USER=root`
- [X] T016 [P] Crear `server/config/db.js`: pool `mysql2/promise` con `utf8mb4`, consultas parametrizadas y helper de transacciÃ³n
- [X] T017 [P] Crear `server/utils/AppError.js` (cÃ³digo estable, estado HTTP, mensaje en espaÃ±ol, detalles opcionales) y `server/utils/response.js` (`ok(res, data, meta)` con el formato `{ data, meta }`)
- [X] T018 [P] Crear `server/utils/normalize.js`: recorte de espacios, correo en minÃºsculas con vacÃ­o â†’ `NULL`, placa recortada en mayÃºsculas, conversiÃ³n `snake_case` â†” `camelCase`
- [X] T019 [P] Crear `server/utils/jwt.js`: firma HS256 de 8 horas con payload solo `sub` (id de usuario) y verificaciÃ³n
- [X] T020 Crear `server/middlewares/errorHandler.js`: respuesta `{ "error": { "code", "message", "details?" } }`, traduce errores de zod y de clave duplicada de MySQL, 404 para rutas inexistentes y `INTERNAL_ERROR` genÃ©rico sin trazas ni mensajes del motor
- [X] T021 [P] Crear `server/middlewares/validate.js` que valida `body`, `query` y `params` con esquemas `zod` y produce `VALIDATION_ERROR` con `details` por campo
- [X] T022 Crear `server/models/userModel.js` con las consultas de lectura `findById` y `findByIdentifier` (contiene `@` â†’ correo; si no, `username`) y el mapeo a `camelCase` sin exponer `password_hash` fuera del modelo
- [X] T023 Crear `server/middlewares/authenticate.js`: valida el token, consulta el usuario en la base en CADA peticiÃ³n y rechaza con `401 UNAUTHENTICATED` si falta, es invÃ¡lido, expirÃ³ o la cuenta estÃ¡ inactiva; deja `req.user` con el rol vigente
- [X] T024 [P] Crear `server/middlewares/authorize.js` (`authorize(...roles)`) que responde `403 FORBIDDEN` segÃºn la matriz de permisos de contracts/api-rest.md
- [X] T025 Crear `server/app.js` (helmet, cors, `express.json`, rutas bajo `/api`, `errorHandler`; sin escuchar puerto), `server/routes/index.js` y `server/server.js` (lee `PORT` y arranca)
- [X] T026 [P] Crear `server/tests/helpers/setup.js` y `server/tests/helpers/factories.js`: vaciar tablas entre pruebas, crear usuarios por rol con contraseÃ±a conocida de prueba, emitir tokens, crear clientes y vehÃ­culos; abortar si la base no es `motorix_test`
- [X] T027 [P] Crear pruebas unitarias en `server/tests/unit/authorize.test.js` y `server/tests/unit/errorHandler.test.js` (nombres en espaÃ±ol, p. ej. `test_rechaza_rol_no_autorizado`; el manejador nunca devuelve trazas)
- [X] T028 [P] Crear `server/tests/unit/esm.test.js` que verifica que `server/package.json` declara `"type": "module"` y que ningÃºn `.js` bajo `server/` usa `require(` ni `module.exports` (CA-5)

### Frontend base

- [X] T029 [P] Crear `client/lib/utils/app_theme.dart` y `client/lib/utils/tokens.dart`: `ThemeData` propio de Material 3 (`useMaterial3: true`) con el `ColorScheme` de docs/design-system.md Â§4, paleta Â§5, IBM Plex Sans con la escala 12/14/18/28, espaciado 4/8/12/16/24/32, radios 6/8/12, y configuraciÃ³n de `NavigationRailThemeData`, `DataTableThemeData`, `ChipThemeData`, `InputDecorationTheme`, botones, `DividerThemeData`, `TooltipThemeData` y `PageTransitionsTheme` (150/200/250 ms con `Curves.easeInOut`)
- [X] T030 [P] Crear `client/lib/services/api_client.dart`: cliente `http` con `API_BASE_URL` (`--dart-define`), cabecera `Authorization`, decodificaciÃ³n de `{ data, meta }`, `ApiException` (cÃ³digo, mensaje, detalles) y cierre de sesiÃ³n ante `401`
- [X] T031 [P] Crear `client/lib/widgets/confirm_dialog.dart`: diÃ¡logo con botones "Confirmar" y "Cancelar" (docs/design-system.md Â§8.5)
- [X] T032 [P] Crear `client/lib/widgets/state_views.dart` (vista vacÃ­a con acciÃ³n sugerida, cargando, error en espaÃ±ol) y un helper de *snackbar* de Ã©xito

**Punto de control**: base lista; ya se pueden empezar las historias de usuario

---

## Fase 3: Historia de usuario 1 - Iniciar sesiÃ³n segÃºn mi rol (Prioridad: P1) ðŸŽ¯ MVP

**Meta**: iniciar sesiÃ³n con usuario o correo y entrar a una aplicaciÃ³n con menÃº segÃºn el rol; los permisos se aplican en cada peticiÃ³n.

**Prueba independiente**: iniciar sesiÃ³n con las tres cuentas sembradas, con usuario y con correo, y verificar que cada una ve solo lo permitido; credenciales invÃ¡lidas, cuenta inactiva y bloqueo por intentos se rechazan.

### Pruebas de la historia 1

> **NOTA**: escribirlas primero y comprobar que FALLAN antes de implementar

- [X] T033 [P] [US1] Prueba de contrato de `POST /api/auth/login` y `GET /api/auth/me` en `server/tests/contract/auth.contract.test.js` (forma de la respuesta `{ token, expiresIn, user }`, `400` por validaciÃ³n, `401` sin token)
- [X] T034 [P] [US1] Prueba de integraciÃ³n en `server/tests/integration/auth.flow.test.js`: login por usuario y por correo (misma contraseÃ±a), contraseÃ±a incorrecta con mensaje genÃ©rico, cuenta inexistente igual que incorrecta, cuenta inactiva rechazada, token vencido, y cambio de rol o desactivaciÃ³n con sesiÃ³n abierta efectivo en la siguiente peticiÃ³n
- [X] T035 [P] [US1] Prueba unitaria de bloqueo en `server/tests/unit/authService.test.js`: el 5.Âº fallo consecutivo bloquea 15 minutos (`423 ACCOUNT_LOCKED` con `retryAfterSeconds`) y un acceso correcto reinicia el contador

### ImplementaciÃ³n de la historia 1

- [X] T036 [P] [US1] Crear `server/validators/authValidators.js` con el esquema de login (`identifier` y `password` obligatorios, recortados)
- [X] T037 [US1] Ampliar `server/models/userModel.js` con `registerFailedAttempt`, `lockUntil` y `resetFailures` (depende de T022)
- [X] T038 [US1] Crear `server/services/authService.js`: `login` (busca por usuario o correo, compara con bcrypt, bloqueo tras 5 fallos por 15 minutos, mensaje genÃ©rico `INVALID_CREDENTIALS`, rechaza cuentas inactivas) y `getProfile`
- [X] T039 [US1] Crear `server/controllers/authController.js` y `server/routes/authRoutes.js` (`POST /api/auth/login` pÃºblico, `GET /api/auth/me` autenticado) y montar en `server/routes/index.js`
- [X] T040 [P] [US1] Crear `client/lib/models/user.dart` y `client/lib/services/auth_service.dart` (login y perfil)
- [X] T041 [US1] Crear `client/lib/providers/session_provider.dart`: token solo en memoria, usuario y rol, inicio y cierre de sesiÃ³n, expiraciÃ³n
- [X] T042 [P] [US1] Crear `client/lib/providers/sidebar_provider.dart` (expandido/colapsado, colapsado por defecto bajo ~1000 px)
- [X] T043 [US1] Crear `client/lib/widgets/app_shell.dart`: sidebar con `NavigationRail` (260 px/72 px, animaciÃ³n de 200 ms), encabezado con tÃ­tulo de secciÃ³n, nombre y rol, opciones por rol segÃºn contracts/interfaz.md y "Cerrar sesiÃ³n" con confirmaciÃ³n
- [X] T044 [US1] Crear `client/lib/screens/login_screen.dart`: campo "Usuario o correo", contraseÃ±a, estados cargando, error genÃ©rico y cuenta bloqueada
- [X] T045 [P] [US1] Crear `client/lib/screens/home_screen.dart`: bienvenida con nombre y rol y accesos directos a las secciones permitidas (sin indicadores)
- [X] T046 [US1] Configurar `client/lib/main.dart`: `MultiProvider`, tema, rutas protegidas por sesiÃ³n y pantalla inicial Inicio
- [X] T047 [P] [US1] Pruebas de widgets en `client/test/login_screen_test.dart` y `client/test/app_shell_test.dart` (menÃº por rol, confirmaciÃ³n al cerrar sesiÃ³n)

**Punto de control**: la historia 1 es funcional y probable de forma independiente

---

## Fase 4: Historia de usuario 3 - Registrar y consultar clientes (Prioridad: P1)

**Meta**: registrar clientes, buscarlos y consultar su detalle con sus vehÃ­culos.

**Prueba independiente**: con la sesiÃ³n de recepcionista, registrar un cliente, buscarlo por nombre o telÃ©fono y abrir su detalle; el mecÃ¡nico solo consulta.

### Pruebas de la historia 3

- [X] T048 [P] [US3] Prueba de contrato de `GET /api/clients`, `POST /api/clients` y `GET /api/clients/:id` en `server/tests/contract/clients.contract.test.js` (forma, `400`, `401`, `403` para mecÃ¡nico en `POST`)
- [X] T049 [P] [US3] Prueba de integraciÃ³n en `server/tests/integration/clients.flow.test.js`: bÃºsqueda por nombre y por telÃ©fono, paginaciÃ³n, `409 PHONE_DUPLICATE` con coincidencias y guardado con `confirmDuplicatePhone: true`, `409 EMAIL_DUPLICATE` sin posibilidad de confirmar, correo vacÃ­o guardado como `NULL`, detalle con vehÃ­culos asociados

### ImplementaciÃ³n de la historia 3

- [X] T050 [P] [US3] Crear `server/validators/clientValidators.js`: `name` obligatorio (mÃ¡x. 120), `phone` obligatorio (mÃ¡x. 20, "DÃ­gitos con `+`, espacios, guiones o parÃ©ntesis; mÃ­nimo 7 dÃ­gitos"), `email` opcional con formato vÃ¡lido (mÃ¡x. 254), `address` opcional (mÃ¡x. 255), `confirmDuplicatePhone` booleano opcional, y parÃ¡metros de listado (`search`, `page`, `pageSize` 20 por defecto y mÃ¡ximo 100)
- [X] T051 [US3] Crear `server/models/clientModel.js`: listado con bÃºsqueda `LIKE` por nombre o telÃ©fono y conteo de vehÃ­culos, `findById` con sus vehÃ­culos, `findByPhone`, `create` (consultas parametrizadas)
- [X] T052 [US3] Crear `server/services/clientService.js`: `list`, `getById`, `create` con normalizaciÃ³n, regla de telÃ©fono duplicado (advertencia confirmable) y correo duplicado (rechazo)
- [X] T053 [US3] Crear `server/controllers/clientController.js` y `server/routes/clientRoutes.js`: `GET` (todos los roles), `POST` (ADMIN, RECEPTIONIST) y `GET /:id`; montar en `server/routes/index.js`
- [X] T054 [P] [US3] Crear `client/lib/models/client.dart` y `client/lib/services/clients_service.dart`
- [X] T055 [P] [US3] Crear `client/lib/widgets/app_data_table.dart`: tabla densa con `data_table_2`, bÃºsqueda, paginaciÃ³n, chips y acciones al final, con hover suave
- [X] T056 [US3] Crear `client/lib/providers/clients_provider.dart` (listado, bÃºsqueda, paginaciÃ³n, estados)
- [X] T057 [US3] Crear `client/lib/screens/clients_list_screen.dart` con estados vacÃ­o, cargando, error y sin resultados; "Nuevo cliente" oculto para MECHANIC
- [X] T058 [US3] Crear `client/lib/screens/client_form_screen.dart` (alta): validaciÃ³n por campo, diÃ¡logo de telÃ©fono duplicado con coincidencias y confirmaciÃ³n de salida con cambios sin guardar
- [X] T059 [US3] Crear `client/lib/screens/client_detail_screen.dart` con datos del cliente y tabla de sus vehÃ­culos (vista vacÃ­a si no tiene)
- [X] T060 [P] [US3] Pruebas de widgets en `client/test/clients_screens_test.dart` (estados, diÃ¡logo de duplicado, ausencia de acciones de alta para mecÃ¡nico)

**Punto de control**: las historias 1 y 3 funcionan de forma independiente

---

## Fase 5: Historia de usuario 5 - Registrar vehÃ­culos (Prioridad: P1)

**Meta**: registrar y consultar vehÃ­culos con propietario obligatorio.

**Prueba independiente**: registrar un vehÃ­culo con sus datos y verlo en el listado; la placa repetida y los datos invÃ¡lidos se rechazan.

### Pruebas de la historia 5

- [X] T061 [P] [US5] Prueba de contrato de `GET /api/vehicles`, `POST /api/vehicles` y `GET /api/vehicles/:id` en `server/tests/contract/vehicles.contract.test.js` (forma, `400`, `401`, `403` para mecÃ¡nico en `POST`)
- [X] T062 [P] [US5] Prueba de integraciÃ³n en `server/tests/integration/vehicles.flow.test.js`: `422 OWNER_NOT_FOUND` sin propietario o con propietario inexistente, `409 PLATE_DUPLICATE` (tambiÃ©n con distinta capitalizaciÃ³n), `409 VIN_DUPLICATE`, aÃ±o fuera de rango, bÃºsqueda por placa, marca, modelo y propietario, filtro `clientId`

### ImplementaciÃ³n de la historia 5

- [X] T063 [P] [US5] Crear `server/validators/vehicleValidators.js`: `clientId` obligatorio, `brand` y `model` obligatorios (mÃ¡x. 60), `year` obligatorio ("De 1950 al aÃ±o actual + 1"), `licensePlate` obligatoria (mÃ¡x. 15), `vin` opcional ("17 caracteres alfanumÃ©ricos sin I, O, Q"), `color` opcional (mÃ¡x. 40), `currentMileage` opcional entero no negativo, y parÃ¡metros de listado
- [X] T064 [US5] Crear `server/models/vehicleModel.js`: listado con bÃºsqueda y propietario (`JOIN clients`), `findById`, `findByPlate`, `create`
- [X] T065 [US5] Crear `server/services/vehicleService.js`: `list`, `getById`, `create` (comprueba que el propietario exista, normaliza placa en mayÃºsculas, traduce duplicados de placa y VIN)
- [X] T066 [US5] Crear `server/controllers/vehicleController.js` y `server/routes/vehicleRoutes.js`: `GET`, `POST` (ADMIN, RECEPTIONIST) y `GET /:id`; montar en `server/routes/index.js`
- [X] T067 [P] [US5] Crear `client/lib/models/vehicle.dart` y `client/lib/services/vehicles_service.dart`
- [X] T068 [P] [US5] Crear `client/lib/widgets/client_selector.dart`: selector de propietario con bÃºsqueda, obligatorio
- [X] T069 [US5] Crear `client/lib/providers/vehicles_provider.dart`
- [X] T070 [US5] Crear `client/lib/screens/vehicles_list_screen.dart` (placa, marca, modelo, aÃ±o, propietario; estados vacÃ­o, cargando, error y sin resultados; "Nuevo vehÃ­culo" oculto para MECHANIC)
- [X] T071 [US5] Crear `client/lib/screens/vehicle_form_screen.dart` (alta) con validaciÃ³n por campo, selector de propietario obligatorio y confirmaciÃ³n de salida con cambios sin guardar
- [X] T072 [P] [US5] Pruebas de widgets en `client/test/vehicles_screens_test.dart`

**Punto de control**: se puede registrar el flujo cliente â†’ vehÃ­culo

---

## Fase 6: Historia de usuario 6 - Asociar un vehÃ­culo con su propietario (Prioridad: P1)

**Meta**: que cada vehÃ­culo se vea ligado a su propietario y poder cambiarlo con confirmaciÃ³n.

**Prueba independiente**: registrar un vehÃ­culo desde el detalle de un cliente, verlo allÃ­ y ver el propietario en el detalle del vehÃ­culo; cambiar el propietario y comprobar que se mueve.

### Pruebas de la historia 6

- [X] T073 [P] [US6] Prueba de contrato de `PATCH /api/vehicles/:id` en `server/tests/contract/vehicles.patch.contract.test.js` (forma, `400`, `401`, `403`, `404`)
- [X] T074 [P] [US6] Prueba de integraciÃ³n en `server/tests/integration/vehicles.owner.test.js`: cambio de propietario (el vehÃ­culo deja de listarse en el anterior y aparece en el nuevo), `422 OWNER_NOT_FOUND`, `422 MILEAGE_DECREASE` salvo con `mileageCorrection: true`, mecÃ¡nico recibe `403`

### ImplementaciÃ³n de la historia 6

- [X] T075 [US6] Ampliar `server/validators/vehicleValidators.js` con el esquema parcial de `PATCH` (incluye `clientId` y `mileageCorrection` booleano)
- [X] T076 [US6] Ampliar `server/models/vehicleModel.js` y `server/services/vehicleService.js` con `update`: cambio de propietario existente, regla de kilometraje ("no puede disminuir salvo correcciÃ³n explÃ­cita") y duplicados de placa y VIN
- [X] T077 [US6] AÃ±adir `PATCH /api/vehicles/:id` (ADMIN, RECEPTIONIST) en `server/controllers/vehicleController.js` y `server/routes/vehicleRoutes.js`
- [X] T078 [US6] Crear `client/lib/screens/vehicle_detail_screen.dart`: datos del vehÃ­culo y propietario con enlace al detalle del cliente
- [X] T079 [US6] Ampliar `client/lib/screens/vehicle_form_screen.dart` con modo ediciÃ³n, diÃ¡logo de confirmaciÃ³n al cambiar el propietario y diÃ¡logo de confirmaciÃ³n al corregir un kilometraje menor
- [X] T080 [US6] AÃ±adir en `client/lib/screens/client_detail_screen.dart` la acciÃ³n "Registrar vehÃ­culo" con el propietario preseleccionado (oculta para MECHANIC) y enlaces a cada vehÃ­culo
- [X] T081 [P] [US6] Pruebas de widgets en `client/test/vehicle_owner_test.dart` (diÃ¡logos de confirmaciÃ³n, propietario preseleccionado)

**Punto de control**: el flujo del sprint (sesiÃ³n â†’ cliente â†’ vehÃ­culo â†’ asociaciÃ³n â†’ consulta) funciona de extremo a extremo

---

## Fase 7: Historia de usuario 2 - Gestionar usuarios y roles (Prioridad: P2)

**Meta**: que el administrador gestione usuarios y roles, y que cualquier persona cambie su contraseÃ±a.

**Prueba independiente**: con la cuenta administradora crear un usuario, cambiar su rol y desactivarlo; otro rol no puede; cambiar la propia contraseÃ±a respeta la polÃ­tica.

### Pruebas de la historia 2

- [X] T082 [P] [US2] Prueba de contrato de `/api/users` (`GET`, `POST`, `GET /:id`, `PATCH /:id`) y `POST /api/auth/change-password` en `server/tests/contract/users.contract.test.js` (forma, `400`, `401`, `403` para RECEPTIONIST y MECHANIC)
- [X] T083 [P] [US2] Prueba de integraciÃ³n en `server/tests/integration/users.flow.test.js`: `409 USERNAME_DUPLICATE` y `EMAIL_DUPLICATE` (tambiÃ©n con distinta capitalizaciÃ³n), `409 LAST_ADMIN` al desactivar o cambiar de rol al Ãºnico administrador, efecto inmediato del cambio de rol y de la desactivaciÃ³n, `422 PASSWORD_POLICY`, `422 SAME_PASSWORD` y `401` con contraseÃ±a actual incorrecta

### ImplementaciÃ³n de la historia 2

- [X] T084 [P] [US2] Crear `server/validators/userValidators.js`: `username` ("3â€“50 caracteres; letras, nÃºmeros, `.`, `_`, `-`; sin `@`"), `name` obligatorio (mÃ¡x. 120), `email` vÃ¡lido (mÃ¡x. 254), `role` ("ADMIN", "RECEPTIONIST" o "MECHANIC"), `active` booleano, y polÃ­tica de contraseÃ±a ("mÃ­nimo 8 caracteres con al menos una mayÃºscula, una minÃºscula y un nÃºmero")
- [X] T085 [US2] Ampliar `server/models/userModel.js` con `list` (bÃºsqueda, filtros de rol y estado, paginaciÃ³n), `create`, `update`, `updatePassword` y `countActiveAdmins` con bloqueo de filas dentro de una transacciÃ³n
- [X] T086 [US2] Crear `server/services/userService.js`: alta con hash bcrypt (costo 10), ediciÃ³n de nombre, correo, rol y estado, y regla `LAST_ADMIN`
- [X] T087 [US2] Ampliar `server/services/authService.js` con `changePassword` (valida contraseÃ±a actual, polÃ­tica y que la nueva sea distinta)
- [X] T088 [US2] Crear `server/controllers/userController.js` y `server/routes/userRoutes.js` (solo ADMIN) y aÃ±adir `POST /api/auth/change-password` en `server/routes/authRoutes.js`; montar en `server/routes/index.js`
- [X] T089 [P] [US2] Crear `client/lib/services/users_service.dart` y `client/lib/providers/users_provider.dart`
- [X] T090 [US2] Crear `client/lib/screens/users_screen.dart` (tabla con usuario, nombre, correo, rol y estado; cambiar rol; activar o desactivar con confirmaciÃ³n al desactivar; conflicto de Ãºltimo administrador) y `client/lib/screens/user_form_screen.dart` (alta)
- [X] T091 [US2] Crear `client/lib/screens/change_password_screen.dart` (contraseÃ±a actual, nueva y confirmaciÃ³n con reglas visibles) y aÃ±adir las entradas "Usuarios" (solo ADMIN) y "Cambiar contraseÃ±a" en `client/lib/widgets/app_shell.dart`
- [X] T092 [P] [US2] Pruebas de widgets en `client/test/users_screens_test.dart` (menÃº Usuarios solo para ADMIN, confirmaciÃ³n al desactivar, polÃ­tica de contraseÃ±a)

**Punto de control**: las historias 1, 2, 3, 5 y 6 funcionan de forma independiente

---

## Fase 8: Historia de usuario 4 - Editar clientes (Prioridad: P2)

**Meta**: corregir o actualizar los datos de un cliente existente.

**Prueba independiente**: modificar el telÃ©fono de un cliente y verificar el nuevo valor en listado y detalle; una ediciÃ³n invÃ¡lida no cambia nada.

### Pruebas de la historia 4

- [X] T093 [P] [US4] Prueba de contrato de `PATCH /api/clients/:id` en `server/tests/contract/clients.patch.contract.test.js` (forma, `400`, `401`, `403` para mecÃ¡nico, `404`)
- [X] T094 [P] [US4] Prueba de integraciÃ³n en `server/tests/integration/clients.edit.test.js`: ediciÃ³n vÃ¡lida, ediciÃ³n invÃ¡lida conserva los datos anteriores, `409 EMAIL_DUPLICATE`, `409 PHONE_DUPLICATE` confirmable que ignora al propio cliente

### ImplementaciÃ³n de la historia 4

- [X] T095 [US4] Ampliar `server/validators/clientValidators.js` con el esquema parcial de `PATCH`
- [X] T096 [US4] Ampliar `server/models/clientModel.js` y `server/services/clientService.js` con `update` (mismas reglas de duplicados, excluyendo al propio registro)
- [X] T097 [US4] AÃ±adir `PATCH /api/clients/:id` (ADMIN, RECEPTIONIST) en `server/controllers/clientController.js` y `server/routes/clientRoutes.js`
- [X] T098 [US4] Ampliar `client/lib/screens/client_form_screen.dart` con modo ediciÃ³n y aÃ±adir la acciÃ³n "Editar" en `client/lib/screens/client_detail_screen.dart` y en `client/lib/screens/clients_list_screen.dart` (oculta para MECHANIC)
- [X] T099 [P] [US4] Pruebas de widgets en `client/test/client_edit_test.dart`

**Punto de control**: las seis historias funcionan

---

## Fase 9: Pulido y asuntos transversales

**PropÃ³sito**: mejoras que afectan a varias historias

- [X] T100 [P] Prueba de integraciÃ³n en `server/tests/integration/seeds.test.js` que ejecuta dos veces `database/seeds/001_initial_data.sql` sobre `motorix_test` y verifica que no se duplican registros (CA-10, SC-006)
- [X] T101 [P] Prueba de integraciÃ³n en `server/tests/integration/passwords.test.js` que verifica que las tres cuentas sembradas almacenan hashes bcrypt y que ninguna respuesta de la API contiene `passwordHash` ni `password_hash` (SC-005, CA-1)
- [X] T102 [P] Prueba de rendimiento en `server/tests/integration/performance.test.js`: con 1 000 clientes y 1 000 vehÃ­culos, las bÃºsquedas responden en menos de 2 s (SC-008)
- [X] T103 [P] Actualizar `docs/project-context.md` Â§27 (set de Ã­conos: Material; bloqueo de cuenta) y Â§11 (sin carpeta `src/`), y `docs/design-system.md` Â§3 y Â§12 (set de Ã­conos definitivo: Material; librerÃ­a complementaria: ninguna)
- [X] T104 Revisar que ningÃºn archivo versionado contiene secretos ni contraseÃ±as en texto plano (`.env` ignorado, `.env.example` sin valores) y que la aplicaciÃ³n no usa `root` (CA-7, CA-8)
- [X] T105 [P] Revisar cada pantalla del cliente contra los criterios de "terminado" de `docs/design-system.md` Â§11 (tokens, sidebar expandido y colapsado, estados, transiciones, confirmaciones, ventana angosta) y corregir desvÃ­os (CA-12)
- [X] T106 [P] Completar `README.md` y `database/README.md` con el estado final y los comandos reales
- [X] T107 Ejecutar `database/scripts/reiniciar-local.ps1` en un entorno limpio y validar los 17 escenarios de `specs/001-base-clientes-vehiculos/quickstart.md`, incluyendo el tiempo de recreaciÃ³n de menos de 10 minutos (SC-007)
- [X] T108 Comprobar la trazabilidad CA-1 a CA-12 de `docs/sprints/sprint-1-base-clientes-vehiculos.md` y registrar el resultado y los pendientes en `specs/001-base-clientes-vehiculos/quickstart.md`

---

## Dependencias y orden de ejecuciÃ³n

### Dependencias entre fases

- **PreparaciÃ³n (Fase 1)**: sin dependencias; puede empezar de inmediato
- **Fundamentos (Fase 2)**: depende de la Fase 1 y BLOQUEA todas las historias
- **Historias de usuario (Fases 3 a 8)**: dependen de la Fase 2
  - US1 va primero: US3, US5, US6, US2 y US4 necesitan sesiÃ³n para probarse en la interfaz
  - En el backend las historias son independientes entre sÃ­ tras la Fase 2
- **Pulido (Fase 9)**: depende de las historias deseadas

### Dependencias entre historias

- **US1 (P1)**: tras la Fase 2; sin dependencias de otras historias
- **US3 (P1)**: tras la Fase 2; en la interfaz necesita el shell de US1 (T043)
- **US5 (P1)**: tras la Fase 2; necesita clientes existentes para probar propietario (usa la fÃ¡brica de pruebas T026); en la interfaz, el selector T068 consume `clients_service.dart` (T054)
- **US6 (P1)**: depende de US5 (amplÃ­a su servicio, formulario y rutas) y de US3 (detalle de cliente)
- **US2 (P2)**: tras la Fase 2; amplÃ­a `userModel.js` y `authService.js` de US1
- **US4 (P2)**: depende de US3 (amplÃ­a su servicio, formulario y rutas)

### Dentro de cada historia

- Las pruebas se escriben primero y deben fallar antes de implementar
- Validadores y modelos â†’ servicios â†’ controladores y rutas â†’ pantallas
- Completar la historia antes de pasar a la siguiente prioridad

### Oportunidades de paralelismo

- Fase 1: T002 a T006 en paralelo tras T001
- Fase 2: T009, T012 a T014 (scripts de base de datos); T016 a T019, T021, T024, T026 a T028 (backend); T029 a T032 (frontend) en paralelo
- Tras la Fase 2, el backend de US1, US3, US5 y US2 puede avanzarse en paralelo (archivos distintos)
- Dentro de cada historia, las pruebas de contrato e integraciÃ³n [P] y las capas de cliente [P] corren a la vez

---

## Ejemplo de paralelismo: Historia de usuario 3

```text
# Lanzar juntas las pruebas de la historia 3:
Tarea: "Prueba de contrato de clientes en server/tests/contract/clients.contract.test.js"
Tarea: "Prueba de integraciÃ³n de clientes en server/tests/integration/clients.flow.test.js"

# Lanzar juntas las piezas independientes:
Tarea: "Validadores en server/validators/clientValidators.js"
Tarea: "Modelo y servicio de cliente en client/lib/models/client.dart y client/lib/services/clients_service.dart"
Tarea: "Tabla reutilizable en client/lib/widgets/app_data_table.dart"
```

---

## Estrategia de implementaciÃ³n

### Primero el MVP (solo la historia 1)

1. Completar la Fase 1 (preparaciÃ³n)
2. Completar la Fase 2 (fundamentos, CRÃTICA)
3. Completar la Fase 3 (historia 1)
4. **DETENERSE Y VALIDAR**: probar el inicio de sesiÃ³n de forma independiente

### Entrega incremental

1. PreparaciÃ³n + Fundamentos â†’ base lista
2. US1 â†’ validar â†’ demostraciÃ³n (acceso por rol)
3. US3 â†’ validar (clientes)
4. US5 y US6 â†’ validar (vehÃ­culos y asociaciÃ³n): el flujo del sprint queda completo
5. US2 y US4 â†’ validar (usuarios y ediciÃ³n de clientes)
6. Pulido â†’ validar con el quickstart

### Estrategia para varias personas

1. El equipo completa juntos PreparaciÃ³n y Fundamentos
2. DespuÃ©s:
   - Persona A: US1 y US2 (sesiÃ³n y usuarios)
   - Persona B: US3 y US4 (clientes)
   - Persona C: US5 y US6 (vehÃ­culos)
3. El frontend de US3, US5 y US6 espera el shell de US1 (T043)

---

## Notas

- [P] = archivos distintos, sin dependencias pendientes
- La etiqueta [USn] vincula cada tarea con su historia para la trazabilidad
- Cada historia debe poder completarse y probarse por separado
- Verificar que las pruebas fallan antes de implementar
- Hacer commit tras cada tarea o grupo lÃ³gico (Conventional Commits, descripciÃ³n en espaÃ±ol)
- Detenerse en cualquier punto de control para validar la historia
- Evitar tareas vagas, conflictos en un mismo archivo y dependencias entre historias que rompan su independencia
