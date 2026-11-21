---

description: "Lista de tareas del Sprint 7: reportes, configuración, términos y seguridad de la información"
---

# Tareas: Reportes, configuración, términos y seguridad (Sprint 7)

**Entrada**: Documentos de diseño en `specs/007-reportes-configuracion-seguridad/`

**Requisitos previos**: plan.md, spec.md, research.md, data-model.md, contracts/ (api-rest.md e interfaz.md), quickstart.md

**Pruebas**: INCLUIDAS. La constitución (Principio VII) exige pruebas para la lógica de negocio (permisos, importes, términos, sesión, bitácora) y el aseguramiento de la calidad pide una prueba por cada criterio de aceptación. Las pruebas de cada historia se escriben primero y deben fallar antes de implementar.

**Organización**: Las tareas se agrupan por historia de usuario para poder implementar y probar cada una de forma independiente. El orden de las fases sigue la decisión D-04: **configuración, catálogo, ticket, términos y seguridad primero; reportes y exportación después**.

## Formato: `[ID] [P?] [Historia] Descripción`

- **[P]**: se puede ejecutar en paralelo (archivos distintos, sin dependencias pendientes)
- **[USn]**: historia de usuario a la que pertenece la tarea (US1 a US10 de spec.md)
- Todas las rutas son relativas a la raíz del repositorio (`D:\sdd\motorix`)

## Convenciones de rutas

- Backend: `server/` (capas directamente en la raíz de `server/`, sin carpeta `src/`)
- Frontend: `client/lib/` y `client/test/`
- Base de datos: `database/`
- El código backend usa ES Modules (`import`/`export`); los identificadores van en inglés y los comentarios, mensajes y nombres de pruebas en español
- Las pruebas de integración y contrato se ejecutan solo contra `motorix_test`; los errores nuevos usan `AppError` (`server/utils/AppError.js`) con los códigos de `contracts/api-rest.md`
- **Sin dependencias nuevas** en `server/package.json` ni en `client/pubspec.yaml`: el CSV se arma con código propio y se guarda con `dart:io`
- Los importes se calculan en centavos enteros y se presentan como cadenas con dos decimales
- Ninguna respuesta de la API ni de la bitácora incluye contraseñas, hashes, tokens ni datos de tarjeta; el precio de compra solo lo recibe el administrador
- Las pruebas del cliente usan la API simulada de `client/test/helpers/fake_api.dart`

## Orden de las historias (prioridad)

P1: US1 (datos del taller), US3 (catálogo de tipos de servicio), US8 (próximo servicio en el ticket), US9 (términos y condiciones) y US10 (seguridad). P2: US2 (márgenes de «Próximo»), US4 (ingresos), US5 (servicios y productividad), US6 (refacciones y rotación) y US7 (exportación).

> Correspondencia con la especificación: US1 a US10 = Historias 1 a 10. Las fases siguen el orden de entrega, no el numérico: US1, US2, US3, US8, US9, US10 (todo lo de configuración, ticket, términos y seguridad) y después US4, US5, US6 y US7 (reportes y exportación).

> **Puerta de la constitución**: la aprobación del Sprint 7 ya quedó registrada el 2026-11-21 (versión 1.1.2, «Decisiones resueltas durante el Sprint 7»), por lo que no hay una tarea de puerta en este sprint.

> **Cambios de pruebas declarados (SC-011)**: se actualizan las pruebas que usan contraseñas de menos de 10 caracteres, las que inician sesión con cuentas sembradas (deben aceptar los términos) y el `FakeApi` del cliente. Cada actualización se registra en el documento de aseguramiento.

---

## Fase 1: Preparación (infraestructura compartida)

**Propósito**: verificar la base y abrir el documento de aseguramiento

- [ ] T001 Verificar la línea base en la rama `007-reportes-configuracion-seguridad`: MySQL local en ejecución, migraciones 001 a 006 aplicadas en `motorix` y `motorix_test`, `npm test` (en `server/`) y `flutter test` (en `client/`) en verde; anotar el número de suites y de pruebas de cada uno (la última cifra documentada es 1 349 de backend en 97 suites y 373 de frontend) y abrir `docs/aseguramiento-calidad-sprint-7.md` a partir de `docs/aseguramiento-calidad/plantilla-aseguramiento-calidad.md` con esa línea base

---

## Fase 2: Fundamentos (requisitos bloqueantes)

**Propósito**: esquema, ayudantes de pruebas, bitácora y constantes de seguridad que usan varias historias

**⚠️ CRÍTICO**: ninguna historia puede empezar hasta terminar esta fase

- [ ] T002 Crear `database/migrations/007_sprint7_settings_terms_audit.sql` (InnoDB, `utf8mb4`, aditiva, sin editar migraciones anteriores ni tocar filas existentes; encabezado en español). Según data-model.md:
  - `settings`: `setting_key VARCHAR(60) NOT NULL` (llave primaria), `setting_value VARCHAR(255) NOT NULL`, `updated_by INT UNSIGNED NULL` (llave foránea a `users(id)` con `ON DELETE RESTRICT`), `updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`
  - `service_types`: `id INT UNSIGNED NOT NULL AUTO_INCREMENT` (llave primaria), `name VARCHAR(100) NOT NULL` con `UNIQUE KEY uq_service_types_name (name)`, `interval_days INT UNSIGNED NULL`, `interval_km INT UNSIGNED NULL`, `active TINYINT(1) NOT NULL DEFAULT 1`, `created_at` y `updated_at` con valores por omisión; `CONSTRAINT chk_service_types_interval CHECK (interval_days IS NOT NULL OR interval_km IS NOT NULL)`, `chk_service_types_days CHECK (interval_days IS NULL OR interval_days > 0)` y `chk_service_types_km CHECK (interval_km IS NULL OR interval_km > 0)`
  - `terms_versions`: `id INT UNSIGNED NOT NULL AUTO_INCREMENT`, `version VARCHAR(20) NOT NULL` con `UNIQUE KEY uq_terms_versions_version (version)`, `title VARCHAR(150) NOT NULL`, `body MEDIUMTEXT NOT NULL`, `published_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`; **insertar la versión `1.0`** con el título «Términos y condiciones y aviso de privacidad» y un texto en español que cubra el uso permitido del sistema, la confidencialidad de los datos de clientes y vehículos, la responsabilidad de las cuentas personales y el aviso de privacidad (plantilla que el taller debe revisar; sin asesoría legal)
  - `terms_acceptances`: `id INT UNSIGNED NOT NULL AUTO_INCREMENT`, `user_id INT UNSIGNED NOT NULL` y `terms_version_id INT UNSIGNED NOT NULL` (llaves foráneas con `ON DELETE RESTRICT`), `accepted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`; `UNIQUE KEY uq_terms_acceptances (user_id, terms_version_id)` y `KEY idx_terms_acceptances_version (terms_version_id, accepted_at)`
  - `audit_log`: `id INT UNSIGNED NOT NULL AUTO_INCREMENT`, `actor_user_id INT UNSIGNED NULL` (llave foránea a `users(id)` con `ON DELETE RESTRICT`), `action VARCHAR(40) NOT NULL`, `entity_type VARCHAR(30) NULL`, `entity_id INT UNSIGNED NULL`, `summary VARCHAR(255) NOT NULL`, `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`; `KEY idx_audit_created (created_at)`, `KEY idx_audit_actor (actor_user_id, created_at)` y `KEY idx_audit_action (action, created_at)`
  - `ALTER TABLE order_services ADD COLUMN service_type_id INT UNSIGNED NULL`, con `KEY idx_order_services_type (service_type_id)` y `CONSTRAINT fk_order_services_type FOREIGN KEY (service_type_id) REFERENCES service_types (id) ON DELETE RESTRICT ON UPDATE CASCADE`
  - `ALTER TABLE users ADD COLUMN last_activity_at DATETIME NULL`
