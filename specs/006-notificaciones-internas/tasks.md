---

description: "Lista de tareas del Sprint 6: notificaciones internas y clientes por avisar"
---

# Tareas: Notificaciones internas y clientes por avisar (Sprint 6)

**Entrada**: Documentos de diseño en `specs/006-notificaciones-internas/`

**Requisitos previos**: plan.md, spec.md, research.md, data-model.md, contracts/ (api-rest.md e interfaz.md), quickstart.md

**Pruebas**: INCLUIDAS. La constitución (Principio VII) exige pruebas para la lógica de negocio (permisos, claves de aviso, lecturas, estados) y el aseguramiento de la calidad del sprint pide una prueba por cada criterio de aceptación. Las pruebas de cada historia se escriben primero y deben fallar antes de implementar.

**Organización**: Las tareas se agrupan por historia de usuario para poder implementar y probar cada una de forma independiente.

## Formato: `[ID] [P?] [Historia] Descripción`

- **[P]**: se puede ejecutar en paralelo (archivos distintos, sin dependencias pendientes)
- **[USn]**: historia de usuario a la que pertenece la tarea (US1 a US7 de spec.md)
- Todas las rutas son relativas a la raíz del repositorio (`D:\sdd\motorix`)

## Convenciones de rutas

- Backend: `server/` (capas directamente en la raíz de `server/`, sin carpeta `src/`)
- Frontend: `client/lib/` y `client/test/`
- Base de datos: `database/`
- El código backend usa ES Modules (`import`/`export`); los identificadores van en inglés y los comentarios, mensajes y nombres de pruebas en español
- Las pruebas de integración y contrato se ejecutan solo contra `motorix_test`; los errores nuevos usan `AppError` (`server/utils/AppError.js`) con los códigos de `contracts/api-rest.md`
- Los avisos NO se guardan: se calculan al consultar. Solo se guardan `notification_reads` y `client_notices`
- Los permisos se validan en el servidor: el stock no se devuelve a recepción ni al mecánico; el mecánico no recibe teléfonos ni accede a la lista de clientes por avisar
- Ningún código envía mensajes al cliente por ningún canal (FR-019); no se agregan dependencias nuevas
- Las pruebas del cliente usan la API simulada de `client/test/helpers/fake_api.dart`

## Orden de las historias (prioridad)

P1: US1 (campana y panel), US2 (mantenimientos y citas para recepción), US6 (leído y abrir el módulo), US7 (clientes por avisar). P2: US3 (stock), US4 (órdenes detenidas), US5 (mecánico).

> Correspondencia con la especificación: US1 = Historia 1; US2 = Historia 2; US3 = Historia 3; US4 = Historia 4; US5 = Historia 5; US6 = Historia 6; US7 = Historia 7. Las fases siguen el orden de prioridad, no el numérico.

> **Tipo de referencia de la historia 1**: para poder probar la campana y el panel de extremo a extremo, la historia 1 incluye el tipo «mantenimiento vencido». Las demás historias agregan sus tipos al mismo servicio.

---

## Fase 1: Preparación (infraestructura compartida)

**Propósito**: verificar la base, registrar la condición de la constitución y abrir el documento de aseguramiento

- [X] T001 Verificar la línea base en la rama `006-notificaciones-internas`: MySQL local en ejecución, migraciones 001 a 005 aplicadas en `motorix` y `motorix_test`, `npm test` (en `server/`) y `flutter test` (en `client/`) en verde; anotar el número de suites y de pruebas de cada uno (la última cifra documentada es 1 215 de backend y 321 de frontend) y abrir `docs/aseguramiento-calidad-sprint-6.md` a partir de `docs/aseguramiento-calidad/plantilla-aseguramiento-calidad.md` con esa línea base
- [X] T002 ⚠️ PUERTA (aprobada y registrada el 2026-11-20, versión 1.1.1): registrar en `.specify/memory/constitution.md`, en una sección nueva «Decisiones resueltas durante el Sprint 6», la aprobación del responsable del proyecto para construir el Sprint 6 (principio I: los sprints posteriores al MVP exigen insumo en `docs/sprints/`, aprobación registrada y flujo de Spec Kit), con la fecha 2026-11-20 y el insumo `docs/sprints/sprint-6-notificaciones-internas.md`; incrementar la versión PATCH (1.1.0 → 1.1.1) y actualizar el reporte de impacto del encabezado y la fecha de última enmienda. No se inicia la fase 2 sin esta aprobación

---

## Fase 2: Fundamentos (requisitos bloqueantes)

**Propósito**: esquema, reglas puras, validadores, modelos de lectura y de avisos, y los modelos del cliente que DEBEN existir antes de cualquier historia

**⚠️ CRÍTICO**: esta fase no empieza hasta que la aprobación de la constitución (T002) esté registrada, y ninguna historia puede empezar hasta terminarla

### Base de datos

