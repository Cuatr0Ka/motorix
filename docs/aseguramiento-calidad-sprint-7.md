# Aseguramiento de la calidad - Sprint 7: Reportes, configuración, términos y seguridad

Este documento es el registro de calidad del Sprint 7 de Motorix. Reúne las puertas de calidad, las decisiones, los riesgos, la trazabilidad de los criterios de aceptación, los hallazgos, la regresión de los sprints anteriores y el control de calidad final, con sus evidencias.

Resultado general: el sprint se aprobó con observaciones el 2026-11-21, con la aprobación expresa de la persona responsable. Todas las pruebas automáticas pasan (1 534 del servidor y 449 del cliente) y no hay defectos abiertos. Las observaciones son dos: la dependencia nueva `exceljs`, aprobada por la persona responsable al cambiar la exportación de CSV a Excel (el diseño del libro también quedó aprobado), y el recorrido manual con la interfaz gráfica, que la persona responsable completó el 2026-11-21 (las pantallas cargan en menos de 3 segundos y el flujo de aceptar los términos y entrar toma unos 40 segundos, dentro del límite de 1 minuto de SC-010). Durante el recorrido se corrigió H-07.

## 0. Datos del documento

| Campo | Valor |
|---|---|
| Sprint | 7 - Reportes, configuración, términos y seguridad |
| Insumo | `docs/sprints/sprint-7-reportes-configuracion.md` |
| Rama | `007-reportes-configuracion-seguridad` |
| Responsable | José Adrián Mendoza Hernández, responsable del proyecto |
| Fecha de inicio | 2026-11-21 |
| Fecha de cierre | 2026-11-21 |
| Estado general | Aprobado con observación |

## 1. Objetivo y alcance

**Objetivo.** Asegurar que el Sprint 7 salga con calidad: que los requisitos estén completos, sean medibles y no se contradigan, que las pruebas estén planeadas antes del código y que el cambio no rompa lo construido en los sprints anteriores.

**Dentro del alcance:** configuración del taller y de los márgenes de mantenimiento desde la aplicación, catálogo de tipos de servicio con intervalos, próximo servicio en el ticket, términos y condiciones con aviso de privacidad, bitácora de acciones sensibles, política de contraseñas de 10 caracteres, cierre de sesión por inactividad, reportes (ingresos, servicios, productividad, refacciones y rotación) y su exportación a Excel (.xlsx) con el diseño de Motorix.

**Fuera del alcance:** cifrado de la base en disco, respaldos, HTTPS y despliegue, autenticación de dos pasos, recuperación de contraseña por correo, gráficas avanzadas, impuestos y facturación electrónica, envío automático de reportes y mensajes al cliente.

## 2. Criterios de entrada y de salida

**Criterios de entrada (para comenzar la implementación):**

- [x] Las 8 puertas de la sección 3 están Aprobadas o Aprobadas con observación.
- [x] La enmienda a la constitución está aprobada y registrada (versión 1.1.2, hallazgo H-01).
- [x] Las decisiones de la sección 4 están resueltas y registradas.
- [x] No hay hallazgos críticos ni altos abiertos en el análisis de consistencia.
- [x] Cada criterio de aceptación tuvo al menos una prueba planeada (sección 6).
- [x] La línea base de regresión está registrada (sección 8).
- [x] La documentación desfasada de los sprints anteriores está identificada (`project-context.md`, `design-system.md` y `.env.example`).

**Criterios de salida (para cerrar el sprint):**

- [x] Los 26 criterios de aceptación están Aprobados (con la observación de CA-9 por el cambio a Excel).
- [x] Todas las pruebas de los sprints anteriores siguen pasando (con las actualizaciones declaradas en H-02).
- [x] No hay defectos críticos ni altos abiertos (sección 7).
- [x] La matriz de calidad final (sección 9) está completa.
- [x] Reporte, análisis y matriz no se contradicen.

## 3. Puertas de calidad

