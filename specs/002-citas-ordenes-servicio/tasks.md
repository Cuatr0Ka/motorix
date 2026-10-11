---

description: "Lista de tareas del Sprint 2: citas y órdenes de servicio"
---

# Tareas: Citas y órdenes de servicio (Sprint 2)

**Entrada**: Documentos de diseño en `specs/002-citas-ordenes-servicio/`

**Requisitos previos**: plan.md, spec.md, research.md, data-model.md, contracts/ (api-rest.md e interfaz.md), quickstart.md

**Pruebas**: INCLUIDAS. La constitución (Principio VII) exige pruebas para la lógica de negocio (transiciones de estado, permisos) y el sprint exige CA-8; las del backend usan Jest + supertest contra `motorix_test` y las del frontend `flutter test`.

**Organización**: Las tareas se agrupan por historia de usuario para poder implementar y probar cada una de forma independiente.

## Formato: `[ID] [P?] [Historia] Descripción`

- **[P]**: se puede ejecutar en paralelo (archivos distintos, sin dependencias pendientes)
- **[USn]**: historia de usuario a la que pertenece la tarea (US1 a US6 de spec.md)
- Todas las rutas son relativas a la raíz del repositorio (`D:\sdd\motorix`)

## Convenciones de rutas

- Backend: `server/` (capas directamente en la raíz de `server/`, sin carpeta `src/`)
- Frontend: `client/lib/` y `client/test/`
- Base de datos: `database/`
- El código backend usa ES Modules (`import`/`export`); los identificadores van en inglés y los comentarios, mensajes y nombres de pruebas en español
- Las pruebas de integración y contrato se ejecutan solo contra `motorix_test`; los errores nuevos usan `AppError` (`server/utils/AppError.js`) con los códigos de `contracts/api-rest.md`

## Orden de las historias (prioridad)

P1: US1 (citas), US2 (crear orden con cliente y vehículo), US3 (asignar mecánico), US4 (mis órdenes). P2: US5 (diagnóstico, servicios, mano de obra y recomendaciones), US6 (cambiar el estado).

---

## Fase 1: Preparación (infraestructura compartida)

**Propósito**: verificar la base del Sprint 1 y alinear la documentación

- [X] T001 Verificar la línea base: MySQL local en ejecución, migración 001 aplicada en `motorix` y `motorix_test`, y `npm test` (en `server/`) y `flutter test` (en `client/`) en verde antes de empezar
- [X] T002 [P] Actualizar `docs/project-context.md`: añadir en la tabla de cuentas iniciales (§5) la fila de `mecanico2` con su contraseña de entorno local (mismo formato que las demás cuentas), anotar en §12 que los totales de la orden se **calculan** a partir de `order_services` y `order_labor` (research D-11), y registrar la tabla auxiliar `order_status_history` y los campos de corrección de kilometraje del Sprint 2
- [X] T003 [P] Actualizar `database/README.md` con la migración `002_sprint2_appointments_service_orders.sql`, el seed `002_appointments_orders.sql` y las cuentas `mecanico2`

---

## Fase 2: Fundamentos (requisitos bloqueantes)

**Propósito**: esquema, utilidades y plantillas de prueba que DEBEN existir antes de cualquier historia

**⚠️ CRÍTICO**: ninguna historia puede empezar hasta terminar esta fase

### Base de datos

