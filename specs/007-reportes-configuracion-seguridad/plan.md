# Plan de implementación: Reportes, configuración, términos y seguridad (Sprint 7)

**Rama**: `007-reportes-configuracion-seguridad` | **Fecha**: 2026-11-21 | **Especificación**: [spec.md](./spec.md)

**Entrada**: Especificación de la funcionalidad en `specs/007-reportes-configuracion-seguridad/spec.md`

## Resumen

El administrador configura desde la aplicación los datos del taller y los márgenes de «Próximo», mantiene un catálogo de
tipos de servicio con intervalos (que propone el próximo mantenimiento y lo muestra en el ticket) y consulta y exporta a
Excel (con el diseño de Motorix) reportes de ingresos, servicios, productividad, refacciones y rotación. Todo usuario acepta los términos y condiciones y
el aviso de privacidad al ingresar, y la información queda protegida con una bitácora de solo inserción, contraseñas de al
menos 10 caracteres, cierre de sesión por inactividad validado en el servidor y pruebas de no exposición de datos y de
inyección.

Enfoque técnico (detalle en [research.md](./research.md)): se reutilizan la pila y las capas de los sprints anteriores, con **una sola
dependencia nueva** (`exceljs`, para el libro de Excel). La migración `007` es aditiva: cinco tablas nuevas (`settings`, `service_types`, `terms_versions`,
`terms_acceptances` y `audit_log`) y dos columnas nulas (`order_services.service_type_id` y `users.last_activity_at`).
`settingsService` lee la configuración bajo demanda (guardado → `.env` → predeterminado) y `presentMaintenance` recibe los
márgenes como parámetro. Las reglas nuevas viven en módulos puros y probados (`reportRules`, `serviceIntervals`); los
reportes son agregados SQL en centavos enteros. `authenticate` valida la aceptación de términos y la inactividad en cada
petición. La bitácora se escribe con `auditService` después de cada acción sensible. El ticket nuevo lleva `formatVersion: 3`
con «Próximo servicio»; los anteriores no cambian. El cliente agrega las secciones Reportes, Configuración, Bitácora y
Términos, la pantalla de aceptación y el guardián de inactividad, y guarda el Excel con `dart:io`.

## Contexto técnico

**Lenguaje/Versión**: JavaScript (ES Modules) sobre Node.js (≥ 20) en el backend; Dart con Flutter en el frontend; SQL para
MySQL 8.0 (sin cambios respecto a los sprints anteriores)

**Dependencias principales**:
- Backend: una nueva, `exceljs` (libro de Excel con logo, colores y formatos; decisión de la persona responsable del 2026-11-21). Las demás sin cambio (`express`, `mysql2`, `jsonwebtoken`, `bcryptjs`, `zod`, `cors`, `helmet`, `dotenv`).
- Frontend: ninguna nueva (`provider`, `http`, `google_fonts`, `data_table_2`, `fl_chart`, `printing`, `url_launcher`).
- Pruebas: `jest`, `supertest` (backend); `flutter_test` (frontend).

**Almacenamiento**: MySQL 8.0 local, InnoDB, `utf8mb4`; bases `motorix` y `motorix_test`; usuario dedicado `motorix_app`. Nueva
migración `database/migrations/007_sprint7_settings_terms_audit.sql` (incluye la versión `1.0` de los términos) y nuevo seed
`database/seeds/007_settings_service_types.sql`. Sin variables de entorno nuevas; `SHOP_*` y `MAINTENANCE_WARN_*` quedan como
valor de respaldo.

**Pruebas**: Jest (unitarias de `reportRules`, `serviceIntervals` y la política de contraseñas), Jest + supertest
(integración y contrato contra `motorix_test`: configuración, catálogo, ticket, términos, bitácora, sesión, reportes,
exposición de datos e inyección, permisos por rol, concurrencia y rendimiento); `flutter test` (modelos, proveedores y
pantallas, con tiempo controlado para la inactividad). Línea base: 1 349 pruebas de backend y 373 de frontend del 2026-11-20.

**Plataforma objetivo**: Aplicación de escritorio (Windows como principal) que consume la API REST local; interfaz responsiva con
prioridad en escritorio

**Tipo de proyecto**: Aplicación web/escritorio con API (frontend + backend + persistencia)