- [X] T003 Crear `database/migrations/006_sprint6_notices.sql` (InnoDB, `utf8mb4`, aditiva, sin editar migraciones anteriores ni tocar datos existentes; encabezado en español). Según data-model.md:
  - `notification_reads`: `user_id INT UNSIGNED NOT NULL`, `notice_key VARCHAR(60) NOT NULL`, `read_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`; `PRIMARY KEY (user_id, notice_key)`; `CONSTRAINT fk_notification_reads_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE`
  - `client_notices`: `id INT UNSIGNED NOT NULL AUTO_INCREMENT` (llave primaria), `client_id INT UNSIGNED NOT NULL`, `reason ENUM('ORDER_READY','APPT_TOMORROW','MAINT_UPCOMING','MAINT_OVERDUE') NOT NULL`, `fact_id INT UNSIGNED NOT NULL`, `notified_by INT UNSIGNED NOT NULL`, `notified_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`; `UNIQUE KEY uq_client_notices_fact (reason, fact_id)`; `KEY idx_client_notices_client (client_id)`; llaves foráneas a `clients(id)` y `users(id)` con `ON DELETE RESTRICT`; sin columna de nota ni de canal (D-02)
- [X] T004 Aplicar la migración 006 en `motorix` y `motorix_test` con `database/scripts/aplicar-migraciones.ps1` (repetirla debe terminar sin error), comprobar que el número de filas de `clients`, `vehicles`, `appointments`, `service_orders`, `maintenance`, `payments` y `tickets` es el mismo antes y después de aplicarla (FR-025) y actualizar `database/README.md` con la migración 006
- [X] T005 Actualizar `resetDatabase()` en `server/tests/helpers/factories.js`: borrar `client_notices` y `notification_reads` antes de `users` y `clients` (respetando las llaves foráneas)

### Backend base

- [X] T006 [P] Crear `server/services/noticeRules.js` (módulo puro, sin acceso a la base): constantes `STALLED_DAYS = 3`, `NOTICE_TYPES` (`MAINT_UPCOMING`, `MAINT_OVERDUE`, `APPT_TODAY`, `STOCK_LOW`, `STOCK_OUT`, `STALLED`), `CLIENT_NOTICE_REASONS` (`ORDER_READY`, `APPT_TOMORROW`, `MAINT_UPCOMING`, `MAINT_OVERDUE`) y `GROUP_ORDER` (orden de los grupos de api-rest.md); `isStalledOrder({ status, lastChangeAt, today })` (solo `RECIBIDO`, `DIAGNOSTICO`, `EN_REPARACION` y `ESPERANDO_REFACCION`, más de 3 días calendario); `buildNoticeKey(type, id, variant)` y `isValidNoticeKey(text)` (clave de hasta 60 caracteres con las formas de data-model.md); `typesForRole(role)` (ADMIN todos; RECEPTIONIST todos menos `STOCK_LOW` y `STOCK_OUT`; MECHANIC solo `STALLED`)
- [X] T007 [P] Pruebas unitarias de las reglas en `server/tests/unit/noticeRules.test.js`: 3 días exactos no es detenida y 4 días sí; los estados `TERMINADO` y `ENTREGADO` nunca; claves válidas e inválidas (vacía, con más de 60 caracteres, tipo desconocido); `typesForRole` para los tres roles
- [X] T008 [P] Crear `server/validators/noticeValidators.js` (zod): `readNoticesSchema` (`keys`: arreglo de 1 a 50 claves de hasta 60 caracteres que pasen `isValidNoticeKey`) y `createClientNoticeSchema` estricto (`reason` entre los motivos y `factId` entero positivo; rechaza campos desconocidos como una nota, D-02)
- [X] T009 [P] Pruebas unitarias de los validadores en `server/tests/unit/noticeValidators.test.js`: arreglo vacío, 51 claves, clave mal formada, motivo desconocido, `factId` no entero o negativo y campo extra `note` se rechazan; entradas válidas pasan
- [X] T010 [P] Crear `server/models/notificationReadModel.js`: `listReadKeys(userId, connection)` (claves leídas del usuario) e `insertIgnore(userId, keys, connection)` con `INSERT IGNORE` (repetir o ejecutar en paralelo no falla ni duplica filas)
- [X] T011 [P] Crear `server/models/clientNoticeModel.js`: `findByFact(reason, factId, connection)`, `insertIgnore({ clientId, reason, factId, notifiedBy }, connection)` con `INSERT IGNORE` sobre `uq_client_notices_fact` y `listNoticedFacts(connection)` (pares `(reason, fact_id)` ya avisados)

### Cliente base

- [X] T012 [P] Crear `client/lib/models/notice.dart`: tipo `NoticeType` (con `apiValue` y etiqueta en español por tipo), `AppNotice` (`key`, `type`, `read`, `title`, `detail`, `target` con `kind` e `id`, campos opcionales `dueDate`, `scheduledAt`, `stock`, `minStock`, `daysStalled`), `NoticeGroup` (`type`, `total`, `unread`, `items`) y `NoticesSummary` (`unread`, `total`, `groups`, `generatedAt`) con `fromJson`
- [X] T013 [P] Crear `client/lib/models/client_notice.dart`: motivo `ClientNoticeReason` (con `apiValue` y etiqueta «Vehículo listo», «Cita de mañana», «Mantenimiento próximo», «Mantenimiento vencido») y `PendingClientNotice` (`reason`, `factId`, `factDate`, `folio` opcional, `client` con `id`, `name` y `phone`, `vehicle`) con `fromJson`
- [X] T014 [P] Pruebas de los modelos del cliente en `client/test/notice_models_test.dart`: `fromJson` de cada tipo y motivo, teléfono vacío y listas vacías

