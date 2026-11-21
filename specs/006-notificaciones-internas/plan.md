# Plan de implementación: Notificaciones internas y clientes por avisar (Sprint 6)

**Rama**: `006-notificaciones-internas` | **Fecha**: 2026-11-20 | **Especificación**: [spec.md](./spec.md)

**Entrada**: Especificación de la funcionalidad en `specs/006-notificaciones-internas/spec.md`

## Resumen

Cada usuario ve en el encabezado una campana con los avisos que le corresponden por su rol (mantenimientos
próximos y vencidos, citas del día, stock bajo o agotado y órdenes detenidas), calculados al consultar con los
mismos cálculos del panel, de la lista de Mantenimientos y de las alertas de stock. Puede marcarlos como leídos y
abrir la pantalla relacionada. Además, la recepción tiene una lista de «Clientes por avisar» (vehículo listo,
cita de mañana, mantenimiento próximo o vencido) con teléfono, y marca cada uno como avisado; el sistema solo lo
registra y no envía ningún mensaje.

Enfoque técnico (detalle en [research.md](./research.md)): se reutilizan la pila y las capas de los sprints
anteriores, sin dependencias nuevas. La migración `006` es aditiva y crea solo dos tablas: `notification_reads`
(lectura por usuario) y `client_notices` (avisos a clientes, con unicidad por motivo y hecho). Los avisos no se
guardan: `notificationService` los compone llamando a `maintenanceService.list`, `partService.alerts` y a dos
consultas nuevas (citas de hoy y órdenes detenidas), y filtra por rol en el servidor. Las reglas nuevas viven en
un módulo puro y probado (`noticeRules`: orden detenida con más de 3 días, claves de aviso y motivos). El cliente
agrega un proveedor con actualización cada 60 segundos, la campana en el encabezado, un panel con estados de
carga, vacío y error, y la sección «Clientes por avisar».

## Contexto técnico

**Lenguaje/Versión**: JavaScript (ES Modules) sobre Node.js (≥ 20) en el backend; Dart con Flutter en el
frontend; SQL para MySQL 8.0 (sin cambios respecto a los sprints anteriores)

**Dependencias principales**:
- Backend: ninguna nueva (`express`, `mysql2`, `jsonwebtoken`, `bcryptjs`, `zod`, `cors`, `helmet`, `dotenv`).
- Frontend: ninguna nueva (`provider`, `http`, `google_fonts`, `data_table_2`, `printing`, `url_launcher`).
- Pruebas: `jest`, `supertest` (backend); `flutter_test` (frontend).

**Almacenamiento**: MySQL 8.0 local, InnoDB, `utf8mb4`; bases `motorix` y `motorix_test`; usuario dedicado
`motorix_app`. Nueva migración `database/migrations/006_sprint6_notices.sql` y nuevo seed
`database/seeds/006_notices.sql`. Sin variables de entorno nuevas.

**Pruebas**: Jest (unitarias de `noticeRules`), Jest + supertest (integración y contrato contra `motorix_test`:
permisos por rol, lectura por usuario, claves, concurrencia y rendimiento); `flutter test` (modelos, proveedor
con temporizador controlado, campana, panel y sección). Línea base: la última cifra documentada es 1 215 pruebas
de backend y 321 de frontend; se mide de nuevo en la primera tarea.

**Plataforma objetivo**: Aplicación de escritorio (Windows como principal) que consume la API REST local;
interfaz responsiva con prioridad en escritorio

**Tipo de proyecto**: Aplicación web/escritorio con API (frontend + backend + persistencia)

**Metas de rendimiento**: `GET /api/notifications` responde en menos de 2 segundos con 1 000 órdenes, 1 000
citas y 1 000 mantenimientos (SC-007); la campana refleja un aviso nuevo en un máximo de 60 segundos (SC-009)

**Restricciones**: ES Modules obligatorio en el backend; solo el backend accede a la base de datos; permisos
validados en el backend (el stock no se devuelve a recepción ni al mecánico; el mecánico no recibe teléfonos ni
la lista de clientes); no se editan scripts de sprints anteriores; sin mensajería al cliente por ningún canal;
sin tiempo real por empuje; seeds idempotentes; cumplimiento de `docs/design-system.md`

**Escala/Alcance**: 3 roles, 2 tablas nuevas, 4 rutas (consultar y marcar avisos, consultar y registrar clientes por avisar), 1
sección de menú nueva, 1 panel en el encabezado, cambios mínimos en la navegación y en el refresco tras
movimientos de inventario