- [X] T004 Crear `database/migrations/002_sprint2_appointments_service_orders.sql` (InnoDB, `utf8mb4`, sin editar la migración 001; todas las tablas con `id` INT UNSIGNED AUTO_INCREMENT PK y `created_at`/`updated_at` DATETIME NOT NULL con `DEFAULT CURRENT_TIMESTAMP` y `ON UPDATE CURRENT_TIMESTAMP` en `updated_at`, salvo `order_status_history`). Tablas según data-model.md: `appointments` (`client_id` INT UNSIGNED NOT NULL FK → `clients(id)` ON DELETE RESTRICT ON UPDATE CASCADE; `vehicle_id` INT UNSIGNED NOT NULL FK → `vehicles(id)` ON DELETE RESTRICT ON UPDATE CASCADE; `scheduled_at` DATETIME NOT NULL; `reason` VARCHAR(255) NOT NULL; `notes` VARCHAR(1000) NULL; `status` ENUM('PENDIENTE','CONFIRMADA','EN_PROCESO','COMPLETADA','CANCELADA') NOT NULL DEFAULT 'PENDIENTE'; `cancel_reason` VARCHAR(255) NULL; `cancelled_at` DATETIME NULL; `active_vehicle_id` INT UNSIGNED GENERATED ALWAYS AS (IF(status IN ('CANCELADA','COMPLETADA'), NULL, vehicle_id)) STORED; `created_by` INT UNSIGNED NOT NULL FK → `users(id)`; `UNIQUE uq_appointments_active_slot (active_vehicle_id, scheduled_at)`; índices `idx_appointments_scheduled (scheduled_at)`, `idx_appointments_status (status)`, `idx_appointments_client (client_id)`), `service_orders` (`client_id` INT UNSIGNED NOT NULL FK → `clients(id)`; `vehicle_id` INT UNSIGNED NOT NULL FK → `vehicles(id)`; `appointment_id` INT UNSIGNED NULL FK → `appointments(id)` con `UNIQUE uq_orders_appointment`; `mechanic_id` INT UNSIGNED NULL FK → `users(id)`; `status` ENUM('RECIBIDO','DIAGNOSTICO','EN_REPARACION','ESPERANDO_REFACCION','TERMINADO','ENTREGADO') NOT NULL DEFAULT 'RECIBIDO'; `reported_problem` VARCHAR(1000) NOT NULL; `entry_mileage` INT UNSIGNED NOT NULL; `mileage_correction` TINYINT(1) NOT NULL DEFAULT 0; `mileage_correction_reason` VARCHAR(255) NULL; `diagnosis` TEXT NULL; `observations` TEXT NULL; `recommendations` TEXT NULL; `open_vehicle_id` INT UNSIGNED GENERATED ALWAYS AS (IF(status = 'ENTREGADO', NULL, vehicle_id)) STORED con `UNIQUE uq_orders_open_vehicle (open_vehicle_id)`; `created_by` INT UNSIGNED NOT NULL FK → `users(id)`; `delivered_at` DATETIME NULL; índices `idx_orders_status (status)`, `idx_orders_mechanic_status (mechanic_id, status)`, `idx_orders_vehicle (vehicle_id)`, `idx_orders_client (client_id)`; todas las FK con ON DELETE RESTRICT), `order_services` y `order_labor` (`order_id` INT UNSIGNED NOT NULL FK → `service_orders(id)` ON DELETE RESTRICT; `description` VARCHAR(255) NOT NULL; `amount` DECIMAL(10,2) NOT NULL con CHECK (`amount >= 0`); índices `idx_order_services_order (order_id)` e `idx_order_labor_order (order_id)`) y `order_status_history` (`order_id` INT UNSIGNED NOT NULL FK → `service_orders(id)`; `from_status` ENUM de estados de la orden NULL; `to_status` ENUM de estados de la orden NOT NULL; `changed_by` INT UNSIGNED NOT NULL FK → `users(id)`; `changed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP; índice `idx_order_history_order (order_id, changed_at)`; sin `created_at`/`updated_at`)
- [X] T005 Aplicar la migración con `database/scripts/aplicar-migraciones.ps1 -Base motorix` y `-Base motorix_test`, y verificar que quede registrada en `schema_migrations` y que repetir el comando no la vuelva a ejecutar

### Utilidades y reglas puras del backend

- [X] T006 [P] Crear `server/utils/orderFolio.js`: `formatFolio(id)` → `OS-` + id con 6 dígitos (por ejemplo `OS-000012`) y `parseFolioSearch(text)` que acepta `OS-12`, `os-000012` o `12` y devuelve el id numérico o `null` (research D-08)
- [X] T007 [P] Crear `server/services/orderTransitions.js` (módulo puro, sin acceso a base ni a Express): `ORDER_STATUSES`, tabla de transiciones permitidas de data-model.md (`RECIBIDO→DIAGNOSTICO`, `DIAGNOSTICO→EN_REPARACION`, `DIAGNOSTICO→ESPERANDO_REFACCION`, `EN_REPARACION→TERMINADO`, `EN_REPARACION→ESPERANDO_REFACCION`, `ESPERANDO_REFACCION→EN_REPARACION`, `TERMINADO→ENTREGADO`; `ENTREGADO` sin salidas), `allowedNext(status)`, `assertTransition(from, to)` que lanza `AppError.unprocessable('INVALID_TRANSITION', …, { currentStatus, allowed })`, y `canActorTransition({ role, userId, order, to })` (hasta `TERMINADO`: ADMIN o el MECHANIC asignado; a `ENTREGADO`: ADMIN o RECEPTIONIST) más `allowedFor({ role, userId, order })` que devuelve las transiciones filtradas por rol y pertenencia
- [X] T008 [P] Crear `server/validators/orderCommon.js` con esquemas zod compartidos y mensajes en español: `money` (número con hasta dos decimales, "entre 0 y 9 999 999.99", acepta número o cadena decimal), `entryMileage` (entero "0 a 2 000 000"), `isoDateTime` (ISO 8601 válido) y `longText(label)` (hasta 5 000 caracteres; vacío o null → null)

### Pruebas de los fundamentos

- [X] T009 [P] Crear `server/tests/unit/orderFolio.test.js`: formato con ceros (`OS-000001`, `OS-123456`), lectura de `OS-12`, `os-000012`, `12`, rechazo de texto no numérico
- [X] T010 [P] Crear `server/tests/unit/orderTransitions.test.js` (CA-8, SC-004): recorrer los 6 × 6 pares de estados y comprobar que solo las 7 transiciones de data-model.md se aceptan; el error `INVALID_TRANSITION` lleva `details.allowed`; `ENTREGADO` no tiene salidas; `ESPERANDO_REFACCION` solo regresa a `EN_REPARACION`; no hay retrocesos
- [X] T011 [P] Crear `server/tests/unit/orderPermissions.test.js`: `canActorTransition` y `allowedFor` para ADMIN, RECEPTIONIST, mecánico asignado y mecánico ajeno (solo ADMIN o el asignado hasta `TERMINADO`; solo ADMIN o RECEPTIONIST a `ENTREGADO`; el mecánico ajeno y recepción no avanzan hasta `TERMINADO`)

### Plantillas de pruebas de integración

- [X] T012 Ampliar `server/tests/helpers/factories.js`: `resetDatabase()` debe borrar también, en este orden y antes de `vehicles`, `order_status_history`, `order_labor`, `order_services`, `service_orders` y `appointments`; añadir `createAppointment(clientId, vehicleId, createdBy, overrides)` (fecha futura por defecto, estado `PENDIENTE`) y `createOrder(vehicleId, createdBy, overrides)` (deriva `client_id` del vehículo, `entry_mileage` y `reported_problem` por defecto, mecánico y estado opcionales, registra la entrada inicial del historial), más `createService(orderId, overrides)` y `createLabor(orderId, overrides)`
- [X] T013 [P] Ampliar `server/tests/helpers/seed.js`: `readStandardPasswords()` debe reconocer también `mecanico2`

### Cliente (fundamentos de interfaz)

- [X] T014 [P] Crear `client/lib/utils/status_labels.dart`: etiquetas en español y color (según `contracts/interfaz.md`: neutro, primario, ámbar, verde, rojo) para los estados de cita y de orden, con los tokens de `client/lib/utils/tokens.dart` (sin colores sueltos)
- [X] T015 [P] Crear `client/lib/widgets/status_chip.dart`: chip de estado reutilizable que usa `status_labels.dart`
- [X] T016 Ampliar `client/lib/providers/navigation_provider.dart` con las secciones `appointments` ('Citas'), `orders` ('Órdenes') y `myOrders` ('Mis órdenes'), y `sectionsFor(role)` según `contracts/interfaz.md` (ADMIN y RECEPTIONIST: Citas y Órdenes; MECHANIC: Mis órdenes); añadir los íconos (`Icons.event_outlined`/`event`, `Icons.assignment_outlined`/`assignment`, `Icons.build_outlined`/`build`) en `client/lib/widgets/app_shell.dart` y las pruebas de navegación por rol en `client/test/app_shell_test.dart`
- [X] T017 Ampliar `client/test/helpers/fake_api.dart` y `client/test/helpers/data.dart` con JSON de ejemplo de citas, órdenes (resumen y detalle) y mecánicos según `contracts/api-rest.md`

**Punto de control**: migración aplicada, utilidades puras probadas, plantillas de pruebas listas; ya pueden empezar las historias.

---

## Fase 3: Historia de usuario 1 - Registrar y consultar citas (Prioridad: P1) 🎯 MVP

**Objetivo**: recepción y administración registran, consultan, modifican, confirman y cancelan citas.

**Prueba independiente**: con la sesión de recepcionista, registrar una cita para un cliente y uno de sus vehículos, localizarla en el listado, cambiar su hora, confirmarla y cancelarla; un mecánico es rechazado.

### Pruebas de la historia 1

- [X] T018 [P] [US1] Crear `server/tests/contract/appointments.contract.test.js`: forma de la respuesta de `GET/POST /api/appointments`, `GET/PATCH /api/appointments/:id`, `POST …/confirm` y `POST …/cancel`; error `400 VALIDATION_ERROR`; `401` sin token y `403` para MECHANIC en cada endpoint
- [X] T019 [P] [US1] Crear `server/tests/integration/appointments.flow.test.js`: alta en `PENDIENTE`; confirmar; modificar fecha, motivo y observaciones; cancelar con y sin motivo; no se modifica ni cancela una cita `CANCELADA`, `EN_PROCESO` ni `COMPLETADA` (`APPOINTMENT_NOT_EDITABLE`); rechaza fecha pasada (`APPOINTMENT_IN_PAST`), vehículo ajeno al cliente (`VEHICLE_CLIENT_MISMATCH`), vehículo o cliente inexistente (`VEHICLE_NOT_FOUND`) y mismo vehículo en el mismo horario (`APPOINTMENT_SLOT_TAKEN`, también en una carrera simultánea); un horario liberado por una cancelación puede reutilizarse; filtros por estado y fechas, búsqueda por cliente o placa y paginación; no existe `DELETE`

### Implementación de la historia 1

- [X] T020 [P] [US1] Crear `server/validators/appointmentValidators.js`: `createAppointmentSchema` (`clientId` y `vehicleId` enteros positivos; `scheduledAt` ISO 8601; `reason` obligatorio de 1 a 255 caracteres; `notes` opcional hasta 1000), `updateAppointmentSchema` (parcial: `scheduledAt`, `reason`, `notes`; al menos un campo), `cancelAppointmentSchema` (`reason` opcional hasta 255) y `listAppointmentsQuery` (`search`, `status` del enum, `from`, `to`, paginación de `common.js`), con mensajes en español
- [X] T021 [US1] Crear `server/models/appointmentModel.js` con `mysql2`: `list` (filtros, búsqueda con `likePattern` por cliente o placa, orden `scheduled_at` ascendente, `limitOffset`), `findById` (con cliente, vehículo y orden asociada `{ id, folio, status }`), `create`, `update` con lista blanca de columnas, `setStatus` y `findActiveSlot(vehicleId, scheduledAt, excludeId)`
- [X] T022 [US1] Crear `server/services/appointmentService.js`: `list`, `getById` (404 si no existe), `create` (verifica cliente y vehículo, que el vehículo sea del cliente y que la fecha no sea anterior a "ahora menos 1 minuto"; traduce `ER_DUP_ENTRY` de `uq_appointments_active_slot` a `APPOINTMENT_SLOT_TAKEN`), `update` y `confirm` y `cancel` (solo desde `PENDIENTE`/`CONFIRMADA`; `cancel` guarda `cancel_reason` y `cancelled_at`), con `created_by` del usuario autenticado
- [X] T023 [US1] Crear `server/controllers/appointmentController.js` y `server/routes/appointmentRoutes.js` (todas las rutas con `authenticate` y `authorize(ROLES.ADMIN, ROLES.RECEPTIONIST)`, `validate` y `asyncHandler`; sin ruta `DELETE`) y montar `router.use('/appointments', appointmentRoutes)` en `server/routes/index.js`

### Interfaz de la historia 1

- [X] T024 [P] [US1] Crear `client/lib/models/appointment.dart` (cita con cliente, vehículo, orden asociada opcional y enum de estado) y `client/lib/services/appointments_service.dart` (`list`, `get`, `create`, `update`, `confirm`, `cancel`) siguiendo el patrón de `vehicles_service.dart`
- [X] T025 [P] [US1] Crear `client/lib/widgets/vehicle_selector.dart`: selector de vehículo con búsqueda, acotable a los vehículos de un cliente (patrón de `client_selector.dart`)
- [X] T026 [US1] Crear `client/lib/providers/appointments_provider.dart` (extiende `PagedListProvider`, con filtros de estado y rango de fechas)
- [X] T027 [US1] Crear `client/lib/screens/appointments_list_screen.dart` (tabla con fecha y hora, cliente, placa, motivo y `StatusChip`; búsqueda, filtros, paginación; estados vacío, cargando, error y sin resultados; acciones de confirmar y cancelar en la fila) según `contracts/interfaz.md`
- [X] T028 [US1] Crear `client/lib/screens/appointment_form_screen.dart` (cliente con `ClientSelectorField`, vehículo con `vehicle_selector.dart` restringido al cliente, fecha y hora, motivo, observaciones; errores de horario ocupado y fecha pasada; confirmación al salir con cambios) y `client/lib/screens/appointment_detail_screen.dart` (datos, orden asociada con enlace, Editar, Confirmar, Cancelar con diálogo de confirmación y motivo opcional vía `confirm_dialog.dart`; el botón "Recibir vehículo y crear orden" se agrega en US2)
- [X] T029 [US1] Conectar la sección Citas: construir `AppointmentsListScreen` en el `sectionBuilder` de `client/lib/main.dart`, registrar `AppointmentsProvider` y `AppointmentsService`, y añadir su acceso directo en `client/lib/screens/home_screen.dart`
- [X] T030 [US1] Crear `client/test/appointments_screens_test.dart`: listado con datos y vacío, filtros, alta válida e inválida, confirmar, cancelar con diálogo, y que el mecánico no ve la sección Citas

**Punto de control**: las citas funcionan de extremo a extremo (CA-1).

---

## Fase 4: Historia de usuario 2 - Crear una orden asociada a cliente y vehículo (Prioridad: P1)

**Objetivo**: recepción crea órdenes (desde una cita o directas) con kilometraje de entrada validado, asociadas al cliente propietario y al vehículo.

**Prueba independiente**: crear una orden para un vehículo existente con kilometraje de entrada y verificar folio, estado `RECIBIDO`, cliente derivado, kilometraje del vehículo actualizado y cita en `EN_PROCESO`; rechazos de vehículo inexistente, kilometraje ausente o menor, y segunda orden abierta.

### Pruebas de la historia 2

- [X] T031 [P] [US2] Crear `server/tests/unit/mileageRule.test.js`: función pura de la regla de kilometraje (menor al actual rechaza; igual o mayor acepta; sin valor previo acepta de 0 a 2 000 000; fuera de rango rechaza; corrección con motivo mínimo de 5 caracteres acepta)
- [X] T032 [P] [US2] Crear `server/tests/contract/orders.contract.test.js` (parte de creación y lectura): forma de `POST /api/orders` (directa y desde cita), `GET /api/orders/:id` y `GET /api/orders`; `400` por kilometraje ausente; `401` sin token; `403` para MECHANIC al crear
- [X] T033 [P] [US2] Crear `server/tests/integration/orders.create.test.js`: creación directa y desde cita (hereda cliente, vehículo y motivo; la cita pasa a `EN_PROCESO`); `client_id` se deriva del propietario; vehículo inexistente (`VEHICLE_NOT_FOUND`); kilometraje obligatorio; `MILEAGE_DECREASE` sin corrección y aceptación con `mileageCorrection` y motivo (queda guardado); actualiza `vehicles.current_mileage`; el cuerpo exige `vehicleId` o `appointmentId`, no ambos; `OPEN_ORDER_EXISTS` con `details.orderId`, incluida la carrera de dos creaciones simultáneas (solo una prospera); `APPOINTMENT_NOT_AVAILABLE` para citas canceladas, completadas, en proceso o con orden; la orden nace en `RECIBIDO` con una entrada de historial; sin `DELETE`; el rollback deja el kilometraje y la cita intactos si falla

### Implementación de la historia 2

- [X] T034 [P] [US2] Crear `server/validators/orderValidators.js`: `createOrderSchema` (`vehicleId` o `appointmentId` exclusivos; `entryMileage` obligatorio de 0 a 2 000 000 con `orderCommon.js`; `reportedProblem` de 1 a 1000 caracteres, opcional si hay `appointmentId`; `mechanicId` entero positivo opcional; `mileageCorrection` booleano y `mileageCorrectionReason` de 5 a 255 caracteres, exigidos juntos) y `listOrdersQuery` (`search`, `status`, `mechanicId`, paginación)
- [X] T035 [P] [US2] Crear la regla pura de kilometraje en `server/services/mileageRule.js` (`assertEntryMileage({ previous, entry, correction, reason })`, lanza `MILEAGE_DECREASE`) y usarla desde el servicio de órdenes
- [X] T036 [US2] Crear `server/models/orderModel.js`: `create` (dentro de una conexión de transacción), `findById` (con cliente, vehículo, mecánico y cita), `list` (filtros `status` y `mechanicId`, búsqueda por folio con `parseFolioSearch`, cliente o placa; orden por id descendente; `limitOffset`), `lockVehicle(vehicleId, connection)` (`SELECT … FOR UPDATE`) y `lockAppointment`
- [X] T037 [US2] Crear `server/models/orderWorkModel.js` con las lecturas: `listServices(orderId)`, `listLabor(orderId)`, `totals(orderId)` (suma con `SUM`, importes como cadenas de dos decimales) y `listHistory(orderId)` (con el usuario que cambió), y la escritura `insertHistory({ orderId, fromStatus, toStatus, changedBy }, connection)`
- [X] T038 [US2] Crear `server/services/orderService.js` con `create`: dentro de `withTransaction` bloquea el vehículo, valida existencia y kilometraje con `mileageRule`, comprueba `OPEN_ORDER_EXISTS`, valida mecánico (activo y rol `MECHANIC`, `MECHANIC_INVALID`), si trae `appointmentId` lo bloquea y exige `PENDIENTE`/`CONFIRMADA` y la pasa a `EN_PROCESO`, inserta la orden, registra la entrada inicial del historial y actualiza `vehicles.current_mileage`; traduce `ER_DUP_ENTRY` de `uq_orders_open_vehicle` a `OPEN_ORDER_EXISTS`; más `getById(id, actor)` que arma el detalle de `contracts/api-rest.md` (servicios, mano de obra, totales, historial, `allowedTransitions` con `allowedFor`) y `list(filters, actor)` (el alcance del mecánico se completa en US4)
- [X] T039 [US2] Crear `server/controllers/orderController.js` y `server/routes/orderRoutes.js` con `GET /` y `GET /:id` (todos los roles autenticados; la restricción del mecánico llega en US4) y `POST /` (`authorize(ROLES.ADMIN, ROLES.RECEPTIONIST)`), y montar `router.use('/orders', orderRoutes)` en `server/routes/index.js`

### Interfaz de la historia 2

- [X] T040 [P] [US2] Crear `client/lib/models/service_order.dart` (resumen y detalle con servicios, mano de obra, totales, historial y `allowedTransitions`) y `client/lib/services/orders_service.dart` (`list`, `get`, `create`)
- [X] T041 [US2] Crear `client/lib/providers/orders_provider.dart` (extiende `PagedListProvider`, con filtros de estado y mecánico) y `client/lib/screens/orders_list_screen.dart` (tabla con folio, fecha, cliente, vehículo, mecánico y `StatusChip`; búsqueda, filtros, paginación; estados vacío, cargando, error y sin resultados)
- [X] T042 [US2] Crear `client/lib/screens/order_form_screen.dart`: vehículo con `vehicle_selector.dart` (cliente derivado) o cita de origen, kilometraje de entrada, problema reportado, mecánico opcional; diálogo de corrección de kilometraje con motivo obligatorio cuando el servidor responde `MILEAGE_DECREASE`; muestra los errores `OPEN_ORDER_EXISTS` y de validación; confirmación al salir con cambios
- [X] T043 [US2] Crear `client/lib/screens/order_detail_screen.dart` (solo lectura por ahora: encabezado con folio, cliente, vehículo, kilometraje de entrada, mecánico o "Sin asignar", `StatusChip`, secciones de diagnóstico, servicios, mano de obra, totales e historial) y añadir el botón "Recibir vehículo y crear orden" en `appointment_detail_screen.dart` que abre `order_form_screen.dart` con la cita
- [X] T044 [US2] Conectar la sección Órdenes en `client/lib/main.dart` (registro de `OrdersProvider` y `OrdersService`) y su acceso directo en `client/lib/screens/home_screen.dart`
- [X] T045 [US2] Crear `client/test/orders_screens_test.dart`: listado, alta directa y desde cita, diálogo de corrección de kilometraje, error de orden abierta y detalle de solo lectura

**Punto de control**: se crea una orden asociada a cliente y vehículo contra MySQL local (CA-2, CA-6 en la creación).

---

## Fase 5: Historia de usuario 3 - Asignar una orden a un mecánico (Prioridad: P1)

**Objetivo**: recepción y administración asignan y reasignan órdenes a mecánicos activos.

**Prueba independiente**: asignar una orden a un mecánico, reasignarla a otro, y comprobar que rechaza usuarios inactivos o que no son mecánicos y órdenes terminadas o entregadas.

### Pruebas de la historia 3

- [X] T046 [P] [US3] Crear `server/tests/contract/mechanics.contract.test.js` y completar en `orders.contract.test.js` el contrato de `PUT /api/orders/:id/mechanic`: `GET /api/mechanics` devuelve `{ id, name, username }` solo de mecánicos activos, `401` sin token y `403` para MECHANIC; asignación `200`, `422 MECHANIC_INVALID`, `403` para MECHANIC
- [X] T047 [P] [US3] Crear `server/tests/integration/orders.assign.test.js`: asignar y reasignar (la orden cambia de lista); quitar la asignación con `null` solo en `RECIBIDO`; rechaza usuario inactivo, rol distinto de mecánico e inexistente (`MECHANIC_INVALID`); rechaza `TERMINADO` y `ENTREGADO` (`ORDER_NOT_ASSIGNABLE` y `ORDER_READ_ONLY`)

### Implementación de la historia 3

- [X] T048 [P] [US3] Ampliar `server/models/userModel.js`: añadir `listActiveMechanics()` y `findActiveMechanic(id)` (solo columnas `id`, `name`, `username`; nunca correo ni hash)
- [X] T049 [US3] Crear `server/controllers/mechanicController.js` y `server/routes/mechanicRoutes.js` (`GET /` con `authorize(ROLES.ADMIN, ROLES.RECEPTIONIST)`) y montar `router.use('/mechanics', mechanicRoutes)` en `server/routes/index.js`
- [X] T050 [US3] Ampliar `server/validators/orderValidators.js` con `assignMechanicSchema` (`mechanicId` entero positivo o `null`), `server/models/orderModel.js` con `setMechanic`, y `server/services/orderService.js` con `assignMechanic(id, mechanicId, actor)` (valida mecánico activo, rechaza órdenes `TERMINADO`/`ENTREGADO`, solo permite `null` en `RECIBIDO`)
- [X] T051 [US3] Añadir `PUT /:id/mechanic` (`authorize(ROLES.ADMIN, ROLES.RECEPTIONIST)`) a `server/routes/orderRoutes.js` y su método en `server/controllers/orderController.js`

### Interfaz de la historia 3

- [X] T052 [P] [US3] Crear `client/lib/models/mechanic.dart`, ampliar `client/lib/services/orders_service.dart` con `assignMechanic` y `listMechanics`, y crear `client/lib/widgets/mechanic_selector.dart` (lista desplegable de mecánicos activos)
- [X] T053 [US3] Añadir el selector de mecánico al formulario de orden (`order_form_screen.dart`) y la asignación o reasignación al detalle (`order_detail_screen.dart`, visible solo para recepción y administración y mientras la orden no esté terminada ni entregada) y el filtro por mecánico en `orders_list_screen.dart`
- [X] T054 [US3] Crear `client/test/order_assign_test.dart`: asignación y reasignación, ocultar el selector a roles sin permiso y a órdenes cerradas

**Punto de control**: el flujo "crear orden → asignar mecánico" funciona.

---

## Fase 6: Historia de usuario 4 - Consultar mis órdenes asignadas (Prioridad: P1)

**Objetivo**: el mecánico ve y abre únicamente las órdenes que tiene asignadas.

**Prueba independiente**: con dos mecánicos y órdenes repartidas, cada uno ve solo las suyas; abrir una ajena responde 404; por defecto no ve las entregadas.

### Pruebas de la historia 4

- [X] T055 [P] [US4] Crear `server/tests/integration/orders.mechanicScope.test.js` (CA-3, SC-005): el mecánico lista solo sus órdenes aunque envíe otro `mechanicId`; sin `status` excluye `ENTREGADO` y con `status=ENTREGADO` las muestra; leer una orden ajena por id responde `404 NOT_FOUND` (igual que una inexistente) y el mismo 404 en cada operación de escritura de US5 y US6; recepción y administración ven todas; filtros y búsqueda por folio, cliente y placa; un mecánico desactivado después de iniciar sesión es rechazado en la siguiente petición
- [X] T056 [P] [US4] Ampliar `server/tests/contract/orders.contract.test.js` con el contrato de `GET /api/orders` y `GET /api/orders/:id` para MECHANIC (alcance y 404)

### Implementación de la historia 4

- [X] T057 [US4] Ampliar `server/services/orderService.js` (`list` y `getById` con `actor`): para MECHANIC forzar `mechanicId` al del solicitante, excluir `ENTREGADO` cuando no se indica `status`, y responder `AppError.notFound('La orden no existe.')` si la orden no es suya; añadir el helper `loadOrderForActor(id, actor)` que reutilizarán US5 y US6

### Interfaz de la historia 4

- [X] T058 [US4] Hacer que `orders_list_screen.dart` acepte un modo "Mis órdenes" (título, filtro de estado, sin filtro de mecánico ni botón "Nueva orden", estado vacío «No tienes órdenes asignadas») y registrarlo para el rol MECHANIC en el `sectionBuilder` de `client/lib/main.dart`; añadir su acceso directo en `home_screen.dart`
- [X] T059 [US4] Crear `client/test/my_orders_test.dart`: el mecánico ve la sección Mis órdenes y no Citas ni Órdenes, la lista excluye entregadas por defecto, estado vacío y apertura del detalle

**Punto de control**: el mecánico solo ve sus órdenes (CA-3).

---

## Fase 7: Historia de usuario 5 - Registrar diagnóstico, servicios y recomendaciones (Prioridad: P2)

**Objetivo**: el mecánico asignado (y el administrador) documentan el trabajo de la orden.

**Prueba independiente**: con el mecánico asignado, registrar diagnóstico, dos servicios, una línea de mano de obra y una recomendación; corregirlos y quitarlos; los totales se recalculan; una orden entregada es de solo lectura.

### Pruebas de la historia 5

- [X] T060 [P] [US5] Crear `server/tests/contract/orders.work.contract.test.js`: forma de `PATCH /api/orders/:id/work`, `POST/PATCH/DELETE /api/orders/:id/services` y `/labor` (con `totals`), `400` por importe negativo o descripción vacía, `401` sin token y `403` para RECEPTIONIST
- [X] T061 [P] [US5] Crear `server/tests/integration/orders.work.test.js` (CA-4): guarda diagnóstico, observaciones y recomendaciones (vacío → `null`); alta, corrección y baja de servicios y mano de obra con totales recalculados (importes como cadenas de dos decimales y sin errores de redondeo); el mecánico asignado y el ADMIN pueden, otro mecánico recibe 404 y recepción 403; `ORDER_READ_ONLY` en una orden `ENTREGADO` para cada operación; permite editar en cualquier estado anterior a `ENTREGADO`; una línea inexistente o de otra orden responde 404

### Implementación de la historia 5

- [X] T062 [P] [US5] Ampliar `server/validators/orderValidators.js` con `updateWorkSchema` (`diagnosis`, `observations`, `recommendations` con `longText`, al menos un campo), `createLineSchema` (`description` de 1 a 255 caracteres y `amount` con `money`) y `updateLineSchema` (parcial, al menos un campo), más `lineParams` (`id` y `serviceId`/`laborId` positivos)
- [X] T063 [US5] Ampliar `server/models/orderWorkModel.js` con `insertService`, `updateService`, `deleteService`, `insertLabor`, `updateLabor`, `deleteLabor` (siempre con `AND order_id = ?` para no tocar líneas de otra orden) y `server/models/orderModel.js` con `updateWork(id, fields)` (lista blanca `diagnosis`, `observations`, `recommendations`)
- [X] T064 [US5] Crear `server/services/orderWorkService.js`: `updateWork`, `addService`, `updateService`, `removeService`, `addLabor`, `updateLabor`, `removeLabor`; cada operación usa `loadOrderForActor` (rol ADMIN o mecánico asignado), rechaza `ENTREGADO` con `ORDER_READ_ONLY` y devuelve la línea con los `totals` recalculados
- [X] T065 [US5] Crear `server/controllers/orderWorkController.js` y añadir a `server/routes/orderRoutes.js` `PATCH /:id/work`, `POST /:id/services`, `PATCH|DELETE /:id/services/:serviceId`, `POST /:id/labor` y `PATCH|DELETE /:id/labor/:laborId` con `authorize(ROLES.ADMIN, ROLES.MECHANIC)`

### Interfaz de la historia 5

- [X] T066 [P] [US5] Crear `client/lib/models/order_work.dart` (línea de servicio o mano de obra, totales) y ampliar `client/lib/services/orders_service.dart` con `updateWork`, `addService`, `updateService`, `removeService`, `addLabor`, `updateLabor` y `removeLabor`
- [X] T067 [US5] Crear `client/lib/providers/order_detail_provider.dart` (carga el detalle, aplica cambios y recarga; maneja estados cargando, error y conflicto)
- [X] T068 [US5] Ampliar `client/lib/screens/order_detail_screen.dart` con edición de diagnóstico, observaciones y recomendaciones, y tablas de servicios y mano de obra con alta, edición y baja (diálogo de confirmación al quitar una línea) y totales; las acciones de edición solo para el mecánico asignado y el administrador y ocultas en órdenes entregadas, con el aviso «Orden entregada: solo lectura»
- [X] T069 [US5] Crear `client/test/order_work_test.dart`: edición del diagnóstico, alta y baja de líneas con confirmación, recálculo de totales, acciones ocultas a recepción y en órdenes entregadas

**Punto de control**: el mecánico documenta el trabajo (CA-4).

---

## Fase 8: Historia de usuario 6 - Cambiar el estado de una orden (Prioridad: P2)

**Objetivo**: el mecánico avanza la orden hasta `TERMINADO`; recepción o administración registran la entrega.

**Prueba independiente**: avanzar una orden de `RECIBIDO` a `TERMINADO` con el mecánico, entregarla con recepción, probar `ESPERANDO_REFACCION`, intentar saltos de estado y comprobar el historial y la cita.

### Pruebas de la historia 6

- [X] T070 [P] [US6] Crear `server/tests/contract/orders.status.contract.test.js`: forma de `POST /api/orders/:id/status`, `422 INVALID_TRANSITION` con `details.allowed`, `422 ORDER_UNASSIGNED`, `409 STATE_CONFLICT`, `401` sin token y `403` para el rol sin permiso
- [X] T071 [P] [US6] Crear `server/tests/integration/orders.status.test.js` (CA-5, CA-7, SC-003): flujo completo `RECIBIDO → DIAGNOSTICO → EN_REPARACION → TERMINADO → ENTREGADO` con los tres roles; `ESPERANDO_REFACCION` desde `DIAGNOSTICO` y `EN_REPARACION` y regreso solo a `EN_REPARACION`; saltos y retrocesos rechazados con la lista de permitidas; el mecánico no puede entregar; recepción no puede avanzar hasta `TERMINADO`; el ADMIN sí; orden sin mecánico no sale de `RECIBIDO`; la cita pasa a `COMPLETADA` al llegar a `TERMINADO`; `delivered_at` se fija al entregar; cada cambio deja un registro en el historial con usuario y fecha; `ORDER_READ_ONLY` tras la entrega y no hay `DELETE`; conflicto: dos cambios simultáneos de la misma orden, solo uno prospera y el otro recibe `STATE_CONFLICT` con el estado vigente
- [X] T072 [P] [US6] Ampliar `server/tests/integration/orders.mechanicScope.test.js`: un mecánico no puede cambiar el estado de una orden ajena (404)

### Implementación de la historia 6

- [X] T073 [P] [US6] Ampliar `server/validators/orderValidators.js` con `changeStatusSchema` (`status` dentro de `ORDER_STATUSES`, mensaje en español)
- [X] T074 [US6] Ampliar `server/models/orderModel.js` con `updateStatusIf(id, from, to, extraFields, connection)` (`UPDATE … SET status = ? WHERE id = ? AND status = ?`, devuelve `affectedRows`) y `server/models/appointmentModel.js` con `setStatusByOrder`
- [X] T075 [US6] Ampliar `server/services/orderService.js` con `changeStatus(id, to, actor)`: carga con `loadOrderForActor`, rechaza `ENTREGADO` con `ORDER_READ_ONLY`, valida con `assertTransition` y `canActorTransition` (403 `FORBIDDEN` si el rol no puede, incluida recepción hasta `TERMINADO`), exige mecánico (`ORDER_UNASSIGNED`) para salir de `RECIBIDO`, y dentro de `withTransaction` aplica `updateStatusIf`, responde `409 STATE_CONFLICT` con `details.currentStatus` si `affectedRows` es 0, inserta el historial, fija `delivered_at` al entregar y pasa la cita a `COMPLETADA` al llegar a `TERMINADO`
- [X] T076 [US6] Añadir `POST /:id/status` a `server/routes/orderRoutes.js` (`authorize(ROLES.ADMIN, ROLES.RECEPTIONIST, ROLES.MECHANIC)`; la autorización fina por destino la hace el servicio) y su método en `server/controllers/orderController.js`

### Interfaz de la historia 6

- [X] T077 [P] [US6] Ampliar `client/lib/services/orders_service.dart` con `changeStatus` y `client/lib/providers/order_detail_provider.dart` con la acción de cambio, que ante `STATE_CONFLICT` recarga la orden y expone el mensaje con el estado vigente
- [X] T078 [US6] Ampliar `client/lib/screens/order_detail_screen.dart` con los botones de transición generados desde `allowedTransitions` del servidor, diálogo de confirmación para "Registrar entrega" (`confirm_dialog.dart`), mensaje de éxito, mensaje de conflicto y las acciones de avance deshabilitadas con explicación cuando no hay mecánico; mostrar el historial de estados con persona y fecha
- [X] T079 [US6] Crear `client/test/order_status_test.dart`: botones según `allowedTransitions`, entrega con confirmación solo para recepción, conflicto de estado, orden sin mecánico y orden entregada de solo lectura

**Punto de control**: las transiciones respetan la secuencia (CA-5) y las pruebas de la lógica existen y pasan (CA-8).

---

## Fase 9: Pulido y aspectos transversales

**Propósito**: datos de ejemplo, validación de extremo a extremo y documentación

- [X] T080 Generar con `bcryptjs` (costo 10) el hash de la contraseña de `mecanico2` indicada en T002, sin escribir la contraseña en ningún archivo del repositorio distinto de `docs/project-context.md`
- [X] T081 Crear `database/seeds/002_appointments_orders.sql`, idempotente y sin identificadores fijos (research D-15): `INSERT IGNORE` del usuario `mecanico2` (`mecanico2@motorix.local`, rol MECHANIC, hash de T080); citas con `INSERT … SELECT … WHERE NOT EXISTS` por clave natural (placa del vehículo + motivo) y fechas relativas a `NOW()`: dos futuras (una `PENDIENTE` y una `CONFIRMADA`), una `EN_PROCESO` ligada a una orden, una `COMPLETADA` y una `CANCELADA` con motivo; órdenes por clave natural (placa + problema reportado), una por cada estado `RECIBIDO`, `DIAGNOSTICO`, `EN_REPARACION`, `ESPERANDO_REFACCION` y `TERMINADO` en vehículos distintos, más dos `ENTREGADO`, repartidas entre `mecanico` y `mecanico2` (y una sin asignar en `RECIBIDO`), con `entry_mileage` igual o mayor al kilometraje del vehículo sembrado en el Sprint 1, diagnóstico, servicios, mano de obra, recomendaciones e historial de estados coherente (solo para las líneas e historial de órdenes nuevas, con `NOT EXISTS` por orden y descripción)
- [X] T082 Crear `server/tests/integration/seeds.sprint2.test.js` (FR-026, SC-009): tras `runSeedFile('001_initial_data.sql')` y `runSeedFile('002_appointments_orders.sql')` existen citas en los cinco estados y órdenes en los seis estados, dos mecánicos, ningún vehículo con más de una orden abierta, kilometraje de entrada coherente; repetir el seed no duplica nada (conteos iguales) ni rompe referencias
- [X] T083 Aplicar el seed en `motorix` (`database/scripts/aplicar-seeds.ps1 -Base motorix`), repetirlo y verificar que las pantallas muestran datos al abrir la aplicación
- [X] T084 [P] Revisar con `flutter analyze` que no queden avisos y que toda pantalla nueva use los tokens de `client/lib/utils/tokens.dart` (sin colores, espaciados ni radios sueltos) y tenga estados vacío, cargando y error
- [X] T085 [P] Revisar el rendimiento (SC-010): ampliar `server/tests/integration/performance.test.js` con 1 000 citas y 1 000 órdenes y verificar que listados, filtros y búsqueda responden en menos de 2 s
- [X] T086 Ejecutar todas las pruebas (`npm test` en `server/`, `flutter test` en `client/`) y recorrer los 17 escenarios de `quickstart.md` contra MySQL local con la API real; completar la sección 6 "Resultado de la validación" de `specs/002-citas-ordenes-servicio/quickstart.md`
- [X] T087 [P] Actualizar `README.md` de la raíz y `client/README.md` con los módulos de Citas y Órdenes, las cuentas de ejemplo nuevas (sin contraseñas) y el enlace a `specs/002-citas-ordenes-servicio/quickstart.md`
- [X] T088 [P] Auditoría de seguridad y reglas: confirmar que no hay secretos en el repositorio, que ninguna ruta nueva carece de `authenticate`/`authorize`, que no existe `DELETE` para citas ni órdenes, que los errores no exponen trazas y que el backend no usa `require` ni `module.exports`

---

## Dependencias y orden de ejecución

### Dependencias entre fases

- **Fase 1** (preparación): sin dependencias
- **Fase 2** (fundamentos): tras la Fase 1; **bloquea todas las historias**
- **Fases 3 a 8** (historias): tras la Fase 2, en el orden de prioridad
- **Fase 9** (pulido): tras las historias que se quieran entregar

### Dependencias entre historias

- **US1 (P1)**: independiente; solo necesita la Fase 2
- **US2 (P1)**: independiente en el backend; su botón "Recibir vehículo y crear orden" usa la pantalla de detalle de cita de US1 (T028)
- **US3 (P1)**: necesita el servicio y las rutas de órdenes de US2 (T038, T039)
- **US4 (P1)**: necesita US2 (listado y detalle) y US3 (asignación para tener órdenes de mecánico)
- **US5 (P2)**: necesita US4 (`loadOrderForActor`, T057) y el detalle de US2
- **US6 (P2)**: necesita US4 (`loadOrderForActor`) y US2; la sincronización con la cita usa US1 y US2
- Dentro de cada historia: pruebas → validadores → modelos → servicios → controladores y rutas → interfaz

### Oportunidades de paralelismo

- Fase 1: T002 y T003 en paralelo tras T001
- Fase 2: T006 a T008 (utilidades), T009 a T011 (pruebas unitarias), T013 a T015 y T017 en paralelo; T012 y T016 son secuenciales por tocar archivos compartidos
- Tras la Fase 2: US1 y el backend de US2 pueden avanzarse en paralelo (archivos distintos); las tareas del mismo archivo (`orderService.js`, `orderRoutes.js`, `orderController.js`, `orderModel.js`, `orders_service.dart`, `order_detail_screen.dart`) NO se marcan [P] entre sí y se ejecutan en el orden de las historias

### Ejemplo de paralelismo: Historia de usuario 1

```text
Pruebas:        T018 (contrato)  T019 (integración)          # en paralelo
Backend:        T020 (validadores) en paralelo con T024 y T025 (cliente)
Luego:          T021 → T022 → T023 (modelo → servicio → rutas)
Interfaz:       T026 → T027 → T028 → T029 → T030
```

---

## Estrategia de implementación

### MVP primero

1. Completar las Fases 1 y 2 (migración, utilidades y plantillas)
2. Completar US1 (citas) y US2 (crear orden): entregan la llegada del vehículo y la orden asociada
3. **Detener y validar**: probar de forma independiente con los escenarios 2 a 7 de `quickstart.md`
4. Seguir con US3 y US4 (asignación y vista del mecánico) para tener el flujo de recepción a taller
5. Terminar con US5 y US6 (trabajo y estados) y la Fase 9 (seeds y validación completa)

### Entrega incremental

Cada historia se cierra con sus pruebas en verde antes de pasar a la siguiente: US1 → US2 → US3 → US4 → US5 → US6. El sprint se considera completo cuando se cumplen CA-1 a CA-8 de `docs/sprints/sprint-2-citas-ordenes.md` y el flujo "registrar cita → recibir vehículo → crear orden → asignar → diagnóstico → servicios → estado → terminar" se demuestra con los tres roles.

## Notas

- Las tareas [P] tocan archivos distintos y no dependen de tareas incompletas.
- Cada historia debe poder completarse y probarse de forma independiente salvo las dependencias indicadas.
- Confirmar que las pruebas fallan antes de implementar y hacer un commit pequeño por tarea o grupo lógico (Conventional Commits con la descripción en español).
- No se editan scripts de sprints ya aplicados: todo cambio de esquema va en `002_…`.
- Ninguna contraseña en texto plano en código ni scripts; las del estándar del MVP viven solo en `docs/project-context.md`.