**Punto de control**: la migración está aplicada, las reglas puras y los validadores pasan sus pruebas y los modelos del cliente se leen bien; las historias pueden empezar

---

## Fase 3: Historia de usuario 1 - Ver cuántos avisos pendientes tengo (Prioridad: P1) 🎯 MVP

**Objetivo**: el encabezado muestra una campana con el total de avisos no leídos y un panel con los avisos agrupados por tipo, con estados de carga, vacío y error; el contador se actualiza al iniciar sesión, al navegar y cada 60 segundos.

**Prueba independiente**: con un mantenimiento vencido, el administrador inicia sesión, ve la campana con «1», abre el panel y ve el aviso agrupado; sin avisos ve el estado vacío; si el servidor falla ve el error con «Reintentar».

### Pruebas de la historia 1 (escribir primero y comprobar que fallan)

- [X] T015 [P] [US1] Prueba de integración `server/tests/integration/notifications.flow.test.js`: sin avisos devuelve `unread: 0`, `total: 0` y `groups: []`; con un mantenimiento vencido devuelve 1 grupo `MAINT_OVERDUE` con su aviso; sin token responde 401; con más de 50 vencidos lista 50 y `total` real; `generatedAt` presente
- [X] T016 [P] [US1] Prueba de contrato `server/tests/contract/notifications.contract.test.js`: forma exacta de `GET /api/notifications` según `contracts/api-rest.md` (campos del ítem y del grupo, `target.kind`, orden de grupos)
- [X] T017 [P] [US1] Pruebas del cliente en `client/test/notifications_test.dart`: el proveedor consulta al iniciar y cada 60 segundos con tiempo simulado, se detiene y limpia al cerrar sesión; la campana no muestra número con 0, muestra el total y «99+» con más de 99; el panel muestra cargando, vacío («No hay avisos pendientes») y error con «Reintentar» conservando los datos previos

### Implementación de la historia 1

- [X] T018 [US1] Crear `server/services/notificationService.js`: `list(actor)` calcula los avisos del rol con `typesForRole`, agrupa en el orden de `GROUP_ORDER`, limita a 50 avisos por tipo con el total real del tipo, marca `read` con `notificationReadModel.listReadKeys` y devuelve `unread`, `total` y `generatedAt`; registrar el tipo de referencia `MAINT_OVERDUE` con `maintenanceService.list({ status: 'PENDIENTE', indicator: 'VENCIDO', page: 1, pageSize: 50 }, actor)` (mismo cálculo que el panel de control) y la clave `MAINT_OVERDUE:{id}`, con `target` de tipo `vehicle` y `dueDate`/`dueMileage`; el servicio no ejecuta ninguna consulta de un tipo que el rol no puede ver
- [X] T019 [US1] Crear `server/controllers/notificationController.js` y `server/routes/notificationRoutes.js` con `GET /` (`authenticate`, sin parámetros) y montarla en `server/routes/index.js` como `/notifications`
- [X] T020 [P] [US1] Crear `client/lib/services/notifications_service.dart` con `fetch()` que llama `GET /notifications` y devuelve `NoticesSummary`
- [X] T021 [US1] Crear `client/lib/providers/notifications_provider.dart`: estado (`summary`, `loading`, `error`, `loaded`), `refresh()` que conserva el último resultado si falla, `start()` con `Timer.periodic` de 60 segundos, `stop()`/`clear()` que cancelan el temporizador y limpian, y `dispose()` seguro
- [X] T022 [P] [US1] Crear `client/lib/widgets/notification_bell.dart`: botón de ícono con insignia (sin número con 0; «99+» si pasa de 99; ámbar, y rojo si hay vencidos o agotados sin leer), etiqueta de accesibilidad «Notificaciones, N sin leer» y apertura por teclado, con los tokens de `client/lib/utils/tokens.dart`
- [X] T023 [US1] Crear `client/lib/widgets/notifications_panel.dart`: panel anclado a la campana con título «Notificaciones», «N sin leer», secciones por tipo con nombre, total y avisos (indicador de color por tipo, punto de no leído, texto atenuado si está leído), «Mostrando 50 de N» y los estados cargando, vacío («No hay avisos pendientes») y error con «Reintentar» usando `client/lib/widgets/state_views.dart`
- [X] T024 [US1] Integrar en `client/lib/widgets/app_shell.dart`: agregar la campana al `_Header` entre el título y el usuario; iniciar `NotificationsProvider` al montar el `AppShell`, refrescar al cambiar de sección y detenerlo al desmontarse o cerrar sesión; registrar `NotificationsService` y `NotificationsProvider` en `client/lib/main.dart`

**Punto de control**: la campana y el panel funcionan de extremo a extremo con el tipo de referencia; las pruebas de la historia 1 pasan