| ID | Puerta | Estado | Evidencia |
|:--:|---|---|---|
| G-01 | Insumo del sprint revisado contra el código | Aprobada | `docs/sprints/sprint-7-reportes-configuracion.md` ampliado con términos y seguridad antes de especificar |
| G-02 | Especificación (`/speckit.specify`) | Aprobada | `specs/007-reportes-configuracion-seguridad/spec.md` (10 historias, FR-001 a FR-032) |
| G-03 | Aclaraciones (`/speckit.clarify`) | Aprobada | D-01 a D-12 resueltas con la recomendación propia; sin marcadores `[NEEDS CLARIFICATION]` |
| G-04 | Lista de calidad de requisitos (`/speckit.checklist`) | Aprobada | `checklists/requirements.md`, todos los puntos marcados |
| G-05 | Plan (`/speckit.plan`) | Aprobada | `plan.md`, `research.md`, `data-model.md`, `contracts/` y `quickstart.md` |
| G-06 | Tareas (`/speckit.tasks`) | Aprobada | `tasks.md`, 94 tareas (T001 a T094) |
| G-07 | Consistencia (`/speckit.analyze`) | Aprobada | Inconsistencias corregidas y decisiones D-13 a D-18 registradas (commit `836abcd`) |
| G-08 | Pruebas planeadas y línea base | Aprobada | Pruebas antes del código en cada historia; línea base de la sección 8 |

## 4. Decisiones de aclaración

| ID | Decisión | Resolución | Requisito afectado |
|:--:|---|---|---|
| D-01 | Formato de exportación | **Excel (.xlsx) con el diseño de Motorix**, no CSV. Revisada el 2026-11-21 por la persona responsable; agrega `exceljs` (H-03) | FR-014 |
| D-02 | Términos y condiciones | Texto fijo versionado por el equipo (migración), sin editor en la aplicación | FR-018 a FR-022 |
| D-03 | Contraseñas e inactividad | 10 caracteres con mayúscula, minúscula y número; cierre a los 30 minutos con aviso a los 28 | FR-026, FR-027 |
| D-04 a D-12 | Orden de entrega, márgenes, intervalos, reportes, permisos, etc. | Confirmadas por omisión según la recomendación; ver `spec.md` | varios |
| D-13 a D-18 | Aclaraciones del análisis de consistencia | Registradas en el commit `836abcd` | varios |

## 5. Riesgos y mitigaciones

| ID | Riesgo | Impacto | Mitigación | Prueba que lo cubre | Estado |
|:--:|---|---|---|---|---|
| R-01 | Un cambio de configuración altera un ticket emitido | Alto: comprobantes inconsistentes | El ticket guarda su instantánea | `settings.flow.test.js` (ticket nuevo y anterior) | Mitigado |
| R-02 | Los márgenes no coinciden entre pantallas | Medio | Los consumidores leen `settingsService.getMaintenanceMargins()` | `settings.margins.test.js` | Mitigado |
| R-03 | Los reportes no cuadran con los pagos | Alto | Centavos enteros y comprobación de que las partes suman el total | `reports.income.test.js` | Mitigado |
| R-04 | El Excel difiere de la pantalla | Medio | El libro sale de la misma función de servicio que el JSON | `reports.xlsx.test.js` | Mitigado |
| R-05 | Una celda con fórmula se ejecuta | Medio | Los textos se escriben como cadenas de Excel | `reports.xlsx.test.js` (`=SUMA(1+1)`) | Mitigado |
| R-06 | El precio de compra llega a un rol sin permiso | Alto | Reportes solo ADMIN y pruebas de exposición | `dataExposure.test.js`, `reports.parts.test.js` | Mitigado |
| R-07 | Una ruta nueva olvida exigir la aceptación | Alto | Validación dentro de `authenticate` con lista fija | `terms.flow.test.js` | Mitigado |
| R-08 | Se evade el cierre por inactividad | Medio | Validación en el servidor con `last_activity_at` | `session.inactivity.test.js` | Mitigado |
| R-09 | La bitácora guarda datos reservados | Alto | Resúmenes sin datos tecleados y rechazo de cadenas reservadas | `audit.flow.test.js`, `auditService.test.js` | Mitigado |
| R-10 | La bitácora se puede alterar | Alto | Sin rutas ni servicios de edición o borrado | `audit.flow.test.js` (404 en POST, PUT, PATCH y DELETE) | Mitigado |
| R-11 | Una falla de la bitácora cancela una operación válida | Medio | `auditService.record` no propaga errores | `auditService.test.js` | Mitigado |
| R-12 | Las pruebas anteriores fallan por términos o contraseña | Medio | Ayudantes de prueba y contraseñas de 10 caracteres | Regresión completa (H-02) | Mitigado |
| R-13 | Una consulta de reporte es lenta | Medio | Agregados SQL y rango máximo de un año | `reports.performance.test.js` (menos de 3 s con 1 000 pagos y 1 000 órdenes) | Mitigado |
| R-14 | Una inyección altera una búsqueda | Alto | Consultas parametrizadas y `likePattern` | `injection.test.js` | Mitigado |
| R-15 | La documentación queda desfasada | Bajo | Tareas de documentación | `project-context.md`, `design-system.md`, `.env.example` | Mitigado |

