---

description: "Lista de tareas del Sprint 3: historial, mantenimiento e inventario"
---

# Tareas: Historial, mantenimiento e inventario (Sprint 3)

**Entrada**: Documentos de diseño en `specs/003-historial-inventario/`

**Requisitos previos**: plan.md, spec.md, research.md, data-model.md, contracts/ (api-rest.md e interfaz.md), quickstart.md

**Pruebas**: INCLUIDAS. La constitución (Principio VII) exige pruebas para la lógica de negocio (estado de mantenimiento, reglas de stock, permisos) y el sprint exige CA-8; las del backend usan Jest + supertest contra `motorix_test` y las del frontend `flutter test`.

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
- Solo `inventoryService` modifica `parts.stock` y registra movimientos; ningún otro módulo escribe en esas tablas

## Orden de las historias (prioridad)

P1: US1 (historial del vehículo), US2 (kilometraje del servicio y próximo mantenimiento), US3 (catálogo y stock de refacciones), US4 (refacciones en la orden). P2: US5 (lista de mantenimientos próximos y vencidos), US6 (alertas de stock bajo).

> Correspondencia con la especificación: US1 = Historia 1; US2 = Historia 2; US3 = Historia 4; US4 = Historia 5; US5 = Historia 3; US6 = Historia 6.

---

## Fase 1: Preparación (infraestructura compartida)

**Propósito**: verificar la base de los sprints 1 y 2 y alinear la documentación

- [X] T001 Verificar la línea base: MySQL local en ejecución, migraciones 001 y 002 aplicadas en `motorix` y `motorix_test`, y `npm test` (en `server/`) y `flutter test` (en `client/`) en verde antes de empezar
- [X] T002 [P] Actualizar `docs/project-context.md`: en las entidades `Part`, `InventoryMovement` y `Maintenance` reflejar los campos del Sprint 3 (research D-12: sin precios, marca ni categoría; movimiento con cantidad con signo, motivo, orden y persona; mantenimiento con descripción, fecha y kilometraje objetivo, orden de origen y estado), y registrar la tabla `order_parts` y la columna `service_orders.service_mileage` en la sección de tablas del Sprint 3
- [X] T003 [P] Actualizar `.env.example` con `MAINTENANCE_WARN_DAYS=30` y `MAINTENANCE_WARN_KM=1000` (opcionales, con un comentario en español que explique el margen de aviso «Próximo»)
- [X] T004 [P] Actualizar `database/README.md` con la migración `003_sprint3_maintenance_inventory.sql` y el seed `003_history_inventory.sql`

---

## Fase 2: Fundamentos (requisitos bloqueantes)

**Propósito**: esquema, reglas puras, configuración y plantillas de prueba que DEBEN existir antes de cualquier historia

**⚠️ CRÍTICO**: ninguna historia puede empezar hasta terminar esta fase

### Base de datos