---

## Fase 4: Historia de usuario 2 - Avisos de mantenimientos y citas para la recepción (Prioridad: P1)

**Objetivo**: la recepción ve los mantenimientos próximos y vencidos y las citas del día, calculados con las mismas reglas que ya existen.

**Prueba independiente**: con un mantenimiento próximo, uno vencido y una cita de hoy, la recepcionista inicia sesión y ve esos tres avisos; una cita cancelada o completada no aparece.

### Pruebas de la historia 2 (escribir primero y comprobar que fallan)

- [X] T025 [P] [US2] Prueba de integración `server/tests/integration/notifications.reception.test.js`: la recepción recibe `MAINT_UPCOMING`, `MAINT_OVERDUE` y `APPT_TODAY` en grupos separados; la cita de hoy `PENDIENTE` o `CONFIRMADA` genera aviso y la `CANCELADA`, `COMPLETADA` o `EN_PROCESO` no; una cita de mañana o de ayer no; los totales de mantenimientos coinciden con `GET /api/dashboard` y con `GET /api/maintenance` (FR-005, SC-003)
- [X] T026 [P] [US2] Pruebas del cliente en `client/test/notifications_test.dart` (ampliar): el panel muestra las secciones «Mantenimientos vencidos», «Citas de hoy» y «Mantenimientos próximos» en el orden de `contracts/interfaz.md`, con el color por tipo y la hora de la cita

### Implementación de la historia 2

- [X] T027 [US2] Crear (si aún no existe) `server/models/noticeModel.js`, que comparten las historias 2, 4 y 7, con `listAppointmentsOn(date, connection)` (citas con `DATE(scheduled_at) = date` y estado `PENDIENTE` o `CONFIRMADA`, con cliente y vehículo) y `countAppointmentsOn(date)`; la fecha de hoy es la del servidor, igual que el panel
- [X] T028 [US2] Ampliar `server/services/notificationService.js` con `MAINT_UPCOMING` (`maintenanceService.list` con indicador `PROXIMO`, clave `MAINT_UPCOMING:{id}`, `target` de tipo `vehicle`) y `APPT_TODAY` (clave `APPT_TODAY:{id}`, `target` de tipo `appointment`, `scheduledAt`), con el nombre del cliente en `detail` para ADMIN y RECEPTIONIST y nunca el teléfono
- [X] T029 [P] [US2] Ampliar `client/lib/widgets/notifications_panel.dart` y `client/lib/models/notice.dart` con las secciones de próximos y de citas del día (indicador ámbar para próximo y neutro para la cita)

**Punto de control**: la recepción ve los avisos de mantenimientos y citas, y los números coinciden con el panel y con la lista de Mantenimientos

---

## Fase 5: Historia de usuario 6 - Marcar como leído y abrir el módulo relacionado (Prioridad: P1)

**Objetivo**: el usuario marca avisos como leídos (por usuario y persistente), el aviso desaparece o reaparece según su condición, y cada aviso abre la pantalla relacionada.

**Prueba independiente**: el administrador abre el aviso de un mantenimiento, llega a su vehículo, el aviso queda leído y el contador baja; tras cerrar e iniciar sesión sigue leído; otro usuario lo ve sin leer.

### Pruebas de la historia 6 (escribir primero y comprobar que fallan)

- [X] T030 [P] [US6] Prueba de integración `server/tests/integration/notifications.read.test.js`: marcar como leído persiste y baja `unread`; otro usuario del mismo rol lo ve sin leer; un aviso leído cuya condición deja de cumplirse desaparece; de próximo a vencido reaparece sin leer (clave nueva); claves inexistentes o de otro rol se ignoran con 200; repetir la solicitud no falla; cinco solicitudes simultáneas dejan una sola fila en `notification_reads`; 50 claves como máximo
- [X] T031 [P] [US6] Prueba de contrato `server/tests/contract/notifications.read.contract.test.js`: forma de `POST /api/notifications/read` (`{ marked, unread }`), 400 `VALIDATION_ERROR` con `keys` vacío, más de 50 o mal formadas, y 401 sin token
- [X] T032 [P] [US6] Pruebas del cliente en `client/test/notifications_test.dart` (ampliar): pulsar un aviso lo marca como leído, baja el contador y abre la pantalla relacionada (orden, cita, vehículo o inventario) cerrando el panel; el botón «Marcar como leído» solo marca; un error al marcar muestra el mensaje y no cambia el contador

### Implementación de la historia 6

- [X] T033 [US6] Ampliar `server/services/notificationService.js` con `markRead(keys, actor)`: recalcula los avisos vigentes del actor, intersecta con las claves recibidas, inserta con `notificationReadModel.insertIgnore` y devuelve `{ marked, unread }`; las claves que no correspondan se ignoran sin error
- [X] T034 [US6] Agregar `markRead` al controlador y la ruta `POST /notifications/read` con `validate({ body: readNoticesSchema })` en `server/controllers/notificationController.js` y `server/routes/notificationRoutes.js`
- [X] T035 [P] [US6] Ampliar `client/lib/services/notifications_service.dart` con `markRead(List<String> keys)` y `client/lib/providers/notifications_provider.dart` con `markRead` (actualiza el aviso y el contador de inmediato y reconcilia con el servidor)
- [X] T036 [US6] Agregar la apertura del módulo relacionado: método `openTarget(kind, id)` en `client/lib/providers/navigation_provider.dart` (cambia a la sección de órdenes —«Mis órdenes» para el mecánico—, citas, vehículos o inventario y empuja el detalle) y su uso en `client/lib/widgets/app_shell.dart`; conectar el panel (`notifications_panel.dart`) para marcar como leído y abrir el aviso, y agregar el botón «Marcar como leído»