- [ ] T003 Aplicar la migración 007 en `motorix` y `motorix_test` con `database/scripts/aplicar-migraciones.ps1` (repetirla debe terminar sin error), comprobar que el número de filas de `clients`, `vehicles`, `appointments`, `service_orders`, `order_services`, `maintenance`, `payments`, `tickets` y `users` es el mismo antes y después (FR-032) y actualizar `database/README.md` con la migración 007 y su reversa manual
- [ ] T004 Actualizar los ayudantes de pruebas en `server/tests/helpers/factories.js`: `resetDatabase()` borra `audit_log`, `terms_acceptances`, `settings` y `service_types` (en orden que respete las llaves foráneas, después de `order_services`) y **conserva** `terms_versions` con la versión `1.0`; `createUser` registra la aceptación de la versión vigente del usuario creado (para que las pruebas anteriores no reciban `TERMS_NOT_ACCEPTED`); agregar `createServiceType(overrides)` y `acceptTerms(userId)`
- [ ] T005 [P] Crear `server/config/security.js` con las constantes `INACTIVITY_MINUTES = 30`, `ACTIVITY_WRITE_SECONDS = 60` y `PASSWORD_MIN_LENGTH = 10`
- [ ] T006 [P] Crear `server/models/auditLogModel.js` (`insert({ actorUserId, action, entityType, entityId, summary }, connection)` y `list({ from, to, userId, action, page, pageSize })` de la más reciente a la más antigua, con el usuario unido; **sin** funciones de edición ni de borrado) y `server/services/auditService.js` (`ACTIONS` con las 12 acciones de data-model.md y `record({ actor, action, entityType, entityId, summary })`: se llama **después** de la acción, recorta el resumen a 255 caracteres, rechaza resúmenes con las cadenas reservadas `password`, `hash`, `token` y números de tarjeta, y **no propaga errores** (los avisa en el registro del servidor))
- [ ] T007 [P] Pruebas unitarias en `server/tests/unit/auditService.test.js`: registra cada acción válida; una acción desconocida se rechaza; un resumen con contraseña, hash o token no se guarda; una falla del modelo no propaga el error; el resumen se recorta a 255 caracteres

**Punto de control**: la migración está aplicada, los ayudantes de pruebas aceptan los términos y la bitácora está lista; las historias pueden empezar

---

## Fase 3: Historia de usuario 1 - Editar los datos del taller (Prioridad: P1) 🎯 MVP

**Objetivo**: el administrador edita nombre, dirección y teléfono del taller desde la aplicación; los tickets nuevos los usan y los emitidos no cambian.

**Prueba independiente**: el administrador cambia el nombre y el teléfono del taller, genera un ticket nuevo y ve los datos actualizados; un ticket anterior se ve igual que cuando se emitió.

### Pruebas de la historia 1 (escribir primero y comprobar que fallan)

- [ ] T008 [P] [US1] Prueba de integración `server/tests/integration/settings.flow.test.js`: `GET /api/settings` devuelve `shop`, `maintenance` y `sources`; sin valores guardados usa `.env` y, sin `.env`, el predeterminado «Motorix Taller Mecánico»; `PUT` guarda solo los campos enviados; nombre vacío o de más de 100 caracteres, dirección de más de 200 y teléfono de más de 20 o con letras se rechazan con el campo y el motivo; un ticket generado después usa los datos nuevos y un ticket emitido antes conserva los suyos; dos `PUT` simultáneos no dejan datos a medias; RECEPTIONIST y MECHANIC reciben 403; el cambio queda en la bitácora como `SETTINGS_CHANGED`
- [ ] T009 [P] [US1] Prueba de contrato `server/tests/contract/settings.contract.test.js`: forma exacta de `GET` y `PUT /api/settings` según `contracts/api-rest.md`, campos desconocidos rechazados con `VALIDATION_ERROR`, 401 sin token
- [ ] T010 [P] [US1] Pruebas del cliente en `client/test/settings_test.dart` (pestaña Taller): el administrador ve la sección «Configuración» y los otros roles no; los campos traen los valores y el chip de origen («Guardado», «Variable de entorno» o «Predeterminado»); guardar envía solo lo cambiado y muestra «Datos del taller guardados. Los tickets nuevos los usarán; los emitidos no cambian»; los errores del servidor se muestran en su campo; estados de carga y de error con «Reintentar»

### Implementación de la historia 1

- [ ] T011 [US1] Crear `server/models/settingsModel.js` (`getAll(connection)` y `upsertMany(entries, updatedBy, connection)` con `INSERT ... ON DUPLICATE KEY UPDATE`) y `server/services/settingsService.js`: `getShop()`, `getMaintenanceMargins()` y `getAll()` asíncronas que leen la base en cada llamada (guardado → variable `SHOP_*` o `MAINTENANCE_WARN_*` → predeterminado de 30 días y 1 000 km) y devuelven el origen de cada valor (`STORED`, `ENV` o `DEFAULT`); `update(fields, actor)` valida y guarda solo lo enviado dentro de una transacción y registra `SETTINGS_CHANGED` con los nombres de los campos y los valores no reservados
- [ ] T012 [US1] Crear `server/validators/settingsValidators.js` (zod, estricto): `shop.name` de 1 a 100 caracteres; `shop.address` hasta 200; `shop.phone` hasta 20 con dígitos, espacios, `+`, `-` y paréntesis; `maintenance.warnDays` entero de 1 a 365 y `maintenance.warnKm` entero de 1 a 100 000; al menos un campo; más `server/controllers/settingsController.js` y `server/routes/settingsRoutes.js` (`GET /` y `PUT /` con `authenticate` y `authorize(ROLES.ADMIN)`), montada en `server/routes/index.js` como `/settings`
- [ ] T013 [US1] Hacer que `server/services/ticketService.js` tome los datos del taller de `settingsService.getShop()` (en lugar de `getShopConfig()`), de modo que el ticket nuevo guarde en su `content` los datos vigentes; los tickets emitidos no se tocan
- [ ] T014 [P] [US1] Crear `client/lib/models/settings.dart` (`ShopSettings`, `MaintenanceSettings`, `SettingsSnapshot` con `sources`), `client/lib/services/settings_service.dart` (`fetch()` y `save(...)`) y `client/lib/providers/settings_provider.dart` (carga, guardado y errores por campo)
- [ ] T015 [US1] Crear `client/lib/screens/settings_screen.dart` con las pestañas **Taller**, **Mantenimiento** y **Tipos de servicio** (esta historia llena solo Taller: campos Nombre, Dirección y Teléfono con su límite, chip de origen, botón **Guardar cambios** deshabilitado sin cambios; las otras pestañas se llenan en las historias 2 y 3); agregar `AppSection.settings` («Configuración») solo para ADMIN en `client/lib/providers/navigation_provider.dart`, su ícono y su pantalla en `client/lib/widgets/app_shell.dart` y `client/lib/main.dart`, y registrar los proveedores nuevos en `client/lib/main.dart`

**Punto de control**: el administrador cambia los datos del taller y el ticket nuevo los muestra; las pruebas de la historia 1 pasan

---

## Fase 4: Historia de usuario 2 - Ajustar los márgenes de «Próximo» del mantenimiento (Prioridad: P2)

**Objetivo**: el administrador ajusta los márgenes en días y en kilómetros; la lista de Mantenimientos, el panel de control y los avisos usan el mismo margen.

**Prueba independiente**: el administrador cambia el margen de 30 a 15 días y un mantenimiento a 20 días deja de ser «Próximo» en los tres lugares.

### Pruebas de la historia 2 (escribir primero y comprobar que fallan)