## 6. Trazabilidad

| CA | Criterio de aceptación (resumen) | Requisito | Tarea | Prueba | Resultado |
|:--:|---|---|---|---|---|
| CA-1 | Datos del taller editables; tickets nuevos los usan y los emitidos no cambian | FR-001, FR-002 | T011 a T015 | `settings.flow.test.js`, `settings_test.dart` | Aprobado |
| CA-2 | Márgenes de «Próximo» editables y respetados en lista, panel y avisos | FR-004 | T018, T019 | `settings.margins.test.js` | Aprobado |
| CA-3 | Sin valor guardado se usan `.env` o los predeterminados | FR-003 | T011 | `settings.flow.test.js`, `settings.margins.test.js` | Aprobado |
| CA-4 | Catálogo de tipos de servicio sin borrado | FR-005, FR-006 | T026 a T028 | `serviceTypes.flow.test.js` | Aprobado |
| CA-5 | Próximo mantenimiento propuesto y corregible | FR-007 | T025, T029, T032 | `serviceIntervals.test.js`, `serviceTypes.suggestion.test.js`, `service_types_test.dart` | Aprobado |
| CA-6 | Reportes por rango de fechas | FR-009 a FR-012 | T067 a T079 | `reports.*.test.js`, `reports_test.dart` | Aprobado |
| CA-7 | Importes en centavos enteros que coinciden con su origen | FR-013 | T067, T068 | `reportRules.test.js`, `reports.income.test.js` | Aprobado |
| CA-8 | Costo, precio y margen; precio de compra solo para ADMIN | FR-011 | T078 | `reports.parts.test.js`, `dataExposure.test.js` | Aprobado |
| CA-9 | Cada reporte se exporta y coincide con la pantalla | FR-014 | T083, T084 | `reports.xlsx.test.js`, `reports_test.dart`, `file_saver_test.dart` | Aprobado con observación: se exporta a **Excel** y no a CSV (D-01 revisada, H-03) |
| CA-10 | Configuración y reportes exclusivos de ADMIN | FR-008 | T012, T069 | `settings.contract.test.js`, `reports.contract.test.js` | Aprobado |
| CA-11 | Reportes con muchos datos responden en tiempo razonable | FR-015 | T087 | `reports.performance.test.js` | Aprobado |
| CA-12 | Seeds con configuración y tipos, idempotentes | FR-030 | T085, T086 | `seed.settings.test.js` | Aprobado |
| CA-13 | Pruebas de configuración, reportes, permisos y exportación | FR-001 a FR-015 | T008 a T084 | Suites citadas | Aprobado |
| CA-14 | El ticket nuevo muestra el próximo servicio; los emitidos no cambian | FR-016, FR-017 | T033 a T037 | `ticketContent.test.js`, `tickets.nextService.test.js`, `ticket_next_service_test.dart` | Aprobado |
| CA-15 | Documentación actualizada y `.env.example` aclarado | FR-031 | T089 a T091 | Revisión de `project-context.md`, `design-system.md` y `.env.example` | Aprobado |
| CA-16 | Pantalla de aceptación al ingresar; rechazar cierra la sesión | FR-018 | T045, T046 | `terms_test.dart` | Aprobado |
| CA-17 | La aceptación guarda usuario, versión y fecha y se pide de nuevo con una versión nueva | FR-019, FR-022 | T041, T042 | `terms.flow.test.js` | Aprobado |
| CA-18 | El texto cubre uso, confidencialidad, cuentas y privacidad; el administrador consulta las aceptaciones | FR-020 | T041, T048 | `terms.flow.test.js`, `terms_test.dart` | Aprobado |
| CA-19 | La aceptación se valida en el servidor | FR-021 | T043 | `terms.flow.test.js` (una ruta de cada router) | Aprobado |
| CA-20 | La bitácora registra las acciones sensibles y se consulta con filtros | FR-023, FR-024 | T057, T058, T060 | `audit.flow.test.js`, `audit_log_test.dart` | Aprobado |
| CA-21 | La bitácora no guarda datos reservados | FR-025 | T057 | `audit.flow.test.js`, `auditService.test.js` | Aprobado |
| CA-22 | Política de contraseñas con mensaje claro | FR-026 | T056 | `passwordPolicy.test.js`, `passwords.test.js`, `users_screens_test.dart` | Aprobado |
| CA-23 | La sesión se cierra por inactividad, validada en el servidor | FR-027 | T059, T061 | `session.inactivity.test.js`, `inactivity_test.dart` | Aprobado |
| CA-24 | Ninguna respuesta incluye hashes, tokens ni precios reservados | FR-028 | T053, T062 | `dataExposure.test.js` | Aprobado |
| CA-25 | Consultas parametrizadas; prueba de inyección | FR-029 | T054, T062 | `injection.test.js` | Aprobado |
| CA-26 | Pruebas de términos, bitácora, contraseñas, inactividad y exposición | FR-018 a FR-029 | T038 a T062 | Suites citadas | Aprobado |