**Punto de control**: la lectura es por usuario y persistente, el aviso reaparece al empeorar y cada aviso abre su pantalla

---

## Fase 6: Historia de usuario 7 - Lista de clientes por avisar (Prioridad: P1)

**Objetivo**: la recepción ve a los clientes por avisar (vehículo listo, cita de mañana, mantenimiento próximo o vencido) con su teléfono y marca cada uno como avisado; el sistema solo lo registra y no envía mensajes.

**Prueba independiente**: con una orden Terminada sin entregar, la recepcionista abre «Clientes por avisar», ve al cliente con su teléfono, lo marca como avisado y sale de la lista; un hecho nuevo lo vuelve a mostrar.

### Pruebas de la historia 7 (escribir primero y comprobar que fallan)

- [X] T037 [P] [US7] Prueba de integración `server/tests/integration/clientNotices.flow.test.js`: la lista incluye orden Terminada (`ORDER_READY`), cita de mañana `PENDIENTE` o `CONFIRMADA` (`APPT_TOMORROW`), mantenimiento próximo y vencido; una orden Entregada, una cita cancelada y un mantenimiento atendido no aparecen; un cliente con dos motivos aparece dos veces; marcar crea el registro con quién y cuándo, saca la fila y no reaparece; una orden nueva del mismo cliente aparece de nuevo; `POST` sobre un hecho que ya no aplica responde 409 `NOTICE_NOT_APPLICABLE`; hecho inexistente responde 404
- [X] T038 [P] [US7] Prueba de concurrencia `server/tests/integration/clientNotices.concurrency.test.js`: cinco `POST` simultáneos del mismo hecho dejan una sola fila en `client_notices`, uno responde 201 y los demás 200, sin errores
- [X] T039 [P] [US7] Prueba de contrato `server/tests/contract/clientNotices.contract.test.js`: forma de `GET` y `POST /api/client-notices` según `contracts/api-rest.md`; el cuerpo con el campo `note` se rechaza con `VALIDATION_ERROR`; `MECHANIC` recibe 403 en ambas rutas; sin token 401; `phone` vacío llega como cadena vacía
- [X] T040 [P] [US7] Pruebas del cliente en `client/test/client_notices_test.dart`: la sección aparece solo para administrador y recepción; la tabla muestra cliente, teléfono («Sin teléfono registrado» si está vacío), vehículo, motivo con su chip y fecha; «Avisado» abre la confirmación «¿Ya avisaste a [cliente] por [motivo]?», al confirmar la fila sale y se muestra «Cliente marcado como avisado»; `NOTICE_NOT_APPLICABLE` muestra «Este aviso ya no aplica» y actualiza; estados cargando, vacío («No hay clientes por avisar») y error con «Reintentar»

### Implementación de la historia 7

- [X] T041 [US7] Ampliar (o crear, si la historia 2 aún no se hizo) `server/models/noticeModel.js` con `listFinishedOrders(connection)` (órdenes `TERMINADO` con cliente, vehículo y fecha en que quedaron Terminadas por el último cambio del historial) y `listAppointmentsOn(date)` para el día de mañana (reutiliza la de T027)
- [X] T042 [US7] Crear `server/services/clientNoticeService.js`: `listPending(actor)` arma los cuatro motivos (órdenes terminadas, citas de mañana, mantenimientos próximos y vencidos con `maintenanceService.list`), excluye los pares `(reason, fact_id)` de `clientNoticeModel.listNoticedFacts`, limita a 200 filas con el total real en `meta.total` y devuelve el teléfono; `register({ reason, factId }, actor)` verifica que el hecho cumple hoy su motivo (409 `NOTICE_NOT_APPLICABLE`, 404 si no existe), inserta con `insertIgnore` y devuelve 201 con el registro nuevo o 200 con el existente; nunca envía ningún mensaje
- [X] T043 [US7] Crear `server/controllers/clientNoticeController.js` y `server/routes/clientNoticeRoutes.js` con `GET /` y `POST /` (`authenticate`, `authorize(ROLES.ADMIN, ROLES.RECEPTIONIST)`, `validate` con `createClientNoticeSchema`) y montarla en `server/routes/index.js` como `/client-notices`
- [X] T044 [P] [US7] Crear `client/lib/services/client_notices_service.dart` (`list()` y `markNotified(reason, factId)`, tratando 200 y 201 como éxito) y `client/lib/providers/client_notices_provider.dart` (estados cargando, vacío y error; `markNotified` quita la fila y refresca la campana)
- [X] T045 [US7] Crear `client/lib/screens/client_notices_screen.dart`: encabezado de página con el texto «Llama o avisa en persona y marca al cliente como avisado. El sistema no envía mensajes.», tabla `AppDataTable` con Cliente, Teléfono, Vehículo, Motivo (chip verde para listo, ámbar para próximo y cita, rojo para vencido), Fecha y Acción, botón «Avisado» con `client/lib/widgets/confirm_dialog.dart` y los estados de `state_views.dart`
- [X] T046 [US7] Agregar la sección: `AppSection.clientNotices` («Clientes por avisar») en `client/lib/providers/navigation_provider.dart` (en `sectionsFor` solo para administrador y recepción, debajo de Mantenimientos), su ícono y su pantalla en `client/lib/widgets/app_shell.dart`, la descripción en `client/lib/screens/home_screen.dart` y el registro de los proveedores en `client/lib/main.dart`