- [ ] T016 [P] [US2] Prueba de integración `server/tests/integration/settings.margins.test.js`: un margen nuevo en días y en kilómetros cambia la clasificación en `GET /api/maintenance`, en `GET /api/dashboard` y en `GET /api/notifications` y sus números coinciden; valores de 0, negativos, no numéricos o fuera de 1 a 365 (días) y de 1 a 100 000 (km) se rechazan; sin valor guardado se usan los de `.env` y, sin ellos, 30 días y 1 000 km; la lista de clientes por avisar usa el mismo margen
- [ ] T017 [P] [US2] Pruebas del cliente en `client/test/settings_test.dart` (ampliar, pestaña Mantenimiento): muestra los dos márgenes con su límite y el texto «Un mantenimiento es Próximo cuando falta este margen o menos»; guardar envía los valores; un valor fuera de rango muestra «El valor debe estar entre 1 y 365» (y el de kilómetros, entre 1 y 100 000)

### Implementación de la historia 2

- [ ] T018 [US2] Quitar la lectura de `.env` de `server/services/maintenancePresenter.js` (`presentMaintenance(row, currentMileage, today, margins)` recibe los márgenes como parámetro) y obtener los márgenes **una vez por petición** con `settingsService.getMaintenanceMargins()` en `server/services/maintenanceService.js`, `server/services/orderService.js`, `server/services/vehicleHistoryService.js`, `server/services/clientNoticeService.js` y `server/services/dashboardService.js` / `notificationService.js` (los que usen el indicador), pasándolos al presentador; actualizar las pruebas unitarias del presentador que llamaban sin márgenes
- [ ] T019 [US2] Llenar la pestaña **Mantenimiento** de `client/lib/screens/settings_screen.dart` con «Margen de Próximo (días)» y «Margen de Próximo (km)», validación al escribir y mensajes de rango

**Punto de control**: los tres lugares usan el mismo margen guardado y las pruebas de la historia 2 pasan

---

## Fase 5: Historia de usuario 3 - Catálogo de tipos de servicio con intervalos (Prioridad: P1)

**Objetivo**: el administrador mantiene un catálogo de tipos de servicio con intervalo en días y en kilómetros, los tipos se pueden elegir en los servicios de una orden y el próximo mantenimiento se propone con su intervalo.

**Prueba independiente**: el administrador crea «Cambio de aceite» (180 días y 5 000 km), termina una orden con ese servicio y el sistema propone el próximo mantenimiento con esa fecha y ese kilometraje, que se pueden corregir.

### Pruebas de la historia 3 (escribir primero y comprobar que fallan)

- [ ] T020 [P] [US3] Pruebas unitarias del módulo puro en `server/tests/unit/serviceIntervals.test.js`: con un solo tipo propone hoy más los días y el kilometraje del servicio más los kilómetros; con varios tipos toma el intervalo más corto de cada eje; un tipo con solo días no propone kilometraje y viceversa; sin tipos con intervalo devuelve `null`; usa el kilometraje actual del vehículo si no hay kilometraje del servicio
- [ ] T021 [P] [US3] Prueba de integración `server/tests/integration/serviceTypes.flow.test.js`: crear, editar y desactivar un tipo; nombre único sin distinguir mayúsculas (`SERVICE_TYPE_DUPLICATE`); un tipo sin intervalos o con intervalos de 0, negativos o no enteros se rechaza (`SERVICE_TYPE_INTERVAL_REQUIRED` y `VALIDATION_ERROR`); un tipo en uso se desactiva sin tocar las órdenes ni borrarse y `DELETE` responde 404; `inUse` cuenta las líneas que lo usan; `GET /service-types/options` devuelve solo los activos para ADMIN y MECHANIC y 403 para RECEPTIONIST; una línea de servicio acepta `serviceTypeId`, un tipo inexistente responde 404 y uno desactivado `SERVICE_TYPE_INACTIVE`; las líneas existentes llegan con `serviceType: null`; los cambios quedan en la bitácora como `SERVICE_TYPE_CHANGED`
- [ ] T022 [P] [US3] Prueba de contrato `server/tests/contract/serviceTypes.contract.test.js`: forma exacta de las respuestas de `GET /api/service-types`, `GET /api/service-types/options`, `POST` y `PATCH` según `contracts/api-rest.md`; RECEPTIONIST y MECHANIC reciben 403 en la gestión
- [ ] T023 [P] [US3] Prueba de integración `server/tests/integration/serviceTypes.suggestion.test.js`: `GET /api/orders/:id/maintenance/suggestion` devuelve fecha y kilometraje según el tipo de las líneas, responde 204 sin tipos con intervalo y 404 para una orden de otro mecánico; programar el próximo mantenimiento con la propuesta corregida conserva las validaciones de `POST /orders/:id/maintenance`
- [ ] T024 [P] [US3] Pruebas del cliente en `client/test/service_types_test.dart`: la pestaña **Tipos de servicio** lista nombre, días, km y estado con el chip «Activo» o «Inactivo»; **Nuevo tipo de servicio** valida el nombre y que haya al menos un intervalo; desactivar pide confirmación («Las órdenes anteriores conservan el tipo»); el formulario de servicio de la orden ofrece el selector opcional de tipo; **Usar el intervalo del servicio** rellena fecha y kilometraje y, sin propuesta, explica «Ningún servicio de la orden tiene un intervalo»

### Implementación de la historia 3

- [ ] T025 [US3] Crear `server/services/serviceIntervals.js` (módulo puro `suggestNextMaintenance({ serviceTypes, today, serviceMileage, currentMileage })` y la regla del intervalo más corto de cada eje)
- [ ] T026 [US3] Crear `server/models/serviceTypeModel.js` (`list`, `listActive`, `findById`, `findByName`, `insert`, `update` y el conteo de líneas que usan cada tipo; **sin** borrado) y `server/services/serviceTypeService.js` (alta y edición con las validaciones de unicidad sin distinguir mayúsculas y de al menos un intervalo; desactivar y reactivar; registra `SERVICE_TYPE_CHANGED`)
- [ ] T027 [US3] Crear `server/validators/serviceTypeValidators.js` (zod: `name` de 1 a 100 caracteres; `intervalDays` entero de 1 a 3 650 o `null`; `intervalKm` entero de 1 a 1 000 000 o `null`; al menos un intervalo; `active` booleano), `server/controllers/serviceTypeController.js` y `server/routes/serviceTypeRoutes.js` (`GET /`, `GET /options`, `POST /` y `PATCH /:id`; la gestión con `authorize(ROLES.ADMIN)` y `options` con ADMIN y MECHANIC; sin `DELETE`), montada como `/service-types` en `server/routes/index.js`
- [ ] T028 [US3] Aceptar el campo opcional `serviceTypeId` en las líneas de servicio: ampliar `server/validators/orderValidators.js` (o el validador de líneas), `server/models/orderWorkModel.js` (columna `service_type_id` y unión con el nombre del tipo) y `server/services/orderWorkService.js` (404 si el tipo no existe y `SERVICE_TYPE_INACTIVE` si está desactivado); las respuestas de las líneas de servicio agregan `serviceType: { id, name } | null`
- [ ] T029 [US3] Agregar `GET /api/orders/:id/maintenance/suggestion` (ADMIN y MECHANIC de la orden; 204 sin tipos con intervalo) en `server/routes/orderRoutes.js`, `server/controllers/maintenanceController.js` y `server/services/maintenanceService.js`, usando `serviceIntervals.js` con las líneas de la orden y el kilometraje del vehículo
- [ ] T030 [P] [US3] Crear `client/lib/models/service_type.dart`, `client/lib/services/service_types_service.dart` y `client/lib/providers/service_types_provider.dart` (lista de gestión, opciones activas, alta, edición, desactivar y la propuesta del mantenimiento)
- [ ] T031 [US3] Llenar la pestaña **Tipos de servicio** de `client/lib/screens/settings_screen.dart` (tabla con acciones, **Nuevo tipo de servicio**, formulario con validación y confirmación al desactivar, estados cargando, vacío «Todavía no hay tipos de servicio» y error)
- [ ] T032 [US3] Agregar el selector opcional **Tipo de servicio** y el chip del tipo a `client/lib/widgets/order_work_section.dart` y el botón **Usar el intervalo del servicio** a `client/lib/widgets/maintenance_dialog.dart` (rellena fecha y kilometraje, que la persona corrige antes de guardar)