## 7. Hallazgos y defectos

| ID | Descripción | Severidad | Origen | Estado | Resolución |
|:--:|---|---|---|---|---|
| H-01 | La constitución exige aprobación registrada para cada sprint posterior al MVP | Media | Puerta G-05 | Resuelto | Enmienda 1.1.2 con la aprobación del Sprint 7 |
| H-02 | Pruebas anteriores que debieron actualizarse por cambios declarados en la especificación (SC-011) | Baja | Regresión | Resuelto | Ver el detalle abajo |
| H-03 | La persona responsable pidió **Excel con el diseño de Motorix en lugar de CSV**, lo que agrega `exceljs` al servidor (la especificación decía «sin dependencias nuevas») | Media | Solicitud del 2026-11-21 | Aceptado | `spec.md`, `plan.md`, `research.md`, `contracts/` y `tasks.md` actualizados; `noNewDependencies.test.js` fija `exceljs` como única dependencia nueva y el cliente no agrega ninguna |
| H-04 | Las pruebas transversales de exposición de datos e inyección no revelaron ningún problema | — | T062 | Resuelto | Sin cambios de código; quedan como pruebas permanentes |
| H-05 | Las pruebas de la bitácora mostraban un error de llave foránea en la consola al ejecutarse el servicio de autenticación con un usuario simulado | Baja | Regresión | Resuelto | La prueba unitaria de `authService` simula la bitácora |
| H-06 | El filtro `to` de la bitácora excluía el último día | Media | `audit.flow.test.js` | Resuelto | El filtro incluye todo el día indicado |
| H-07 | Al exportar desde el navegador fallaba con «Unsupported operation: Platform._environment»: el guardado usaba `dart:io`, que no existe en la web | Media | Recorrido manual (T094) | Resuelto | Guardado propio para el navegador (`file_saver_web.dart`) que dispara la descarga del navegador, sin dependencias nuevas; el guardado de escritorio prueba Descargas, Documentos y la carpeta temporal y muestra el motivo real del error; prueba `reports_test.dart` del aviso en el navegador |

**Detalle de H-02 (pruebas actualizadas, ninguna eliminada ni debilitada):**

- Cliente: tres expectativas de `users_screens_test.dart` que esperaban 8 caracteres de contraseña ahora esperan 10 y el texto «Mínimo 10 caracteres, con una mayúscula, una minúscula y un número».
- Servidor: tres expectativas de `orders.work.test.js`, `orders.work.contract.test.js` y `orders.contract.test.js` incluyen ahora `serviceType: null` en las líneas de servicio (los de mano de obra no lo llevan).
- Cliente: dos expectativas de `order_work_test.dart` incluyen `serviceTypeId: null` en el cuerpo de las líneas de servicio.
- Servidor: `seeds.sprint2.test.js` inicia sesión con `loginAndAccept` (las cuentas sembradas aceptan los términos en su primer ingreso); `createUser` acepta los términos por omisión y `resetDatabase` conserva la versión 1.0.
- Cliente: el `FakeApi` por omisión responde `GET /terms/current` con `accepted: true` para no bloquear las pruebas anteriores en la pantalla de aceptación.
- Servidor: `authService.test.js` simula la bitácora y `touchActivity`.

## 8. Línea base de regresión