**Punto de control**: la recepción avisa a un cliente y lo marca en menos de un minuto; ningún cliente reaparece por el mismo hecho y no se envía ningún mensaje

---

## Fase 7: Historia de usuario 3 - Aviso de stock bajo o agotado (Prioridad: P2)

**Objetivo**: el administrador ve las refacciones con stock bajo o agotado en el centro, con el mismo cálculo del inventario; recepción y mecánico no reciben avisos de stock.

**Prueba independiente**: con una refacción en su mínimo y otra en cero, el administrador ve los dos avisos y distingue la agotada; la recepcionista y el mecánico no ven ninguno.

### Pruebas de la historia 3 (escribir primero y comprobar que fallan)

- [X] T047 [P] [US3] Prueba de integración `server/tests/integration/notifications.stock.test.js`: el administrador recibe `STOCK_LOW` (con `0 < stock <= min_stock`) y `STOCK_OUT` (`stock = 0`) solo de refacciones activas; una inactiva no avisa; el total coincide con `GET /api/parts/alerts` y con el panel; la recepción y el mecánico no reciben ningún `STOCK_*`, ni siquiera marcando sus claves
- [X] T048 [P] [US3] Pruebas del cliente en `client/test/notifications_test.dart` (ampliar) y `client/test/home_screen_test.dart`: el panel muestra «Stock agotado» (rojo) y «Stock bajo» (ámbar) con existencia y mínimo; la insignia de Inventario y el aviso de inicio siguen funcionando y no se contradicen con el centro (FR-009); tras un movimiento de inventario se refresca el centro

### Implementación de la historia 3

- [X] T049 [US3] Ampliar `server/services/notificationService.js` con `STOCK_LOW` y `STOCK_OUT` a partir de `partService.alerts()` (claves `STOCK_LOW:{partId}` y `STOCK_OUT:{partId}`, `target` de tipo `part`, `stock` y `minStock`), ejecutado solo para ADMIN
- [X] T050 [P] [US3] Refrescar el centro tras los movimientos de inventario: llamar a `NotificationsProvider.refresh()` junto a `StockAlertsProvider.refresh()` en `client/lib/screens/inventory_screen.dart` y `client/lib/screens/part_detail_screen.dart`, sin cambiar `StockAlertsProvider` ni el banner
- [X] T051 [P] [US3] Ampliar `client/lib/widgets/notifications_panel.dart` con las secciones de stock (rojo para agotado y ámbar para bajo)

**Punto de control**: el administrador ve el stock en el centro y los números coinciden con el inventario

---

## Fase 8: Historia de usuario 4 - Avisos de órdenes detenidas (Prioridad: P2)

**Objetivo**: administración y recepción ven las órdenes abiertas con más de 3 días sin cambio de estado.

**Prueba independiente**: con una orden en Esperando refacción con 4 días sin cambio, el administrador y la recepcionista ven el aviso con folio, cliente, estado y días; al cambiar su estado el aviso desaparece.

### Pruebas de la historia 4 (escribir primero y comprobar que fallan)

- [X] T052 [P] [US4] Prueba de integración `server/tests/integration/notifications.stalled.test.js`: una orden abierta con 4 días desde su último cambio genera `STALLED`, con 3 días exactos no; la fecha del último cambio es el mayor `changed_at` del historial (y `created_at` sin historial); `TERMINADO` y `ENTREGADO` no avisan; cambiar de estado quita el aviso y reinicia el conteo; la clave `STALLED:{orden}:{último id del historial}` cambia cuando la orden vuelve a detenerse, y el aviso reaparece sin leer; `ADMIN` y `RECEPTIONIST` lo reciben
- [X] T053 [P] [US4] Pruebas del cliente en `client/test/notifications_test.dart` (ampliar): la sección «Órdenes detenidas» muestra folio, cliente, estado y «N días sin cambio» con indicador ámbar y abre la orden al pulsar

### Implementación de la historia 4