## Verificación de la constitución

*PUERTA: debe pasar antes de la Fase 0. Se vuelve a verificar tras el diseño de la Fase 1.*

| Principio | Evaluación | Cómo se cumple |
|-----------|------------|----------------|
| I. Alcance, MVP y fuente de verdad | PASA, con una puerta | Sprint posterior al MVP: lo permite la enmienda 1.1.0 (insumo en `docs/sprints/sprint-6-notificaciones-internas.md`, flujo de Spec Kit y documento de aseguramiento). El principio exige además la aprobación registrada del responsable del proyecto para cada sprint: la tarea T002 la registra en la constitución (versión 1.1.1) y bloquea el inicio de los fundamentos. El chatbot y la mensajería quedan fuera (FR-019). Se actualiza `docs/project-context.md` (FR-024) |
| II. Arquitectura separada | PASA | `client/`, `server/`, `database/`; la lógica vive en `services/` y en el módulo puro `noticeRules`; controladores delgados; sin integraciones nuevas |
| III. Stack y base local | PASA | Mismo stack; migración numerada nueva y aditiva; InnoDB, llaves foráneas, `utf8mb4`; seeds idempotentes con datos suficientes. Sin dependencias nuevas |
| IV. Seguridad | PASA | Rutas con `authenticate` + `authorize`; el filtrado por rol ocurre en el servicio; validación `zod` de claves, motivos e identificadores; el teléfono solo en `/client-notices` para ADMIN y RECEPTIONIST; ninguna traza al usuario; sin secretos |
| V. Reglas de negocio | PASA | RN-5 (solo autorizados), RN-8 (el aviso de stock parte de las alertas ya calculadas), RN-10 (los avisos se derivan, no se duplican), RN-11 (mantenimientos por fecha o kilometraje), RN-15 (permisos en el servidor); no se toca ninguna orden, pago ni inventario |
| VI. API consistente | PASA | Misma forma `{ data, meta }` / `{ error }`, códigos HTTP y manejo central; contrato en [contracts/api-rest.md](./contracts/api-rest.md) |
| VII. Pruebas | PASA | Unitarias de las reglas, integración y contrato contra `motorix_test` (permisos, lectura por usuario, concurrencia, rendimiento), regresión de los sprints 1 a 5 y `flutter test`; la historia no se da por terminada solo con la interfaz |
| VIII. UX/UI | PASA | Material 3 con el tema propio y tokens; colores ámbar, rojo y verde por convención; confirmación al marcar como avisado; estados de carga, vacío y error; sin dependencias de UI nuevas; se actualiza `docs/design-system.md` |

**Reevaluación tras la Fase 1**: PASA. El diseño no agrega dependencias ni capas nuevas; las dos tablas son lo
mínimo para guardar la lectura y los avisos a clientes (lo único que el spec obliga a persistir).

## Estructura del proyecto

### Documentación (esta funcionalidad)

```text
specs/006-notificaciones-internas/
├── spec.md              # Especificación (/speckit-specify y /speckit-clarify)
├── plan.md              # Este archivo (/speckit-plan)
├── research.md          # Fase 0: decisiones y alternativas
├── data-model.md        # Fase 1: tablas, claves de aviso, reglas y estados
├── quickstart.md        # Fase 1: guía de validación de extremo a extremo
├── contracts/
│   ├── api-rest.md      # Contrato de la API (notificaciones y clientes por avisar)
│   └── interfaz.md      # Contrato de las pantallas (campana, panel y sección nueva)
├── checklists/
│   └── requirements.md  # Calidad de la especificación
└── tasks.md             # Fase 2 (/speckit-tasks, aún no se crea)
```

### Código fuente (raíz del repositorio)