**Punto de control**: el catálogo funciona y el próximo mantenimiento se propone con el intervalo del servicio; las pruebas de la historia 3 pasan

---

## Fase 6: Historia de usuario 8 - Próximo servicio en el ticket (Prioridad: P1)

**Objetivo**: el ticket nuevo muestra la línea «Próximo servicio» cuando la orden tiene su próximo mantenimiento registrado; los tickets anteriores no cambian.

**Prueba independiente**: con una orden cuyo próximo mantenimiento está registrado, el ticket nuevo muestra «Próximo servicio» con la fecha y el kilometraje; sin próximo mantenimiento no la muestra.

### Pruebas de la historia 8 (escribir primero y comprobar que fallan)

- [ ] T033 [P] [US8] Pruebas unitarias en `server/tests/unit/ticketContent.test.js` (ampliar): con `nextService` el contenido lleva `formatVersion: 3` y el bloque `{ dueDate, dueMileage, description }`; sin él conserva `formatVersion: 2` y no trae el campo; solo fecha o solo kilometraje también se aceptan
- [ ] T034 [P] [US8] Prueba de integración `server/tests/integration/tickets.nextService.test.js`: el ticket de una orden con mantenimiento pendiente propio incluye `nextService`; sin mantenimiento no lo incluye; un ticket de versión 1 o 2 emitido antes se consulta idéntico; corregir el próximo mantenimiento después de emitir el ticket no cambia el ticket emitido; el ticket de la orden con tipo de servicio e intervalo coincide con lo programado
- [ ] T035 [P] [US8] Pruebas del cliente en `client/test/ticket_next_service_test.dart` y `client/test/ticket_printer_test.dart` (ampliar): la vista del ticket versión 3 muestra el bloque «Próximo servicio» con fecha y kilometraje; los tickets versión 1 y 2 se ven e imprimen igual; sin el bloque no hay línea

### Implementación de la historia 8

- [ ] T036 [US8] Ampliar `server/services/ticketContent.js` (`buildTicketContent` recibe `nextService` y, solo si existe, agrega el campo y `formatVersion: 3`), `server/models/maintenanceModel.js` (`findPendingByOrder(orderId, connection)`) y `server/services/ticketService.js` (al generar el ticket busca el mantenimiento pendiente de esa orden y lo pasa al contenido)
- [ ] T037 [US8] Ampliar `client/lib/models/ticket.dart` (`nextService` y `isV3`), `client/lib/widgets/ticket_view.dart` y `client/lib/utils/ticket_printer.dart` para mostrar y imprimir el bloque «Próximo servicio» cuando existe

**Punto de control**: el ticket nuevo muestra el próximo servicio y los anteriores no cambian

---

## Fase 7: Historia de usuario 9 - Aceptar los términos y condiciones al ingresar (Prioridad: P1)

**Objetivo**: todo usuario acepta la versión vigente de los términos y del aviso de privacidad antes de usar el sistema; el servidor lo exige en cada ruta autenticada.

**Prueba independiente**: un usuario que inicia sesión por primera vez ve los términos, los acepta y entra; en el siguiente ingreso no se los vuelven a pedir; con una versión nueva se los piden de nuevo.

### Pruebas de la historia 9 (escribir primero y comprobar que fallan)

- [ ] T038 [P] [US9] Prueba de integración `server/tests/integration/terms.flow.test.js`: `GET /api/terms/current` devuelve la versión `1.0` con `accepted: false` y luego `true`; `POST /api/terms/accept` guarda usuario, versión y fecha, es idempotente y cinco solicitudes simultáneas dejan una sola fila; aceptar una versión que ya no es la vigente responde `409 TERMS_VERSION_OUTDATED`; un usuario sin aceptación recibe `403 TERMS_NOT_ACCEPTED` (con la versión en `details`) en una ruta de cada router (clientes, vehículos, citas, órdenes, mantenimiento, refacciones, pagos, tickets, panel, notificaciones, usuarios y configuración) salvo `GET /terms/current`, `POST /terms/accept` y `GET /auth/me`; al publicar una versión `2.0` todos quedan sin aceptar y deben aceptarla; los usuarios existentes antes del sprint deben aceptar en su siguiente ingreso; `GET /api/terms/acceptances` es solo ADMIN, pagina y cuenta los pendientes; la aceptación queda en la bitácora como `TERMS_ACCEPTED`
- [ ] T039 [P] [US9] Prueba de contrato `server/tests/contract/terms.contract.test.js`: forma exacta de `GET /terms/current`, `POST /terms/accept` y `GET /terms/acceptances` según `contracts/api-rest.md`; 401 sin token; RECEPTIONIST y MECHANIC reciben 403 en `acceptances`
- [ ] T040 [P] [US9] Pruebas del cliente en `client/test/terms_test.dart`: tras iniciar sesión con términos sin aceptar aparece la pantalla de aceptación (título, versión y texto con desplazamiento) y no el menú; **Aceptar y continuar** está deshabilitado hasta marcar la casilla y, al enviarlo, entra al inicio; **Rechazar y salir** cierra la sesión con «Para usar Motorix debes aceptar los términos y condiciones»; con términos aceptados no aparece; un `403 TERMS_NOT_ACCEPTED` a mitad de sesión vuelve a mostrar la pantalla; error al cargar con «Reintentar»; la sección **Términos** del administrador muestra la versión vigente, la tabla de aceptaciones y «N pendientes de aceptar» y no tiene botón de edición

### Implementación de la historia 9

- [ ] T041 [US9] Crear `server/models/termsModel.js` (`findCurrent`, `findById`, `hasAccepted(userId, versionId)`, `insertAcceptanceIgnore` con `INSERT IGNORE` sobre `uq_terms_acceptances` y `listAcceptances` paginada con el conteo de usuarios activos pendientes) y `server/services/termsService.js` (`getCurrent(user)` con `accepted`, `accept(versionId, user)` idempotente que registra `TERMS_ACCEPTED`, y `listAcceptances`)
- [ ] T042 [US9] Crear `server/validators/termsValidators.js` (zod: `versionId` entero positivo; filtros de `acceptances`), `server/controllers/termsController.js` y `server/routes/termsRoutes.js` (`GET /current` y `POST /accept` para cualquier usuario autenticado; `GET /acceptances` con `authorize(ROLES.ADMIN)`), montada como `/terms` en `server/routes/index.js`
- [ ] T043 [US9] Validar la aceptación **dentro de** `server/middlewares/authenticate.js`: después de cargar al usuario, si no aceptó la versión vigente responde `403 TERMS_NOT_ACCEPTED` con `details: { version, versionId }`, salvo `GET /api/terms/current`, `POST /api/terms/accept` y `GET /api/auth/me` (lista fija de excepciones en una constante)
- [ ] T044 [US9] Actualizar las pruebas existentes que inician sesión con cuentas sembradas para que **acepten los términos antes de operar** (`server/tests/integration/seeds.sprint2.test.js`, `seeds.sprint3.test.js`, `seeds.sprint4.test.js`, `seeds.sprint5.test.js`, `seeds.test.js`, `seed.notices.test.js` y las de `auth.flow.test.js` que usen el token para otras rutas) con un ayudante `loginAndAccept` en `server/tests/helpers/factories.js`; anotar cada actualización para el aseguramiento (SC-011)
- [ ] T045 [P] [US9] Crear `client/lib/models/terms.dart`, `client/lib/services/terms_service.dart` y `client/lib/providers/terms_provider.dart`; integrar en `client/lib/providers/session_provider.dart` (tras iniciar sesión consulta `/terms/current` y marca los términos pendientes; un `403 TERMS_NOT_ACCEPTED` los marca de nuevo; rechazar cierra la sesión con el aviso) y en `client/lib/services/api_client.dart` (avisar del código `TERMS_NOT_ACCEPTED`)
- [ ] T046 [US9] Crear `client/lib/screens/terms_accept_screen.dart` (título, versión, texto con desplazamiento, casilla, **Rechazar y salir** y **Aceptar y continuar**, estados cargando y error) y mostrarla desde `client/lib/main.dart` (`_AuthGate`) antes del `AppShell` cuando los términos estén pendientes
- [ ] T047 [US9] Responder `GET /terms/current` con `accepted: true` en el `FakeApi` por omisión de `client/test/helpers/fake_api.dart` para que las pruebas del cliente anteriores no queden bloqueadas en la pantalla de aceptación; anotar el cambio para el aseguramiento
- [ ] T048 [US9] Crear `client/lib/screens/terms_admin_screen.dart` (versión vigente con su texto y tabla de aceptaciones con paginación y «N pendientes de aceptar») y agregar `AppSection.terms` («Términos») solo para ADMIN en `client/lib/providers/navigation_provider.dart`, `client/lib/widgets/app_shell.dart` y `client/lib/main.dart`