- [X] T054 [US4] Ampliar (o crear, si aún no existe) `server/models/noticeModel.js` con `listOpenOrdersWithLastChange({ mechanicId }, connection)` (órdenes en `RECIBIDO`, `DIAGNOSTICO`, `EN_REPARACION` y `ESPERANDO_REFACCION` con el último `changed_at` y el último id de `order_status_history`, o `created_at` y `0`; filtro opcional por mecánico asignado) apoyada en `idx_order_history_order`
- [X] T055 [US4] Ampliar `server/services/notificationService.js` con `STALLED` usando `isStalledOrder` de `noticeRules.js`, la clave `STALLED:{orderId}:{lastHistoryId}`, `target` de tipo `order`, `folio`, `status` y `daysStalled`; **desde esta tarea** el MECHANIC solo recibe las órdenes con `mechanic_id` igual al del actor (`listOpenOrdersWithLastChange({ mechanicId })`) y sin nombre de cliente, para no filtrar avisos de órdenes ajenas aunque la historia 5 aún no se haya hecho
- [X] T056 [P] [US4] Ampliar `client/lib/widgets/notifications_panel.dart` con la sección «Órdenes detenidas»

**Punto de control**: las órdenes detenidas aparecen y desaparecen según la regla de 3 días

---

## Fase 9: Historia de usuario 5 - El mecánico ve solo lo que le corresponde (Prioridad: P2)

**Objetivo**: el mecánico recibe únicamente los avisos de las órdenes que tiene asignadas, sin datos de clientes, y no accede a la lista de clientes por avisar.

**Prueba independiente**: con avisos de las órdenes de dos mecánicos, más avisos de stock, citas y mantenimientos, cada mecánico ve solo los de sus órdenes.

### Pruebas de la historia 5 (escribir primero y comprobar que fallan)

- [X] T057 [P] [US5] Prueba de integración `server/tests/integration/notifications.mechanic.test.js`: el mecánico solo recibe `STALLED` de sus órdenes asignadas; no recibe las de otro mecánico ni las órdenes sin asignar, ni avisos de citas, mantenimientos o stock; los ítems no traen nombre de cliente ni teléfono; marcar claves ajenas se ignora; `GET` y `POST /api/client-notices` responden 403; el rol vigente en la base (no el del token) decide los avisos tras un cambio de rol
- [X] T058 [P] [US5] Pruebas del cliente en `client/test/notifications_test.dart` y `client/test/app_shell_test.dart` (ampliar): el mecánico ve solo la sección «Órdenes detenidas» y no ve «Clientes por avisar» en el menú

### Implementación de la historia 5

- [X] T059 [US5] Reforzar `server/services/notificationService.js` como defensa en profundidad: agregar `projectForRole(notice, role)` aplicada al final de `list` a todos los tipos, que para MECHANIC deja `detail` solo con folio, vehículo y estado y elimina cualquier nombre de cliente o teléfono, y que descarta cualquier aviso cuyo tipo no esté en `typesForRole(role)`; el filtro por mecánico asignado ya lo hizo T055
- [X] T060 [P] [US5] Verificar en `client/lib/providers/navigation_provider.dart` y `client/lib/widgets/app_shell.dart` que `AppSection.clientNotices` no se ofrece al mecánico y que el panel de notificaciones no pide datos que su rol no recibe

**Punto de control**: el mecánico solo ve lo suyo, validado en el servidor

---

## Fase 10: Pulido y asuntos transversales

**Propósito**: datos de ejemplo, rendimiento, documentación, regresión y cierre

- [X] T061 [P] Crear `database/seeds/006_notices.sql` (idempotente, fechas relativas a `CURDATE()`, sin llamar a servicios externos, sin editar seeds anteriores): al menos un mantenimiento próximo y uno vencido, una cita de hoy y una de mañana, una refacción con stock bajo y otra agotada (reutilizar las existentes si cumplen), una orden abierta con más de 3 días sin cambio de estado, una orden Terminada sin entregar y un aviso a cliente ya registrado; aplicarlo con `database/scripts/aplicar-seeds.ps1` en `motorix` y `motorix_test`
- [X] T062 [P] Prueba de datos de ejemplo `server/tests/integration/seed.notices.test.js`: tras correr el seed dos veces no se duplican filas y cada tipo de aviso y cada motivo de la lista de clientes por avisar tiene al menos un caso (usa `runSeedFile` de `server/tests/helpers/seed.js`)
- [X] T063 [P] Prueba de rendimiento `server/tests/integration/notifications.performance.test.js` (SC-007): con 1 000 órdenes, 1 000 citas y 1 000 mantenimientos, `GET /api/notifications` responde en menos de 2 segundos para administrador y recepción, y devuelve el total real con máximo 50 avisos por tipo
- [X] T064 [P] Verificar que el sistema no envía mensajes al cliente (SC-006): revisar que `server/package.json` y `client/pubspec.yaml` no tienen dependencias de mensajería (correo, SMS o WhatsApp) y que ninguna ruta o servicio nuevo hace llamadas externas; anotar el resultado en el documento de aseguramiento
- [X] T065 [P] Actualizar `docs/project-context.md`: §6.12 con el centro de notificaciones y la lista de clientes por avisar (tipos, roles, regla de 3 días), y las rutas `/notifications` y `/client-notices`, las tablas `notification_reads` y `client_notices` y la sección «Clientes por avisar» (FR-024)
- [X] T066 [P] Actualizar `docs/design-system.md` (FR-024): sección 7 («Header») con la campana y el panel, y una sección nueva «Notificaciones y avisos a clientes (Sprint 6)» con los tipos, los colores, los estados, la insignia «99+» y la tabla de clientes por avisar
- [ ] T067 Ejecutar la regresión completa: `npm test` en `server/` y `flutter test` en `client/`; deben pasar todas las pruebas de la línea base de T001 más las nuevas, salvo las que deban actualizarse por cambios declarados en la especificación (cada una se registra en el documento de aseguramiento)
- [ ] T068 Completar `docs/aseguramiento-calidad-sprint-6.md` (y `.docx` si el proceso lo pide): línea base, regresión, matriz final con una prueba por criterio de aceptación del insumo (CA-1 a CA-14) y por requisito (FR-001 a FR-025), capturas de la aplicación (campana, panel, clientes por avisar), tiempos de SC-001, SC-005, SC-007 y SC-009, riesgos R-01 a R-11 de plan.md y aprobación
- [ ] T069 Ejecutar el recorrido manual de `quickstart.md` (secciones 4 a 7) con los datos de ejemplo y anotar el resultado en el documento de aseguramiento