```text
database/
├── migrations/006_sprint6_notices.sql             # nuevo: notification_reads y client_notices
└── seeds/006_notices.sql                          # nuevo: un caso de cada aviso y de cada motivo

server/
├── models/
│   ├── noticeModel.js          # nuevo: citas de hoy y de mañana, órdenes detenidas, órdenes terminadas
│   ├── notificationReadModel.js# nuevo: lecturas por usuario (INSERT IGNORE)
│   └── clientNoticeModel.js    # nuevo: avisos a clientes y hechos pendientes
├── services/
│   ├── noticeRules.js          # nuevo: orden detenida (3 días), claves de aviso y motivos (módulo puro)
│   ├── notificationService.js  # nuevo: compone los avisos por rol y marca la lectura
│   └── clientNoticeService.js  # nuevo: lista de clientes por avisar y registro idempotente
├── controllers/
│   ├── notificationController.js   # nuevo
│   └── clientNoticeController.js   # nuevo
├── routes/
│   ├── notificationRoutes.js   # nuevo: GET /notifications, POST /notifications/read
│   ├── clientNoticeRoutes.js   # nuevo: GET y POST /client-notices
│   └── index.js                # monta las dos rutas
├── validators/
│   └── noticeValidators.js     # nuevo: claves, motivo e identificador del hecho
└── tests/
    ├── unit/                   # noticeRules
    ├── integration/            # notificaciones por rol, lectura, clientes por avisar, concurrencia,
    │                           # rendimiento y seeds
    └── contract/               # notifications y client-notices

client/
├── lib/
│   ├── models/                 # notice.dart (avisos), client_notice.dart
│   ├── services/               # notifications_service.dart, client_notices_service.dart
│   ├── providers/              # notifications_provider.dart (temporizador de 60 s),
│   │                           # client_notices_provider.dart, navigation_provider.dart
│   ├── screens/                # client_notices_screen.dart
│   ├── widgets/                # notification_bell.dart, notifications_panel.dart, app_shell.dart
│   └── main.dart               # registra los proveedores nuevos
└── test/                       # notifications, client_notices, app_shell y navegación

docs/
├── project-context.md          # sección 6.12 y las rutas, tablas y roles que cambian
├── design-system.md            # header (sección 7) y nueva sección de notificaciones
└── aseguramiento-calidad-sprint-6.md  # nuevo: línea base, regresión, matriz final y aprobación

.specify/memory/constitution.md    # registro de la aprobación del Sprint 6 (versión 1.1.1, tarea T002)
```

**Decisión de estructura**: se conserva la estructura de los sprints anteriores. Las únicas piezas nuevas de
lógica son `noticeRules.js` (puro) y los dos servicios; no se agregan capas ni dependencias.

## Cobertura de riesgos

| Riesgo | Cómo lo cubre el diseño | Prueba |
|--------|-------------------------|--------|
| R-01 un rol recibe avisos que no le corresponden | el servicio decide los tipos por rol y no ejecuta las consultas de stock para recepción ni mecánico | integración y contrato con los tres roles, incluido el acceso directo a la API |
| R-02 los números difieren del panel | el centro llama a `maintenanceService.list` y `partService.alerts`, los mismos del panel | integración que compara los totales del centro con los del panel y con la lista de Mantenimientos |
| R-03 una lectura vieja oculta un aviso nuevo | la clave cambia al empeorar (de próximo a vencido) y al reiniciarse la detención (último id del historial) | integración de reaparición |
| R-04 dos personas marcan lo mismo a la vez | llave primaria y `UNIQUE (reason, fact_id)` con `INSERT IGNORE`; la segunda respuesta es 200 | integración de concurrencia |
| R-05 se avisa de un hecho que ya no existe | el servidor verifica la condición al registrar y responde 409 `NOTICE_NOT_APPLICABLE` | integración |
| R-06 el teléfono llega al mecánico | solo existe en `/client-notices`, que exige ADMIN o RECEPTIONIST; los avisos del mecánico no traen cliente | contrato por rol |
| R-07 la consulta se vuelve lenta | consultas acotadas con índices existentes, máximo 50 avisos por tipo y conteos reales | prueba de rendimiento con 1 000 filas por tabla |
| R-08 el temporizador sigue vivo tras cerrar sesión | el proveedor cancela el `Timer` al limpiar la sesión y al destruirse | prueba del proveedor con tiempo simulado |
| R-09 la insignia de Inventario se contradice con el centro | `StockAlertsProvider` no cambia y ambos usan `partService.alerts()`; tras un movimiento se refrescan los dos | prueba de integración de pantalla |
| R-10 se rompe un sprint anterior | la migración es aditiva y no se toca ninguna tabla ni ruta existente | regresión completa de los sprints 1 a 5 |
| R-11 documentación desfasada | tareas de documentación del sprint (FR-024) | revisión en el cierre |

## Seguimiento de complejidad

Sin violaciones de la constitución que justificar.