**Metas de rendimiento**: cada reporte responde en menos de 3 segundos con 1 000 pagos y 1 000 órdenes con sus refacciones
(SC-006); `authenticate` suma dos consultas indexadas por petición (aceptación de términos y actividad) y una escritura como
máximo por minuto

**Restricciones**: ES Modules obligatorio en el backend; solo el backend accede a la base de datos; permisos validados en el
backend (configuración, catálogo, reportes y bitácora solo ADMIN; aceptación de términos exigida a toda ruta autenticada); no
se editan scripts de sprints anteriores; importes en centavos enteros; sin datos reservados en respuestas ni en la bitácora;
sin cifrado de la base, respaldos, HTTPS ni despliegue; cumplimiento de `docs/design-system.md`

**Escala/Alcance**: 3 roles, 5 tablas nuevas y 2 columnas nuevas, 16 rutas nuevas, 4 secciones de menú y 2 pantallas
transversales nuevas, cambios en servicios de la orden, programar mantenimiento, ticket, usuarios y cambio de contraseña

## Verificación de la constitución

*PUERTA: debe pasar antes de la Fase 0. Se vuelve a verificar tras el diseño de la Fase 1.*

| Principio | Evaluación | Cómo se cumple |
|-----------|------------|----------------|
| I. Alcance, MVP y fuente de verdad | PASA | Sprint posterior al MVP: lo permite la enmienda 1.1.0 y la aprobación del Sprint 7 quedó registrada el 2026-11-21 (versión 1.1.2, «Decisiones resueltas durante el Sprint 7»). Insumo en `docs/sprints/sprint-7-reportes-configuracion.md`, flujo de Spec Kit y documento de aseguramiento. Sin mensajería al cliente. Se actualiza `docs/project-context.md` (FR-031) |
| II. Arquitectura separada | PASA | `client/`, `server/`, `database/`; la lógica vive en `services/` y en los módulos puros `reportRules` y `serviceIntervals` y el generador `reportWorkbook`; controladores delgados; sin integraciones nuevas |
| III. Stack y base local | PASA | Mismo stack; migración numerada nueva y aditiva; InnoDB, llaves foráneas, `utf8mb4`; seeds idempotentes con datos suficientes. **Una dependencia nueva aprobada por la persona responsable: `exceljs`** (Excel con diseño de Motorix); el cliente guarda el archivo con `dart:io` |
| IV. Seguridad | PASA | Rutas con `authenticate` + `authorize`; validación `zod`; bitácora sin datos reservados; aceptación de términos e inactividad validadas en el servidor; contraseñas con hash y política de 10 caracteres; el precio de compra solo en el reporte de ADMIN; los textos del Excel se escriben como texto y nunca como fórmulas; pruebas de no exposición e inyección; ninguna traza al usuario |
| V. Reglas de negocio | PASA | RN-5 (solo autorizados), RN-9 (órdenes entregadas se conservan; los reportes solo leen), RN-10 (los reportes se derivan, no se duplican), RN-11 y RN-12 (los intervalos y márgenes son configurables, sin valores universales), RN-14 y RN-15 (sin datos sensibles y permisos en el servidor) |
| VI. API consistente | PASA | Misma forma `{ data, meta }` / `{ error }`, códigos HTTP y manejo central; contrato en [contracts/api-rest.md](./contracts/api-rest.md) (la exportación a Excel es la única respuesta que no es JSON) |
| VII. Pruebas | PASA | Unitarias de las reglas puras, integración y contrato contra `motorix_test` (permisos, términos, bitácora, sesión, reportes, exposición, inyección, concurrencia, rendimiento), regresión de los sprints 1 a 6 y `flutter test`; los cambios de contrato declarados (contraseña de 10 caracteres, aceptación de términos) actualizan pruebas y se registran en el aseguramiento |
| VIII. UX/UI | PASA | Material 3 con el tema propio y tokens; chip ámbar «Sin costo»; confirmación al desactivar un tipo de servicio; estados de carga, vacío y error; diálogo de inactividad accesible; sin dependencias de UI nuevas; se actualiza `docs/design-system.md` |