| Suite | Comando | Antes del sprint | Después del sprint | Diferencia |
|---|---|---|---|---|
| Backend | `npm test` en `server/` | 97 suites y 1 349 pruebas aprobadas, 0 fallidas | 123 suites y 1 534 pruebas aprobadas, 0 fallidas | +26 suites y +185 pruebas |
| Frontend | `flutter test` en `client/` | 373 pruebas aprobadas, 0 fallidas | 449 pruebas aprobadas, 0 fallidas | +76 pruebas |

**Fecha de la línea base:** 2026-11-21, sobre el commit `836abcd` de la rama `007-reportes-configuracion-seguridad`.

**Fecha del cierre:** 2026-11-21, sobre la misma rama. Ninguna prueba de la línea base pasó de verde a rojo; las pruebas actualizadas están en H-02. `flutter analyze` reporta dos avisos informativos (`use_null_aware_elements`) en `test/client_notices_test.dart` y `test/helpers/data.dart`, previos a este sprint.

**Capturas de la regresión:** las toma la persona responsable al repetir `npm test` y `flutter test`.

## 9. Control de calidad final

Cinco requisitos funcionales del sprint, elegidos entre los que más pueden fallar (aceptación de términos, inactividad, bitácora, reportes y exportación), con el mismo formato de la matriz de calidad del MVP.

| ID | Requisito | Criterio de Aceptación | Prueba ejecutada | Resultado | Evidencia / defecto |
|:--:|---|---|---|---|---|
| RF-01 | Spec 007, FR-021: la aceptación de términos se valida en el servidor. | Un usuario sin aceptar recibe `403 TERMS_NOT_ACCEPTED` en una ruta de cada router, salvo las tres permitidas. | Jest + supertest: `terms.flow.test.js`, 10 casos; Flutter: `terms_test.dart`, 8 casos. | Aprobado | Sin defectos. |
| RF-02 | Spec 007, FR-027: la sesión se cierra a los 30 minutos sin actividad. | `401 SESSION_INACTIVE` tras más de 30 minutos; aviso a los 28 en el cliente. | Jest: `session.inactivity.test.js`, 6 casos; Flutter: `inactivity_test.dart`, 6 casos. | Aprobado | Sin defectos. |
| RF-03 | Spec 007, FR-023 y FR-025: la bitácora registra las acciones sensibles sin datos reservados. | Las 12 acciones quedan registradas; ninguna fila contiene contraseñas, hashes, tokens ni tarjetas; sin rutas de escritura. | Jest: `audit.flow.test.js`, 11 casos, `audit.contract.test.js`, `auditService.test.js`. | Aprobado | H-06 corregido durante la prueba. |
| RF-04 | Spec 007, FR-013: los importes de los reportes se calculan en centavos y cuadran con su origen. | El total es igual a la suma por método y por día; solo cuentan los pagos Pagado del rango. | Jest: `reportRules.test.js`, `reports.income.test.js`, `reports.parts.test.js`, `reports.performance.test.js`. | Aprobado | Sin defectos. |
| RF-05 | Spec 007, FR-014: cada reporte se exporta a Excel con el diseño de Motorix y los mismos datos que la pantalla. | Libro `.xlsx` con logo, colores, importes numéricos, totales y los mismos valores que el JSON. | Jest: `reports.xlsx.test.js`, 11 casos; Flutter: `reports_test.dart`, `file_saver_test.dart`. | Aprobado con observación | Cambio de CSV a Excel (H-03); el diseño del libro fue revisado y aprobado por la persona responsable el 2026-11-21. |

## 10. Cierre

| Campo | Valor |
|---|---|
| Criterios de salida cumplidos | 5 de 5 |
| Defectos abiertos | Ninguno crítico, alto ni medio |
| Observaciones | Dependencia nueva `exceljs` aprobada (H-03). El aspecto del libro de Excel (logo y colores) fue aprobado por la persona responsable el 2026-11-21. El recorrido manual con la interfaz gráfica lo completó la persona responsable: carga en menos de 3 segundos y flujo de aceptación de unos 40 segundos (SC-010 cumplido). Los cinco libros se generaron sin errores con los datos reales de la base `motorix` (7 pagos y 22 510.00 de ingresos en el último año) |
| Aprobado por | José Adrián Mendoza Hernández, responsable del proyecto (aprobación confirmada el 2026-11-21) |
| Fecha | 2026-11-21 |