**Punto de control**: nadie opera sin aceptar los términos, validado en el servidor; las pruebas de la historia 9 y de los sprints anteriores pasan

---

## Fase 8: Historia de usuario 10 - Proteger la información del sistema (Prioridad: P1)

**Objetivo**: bitácora de acciones sensibles, política de contraseñas de 10 caracteres, cierre de sesión por inactividad, y respuestas sin datos reservados y sin inyección.

**Prueba independiente**: el administrador cambia el rol de un usuario y un precio y ve ambas acciones en la bitácora; una contraseña débil se rechaza; tras 30 minutos sin actividad la sesión se cierra.

### Pruebas de la historia 10 (escribir primero y comprobar que fallan)

- [ ] T049 [P] [US10] Pruebas de la política de contraseñas: `server/tests/unit/passwordPolicy.test.js` (de 10 caracteres con mayúscula, minúscula y número es válida; 9 caracteres, sin mayúscula, sin minúscula o sin número se rechaza con el mensaje de lo que falta) y ampliar `server/tests/integration/passwords.test.js` (alta de usuario, edición con contraseña y cambio propio rechazan una contraseña de 9 caracteres con `PASSWORD_POLICY`; las contraseñas ya guardadas siguen valiendo para iniciar sesión)
- [ ] T050 [P] [US10] Prueba de integración `server/tests/integration/audit.flow.test.js`: quedan registradas, con quién, cuándo y sobre qué, `LOGIN_FAILED` (con el usuario de la cuenta si existe y sin actor si no, **sin guardar el texto tecleado**), `ACCOUNT_LOCKED`, `PASSWORD_CHANGED`, `USER_CREATED`, `USER_DEACTIVATED`, `USER_ACTIVATED`, `USER_ROLE_CHANGED`, `SETTINGS_CHANGED`, `SERVICE_TYPE_CHANGED`, `PART_PRICE_CHANGED` (solo si cambia el precio de compra o de venta), `PAYMENT_CANCELLED` y `TERMS_ACCEPTED`; `GET /api/audit-log` filtra por fecha, usuario y acción, pagina y ordena de la más reciente a la más antigua; `POST`, `PUT`, `PATCH` y `DELETE` sobre `/api/audit-log` responden 404; ninguna fila contiene contraseñas, hashes, tokens ni números de tarjeta (revisión de todas las filas generadas); RECEPTIONIST y MECHANIC reciben 403; una falla de la bitácora no cancela la operación
- [ ] T051 [P] [US10] Prueba de contrato `server/tests/contract/audit.contract.test.js`: forma exacta de `GET /api/audit-log` según `contracts/api-rest.md` (con `actor` nulo cuando no hay usuario), filtros inválidos responden `VALIDATION_ERROR`, 401 sin token
- [ ] T052 [P] [US10] Prueba de integración `server/tests/integration/session.inactivity.test.js`: una petición tras más de 30 minutos sin actividad (ajustando `last_activity_at` en la base) responde `401 SESSION_INACTIVE`; con actividad reciente la renueva como máximo una vez por minuto; el inicio de sesión la fija; `NULL` se trata como activa; una cuenta inactiva por tiempo puede volver a iniciar sesión
- [ ] T053 [P] [US10] Prueba transversal `server/tests/integration/dataExposure.test.js`: con los tres roles recorre los endpoints de usuarios, refacciones, órdenes, pagos, tickets, configuración, reportes (los que existan en ese momento), bitácora y términos y comprueba que ningún JSON contiene las claves `password`, `passwordHash`, `password_hash`, `hash` ni `token` (salvo el del inicio de sesión) y que el precio de compra solo aparece para el administrador
- [ ] T054 [P] [US10] Prueba transversal `server/tests/integration/injection.test.js`: envía cargas de inyección (`' OR '1'='1`, `%`, `_`, `\`, `--`, `; DROP TABLE clients;--`, `" OR ""="`) a los campos de búsqueda de clientes, vehículos, citas, órdenes, refacciones, usuarios, mantenimientos, pagos y tickets y comprueba que no hay errores 500, que no se devuelven más filas que las coincidencias literales y que las tablas siguen intactas
- [ ] T055 [P] [US10] Pruebas del cliente en `client/test/audit_log_test.dart`, `client/test/inactivity_test.dart` y `client/test/users_screens_test.dart` (ampliar): la sección **Bitácora** solo existe para el administrador y lista fecha, usuario, acción, entidad y resumen con paginación, filtros y estados; el aviso aparece a los 28 minutos con cuenta regresiva y **Seguir conectado** reinicia el temporizador; a los 30 minutos se cierra la sesión con «Tu sesión se cerró por inactividad. Inicia sesión de nuevo.» (con tiempo controlado); un `SESSION_INACTIVE` del servidor cierra la sesión igual; el formulario de usuarios y el cambio de contraseña muestran la ayuda de 10 caracteres y validan al escribir

### Implementación de la historia 10

- [ ] T056 [US10] Cambiar el mínimo de contraseña a 10 en `server/utils/passwordPolicy.js` (usando `PASSWORD_MIN_LENGTH` de `server/config/security.js`) y en `client/lib/utils/password_policy.dart` (mensaje y `kPasswordPolicyHint` «Mínimo 10 caracteres, con una mayúscula, una minúscula y un número»); actualizar las pruebas existentes de usuarios y autenticación (servidor y cliente) que usaban contraseñas de 8 o 9 caracteres; anotar cada actualización para el aseguramiento (SC-011)
- [ ] T057 [US10] Registrar las acciones sensibles con `auditService.record` (después de cada acción): en `server/services/authService.js` (`LOGIN_FAILED` con el usuario si existe y sin el texto tecleado, `ACCOUNT_LOCKED` y `PASSWORD_CHANGED`), `server/services/userService.js` y `server/controllers/userController.js` (pasar el actor a `create` y `update`: `USER_CREATED`, `USER_DEACTIVATED`, `USER_ACTIVATED` y `USER_ROLE_CHANGED` con el rol anterior y el nuevo), `server/services/partService.js` y `server/controllers/partController.js` (pasar el actor a `update`: `PART_PRICE_CHANGED` con el nombre y los precios anterior y nuevo solo si cambian) y `server/services/paymentService.js` y `server/controllers/paymentController.js` (pasar el actor a `cancel`: `PAYMENT_CANCELLED` con el folio de la orden)
- [ ] T058 [US10] Crear `server/validators/auditValidators.js` (zod: `from` y `to` fechas `AAAA-MM-DD`, `userId` entero positivo, `action` una de las acciones de `auditService.ACTIONS`, `page` y `pageSize` hasta 100), `server/controllers/auditLogController.js` y `server/routes/auditLogRoutes.js` (solo `GET /` con `authorize(ROLES.ADMIN)`), montada como `/audit-log` en `server/routes/index.js`
- [ ] T059 [US10] Validar la inactividad en `server/middlewares/authenticate.js` y `server/models/userModel.js`: si `last_activity_at` es anterior a `INACTIVITY_MINUTES` responde `401 SESSION_INACTIVE` (mensaje «Tu sesión se cerró por inactividad. Inicia sesión de nuevo.») y, si no, la actualiza como máximo una vez por `ACTIVITY_WRITE_SECONDS` (`UPDATE users SET last_activity_at = NOW() WHERE id = ? AND (last_activity_at IS NULL OR last_activity_at < NOW() - INTERVAL 60 SECOND)`); `authService.login` la fija al iniciar sesión
- [ ] T060 [P] [US10] Crear `client/lib/models/audit_entry.dart`, `client/lib/services/audit_service.dart`, `client/lib/providers/audit_provider.dart` y `client/lib/screens/audit_log_screen.dart` (tabla con paginación, filtros por fecha, usuario y acción, **Limpiar filtros**, chips de acción en español y estados cargando, vacío «No hay registros con esos filtros» y error) y agregar `AppSection.auditLog` («Bitácora») solo para ADMIN en `client/lib/providers/navigation_provider.dart`, `client/lib/widgets/app_shell.dart` y `client/lib/main.dart`
- [ ] T061 [US10] Crear `client/lib/widgets/inactivity_guard.dart` (observa punteros, clics, desplazamiento y teclas; avisa a los 28 minutos con un diálogo y cuenta regresiva y el botón **Seguir conectado**; cierra la sesión a los 30; consulta `GET /api/auth/me` como máximo cada 5 minutos mientras hay actividad) y rodear el `AppShell` con él en `client/lib/main.dart`; el aviso de cierre se muestra en el acceso mediante `SessionProvider.notice`
- [ ] T062 [US10] Corregir lo que revelen `dataExposure` e `injection` (si algún endpoint devuelve un campo reservado o falla con una carga de inyección, arreglarlo en su modelo, servicio o validador y agregar la prueba que lo cubre); si no revelan nada, dejar constancia en el documento de aseguramiento

**Punto de control**: las acciones sensibles quedan en la bitácora, las contraseñas exigen 10 caracteres, la sesión se cierra por inactividad y no hay datos reservados ni inyección; las pruebas de la historia 10 pasan

---

## Fase 9: Historia de usuario 4 - Consultar los ingresos por periodo (Prioridad: P2)

**Objetivo**: el administrador consulta los ingresos de un periodo con el total, el desglose por método y por día y el número de pagos.

**Prueba independiente**: el administrador elige un mes y ve el total de ingresos pagados; el total coincide con la suma de los pagos pagados de ese mes.

### Pruebas de la historia 4 (escribir primero y comprobar que fallan)

- [ ] T063 [P] [US4] Pruebas unitarias del módulo puro en `server/tests/unit/reportRules.test.js`: valida `from` y `to` (`AAAA-MM-DD` reales), `to >= from` y máximo 366 días; calcula el inicio del día de `from` y el inicio del día siguiente a `to` con la fecha local; convierte importes a centavos enteros y de vuelta a cadenas con dos decimales sin errores de redondeo
- [ ] T064 [P] [US4] Prueba de integración `server/tests/integration/reports.income.test.js`: solo cuentan los pagos `PAGADO` con `paid_at` en el rango (los `PENDIENTE`, `RECHAZADO` y `CANCELADO` no); `total` es igual a la suma de `byMethod` y a la de `byDay`; periodo sin pagos devuelve ceros y listas vacías; el límite del rango (dos días consecutivos, inicio y fin incluidos) es exacto; un rango inválido, con `to` anterior a `from` o de más de 366 días responde `400 VALIDATION_ERROR`; RECEPTIONIST y MECHANIC reciben 403
- [ ] T065 [P] [US4] Prueba de contrato `server/tests/contract/reports.contract.test.js`: forma exacta de `GET /api/reports/income` según `contracts/api-rest.md` (importes como cadenas con dos decimales, `byMethod[]` y `byDay[]`), 401 sin token
- [ ] T066 [P] [US4] Pruebas del cliente en `client/test/reports_test.dart`: la sección **Reportes** solo existe para el administrador; el selector de periodo ofrece Hoy, Esta semana, Este mes y Rango, muestra el periodo y rechaza más de un año con «El periodo no puede pasar de un año»; la pestaña **Ingresos** muestra el total, el número de pagos, las barras por día y la tabla por método; estados cargando, vacío «No hay datos en este periodo» y error con «Reintentar»

### Implementación de la historia 4

- [ ] T067 [US4] Crear `server/services/reportRules.js` (módulo puro: validación del rango, extremos de los días con la fecha local del servidor, presets y conversión a centavos)
- [ ] T068 [US4] Crear `server/models/reportModel.js` con `income(from, to)` (pagos `PAGADO` con `paid_at` en el rango, agrupados por método y por día con `SUM(ROUND(amount * 100))`) y `server/services/reportService.js` con `income(range)` (arma el total, `paymentsCount`, `byMethod[]` y `byDay[]` y comprueba que las partes suman el total)
- [ ] T069 [US4] Crear `server/validators/reportValidators.js` (zod: `from` y `to` obligatorios y `format` opcional `csv`), `server/controllers/reportController.js` y `server/routes/reportRoutes.js` (`GET /income` con `authorize(ROLES.ADMIN)`), montada como `/reports` en `server/routes/index.js`
- [ ] T070 [P] [US4] Crear `client/lib/models/report.dart`, `client/lib/services/reports_service.dart` y `client/lib/providers/reports_provider.dart` (periodo elegido, carga por pestaña y errores) y `client/lib/widgets/period_selector.dart` (Hoy, Esta semana, Este mes y Rango con dos selectores de fecha y la validación de un año)
- [ ] T071 [US4] Crear `client/lib/screens/reports_screen.dart` con las pestañas **Ingresos**, **Servicios y productividad** y **Refacciones y rotación** (esta historia llena Ingresos con tarjetas, barras con `fl_chart` y tabla por método; las otras se llenan en las historias 5 y 6) y agregar `AppSection.reports` («Reportes») solo para ADMIN en `client/lib/providers/navigation_provider.dart`, `client/lib/widgets/app_shell.dart` y `client/lib/main.dart`

**Punto de control**: el administrador consulta los ingresos de un periodo y cuadran con los pagos; las pruebas de la historia 4 pasan

---

## Fase 10: Historia de usuario 5 - Servicios frecuentes y productividad por mecánico (Prioridad: P2)

**Objetivo**: el administrador ve los servicios más frecuentes y, por mecánico, las órdenes terminadas y el importe de mano de obra.

**Prueba independiente**: con órdenes terminadas de dos mecánicos en un mes, ve los servicios por frecuencia y los dos mecánicos con sus órdenes y su mano de obra.

### Pruebas de la historia 5 (escribir primero y comprobar que fallan)

- [ ] T072 [P] [US5] Prueba de integración `server/tests/integration/reports.operation.test.js`: `GET /api/reports/services` cuenta cada servicio de las órdenes terminadas en el rango (por tipo si lo tiene y por descripción si no), de mayor a menor frecuencia, con el importe; `GET /api/reports/productivity` da por mecánico las órdenes terminadas y el importe de mano de obra del periodo; una orden sin mecánico no se atribuye a nadie; una orden terminada fuera del rango no cuenta (la fecha es la del último cambio a `TERMINADO`); periodo sin órdenes devuelve listas vacías; RECEPTIONIST y MECHANIC reciben 403
- [ ] T073 [P] [US5] Pruebas del cliente en `client/test/reports_test.dart` (ampliar): la pestaña **Servicios y productividad** muestra la tabla de servicios por frecuencia y la de mecánicos con órdenes terminadas e importe de mano de obra, y el estado vacío

### Implementación de la historia 5

- [ ] T074 [US5] Agregar `services(from, to)` y `productivity(from, to)` a `server/models/reportModel.js` (órdenes cuya fecha de «Terminada» es el último cambio a `TERMINADO` del historial, o `updated_at` sin historial; agrupa por tipo de servicio o por descripción; mano de obra con `SUM(ROUND(amount * 100))`), sus funciones en `server/services/reportService.js` y las rutas `GET /services` y `GET /productivity` en `server/routes/reportRoutes.js` y `server/controllers/reportController.js`
- [ ] T075 [US5] Llenar la pestaña **Servicios y productividad** de `client/lib/screens/reports_screen.dart` (tabla de servicios y tabla de mecánicos) y ampliar `client/lib/models/report.dart`, `client/lib/services/reports_service.dart` y `client/lib/providers/reports_provider.dart`

**Punto de control**: los servicios frecuentes y la productividad cuadran con las órdenes; las pruebas de la historia 5 pasan

---

## Fase 11: Historia de usuario 6 - Costo, margen y rotación de las refacciones (Prioridad: P2)

**Objetivo**: el administrador ve por refacción las unidades usadas, el costo, el precio, el margen y la rotación del inventario.

**Prueba independiente**: con refacciones usadas en órdenes del periodo, ve por refacción unidades, costo, ingreso y margen, y la rotación; una refacción sin precio de compra aparece como «Sin costo».

### Pruebas de la historia 6 (escribir primero y comprobar que fallan)

- [ ] T076 [P] [US6] Prueba de integración `server/tests/integration/reports.parts.test.js`: `GET /api/reports/parts` devuelve por refacción `units`, `revenue` (`quantity × unit_price` de las líneas), `cost` (`quantity × purchase_price` actual), `margin` y `marginPercent` con dos decimales; una refacción sin precio de compra (nulo o cero) llega con `noCost: true`, sin costo ni margen y **no** entra en `totals.cost` ni `totals.margin` (cuenta en `noCostLines`); las líneas anteriores al Sprint 5 (precio 0) no distorsionan el total; los totales son la suma de las filas; `GET /api/reports/rotation` calcula las salidas `OUT` del rango, la existencia al inicio y al final reconstruida desde los movimientos, el promedio y la rotación (`null` con promedio cero); RECEPTIONIST y MECHANIC reciben 403 y nunca un precio de compra
- [ ] T077 [P] [US6] Pruebas del cliente en `client/test/reports_test.dart` (ampliar): la pestaña **Refacciones y rotación** muestra unidades, ingreso, costo, margen y porcentaje; una refacción sin precio de compra lleva el chip ámbar «Sin costo»; debajo, la tabla de rotación (salidas, existencia inicial y final, promedio y rotación)

### Implementación de la historia 6

- [ ] T078 [US6] Agregar `parts(from, to)` y `rotation(from, to)` a `server/models/reportModel.js` (centavos enteros con `SUM(ROUND(... * 100))`; existencia al inicio y al final a partir del stock actual y los movimientos posteriores), sus funciones en `server/services/reportService.js` (márgenes, porcentajes y totales sin las líneas «Sin costo») y las rutas `GET /parts` y `GET /rotation` en `server/routes/reportRoutes.js` y `server/controllers/reportController.js`
- [ ] T079 [US6] Llenar la pestaña **Refacciones y rotación** de `client/lib/screens/reports_screen.dart` (tabla de refacciones con el chip «Sin costo» y tabla de rotación) y ampliar el modelo, el servicio y el proveedor de reportes

**Punto de control**: el margen y la rotación cuadran con los precios y los movimientos; las pruebas de la historia 6 pasan

---

## Fase 12: Historia de usuario 7 - Exportar los reportes (Prioridad: P2)

**Objetivo**: cada reporte se exporta a CSV con los mismos datos, periodo y filtros que la pantalla.

**Prueba independiente**: el administrador exporta el reporte de ingresos del mes y el archivo contiene lo mismo que la pantalla.

### Pruebas de la historia 7 (escribir primero y comprobar que fallan)

- [ ] T080 [P] [US7] Pruebas unitarias del módulo puro en `server/tests/unit/csv.test.js`: empieza con la marca de orden de bytes UTF-8, usa coma y `\r\n`; los campos con coma, comillas o saltos de línea van entre comillas dobles y las comillas se duplican; una celda de texto que empieza con `=`, `+`, `-` o `@` se antepone con una comilla simple (los importes negativos de tipo numérico no); importes con punto y dos decimales; fechas `AAAA-MM-DD`; tildes y eñe se conservan; un reporte vacío trae solo los encabezados
- [ ] T081 [P] [US7] Prueba de integración `server/tests/integration/reports.csv.test.js`: para cada uno de los cinco reportes `?format=csv` responde `text/csv; charset=utf-8` con `Content-Disposition` y nombre `reporte-<nombre>-<from>_<to>.csv`, y el contenido coincide fila por fila con el JSON del mismo periodo (mismos importes al centavo); un reporte vacío trae solo encabezados; un periodo inválido responde `400` igual que en JSON; RECEPTIONIST y MECHANIC reciben 403
- [ ] T082 [P] [US7] Pruebas del cliente en `client/test/reports_test.dart` (ampliar) y `client/test/csv_saver_test.dart`: **Exportar CSV** descarga el reporte de la pestaña activa con el periodo elegido, lo guarda con el nombre del servidor en una carpeta de descargas simulada y muestra «Archivo guardado en [ruta]» con **Abrir carpeta**; si no se puede escribir muestra el error y no pierde el reporte; sin datos exporta solo los encabezados

### Implementación de la historia 7

- [ ] T083 [US7] Crear `server/services/csv.js` (módulo puro `toCsv(columns, rows)` con la marca de orden de bytes, separador coma, `\r\n`, escape de comillas y la protección contra fórmulas) y hacer que `server/controllers/reportController.js` responda CSV cuando `format=csv` usando **la misma función de servicio** que el JSON, con `Content-Type: text/csv; charset=utf-8` y `Content-Disposition: attachment; filename="reporte-<nombre>-<from>_<to>.csv"` para los cinco reportes
- [ ] T084 [US7] Crear `client/lib/utils/csv_saver.dart` (escribe los bytes con `dart:io` en la carpeta de descargas: `USERPROFILE\Downloads` en Windows y `HOME/Downloads` en otros sistemas, sin sobrescribir un archivo existente al agregar un sufijo; devuelve la ruta), ampliar `client/lib/services/api_client.dart` con una descarga de bytes con el nombre del encabezado y agregar a `client/lib/screens/reports_screen.dart` el botón **Exportar CSV** con el mensaje «Archivo guardado en [ruta]» y **Abrir carpeta** (`url_launcher`)

**Punto de control**: cada reporte se exporta y coincide con la pantalla; las pruebas de la historia 7 pasan

---

## Fase 13: Pulido y asuntos transversales

**Propósito**: datos de ejemplo, rendimiento, verificación de dependencias, documentación, regresión y cierre

- [ ] T085 [P] Crear `database/seeds/007_settings_service_types.sql` (idempotente, sin editar seeds anteriores ni tocar órdenes, pagos o tickets existentes): la configuración inicial (`shop.name`, `shop.address`, `shop.phone`, `maintenance.warn_days` en 30 y `maintenance.warn_km` en 1 000) con `INSERT IGNORE` y los tipos de servicio «Cambio de aceite» (180 días y 5 000 km), «Afinación» (365 días y 10 000 km), «Revisión de frenos» (365 días y 20 000 km), «Alineación y balanceo» (180 días y 10 000 km) y «Revisión general» (180 días); aplicarlo con `database/scripts/aplicar-seeds.ps1` en `motorix`
- [ ] T086 [P] Prueba de datos de ejemplo `server/tests/integration/seed.settings.test.js`: tras correr el seed dos veces no se duplican filas; `GET /api/settings` y `GET /api/service-types` traen datos; los reportes de ingresos, servicios, productividad y refacciones del mes de los datos sembrados traen información (usa `runSeedFile` de `server/tests/helpers/seed.js` y acepta los términos antes de consultar)
- [ ] T087 [P] Prueba de rendimiento `server/tests/integration/reports.performance.test.js` (SC-006): con 1 000 pagos y 1 000 órdenes con sus servicios, mano de obra y refacciones, cada uno de los cinco reportes responde en menos de 3 segundos y devuelve el total real
- [ ] T088 [P] Prueba `server/tests/unit/noNewDependencies.test.js` (FR: sin dependencias nuevas): las dependencias de `server/package.json` y las de `client/pubspec.yaml` son exactamente las de la línea base (listas escritas en la prueba) y ninguna es de exportación (Excel, PDF) ni de mensajería
- [ ] T089 [P] Actualizar `docs/project-context.md` (FR-031): secciones de configuración y catálogo de tipos de servicio, reportes y exportación CSV, términos y condiciones, y seguridad de la información (bitácora, contraseña de 10 caracteres, inactividad), las rutas y tablas nuevas, el ticket versión 3 y una «Decisión del Sprint 7» con las aclaraciones D-01 a D-12
- [ ] T090 [P] Actualizar `docs/design-system.md` (FR-031): sección nueva «Reportes, configuración, términos y seguridad (Sprint 7)» con las pestañas, el selector de periodo, el chip «Sin costo», la pantalla de aceptación, el diálogo de inactividad y las cuatro secciones del menú
- [ ] T091 [P] Actualizar `.env.example` (FR-031): indicar que `SHOP_NAME`, `SHOP_ADDRESS`, `SHOP_PHONE`, `MAINTENANCE_WARN_DAYS` y `MAINTENANCE_WARN_KM` pasan a la aplicación y quedan solo como valor de respaldo
- [ ] T092 Ejecutar la regresión completa: `npm test` en `server/` y `flutter test` en `client/`; deben pasar todas las pruebas de la línea base de T001 más las nuevas, salvo las que deban actualizarse por cambios declarados en la especificación (contraseña de 10 caracteres, aceptación de términos y configuración); cada actualización se registra en el documento de aseguramiento
- [ ] T093 Completar `docs/aseguramiento-calidad-sprint-7.md` (y `.docx` si el proceso lo pide): línea base, regresión, matriz final con una prueba por criterio de aceptación del insumo (CA-1 a CA-26) y por requisito (FR-001 a FR-032), los cambios de pruebas declarados (SC-011), los resultados de `dataExposure` e `injection`, los riesgos R-01 a R-15 de plan.md y la aprobación; las capturas y los tiempos con la interfaz los toma la persona responsable en el recorrido manual
- [ ] T094 Ejecutar el recorrido manual de `quickstart.md` (secciones 4 a 7) con los datos de ejemplo contra la API real y anotar el resultado en el documento de aseguramiento (la parte con la interfaz gráfica, con sus capturas y tiempos de SC-010, la hace el responsable)

---

## Dependencias y orden de ejecución

### Dependencias entre fases

- **Fase 1 (T001)**: sin dependencias
- **Fase 2 (T002 a T007)**: depende de T001; BLOQUEA todas las historias
- **Fase 3 (US1)**: depende de la fase 2; crea `settingsService`, la ruta, el proveedor y la pantalla de Configuración que usan las historias 2 y 3
- **Fase 4 (US2)** y **fase 5 (US3)**: dependen de la fase 3 (la pantalla y el servicio de configuración); entre sí solo comparten `settings_screen.dart`
- **Fase 6 (US8)** depende de la fase 5 en la regla del próximo mantenimiento, pero su cambio al ticket es independiente
- **Fase 7 (US9)** puede ir en paralelo con las fases 4 a 6 **salvo** T043 y T044, que cambian el comportamiento de todas las pruebas con sesión: hacerlas cuando las demás historias del servidor estén en verde, y siempre antes de la fase 8
- **Fase 8 (US10)** depende de las fases 3, 5 y 7 (necesita configuración, tipos de servicio y términos para registrar y revisar sus acciones y para la prueba de exposición)
- **Fases 9 a 12 (reportes)** dependen de la fase 2; entre sí comparten `reportModel.js`, `reportService.js`, `reportRoutes.js` y `reports_screen.dart` (hacerlas en orden US4, US5, US6 y US7); la exportación (US7) cierra todos los reportes
- **Fase 13**: depende de las historias que se vayan a entregar; T085 y T086 necesitan configuración y tipos de servicio, y T092 a T094 van al final

### Dentro de cada historia

- Las pruebas se escriben primero y deben fallar antes de implementar
- Modelos → servicios → validadores, controladores y rutas → cliente (modelo, servicio, proveedor, pantalla) → integración
- Ninguna tarea se da por terminada mientras sus pruebas no pasen

### Oportunidades de ejecución en paralelo

- Fase 2: T005, T006 y T007 son independientes entre sí tras T002 a T004
- Dentro de cada historia: las pruebas marcadas [P] se pueden escribir en paralelo; el backend y el cliente pueden avanzar a la vez cuando el contrato está fijado (`contracts/`)
- Fase 13: T085 a T091 son independientes

---

## Ejemplo de ejecución en paralelo: Historia 1

```text
T008  integración settings.flow
T009  contrato settings
T010  pruebas del cliente (pestaña Taller)
      -> luego: T011 servicio -> T012 ruta -> T013 ticket;  T014 modelos, servicio y proveedor del cliente -> T015 pantalla
```

---

## Estrategia de implementación

### Primero el valor mínimo (historia 1)

1. Fases 1 y 2 (preparación y fundamentos).
2. Fase 3 (US1): el administrador edita los datos del taller y el ticket nuevo los usa.
3. **Detenerse y validar**: cambiar el nombre y el teléfono, generar un ticket nuevo y comparar con uno anterior.

### Entrega incremental

1. Fases 1 y 2 → base lista.
2. US1 → datos del taller (MVP).
3. US2 y US3 → márgenes y catálogo de tipos de servicio.
4. US8 → próximo servicio en el ticket.
5. US9 → términos y condiciones.
6. US10 → bitácora, contraseñas, inactividad, exposición e inyección.
7. US4, US5, US6 y US7 → reportes y exportación (D-04: al final).
8. Fase 13 → seeds, rendimiento, documentación y aseguramiento.

### Si el tiempo se acorta

El Sprint 7 tiene 5 días planificados (25 al 29 de noviembre) y es el más grande. Por la decisión D-04, las fases 3 a 8 (configuración, catálogo, ticket, términos y seguridad) van primero; las fases 9 a 12 (reportes y exportación) pueden pasar a la holgura del 1 al 5 de diciembre solo si el tiempo está muy justo. La fase 13 (datos de ejemplo, documentación y aseguramiento) no se omite.

### Notas

- [P] = archivos distintos y sin dependencias pendientes
- Cada historia se puede completar y probar de forma independiente
- Hacer commit después de cada tarea o grupo lógico (Conventional Commits, tipo y alcance en inglés y descripción en español)
- Los criterios del insumo (CA-1 a CA-26) se cubren así: CA-1 con US1; CA-2 y CA-3 con US2 y US1; CA-4 y CA-5 con US3; CA-6 con US4, US5 y US6; CA-7 con T063 y T064; CA-8 con US6; CA-9 con US7; CA-10 con las pruebas de permisos de cada historia; CA-11 con T087; CA-12 con T085 y T086; CA-13 con las pruebas de cada historia; CA-14 con US8; CA-15 con T089, T090 y T091; CA-16 a CA-19 con US9; CA-20 y CA-21 con T050 y T057; CA-22 con T049 y T056; CA-23 con T052, T059 y T061; CA-24 con T053; CA-25 con T054; CA-26 con las pruebas de la historia 10