**Reevaluación tras la Fase 1**: PASA. El diseño agrega solo `exceljs` y ninguna capa nueva; las tablas y columnas son lo mínimo
que el spec obliga a persistir (configuración, catálogo, términos, aceptaciones, bitácora y actividad).

## Estructura del proyecto

### Documentación (esta funcionalidad)

```text
specs/007-reportes-configuracion-seguridad/
├── spec.md              # Especificación (/speckit-specify y /speckit-clarify)
├── plan.md              # Este archivo (/speckit-plan)
├── research.md          # Fase 0: decisiones y alternativas
├── data-model.md        # Fase 1: tablas, columnas, reportes y reglas
├── quickstart.md        # Fase 1: guía de validación de extremo a extremo
├── contracts/
│   ├── api-rest.md      # Contrato de la API (configuración, catálogo, reportes, términos y bitácora)
│   └── interfaz.md      # Contrato de las pantallas
├── checklists/
│   └── requirements.md  # Calidad de la especificación
└── tasks.md             # Fase 2 (/speckit-tasks, aún no se crea)
```

### Código fuente (raíz del repositorio)

```text
database/
├── migrations/007_sprint7_settings_terms_audit.sql   # nuevo: 5 tablas, 2 columnas y los términos 1.0
└── seeds/007_settings_service_types.sql              # nuevo: configuración inicial y tipos de servicio

server/
├── config/
│   └── security.js                 # nuevo: INACTIVITY_MINUTES = 30 y constantes de sesión
├── models/
│   ├── settingsModel.js            # nuevo
│   ├── serviceTypeModel.js         # nuevo
│   ├── termsModel.js               # nuevo: versiones y aceptaciones
│   ├── auditLogModel.js            # nuevo: solo inserción y consulta
│   ├── reportModel.js              # nuevo: agregados de lectura
│   ├── userModel.js                # actividad de la sesión
│   └── orderWorkModel.js           # service_type_id en las líneas de servicio
├── services/
│   ├── settingsService.js          # nuevo: guardado → .env → predeterminado
│   ├── serviceTypeService.js       # nuevo
│   ├── serviceIntervals.js         # nuevo (puro): propuesta del próximo mantenimiento
│   ├── termsService.js             # nuevo
│   ├── auditService.js             # nuevo: registra sin datos reservados
│   ├── reportRules.js              # nuevo (puro): rango, extremos y centavos
│   ├── reportService.js            # nuevo
│   ├── reportWorkbook.js           # nuevo: libro de Excel con el diseño de Motorix (assets/logo.png)
│   ├── maintenancePresenter.js     # recibe los márgenes como parámetro
│   ├── maintenanceService.js       # márgenes guardados; propuesta
│   ├── clientNoticeService.js      # márgenes guardados
│   ├── ticketContent.js            # formatVersion 3 con nextService
│   ├── ticketService.js            # taller guardado y próximo servicio
│   ├── orderWorkService.js         # tipo de servicio de la línea
│   ├── orderService.js / vehicleHistoryService.js   # márgenes guardados
│   ├── userService.js / authService.js              # contraseña de 10 y bitácora
│   ├── partService.js / paymentService.js           # bitácora (actor)
├── middlewares/
│   └── authenticate.js             # aceptación de términos e inactividad
├── controllers/                    # settings, serviceType, report, terms, auditLog (nuevos)
├── routes/                         # settingsRoutes, serviceTypeRoutes, reportRoutes, termsRoutes, auditLogRoutes + index.js
├── validators/                     # settingsValidators, serviceTypeValidators, reportValidators, termsValidators, auditValidators
├── utils/passwordPolicy.js         # mínimo de 10 caracteres
└── tests/
    ├── unit/                       # serviceIntervals, reportRules, passwordPolicy
    ├── integration/                # settings, serviceTypes, ticket, terms, audit, session, reports, dataExposure, injection, seeds, performance
    ├── contract/                   # settings, serviceTypes, reports, terms, audit
    └── helpers/factories.js        # createUser acepta los términos; resetDatabase conserva terms_versions

client/
├── lib/
│   ├── models/                     # settings.dart, service_type.dart, report.dart, terms.dart, audit_entry.dart
│   ├── services/                   # settings_service, service_types_service, reports_service, terms_service, audit_service
│   ├── providers/                  # settings_provider, service_types_provider, reports_provider, terms_provider,
│   │                               # audit_provider, session_provider (términos), navigation_provider (4 secciones)
│   ├── screens/                    # settings_screen, reports_screen, audit_log_screen, terms_admin_screen, terms_accept_screen
│   ├── widgets/                    # inactivity_guard, period_selector, maintenance_dialog, ticket_view, app_shell
│   │                               # (el diálogo de líneas está en screens/order_detail_screen.dart)
│   ├── utils/                      # file_saver.dart, password_policy.dart, ticket_printer.dart
│   └── main.dart                   # registra los proveedores y la pantalla de aceptación
└── test/                           # settings, service_types, reports, terms, audit_log, inactivity y los helpers (fake_api)

docs/
├── project-context.md              # configuración, reportes, términos, seguridad y entidades
├── design-system.md                # sección nueva del Sprint 7
└── aseguramiento-calidad-sprint-7.md   # nuevo: línea base, regresión, matriz final y aprobación

.env.example                        # SHOP_* y MAINTENANCE_WARN_* como valor de respaldo
```