- [X] T005 Crear `database/migrations/003_sprint3_maintenance_inventory.sql` (InnoDB, `utf8mb4`, intercolado `utf8mb4_0900_ai_ci`, sin editar las migraciones 001 y 002; `ON DELETE RESTRICT` en todas las llaves foráneas). Contenido según data-model.md:
  - `ALTER TABLE service_orders ADD COLUMN service_mileage INT UNSIGNED NULL`
  - `parts`: `id` INT UNSIGNED AUTO_INCREMENT PK; `code` VARCHAR(40) NOT NULL con `UNIQUE uq_parts_code`; `name` VARCHAR(120) NOT NULL; `description` VARCHAR(500) NULL; `unit` VARCHAR(20) NOT NULL; `stock` INT UNSIGNED NOT NULL DEFAULT 0 con CHECK (`stock >= 0`); `min_stock` INT UNSIGNED NOT NULL DEFAULT 0; `active` TINYINT(1) NOT NULL DEFAULT 1; `created_at` y `updated_at` DATETIME NOT NULL (`DEFAULT CURRENT_TIMESTAMP`, y `ON UPDATE CURRENT_TIMESTAMP` en `updated_at`); índices `idx_parts_name (name)` e `idx_parts_stock (active, stock, min_stock)`
  - `inventory_movements`: `id` BIGINT UNSIGNED AUTO_INCREMENT PK; `part_id` INT UNSIGNED NOT NULL FK → `parts(id)`; `type` ENUM('IN','OUT','ADJUSTMENT') NOT NULL; `quantity` INT NOT NULL (con signo); `reason` VARCHAR(255) NULL; `order_id` INT UNSIGNED NULL FK → `service_orders(id)`; `created_by` INT UNSIGNED NOT NULL FK → `users(id)`; `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP; CHECK `((type = 'IN' AND quantity > 0) OR (type = 'OUT' AND quantity < 0) OR (type = 'ADJUSTMENT' AND quantity <> 0))` y CHECK `(ABS(quantity) <= 100000)`; índices `idx_movements_part (part_id, created_at)` e `idx_movements_order (order_id)`; sin `updated_at` (tabla de solo agregar)
  - `order_parts`: `id` INT UNSIGNED AUTO_INCREMENT PK; `order_id` INT UNSIGNED NOT NULL FK → `service_orders(id)`; `part_id` INT UNSIGNED NOT NULL FK → `parts(id)`; `quantity` INT UNSIGNED NOT NULL con CHECK (`quantity > 0`); `created_by` INT UNSIGNED NOT NULL FK → `users(id)`; `created_at` y `updated_at` DATETIME NOT NULL; `UNIQUE uq_order_parts_line (order_id, part_id)`
  - `maintenance`: `id` INT UNSIGNED AUTO_INCREMENT PK; `vehicle_id` INT UNSIGNED NOT NULL FK → `vehicles(id)` con `ON UPDATE RESTRICT` (columna base de una columna generada); `order_id` INT UNSIGNED NOT NULL FK → `service_orders(id)`; `description` VARCHAR(255) NOT NULL; `due_date` DATE NULL; `due_mileage` INT UNSIGNED NULL; `status` ENUM('PENDIENTE','ATENDIDO') NOT NULL DEFAULT 'PENDIENTE'; `attended_at` DATETIME NULL; `pending_vehicle_id` INT UNSIGNED GENERATED ALWAYS AS (IF(status = 'PENDIENTE', vehicle_id, NULL)) STORED con `UNIQUE uq_maintenance_pending (pending_vehicle_id)`; `created_by` INT UNSIGNED NOT NULL FK → `users(id)`; `created_at` y `updated_at` DATETIME NOT NULL; CHECK `(due_date IS NOT NULL OR due_mileage IS NOT NULL)`; índices `idx_maintenance_vehicle (vehicle_id)` e `idx_maintenance_due (status, due_date)`
- [X] T006 Aplicar la migración con `database/scripts/aplicar-migraciones.ps1 -Base motorix` y `-Base motorix_test`, y verificar que quede registrada en `schema_migrations`, que existan las 4 tablas y la columna nueva, y que repetir el comando no la vuelva a ejecutar

### Configuración y reglas puras del backend

- [X] T007 [P] Modificar `server/config/env.js`: añadir `getMaintenanceConfig(source = process.env)` que lee `MAINTENANCE_WARN_DAYS` (por defecto 30) y `MAINTENANCE_WARN_KM` (por defecto 1000), exige enteros positivos y lanza un error en español si el valor es inválido; no debe exigir las variables de la base (research D-03)
- [X] T008 [P] Crear `server/services/maintenanceStatus.js` (módulo puro, sin acceso a base ni a Express): `computeIndicator({ dueDate, dueMileage, currentMileage, today, warnDays, warnKm })` → `'VENCIDO'` si `dueDate < today` o `currentMileage >= dueMileage`; `'PROXIMO'` si no vencido y (`dueDate - today <= warnDays` días o `dueMileage - currentMileage <= warnKm`); `'NORMAL'` en otro caso; solo evalúa las condiciones definidas y omite la de kilometraje si `currentMileage` es nulo; una fecha igual a hoy es Próximo. Además `assertMaintenanceTarget({ dueDate, dueMileage, currentMileage, today })` que lanza `MAINTENANCE_TARGET_REQUIRED` (sin fecha ni kilometraje), `MAINTENANCE_DATE_IN_PAST` (`dueDate < today`) o `MAINTENANCE_MILEAGE_TOO_LOW` (`dueMileage <= currentMileage`) con los códigos de contracts/api-rest.md
- [X] T009 [P] Crear `server/services/stockRules.js` (módulo puro): `MAX_MOVEMENT_QUANTITY = 100000`, `assertPositiveInteger(value, field)` (entero positivo ≤ 100 000, rechaza cero, negativos, decimales y no numéricos), `computeAdjustmentDelta({ stock, countedQuantity })` (entero ≥ 0 y ≤ 1 000 000; lanza `NO_ADJUSTMENT_DIFFERENCE` si la diferencia es 0), `signedQuantity(type, magnitude)` (IN +, OUT −) y `assertStockAvailable({ available, requested })` que lanza `INSUFFICIENT_STOCK` con `details.available` y `details.requested`
- [X] T010 [P] Ampliar `server/services/mileageRule.js` con `assertServiceMileage({ entry, service })`: entero entre 0 y `MAX_MILEAGE` (2 000 000) y no menor al kilometraje de entrada; lanza `SERVICE_MILEAGE_TOO_LOW` o un error de validación (sin romper `assertEntryMileage`)

### Plantillas de prueba y esquema de validación

- [X] T011 [P] Ampliar `server/tests/helpers/factories.js` con `createPart`, `createMovement`, `createOrderPart`, `createMaintenance` y `createFinishedOrder` (orden en `TERMINADO` o `ENTREGADO` con mecánico, servicios y kilometraje), y limpieza de las tablas nuevas entre pruebas respetando el orden de las llaves foráneas
- [X] T012 [P] Ampliar `server/tests/helpers/seed.js` con la ejecución del seed `003_history_inventory.sql` sobre `motorix_test` (solo bases `_test`)
- [X] T013 [P] Crear `server/validators/partValidators.js` con esquemas `zod`: `createPartSchema` (`code` 2–40 caracteres de letras, números, guion y guion bajo, normalizado a mayúsculas; `name` 2–120; `description` opcional hasta 500; `unit` 1–20; `minStock` e `initialStock` enteros 0–1 000 000), `updatePartSchema` (parcial: `name`, `description`, `unit`, `minStock`, `active`; rechaza `code` y `stock`), `listPartsQuery` (`search`, `stockStatus` SUFICIENTE|BAJO|AGOTADO, `active`, `page`, `pageSize`) y `movementSchema` (unión por `type`: `IN` con `quantity` entero positivo ≤ 100 000 y `reason` opcional; `ADJUSTMENT` con `countedQuantity` y `reason` de 5–255 caracteres; rechaza `OUT`)
- [X] T014 [P] Crear `server/validators/maintenanceValidators.js` con `createMaintenanceSchema` (`description` 3–255, `dueDate` `YYYY-MM-DD` opcional, `dueMileage` entero opcional ≤ 2 000 000), `updateMaintenanceSchema` (parcial) y `listMaintenanceQuery` (`status` por defecto `PENDIENTE`, `indicator` NORMAL|PROXIMO|VENCIDO, `search`, `page`, `pageSize`); y ampliar `server/validators/orderValidators.js` con `serviceMileageSchema` (`serviceMileage` entero), `addOrderPartSchema` (`partId`, `quantity` entero positivo ≤ 100 000), `updateOrderPartSchema` (`quantity`) y `orderPartParams` (`id`, `lineId`)

### Pruebas de las reglas puras (CA-8)

- [X] T015 [P] Crear `server/tests/unit/maintenanceStatus.test.js`: cubre Vencido por fecha, por kilometraje, por una sola de dos condiciones, Próximo por días y por kilómetros (límites exactos de 30 días y 1 000 km), fecha igual a hoy, Normal, mantenimiento solo por fecha, solo por kilometraje, vehículo sin kilometraje, márgenes personalizados y las tres validaciones de `assertMaintenanceTarget`; nombres y aserciones en español
- [X] T016 [P] Crear `server/tests/unit/stockRules.test.js`: cantidades cero, negativas, decimales, no numéricas y mayores a 100 000; `computeAdjustmentDelta` (diferencia positiva, negativa y cero; contado negativo o decimal); `signedQuantity`; `assertStockAvailable` con stock justo, insuficiente y cero; y `assertServiceMileage` (igual, mayor, menor a la entrada y fuera de rango)

**Punto de control**: la migración está aplicada y las reglas puras tienen pruebas en verde; las historias pueden comenzar.

---

## Fase 3: Historia de usuario 1 - Consultar el historial de servicios de un vehículo (Prioridad: P1) 🎯 MVP

**Objetivo**: mostrar a cualquier rol las órdenes Terminadas o Entregadas de un vehículo en orden cronológico, derivadas de las órdenes (sin tabla propia).

**Prueba independiente**: con un vehículo con varias órdenes terminadas y una abierta, `GET /api/vehicles/:id/history` devuelve solo las terminadas, la más reciente primero, con servicios, mano de obra, refacciones (vacías aún), mecánico y kilometraje; y el detalle del vehículo las muestra.

### Pruebas de la historia 1

- [X] T017 [P] [US1] Crear `server/tests/contract/history.contract.test.js`: forma de `GET /api/vehicles/:id/history` según contracts/api-rest.md (`vehicle`, `entries[]`, `pendingMaintenance`, `meta`), `404` para vehículo inexistente, `401` sin sesión y acceso permitido a los tres roles
- [X] T018 [P] [US1] Crear `server/tests/integration/history.test.js`: orden cronológico descendente, exclusión de órdenes abiertas, estado vacío (`entries: []`), una orden que pasa a Terminado aparece de inmediato, `mileage` usa el kilometraje del servicio y cae al de entrada si no existe, mecánico ve el historial de un vehículo ajeno, y paginación

### Implementación de la historia 1

- [X] T019 [US1] Crear `server/models/vehicleHistoryModel.js`: consulta de las órdenes `TERMINADO` o `ENTREGADO` de un vehículo (ordenadas por fecha de servicio descendente, con paginación) y carga en lote de servicios, mano de obra, refacciones (`order_parts` con `parts`), mecánico y mantenimiento programado desde cada orden, sin consultas por fila (N+1)
- [X] T020 [US1] Crear `server/services/vehicleHistoryService.js`: arma la respuesta de contracts/api-rest.md (`serviceDate` = fecha del paso a Terminado o la de creación; `mileage` = `service_mileage` o `entry_mileage`; `indicator` calculado con `computeIndicator` y `getMaintenanceConfig`; `pendingMaintenance` del vehículo) y responde `404` si el vehículo no existe
- [X] T021 [US1] Crear `server/controllers/vehicleHistoryController.js` y añadir en `server/routes/vehicleRoutes.js` la ruta `GET /:id/history` (solo `authenticate`, todos los roles) con `validate` de `idParams` y paginación
- [X] T022 [P] [US1] Crear `client/lib/models/history_entry.dart` (entrada del historial, refacción y mantenimiento embebido) y `client/lib/providers/vehicle_history_provider.dart` (estados cargando, vacío, error y datos, con paginación); ampliar `client/lib/services/vehicles_service.dart` con `fetchHistory(vehicleId, page)`
- [X] T023 [US1] Crear `client/lib/widgets/vehicle_history_section.dart` (línea cronológica con fecha, folio, kilometraje con separador de miles, problema, diagnóstico, servicios, refacciones y mecánico; estados vacío «Este vehículo aún no tiene servicios terminados», cargando y error con reintento; mantenimiento vigente destacado) y mostrarla en `client/lib/screens/vehicle_detail_screen.dart` siguiendo `docs/design-system.md`
- [X] T024 [P] [US1] Crear `client/test/vehicle_history_test.dart`: historial con entradas, estado vacío, error con reintento, y visible para los tres roles

**Punto de control**: el historial del vehículo funciona con los escenarios 2 y 3 de `quickstart.md`.

---

## Fase 4: Historia de usuario 2 - Registrar el kilometraje del servicio y el próximo mantenimiento (Prioridad: P1)

**Objetivo**: el mecánico asignado (y los administradores) registran el kilometraje del servicio de una orden Terminada y programan el próximo mantenimiento por fecha, kilometraje o ambos.

**Prueba independiente**: con una orden Terminada asignada a un mecánico, `PUT /api/orders/:id/service-mileage` y `POST /api/orders/:id/maintenance` funcionan, el historial refleja ambos, y las validaciones y los permisos se respetan.

### Pruebas de la historia 2

- [X] T025 [P] [US2] Crear `server/tests/contract/maintenance.contract.test.js` (parte de escritura): formas y códigos de error de `PUT /orders/:id/service-mileage`, `POST /orders/:id/maintenance`, `PATCH /maintenance/:id` y `POST /maintenance/:id/attend` según contracts/api-rest.md
- [X] T026 [P] [US2] Crear `server/tests/integration/serviceMileage.test.js`: kilometraje igual y mayor al de entrada, menor (`SERVICE_MILEAGE_TOO_LOW`), fuera de rango, solo con la orden en Terminado (`ORDER_NOT_FINISHED`), orden Entregada (`ORDER_READ_ONLY`), actualización del kilometraje actual del vehículo solo si es mayor, corrección mientras siga Terminado, mecánico no asignado → `404`, recepción → `403`
- [X] T027 [P] [US2] Crear `server/tests/integration/maintenance.flow.test.js`: programar por fecha, por kilometraje y por ambos; sin objetivos, fecha pasada y kilometraje ≤ actual; orden anterior a Terminado (`ORDER_NOT_FINISHED`); un nuevo mantenimiento deja al anterior en `ATENDIDO` (y dos programaciones simultáneas dejan un solo pendiente); editar y atender; `MAINTENANCE_NOT_EDITABLE` sobre uno Atendido; mecánico de otra orden → `404`; recepción → `403`; mantenimiento visible en el historial

### Implementación de la historia 2

- [X] T028 [P] [US2] Modificar `server/models/orderModel.js`: columna `service_mileage` en las lecturas y `setServiceMileage(id, value, connection)` que además actualiza `vehicles.current_mileage = GREATEST(COALESCE(current_mileage, 0), :valor)` en la misma transacción
- [X] T029 [P] [US2] Crear `server/models/maintenanceModel.js`: `insert`, `findById` (con vehículo, cliente y orden de origen), `update`, `markAttended`, `attendPendingByVehicle(vehicleId, connection)` y `findPendingByVehicle`; traduce `ER_DUP_ENTRY` del índice `uq_maintenance_pending` a un conflicto reintentable
- [X] T030 [US2] Modificar `server/services/orderService.js` (`buildDetail`): incluir `serviceMileage` y el mantenimiento programado desde la orden en el detalle; y crear `server/services/maintenanceService.js` con `schedule(orderId, data, actor)` (reutiliza `loadOrderForActor` para la pertenencia; exige orden `TERMINADO` o `ENTREGADO`; valida con `assertMaintenanceTarget` contra el kilometraje actual del vehículo; en una sola transacción marca como Atendido el pendiente anterior y crea el nuevo), `update(id, data, actor)` y `attend(id, actor)` (solo ADMIN y el mecánico de la orden de origen; `MAINTENANCE_NOT_EDITABLE` si ya está Atendido) y `setServiceMileage(orderId, value, actor)` (orden `TERMINADO`; `ORDER_READ_ONLY` si Entregada; bloqueo de la orden con `orderModel.lockById`)
- [X] T031 [US2] Crear `server/controllers/maintenanceController.js` y rutas: en `server/routes/orderRoutes.js` añadir `PUT /:id/service-mileage` y `POST /:id/maintenance` con `authorize(ROLES.ADMIN, ROLES.MECHANIC)`; crear `server/routes/maintenanceRoutes.js` con `PATCH /:id` y `POST /:id/attend` (`authorize(ADMIN, MECHANIC)`; la pertenencia la valida el servicio); montar `/maintenance` en `server/routes/index.js`; no existe ruta `DELETE`
- [X] T032 [P] [US2] Crear `client/lib/models/maintenance.dart` y `client/lib/services/maintenance_service.dart` (programar, editar y marcar Atendido); ampliar `client/lib/services/orders_service.dart` con `setServiceMileage`, y `client/lib/models/service_order.dart` con `serviceMileage` y el mantenimiento programado
- [X] T033 [US2] Modificar `client/lib/screens/order_detail_screen.dart` y `client/lib/providers/order_detail_provider.dart`: secciones «Kilometraje del servicio» (visible para el mecánico asignado y ADMIN con la orden Terminada) y «Próximo mantenimiento» con formulario (descripción, fecha opcional, kilometraje opcional; al menos uno), mensajes de éxito y errores del servidor en español, confirmación al marcar Atendido, y solo lectura con «Orden entregada: solo lectura»
- [X] T034 [P] [US2] Crear `client/test/order_maintenance_test.dart`: formulario con validación de al menos un objetivo, errores del servidor, acciones ocultas para recepción y confirmación de «Marcar como atendido»

**Punto de control**: escenarios 4 a 7 de `quickstart.md` funcionan y el historial muestra el mantenimiento vigente.

---

## Fase 5: Historia de usuario 3 - Registrar y consultar refacciones y su stock (Prioridad: P1)

**Objetivo**: el administrador registra y mantiene el catálogo, registra entradas y ajustes por conteo y consulta el stock y los movimientos; el mecánico consulta una vista reducida.

**Prueba independiente**: como administrador, crear una refacción con stock inicial, editarla, registrar una entrada y un ajuste, y ver el stock y los movimientos; el mecánico solo ve código, nombre, unidad y existencia.

### Pruebas de la historia 3

- [X] T035 [P] [US3] Crear `server/tests/contract/parts.contract.test.js` y `server/tests/contract/inventory.contract.test.js`: formas de `GET/POST/PATCH /parts`, `GET /parts/:id`, `GET/POST /parts/:id/movements`, proyección reducida del mecánico y códigos de error (`PART_CODE_TAKEN`, `PART_INACTIVE`, `NO_ADJUSTMENT_DIFFERENCE`, `VALIDATION_ERROR`)
- [X] T036 [P] [US3] Crear `server/tests/integration/parts.flow.test.js`: alta con stock inicial (genera movimiento `IN` «Stock inicial»), código duplicado sin distinguir mayúsculas, búsqueda por código o nombre, filtro por estado de stock, edición sin alterar stock, activar y desactivar, sin `DELETE`, mecánico con vista reducida y solo activas, recepción → `403`
- [X] T037 [P] [US3] Crear `server/tests/integration/inventory.movements.test.js`: entrada, ajuste por conteo (el stock queda en lo contado y el movimiento guarda la diferencia), ajuste sin diferencia, contado negativo o decimal, motivo corto, entrada a refacción inactiva, `OUT` rechazado por esta vía, historial de movimientos paginado, y la invariante `stock = SUM(quantity)` tras cada escenario

### Implementación de la historia 3

- [X] T038 [P] [US3] Crear `server/models/partModel.js`: `insert`, `findById`, `findByCode`, `lockById(id, connection)` (`SELECT … FOR UPDATE`), `update`, `list` con búsqueda por código o nombre, filtro por estado de stock (`AGOTADO`: `stock = 0`; `BAJO`: `stock > 0 AND stock <= min_stock`; `SUFICIENTE`: `stock > min_stock`) y paginación; proyección reducida para el mecánico; y `applyDelta(id, delta, connection)` con `UPDATE parts SET stock = stock + :delta WHERE id = :id AND stock + :delta >= 0` que devuelve si afectó una fila
- [X] T039 [P] [US3] Crear `server/models/inventoryMovementModel.js`: `insert` y `listByPart` (con orden y persona relacionadas, paginado); sin operaciones de actualización ni borrado
- [X] T040 [US3] Crear `server/services/inventoryService.js` (único punto que cambia el stock): `registerMovement({ partId, type, quantity, reason, orderId, actor }, connection)` que bloquea la refacción, valida con `stockRules`, aplica `applyDelta`, lanza `INSUFFICIENT_STOCK` con el stock vigente si no hay existencia e inserta el movimiento en la misma transacción; más `receive` (entrada, rechaza refacción inactiva con `PART_INACTIVE`) y `adjust` (calcula `computeAdjustmentDelta` contra el stock bloqueado)
- [X] T041 [US3] Crear `server/services/partService.js` (alta con movimiento `IN` «Stock inicial» si `initialStock > 0`, `PART_CODE_TAKEN` por `ER_DUP_ENTRY`, edición, activar/desactivar, listado con `stockStatus` calculado y detalle con últimos movimientos) y `server/controllers/partController.js` y `server/controllers/inventoryController.js`
- [X] T042 [US3] Crear `server/routes/partRoutes.js`: `GET /` con `authorize(ADMIN, MECHANIC)` (el servicio decide la proyección según el rol); `POST /`, `PATCH /:id`, `GET /:id`, `GET /:id/movements` y `POST /:id/movements` solo con `authorize(ADMIN)`; sin `DELETE`; montar `/parts` en `server/routes/index.js`
- [X] T043 [P] [US3] Crear `client/lib/models/part.dart` y `client/lib/models/inventory_movement.dart`, `client/lib/services/parts_service.dart`, `client/lib/providers/parts_provider.dart` y `client/lib/providers/part_detail_provider.dart` (listado con búsqueda, filtros y paginación; detalle con movimientos)
- [X] T044 [P] [US3] Crear `client/lib/widgets/stock_chip.dart` (Suficiente verde, Bajo ámbar, Agotado rojo, siempre con texto) y ampliar `client/lib/utils/status_labels.dart` con las etiquetas y colores de stock según contracts/interfaz.md
- [X] T045 [US3] Modificar `client/lib/providers/navigation_provider.dart` (añadir `AppSection.inventory` «Inventario» solo para ADMIN en `sectionsFor`) y `client/lib/widgets/app_shell.dart` (íconos y construcción de la sección) y crear `client/lib/screens/inventory_screen.dart` (tabla con código, nombre, unidad, stock, mínimo y chip; búsqueda; filtros de estado de stock y activas; estados vacío, cargando, error y sin resultados)
- [X] T046 [US3] Crear `client/lib/screens/part_form_screen.dart` (código no editable al editar; stock inicial solo al crear; validación por campo y error de código duplicado) y `client/lib/screens/part_detail_screen.dart` (datos, chip, tabla de movimientos, «Registrar entrada», «Ajustar inventario» con diálogo de confirmación que muestra stock actual, cantidad contada y diferencia, y desactivar/reactivar con confirmación)
- [X] T047 [P] [US3] Crear `client/test/inventory_screens_test.dart`: listado, filtros, formulario, detalle con movimientos, confirmación de ajuste y que el mecánico y la recepción no ven la sección Inventario

**Punto de control**: escenarios 10 a 12, 18 y 20 de `quickstart.md` funcionan.

---

## Fase 6: Historia de usuario 4 - Agregar refacciones utilizadas a una orden (Prioridad: P1)

**Objetivo**: el mecánico asignado (y los administradores) agregan, corrigen y quitan refacciones de una orden hasta Terminado; cada operación genera su movimiento y el stock nunca queda negativo.

**Prueba independiente**: con una refacción con stock 10 y una orden asignada, agregar 3 unidades deja el stock en 7, la línea en la orden y un movimiento `OUT` ligado a la orden; pedir más de lo disponible se rechaza sin cambios.

**Dependencia**: requiere la Historia 3 (modelos y `inventoryService`).

### Pruebas de la historia 4

- [X] T048 [P] [US4] Crear `server/tests/contract/orderParts.contract.test.js`: formas y errores de `POST/PATCH/DELETE /orders/:id/parts`, `parts[]` y `serviceMileage` en `GET /orders/:id` para todos los roles que ven la orden
- [X] T049 [P] [US4] Crear `server/tests/integration/orderParts.flow.test.js`: agregar con stock suficiente (línea, descuento y movimiento `OUT` con `order_id`), exceso (`INSUFFICIENT_STOCK` sin cambios), cantidad cero, negativa, decimal y no numérica, sumar sobre la línea existente, corregir al alza (`OUT`) y a la baja (`IN` «Devolución»), quitar (`IN` y línea eliminada), orden Terminada permitida, orden Entregada → `ORDER_READ_ONLY`, refacción inactiva → `PART_INACTIVE`, mecánico ajeno → `404`, recepción → `403`, y la invariante `stock = SUM(quantity)`
- [X] T050 [P] [US4] Crear `server/tests/integration/orderParts.concurrency.test.js`: varias solicitudes simultáneas sobre una refacción con stock limitado (por ejemplo, 5 solicitudes de 2 unidades contra stock 7); solo prospera lo que cabe, el stock final no es negativo y coincide con la suma de movimientos; incluye una carrera entre agregar y ajustar (SC-005)

### Implementación de la historia 4

- [X] T051 [P] [US4] Crear `server/models/orderPartModel.js`: `listByOrder` (con código, nombre y unidad), `findLine`, `findByOrderAndPart`, `insert`, `updateQuantity` y `deleteLine`
- [X] T052 [US4] Crear `server/services/orderPartService.js`: `add`, `updateQuantity` y `remove` dentro de una transacción que primero bloquea la orden (`orderModel.lockById`) y después la refacción (orden fijo para evitar interbloqueos), rechaza `ENTREGADO` con `ORDER_READ_ONLY` y refacción inactiva con `PART_INACTIVE` al aumentar, reutiliza `loadOrderForActor` para la pertenencia y delega todo cambio de stock en `inventoryService.registerMovement` (OUT por aumento, IN «Devolución desde OS-…» por disminución o al quitar); devuelve la línea y la refacción actualizada
- [X] T053 [US4] Modificar `server/services/orderService.js` (`buildDetail`) para incluir `parts[]` y `server/controllers/orderPartController.js` con las rutas `POST /:id/parts`, `PATCH /:id/parts/:lineId` y `DELETE /:id/parts/:lineId` en `server/routes/orderRoutes.js` con `authorize(ROLES.ADMIN, ROLES.MECHANIC)` y `validate` de los esquemas de T014
- [X] T054 [P] [US4] Ampliar `client/lib/models/service_order.dart` y `client/lib/models/order_work.dart` con `parts[]`, y `client/lib/services/orders_service.dart` con agregar, corregir y quitar refacciones; crear `client/lib/widgets/part_selector.dart` (activas con búsqueda y existencia; las agotadas deshabilitadas con «Agotada»)
- [X] T055 [US4] Crear `client/lib/widgets/order_parts_section.dart` y mostrarla en `client/lib/screens/order_detail_screen.dart` (tabla de refacciones con cantidad y stock disponible; agregar, corregir y quitar solo para el mecánico asignado y ADMIN con la orden no Entregada; confirmación al quitar que informa que la cantidad regresa al inventario; `INSUFFICIENT_STOCK` conserva lo capturado y muestra «Solo hay N disponibles»; solo lectura en Entregada) y ajustar `client/lib/providers/order_detail_provider.dart`
- [X] T056 [P] [US4] Crear `client/test/order_parts_test.dart`: agregar, exceso de stock, corregir, quitar con confirmación, refacción agotada deshabilitada, vista de solo lectura y sección oculta para recepción en acciones de edición

**Punto de control**: escenarios 13 a 17 y 21 de `quickstart.md` funcionan; las refacciones aparecen también en el historial (US1).

---

## Fase 7: Historia de usuario 5 - Consultar mantenimientos próximos y vencidos (Prioridad: P2)

**Objetivo**: recepción y administración consultan la lista de mantenimientos con cliente, teléfono y estado calculado (Normal, Próximo, Vencido).

**Prueba independiente**: con mantenimientos de ejemplo en cada indicador, `GET /api/maintenance` los clasifica correctamente, los filtros funcionan y el mecánico recibe `403`.

**Dependencia**: requiere la Historia 2 (mantenimientos programados).

### Pruebas de la historia 5

- [X] T057 [P] [US5] Ampliar `server/tests/contract/maintenance.contract.test.js` (parte de lectura): forma de `GET /api/maintenance` con `indicator`, `client` y `meta`, y `403` para MECHANIC
- [X] T058 [P] [US5] Crear `server/tests/integration/maintenance.list.test.js`: clasificación Normal/Próximo/Vencido (por fecha, por kilometraje y por ambos), orden Vencidos → Próximos → Normales, filtro por `indicator`, búsqueda por cliente o placa, los Atendidos no aparecen por defecto, kilometraje actual que cambia después de programar, márgenes personalizados por entorno, y que el SQL de filtro coincide con `computeIndicator` sobre los mismos datos (research D-02)

### Implementación de la historia 5

- [X] T059 [US5] Ampliar `server/models/maintenanceModel.js` con `list({ status, indicator, search, page, pageSize, today, warnDays, warnKm })` con expresiones SQL equivalentes a `computeIndicator` para filtrar y ordenar por indicador, uniendo vehículo y cliente (teléfono); y `server/services/maintenanceService.js` con `list` que añade el `indicator` calculado con la función pura; añadir `GET /` a `server/routes/maintenanceRoutes.js` con `authorize(ADMIN, RECEPTIONIST)`
- [X] T060 [P] [US5] Crear `client/lib/providers/maintenance_provider.dart` y `client/lib/widgets/maintenance_chip.dart` (Normal verde, Próximo ámbar, Vencido rojo, Atendido neutro, siempre con texto); ampliar `client/lib/services/maintenance_service.dart` con `list`
- [X] T061 [US5] Modificar `client/lib/providers/navigation_provider.dart` (añadir `AppSection.maintenance` «Mantenimientos» para ADMIN y RECEPTIONIST), `client/lib/widgets/app_shell.dart` y crear `client/lib/screens/maintenance_list_screen.dart` (tabla con cliente, teléfono, vehículo, descripción, objetivo y chip; filtro de indicador y búsqueda; estados vacío «Sin mantenimientos pendientes», cargando, error y sin resultados; ADMIN puede editar y marcar como atendido con confirmación)
- [X] T062 [P] [US5] Crear `client/test/maintenance_list_test.dart`: lista con los tres indicadores, filtros, estados vacío y error, y que MECHANIC no ve la sección

**Punto de control**: escenarios 8 y 9 de `quickstart.md` funcionan.

---

## Fase 8: Historia de usuario 6 - Visualizar alertas de stock bajo (Prioridad: P2)

**Objetivo**: el administrador ve el conteo y la lista de refacciones con stock en o bajo el mínimo, distinguiendo las agotadas.

**Prueba independiente**: con refacciones suficientes, bajas y agotadas, `GET /api/parts/alerts` devuelve las correctas; una salida que lleva el stock al mínimo la agrega y una entrada que lo supera la quita; el administrador ve el banner y la insignia.

**Dependencia**: requiere las Historias 3 y 4.

### Pruebas de la historia 6

- [X] T063 [P] [US6] Crear `server/tests/integration/stockAlerts.test.js`: alerta con `stock <= min_stock`, agotada con `stock = 0`, `min_stock = 0` solo alerta en cero, las inactivas no alertan, una salida por uso la agrega, una entrada la quita, orden de agotadas primero, conteo y `outOfStock`, y `403` para MECHANIC y RECEPTIONIST
- [X] T064 [P] [US6] Ampliar `server/tests/contract/parts.contract.test.js` con la forma de `GET /api/parts/alerts` (`count`, `outOfStock`, `items[]`)

### Implementación de la historia 6

- [X] T065 [US6] Añadir `alerts()` en `server/models/partModel.js` y `server/services/partService.js`, y `GET /alerts` en `server/routes/partRoutes.js` con `authorize(ADMIN)` declarado **antes** de `/:id` para que no se interprete como identificador
- [X] T066 [P] [US6] Crear `client/lib/providers/stock_alerts_provider.dart` (consulta al iniciar la sesión de ADMIN, al abrir Inventario y tras cada movimiento; expone conteo y lista) y ampliar `client/lib/services/parts_service.dart` con `fetchAlerts`
- [X] T067 [US6] Modificar `client/lib/screens/inventory_screen.dart` (banner «N refacciones con stock bajo, M agotadas» con atajo «Ver solo alertas» y mensaje «El inventario está en orden»), `client/lib/widgets/app_shell.dart` (insignia con el conteo en el ítem Inventario) y `client/lib/screens/home_screen.dart` (aviso de stock bajo solo para ADMIN)
- [X] T068 [P] [US6] Crear `client/test/stock_alerts_test.dart`: banner con conteo, insignia, estado en orden, actualización tras un movimiento y que no se muestra a otros roles

**Punto de control**: escenario 19 de `quickstart.md` funciona.

---

## Fase 9: Datos de ejemplo, pulido y validación (transversal)

**Propósito**: seeds idempotentes, documentación y validación completa del sprint

- [X] T069 Crear `database/seeds/003_history_inventory.sql` (idempotente, requiere los seeds 001 y 002; fechas relativas a `NOW()` solo al insertar; claves naturales de research D-13): ~10 refacciones por `code` (suficientes, bajas y agotadas); órdenes históricas Terminadas y Entregadas de varios vehículos (clave natural: placa + problema reportado) con servicios, mano de obra, historial de estados, mecánico y `service_mileage`; líneas de `order_parts` por `(orden, refacción)`; movimientos `IN`, `OUT` y `ADJUSTMENT` por `(code, reason, type)`; mantenimientos Normal, Próximo, Vencido y Atendido por `(placa, descripción)` (a lo sumo uno `PENDIENTE` por vehículo); y al final recalcular `parts.stock` como la suma de los movimientos de las refacciones sembradas. Sin contraseñas ni secretos
- [X] T070 [P] Crear `server/tests/integration/seeds.sprint3.test.js`: tras ejecutar el seed hay refacciones en los tres estados de stock, movimientos de los tres tipos, historial de más de un vehículo, mantenimientos en los cuatro estados, la invariante `stock = SUM(quantity)` se cumple; y ejecutarlo tres veces seguidas no duplica refacciones, movimientos, líneas ni mantenimientos (SC-011)
- [X] T071 [P] Ampliar `server/tests/integration/performance.test.js` con 1 000 refacciones, 1 000 movimientos por refacción repartidos y 1 000 mantenimientos: listados y filtros de refacciones, mantenimientos e historial responden en menos de 2 s (SC-012)
- [X] T072 Aplicar el seed con `database/scripts/aplicar-seeds.ps1 -Base motorix`, repetirlo y verificar que no hay duplicados
- [X] T073 [P] Actualizar `database/README.md` (tablas nuevas, seed 003, cómo reiniciar) y `README.md` si menciona los módulos del sistema
- [X] T074 Revisar que la interfaz nueva cumpla `docs/design-system.md` (tokens, estados vacío/cargando/error, confirmaciones de contracts/interfaz.md, accesibilidad: el color nunca es la única señal) y ejecutar `flutter analyze lib` sin avisos
- [X] T075 Ejecutar `npm test` en `server/` y `flutter test` en `client/` completos; corregir regresiones de los sprints 1 y 2
- [X] T076 Recorrer los 22 escenarios de `specs/003-historial-inventario/quickstart.md` con las cuentas `recepcion`, `mecanico`, `mecanico2` y `admin` contra la API real y MySQL local, y completar la sección 6 «Resultado de la validación» con pruebas, comprobaciones y criterios CA-1 a CA-8
- [X] T077 Verificar que no hay secretos en el repositorio y que `git status` no incluye `.env`

---

## Dependencias y orden de ejecución

### Dependencias entre fases

- **Fase 1 (Preparación)**: sin dependencias.
- **Fase 2 (Fundamentos)**: depende de la Fase 1 y **bloquea** todas las historias.
- **Fases 3 a 8 (historias)**: dependen de la Fase 2.
- **Fase 9 (Pulido)**: depende de las historias que se quieran entregar.

### Dependencias entre historias

- **US1** (historial): independiente; muestra mantenimientos y refacciones cuando existan.
- **US2** (kilometraje y mantenimiento): independiente de US1 (se prueba con la API y el detalle de la orden).
- **US3** (catálogo y stock): independiente; crea `inventoryService`, `partModel` y las rutas `/parts`.
- **US4** (refacciones en la orden): depende de US3.
- **US5** (lista de mantenimientos): depende de US2.
- **US6** (alertas): depende de US3 y US4 para la demostración completa del flujo.

### Dentro de cada historia

Pruebas (escribirlas y verificar que fallan) → modelos → servicios → controladores y rutas → cliente (modelos, servicios, proveedores) → pantallas → pruebas del cliente.

### Oportunidades de paralelismo

- Fase 1: T002, T003 y T004 en paralelo.
- Fase 2: T007 a T010 (reglas puras y configuración), T011 a T014 (plantillas y validadores) y T015 y T016 (pruebas) en paralelo tras T006.
- Tras la Fase 2, US1, US2 y US3 pueden avanzar en paralelo por personas distintas (archivos distintos).
- Dentro de cada historia, las tareas [P] de pruebas del servidor y del cliente son independientes.

```text
Fundamentos:    T005 → T006 → { T007, T008, T009, T010, T011, T012, T013, T014 } → { T015, T016 }
US1:            T017, T018 (pruebas) → T019 → T020 → T021 → T022 → T023 → T024
US3 → US4:      T038, T039 → T040 → T041 → T042 → … → T051 → T052 → T053 → T055
```

---

## Estrategia de implementación

### MVP primero

1. Completar las Fases 1 y 2 (migración, reglas puras con sus pruebas, plantillas).
2. Completar US1 (historial) y US2 (kilometraje y mantenimiento): entregan el cierre del servicio y la memoria del vehículo.
3. **Detener y validar**: probar de forma independiente con los escenarios 2 a 7 de `quickstart.md`.
4. Seguir con US3 y US4 (catálogo y uso en órdenes): entregan el control de inventario y la regla de no tener stock negativo.
5. Terminar con US5 y US6 (lista de mantenimientos y alertas) y la Fase 9 (seeds y validación completa).

### Entrega incremental

Cada historia se cierra con sus pruebas en verde antes de pasar a la siguiente. El sprint se considera completo cuando se cumplen CA-1 a CA-8 de `docs/sprints/sprint-3-historial-inventario.md` y el flujo «finalizar servicio → historial → próximo mantenimiento → usar refacciones → actualizar inventario → alertas de stock» se demuestra con los tres roles.

## Notas

- Las tareas [P] tocan archivos distintos y no dependen de tareas incompletas.
- Cada historia debe poder completarse y probarse de forma independiente salvo las dependencias indicadas.
- Confirmar que las pruebas fallan antes de implementar y hacer un commit pequeño por tarea o grupo lógico (Conventional Commits con la descripción en español).
- No se editan scripts de sprints ya aplicados: todo cambio de esquema va en `003_…`.
- Ninguna contraseña en texto plano en código ni scripts; las del estándar del MVP viven solo en `docs/project-context.md`.
- Prohibido modificar el stock o insertar movimientos fuera de `inventoryService`.