---

## Dependencias y orden de ejecución

### Dependencias entre fases

- **Fase 1 (T001 y T002)**: sin dependencias; T002 es una puerta que requiere la aprobación del responsable del proyecto
- **Fase 2 (T003 a T014)**: depende de T001 y T002; BLOQUEA todas las historias
- **Fase 3 (US1)**: depende de la fase 2; crea `notificationService`, la ruta, el proveedor, la campana y el panel que usan las demás historias
- **Fases 4 a 9**: dependen de la fase 3 en lo que comparten (`notificationService.js`, `notifications_panel.dart`, `notifications_test.dart`); la fase 6 (US7) comparte solo `noticeModel.js` (que crea la primera historia que lo necesita: T027, T041 o T054) y puede ir en paralelo con las fases 4, 5, 7, 8 y 9 si se coordinan esos archivos; la fase 9 (US5) solo agrega pruebas y la defensa en profundidad de T059, porque el filtro por mecánico se hace desde T055
- **Fase 5 (US6)** depende de que exista al menos un tipo de aviso (lo da US1)
- **Fase 10**: depende de las historias que se vayan a entregar; T061 a T063 necesitan todos los tipos de aviso

### Dentro de cada historia

- Las pruebas se escriben primero y deben fallar antes de implementar
- Modelos → servicios → controladores y rutas → cliente (servicio, proveedor, pantalla) → integración
- Ninguna tarea se da por terminada mientras sus pruebas no pasen

### Oportunidades de ejecución en paralelo

- Fase 2: T006 a T014 son independientes entre sí (archivos distintos) tras T003 a T005
- Dentro de cada historia: las pruebas marcadas [P] se pueden escribir en paralelo; el backend y el cliente de una historia pueden avanzar a la vez cuando el contrato está fijado (`contracts/`)
- Fase 10: T061 a T066 son independientes

---

## Ejemplo de ejecución en paralelo: Historia 1

```text
T015  integración notifications.flow
T016  contrato notifications
T017  pruebas del cliente (proveedor, campana y panel)
      -> luego: T018 servicio -> T019 ruta;  T020 servicio del cliente -> T021 proveedor -> T022 y T023 -> T024 integración
```

---

## Estrategia de implementación

### Primero el valor mínimo (historia 1)

1. Fases 1 y 2 (preparación, puerta de la constitución y fundamentos).
2. Fase 3 (US1): campana y panel con el tipo de referencia.
3. **Detenerse y validar**: ver la campana, abrir el panel, los tres estados y la actualización cada 60 segundos.

### Entrega incremental

1. Fases 1 y 2 → base lista.
2. US1 → campana y panel (MVP).
3. US2 → avisos de recepción.
4. US6 → leído y abrir el módulo.
5. US7 → clientes por avisar.
6. US3, US4 y US5 → stock, órdenes detenidas y mecánico.
7. Fase 10 → seeds, rendimiento, documentación y aseguramiento.

### Si el tiempo se acorta

El Sprint 6 tiene 5 días planificados (20 al 24 de noviembre). El orden de prioridad es US1, US2, US6 y US7 (P1); US3, US4 y US5 (P2) pueden quedar al final. La fase 10 (datos de ejemplo, documentación y aseguramiento) no se omite.

### Notas

- [P] = archivos distintos y sin dependencias pendientes
- Cada historia se puede completar y probar de forma independiente
- Hacer commit después de cada tarea o grupo lógico (Conventional Commits, tipo y alcance en inglés y descripción en español)
- Los criterios del insumo (CA-1 a CA-14) se cubren así: CA-1 a CA-3 con US1, US2, US3 y US4; CA-4 con US5; CA-5 con US2 y US3; CA-6 y CA-7 con US6; CA-8 con US3; CA-9 con US1; CA-10 y CA-11 con US7; CA-12 con T061 y T062; CA-13 con las pruebas de cada historia; CA-14 con T065 y T066