**Decisión de estructura**: se conserva la estructura de los sprints anteriores. Las piezas nuevas de lógica son los módulos
puros `reportRules` y `serviceIntervals`, el generador `reportWorkbook` y los servicios de cada tema; no se agregan capas y la única dependencia nueva es `exceljs`.

## Cobertura de riesgos

| Riesgo | Cómo lo cubre el diseño | Prueba |
|--------|-------------------------|--------|
| R-01 un cambio de configuración altera un ticket emitido | el ticket guarda su instantánea; la configuración solo alimenta tickets nuevos | integración: cambiar el taller y comparar un ticket anterior |
| R-02 los márgenes no coinciden entre pantallas | los tres consumidores (lista, panel y avisos) leen `settingsService.getMaintenanceMargins()` | integración que compara los tres con un margen nuevo |
| R-03 los reportes no cuadran con los pagos | agregados en centavos enteros sobre las mismas tablas y comprobación de que las partes suman el total | integración con casos de pagos de todos los estados y métodos |
| R-04 el Excel difiere de la pantalla | el Excel sale de la misma función que el JSON | integración que compara ambos reporte por reporte |
| R-05 una celda con fórmula se ejecuta en la hoja de cálculo | los textos se escriben como cadenas de Excel (nunca como fórmulas) | integración `reports.xlsx` con un servicio llamado `=SUMA(1+1)` |
| R-06 el precio de compra llega a un rol sin permiso | reportes exclusivos de ADMIN y exposición de datos probada por rol | integración `dataExposure` y contrato de reportes |
| R-07 una ruta nueva olvida exigir la aceptación | la aceptación se valida dentro de `authenticate`, con una lista fija de excepciones | integración con una ruta por router y un usuario sin aceptar |
| R-08 se evade el cierre por inactividad | validación en el servidor con `last_activity_at` y el cliente solo avisa | integración de sesión con el reloj de la base ajustado |
| R-09 la bitácora guarda datos reservados | el `summary` se arma con campos permitidos y no se guarda el texto tecleado en un inicio de sesión fallido | integración que revisa todas las filas |
| R-10 la bitácora se puede alterar | no existen rutas ni servicios de edición o borrado | integración que prueba `PUT`, `PATCH` y `DELETE` (404) |
| R-11 una falla de la bitácora cancela una operación válida | `auditService.record` se llama después y no propaga errores | unitaria con una falla simulada |
| R-12 las pruebas anteriores fallan por los términos o la contraseña | los ayudantes de pruebas aceptan los términos y las contraseñas de prueba cumplen los 10 caracteres | regresión completa y registro en el aseguramiento |
| R-13 una consulta de reporte es lenta | agregados SQL con índices existentes, rango máximo de un año | prueba de rendimiento con 1 000 pagos y 1 000 órdenes |
| R-14 una inyección altera una búsqueda | consultas parametrizadas y `likePattern` | integración `injection` en todos los campos de búsqueda |
| R-15 la documentación queda desfasada | tareas de documentación del sprint (FR-031) | revisión en el cierre |

## Seguimiento de complejidad

Sin violaciones de la constitución que justificar.
