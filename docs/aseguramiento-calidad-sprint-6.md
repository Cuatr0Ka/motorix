# Aseguramiento de la calidad - Sprint 6: Notificaciones internas y clientes por avisar

Este documento es el registro de calidad del Sprint 6 de Motorix. Reúne las puertas de calidad, las decisiones, los riesgos, la trazabilidad de los criterios de aceptación, los hallazgos, la regresión de los sprints anteriores y el control de calidad final, con sus evidencias.

Resultado general: el sprint se aprobó con observaciones el 2026-11-20. Todas las pruebas automáticas pasan y no hay defectos abiertos. La observación es que las capturas de la aplicación y los tiempos con la interfaz (SC-001, SC-005 y SC-009) los debe tomar la persona responsable en el recorrido manual de la sección 10, porque el recorrido con la interfaz gráfica no se pudo automatizar.

## 0. Datos del documento

| Campo | Valor |
|---|---|
| Sprint | 6 - Notificaciones internas y clientes por avisar |
| Insumo | `docs/sprints/sprint-6-notificaciones-internas.md` |
| Rama | `006-notificaciones-internas` |
| Responsable | José Adrián Mendoza Hernández, responsable del proyecto |
| Fecha de inicio | 2026-11-20 |
| Fecha de cierre | 2026-11-20 |
| Estado general | Aprobado con observación |

## 1. Objetivo y alcance

**Objetivo.** Asegurar que el Sprint 6 salga con calidad: que los requisitos estén completos, sean medibles y no se contradigan, que las pruebas estén planeadas antes del código y que el cambio no rompa lo construido en los sprints anteriores.

**Dentro del alcance:** centro de notificaciones en el encabezado (mantenimientos próximos y vencidos, citas del día, stock bajo o agotado y órdenes detenidas) con lectura por usuario, y lista de clientes por avisar con registro de quién avisó y cuándo.

**Fuera del alcance:** envío automático de avisos al cliente por cualquier canal, notificaciones en tiempo real por empuje o del sistema operativo, preferencias por usuario, historial de avisos pasados y reportes y configuración del taller (Sprint 7).

## 2. Criterios de entrada y de salida

Todos los criterios se cumplieron: los de entrada, antes de comenzar la implementación, y los de salida, al cierre del sprint.

**Criterios de entrada (para comenzar la implementación):**

- [x] Las 8 puertas de la sección 3 están Aprobadas o Aprobadas con observación.
- [x] Si el sprint exige un cambio a la constitución del proyecto, la enmienda está aprobada y registrada (hallazgo H-01).
- [x] Las decisiones de la sección 4 están resueltas y registradas.
- [x] No hay hallazgos críticos ni altos abiertos en el análisis de consistencia.
- [x] Cada criterio de aceptación tuvo al menos una prueba planeada (sección 6).
- [x] La línea base de regresión está registrada (sección 8).
- [x] La documentación desfasada de los sprints anteriores está identificada.

**Criterios de salida (para cerrar el sprint):**

- [x] Los 14 criterios de aceptación están Aprobados.
- [x] Todas las pruebas de los sprints anteriores siguen pasando.
- [x] No hay defectos críticos ni altos abiertos (sección 7).
- [x] La matriz de calidad final (sección 9) está completa, con evidencia.
- [x] Reporte, análisis y matriz no se contradicen.

## 3. Puertas de calidad

Cada puerta se verificó antes de comenzar la implementación. El detalle de cada una está en los documentos citados en la columna de evidencia.

| ID | Puerta | Estado | Evidencia |
|:--:|---|---|---|
| G-01 | Insumo del sprint revisado contra el código | Aprobado | `docs/sprints/sprint-6-notificaciones-internas.md`: se verificó que no existían centro de notificaciones, tabla ni endpoint, y que el dashboard y las alertas de stock ya calculaban parte de los avisos |
| G-02 | Especificación (`/speckit.specify`) | Aprobado con observación | `specs/006-notificaciones-internas/spec.md`: 7 historias, 25 requisitos y 9 criterios de éxito; los 3 marcadores iniciales se resolvieron en G-03 |
| G-03 | Aclaraciones (`/speckit.clarify`) | Aprobado | 6 decisiones resueltas en 2 rondas (D-01 a D-06) y sin marcadores `[NEEDS CLARIFICATION]` |
| G-04 | Lista de calidad de requisitos (`/speckit.checklist`) | Aprobado | `checklists/requirements.md`: 16 de 16 puntos aprobados. No se generó una lista adicional: el sprint no maneja dinero |
| G-05 | Plan (`/speckit.plan`) | Aprobado | `plan.md`, `research.md`, `data-model.md` y `contracts/`; migración `006` aditiva con dos tablas |
| G-06 | Tareas (`/speckit.tasks`) | Aprobado | `tasks.md`: 69 tareas, con las pruebas antes del código |
| G-07 | Consistencia (`/speckit.analyze`) | Aprobado | 1 pasada: 9 hallazgos (2 altos, 4 medios, 3 bajos) corregidos; 25 de 25 requisitos con tarea |
| G-08 | Pruebas planeadas y línea base | Aprobado | Secciones 6 y 8: 14 criterios con prueba y línea base de 1215 pruebas de backend y 321 de frontend |

## 4. Decisiones de aclaración

Las 6 decisiones abiertas del insumo del sprint (D-01 a D-06) se resolvieron en la etapa de aclaraciones el 2026-11-20 con la aprobación del responsable del proyecto. Su texto completo y los requisitos que afectan están en `specs/006-notificaciones-internas/spec.md`.

| ID | Decisión | Resolución | Requisito afectado |
|:--:|---|---|---|
| D-01 | Qué es una orden detenida | Orden abierta (Recibida, Diagnóstico, En reparación o Esperando refacción) con más de 3 días sin cambio de estado; las Terminadas se avisan por la lista de clientes | FR-013 |
| D-02 | Nota al marcar a un cliente como avisado | Solo se registra quién y cuándo, sin nota; el cliente sale de la lista aunque no haya contestado | FR-018 |
| D-03 | Actualización del contador | Al iniciar sesión, al navegar y cada 60 segundos | FR-020 |
| D-04 | Cita del día | Solo la de hoy; las de mañana van a la lista de clientes por avisar | FR-012 |
| D-05 | Identidad de un aviso para la lectura | Tipo y objeto; un cambio de estado del mismo objeto es un aviso nuevo | FR-007 |
| D-06 | Avisos de mantenimiento para el mecánico | No los ve; solo los de las órdenes que tiene asignadas | FR-004 |

## 5. Riesgos y mitigaciones

| ID | Riesgo | Impacto | Mitigación | Prueba que lo cubre | Estado |
|:--:|---|---|---|---|---|
| R-01 | Un rol recibe avisos que no le corresponden | Alto: filtra información por rol | El servicio decide los tipos por rol y no ejecuta las consultas de stock para recepción ni mecánico; proyección por rol como defensa en profundidad | `notifications.mechanic.test.js`, `notifications.stock.test.js`, `notificationProjection.test.js` | Mitigado |
| R-02 | Los números difieren del panel | Medio: confusión del usuario | El centro usa `maintenanceService.list` y `partService.alerts`, los mismos del panel | `notifications.reception.test.js` (totales contra el panel y la lista), `notifications.stock.test.js` | Mitigado |
| R-03 | Una lectura vieja oculta un aviso nuevo | Medio: aviso importante sin ver | La clave cambia al empeorar y al volver a detenerse una orden | `notifications.read.test.js`, `notifications.stalled.test.js` | Mitigado |
| R-04 | Dos personas marcan lo mismo a la vez | Medio: filas duplicadas o error visible | Llave primaria y `UNIQUE (reason, fact_id)` con `INSERT IGNORE`; la segunda respuesta es 200 | `clientNotices.concurrency.test.js`, `notifications.read.test.js` | Mitigado |
| R-05 | Se avisa de un hecho que ya no existe | Medio: aviso falso | El servidor verifica la condición al registrar y responde 409 | `clientNotices.flow.test.js` | Mitigado |
| R-06 | El teléfono llega al mecánico | Alto: dato personal expuesto | Solo existe en `/client-notices` (ADMIN y RECEPTIONIST); los avisos del mecánico no traen cliente | `clientNotices.contract.test.js`, `notifications.mechanic.test.js` | Mitigado |
| R-07 | La consulta se vuelve lenta | Medio: la campana tarda | Consultas acotadas, máximo 50 avisos por tipo y conteos reales | `notifications.performance.test.js` | Mitigado |
| R-08 | El temporizador sigue vivo tras cerrar sesión | Bajo: consultas inútiles | El proveedor cancela el `Timer` al desmontarse el shell | `notifications_test.dart` | Mitigado |
| R-09 | La insignia de Inventario se contradice con el centro | Bajo: confusión | `StockAlertsProvider` no cambia y ambos usan `partService.alerts()`; tras un movimiento se refrescan los dos | `stock_alerts_test.dart`, `notifications_test.dart` | Mitigado |
| R-10 | Se rompe un sprint anterior | Alto: regresión | Migración aditiva; no se tocó ninguna tabla ni ruta existente | Regresión completa (sección 8) | Mitigado |
| R-11 | Documentación desfasada | Bajo: el contexto no refleja el código | Tareas T065 y T066 | Revisión de `docs/project-context.md` y `docs/design-system.md` | Mitigado |

## 6. Trazabilidad

Cada criterio de aceptación (CA) se enlaza con su requisito, su tarea, su prueba y el resultado verificado.

| CA | Criterio de aceptación (resumen) | Requisito (FR) | Tarea | Prueba | Resultado | Evidencia |
|:--:|---|---|---|---|---|---|
| CA-1 | Campana con el total de no leídos y panel agrupado por tipo | FR-001 | T018 a T024 | T015, T016, T017 | Aprobado | `notifications.flow.test.js`, `notifications_test.dart` |
| CA-2 | Los avisos se calculan al consultar y no se copian; solo se guarda la lectura | FR-003 | T017, T018 | T015, T062 | Aprobado | `notifications.flow.test.js`; solo existen las tablas `notification_reads` y `client_notices` |
| CA-3 | Cinco tipos de aviso (stock en dos niveles) | FR-002 | T027, T028, T049, T055 | T025, T047, T052 | Aprobado | `notifications.reception.test.js`, `notifications.stock.test.js`, `notifications.stalled.test.js` |
| CA-4 | Cada rol recibe solo sus avisos; el stock no va a recepción ni al mecánico | FR-004 | T055, T059 | T057, T047 | Aprobado | `notifications.mechanic.test.js`, `notifications.stock.test.js` |
| CA-5 | Mismo cálculo que el panel, la lista de Mantenimientos y las alertas de stock | FR-005 | T028, T049 | T025, T047 | Aprobado | Totales comparados con `/api/dashboard`, `/api/maintenance` y `/api/parts/alerts` |
| CA-6 | La lectura es por usuario, persiste y reaparece si empeora | FR-006, FR-007 | T033, T034 | T030, T031 | Aprobado | `notifications.read.test.js`, `notifications.read.contract.test.js` |
| CA-7 | Cada aviso abre la pantalla relacionada | FR-008 | T036 | T032 | Aprobado | `notifications_test.dart` (orden, cita, vehículo y refacción) |
| CA-8 | La insignia de Inventario y el aviso de inicio siguen funcionando | FR-009 | T050 | T048 | Aprobado | `stock_alerts_test.dart`, `home_screen_test.dart` |
| CA-9 | Estados de carga, vacío y error | FR-010 | T023 | T017 | Aprobado | `notifications_test.dart` |
| CA-10 | Lista de clientes por avisar con cliente, teléfono, vehículo y motivo; el mecánico no accede | FR-014, FR-015 | T042, T043, T045 | T037, T039, T040 | Aprobado | `clientNotices.flow.test.js`, `clientNotices.contract.test.js`, `client_notices_test.dart` |
| CA-11 | Marcar como avisado guarda quién y cuándo, saca la fila y un hecho nuevo reaparece | FR-016, FR-017, FR-018 | T042, T043 | T037, T038 | Aprobado | `clientNotices.flow.test.js`, `clientNotices.concurrency.test.js` |
| CA-12 | Los seeds incluyen un caso de cada tipo y son idempotentes | FR-022 | T061 | T062 | Aprobado | `seed.notices.test.js` |
| CA-13 | Pruebas de cálculo, permisos, lectura y rendimiento | FR-023 | T006, T008, T063 | T063 y las de cada historia | Aprobado | `notifications.performance.test.js` y las pruebas de cada historia |
| CA-14 | Documentación actualizada | FR-024 | T065, T066 | Revisión | Aprobado | `docs/project-context.md` (sección 6.12 y decisión del Sprint 6) y `docs/design-system.md` (sección 8.5.2) |

## 7. Hallazgos y defectos

Se registra todo lo que se encuentre, sea en los documentos, en el análisis o en las pruebas.

| ID | Descripción | Severidad (crítica, alta, media, baja) | Origen (puerta o prueba) | Estado | Resolución | Evidencia |
|:--:|---|---|---|---|---|---|
| H-01 | El principio I de la constitución exige la aprobación registrada del responsable para cada sprint posterior al MVP y el Sprint 6 no tenía tarea para registrarla | Alta | G-07 (análisis) | Resuelto | Se agregó la puerta T002 y se registró la aprobación en la constitución (versión 1.1.1) | `.specify/memory/constitution.md` |
| H-02 | Si se hacía la historia de órdenes detenidas antes que la del mecánico, este recibía avisos de órdenes ajenas | Alta | G-07 (análisis) | Resuelto | El filtro por mecánico asignado se hace desde la tarea T055 y la proyección por rol queda como defensa en profundidad (T059) | `notifications.mechanic.test.js` |
| H-03 | Otros 7 hallazgos medios y bajos del análisis (destino del mecánico, creación de `noticeModel.js`, 5 o 6 tipos en FR-002, nombres de pruebas del quickstart, orden de SC-009, comprobación de FR-025 y árbol del plan) | Media y baja | G-07 (análisis) | Resuelto | Corregidos en `spec.md`, `plan.md`, `tasks.md` y `quickstart.md` antes de implementar | Commit `8cb3b5b` |
| H-04 | El aviso «el inventario está en orden» (`StockAlertsBanner`) no tenía `Expanded`: con un riel lateral más ancho se desbordaba 32 px. Lo destapó la nueva opción del menú en las pruebas | Baja | Prueba (`inventory_screens_test.dart`, `stock_alerts_test.dart`) | Resuelto | Se agregó `Expanded` al texto; no se modificó ninguna prueba | `client/lib/widgets/stock_alerts_banner.dart` |
| H-05 | `database/README.md` tenía dos caracteres de control dañados desde el Sprint 5 (un retroceso en «brand» y un nulo en el nombre de la migración 005) y los editores lo trataban como binario | Baja | Revisión | Resuelto | Se repararon los dos caracteres al agregar la migración 006 | `database/README.md` |
| H-06 | Ninguna prueba de la línea base se actualizó ni se reemplazó: el Sprint 6 no cambia contratos existentes | Informativo | Regresión | Resuelto | No aplica | Sección 8 |

## 8. Línea base de regresión

Se ejecuta la suite completa **antes** de tocar el código y de nuevo **al cierre**. Ninguna prueba de los sprints anteriores debe pasar de verde a rojo.

| Suite | Comando | Antes del sprint | Después del sprint | Diferencia | Evidencia |
|---|---|---|---|---|---|
| Backend | `npm test` en `server/` | 80 suites y 1215 pruebas aprobadas, 0 fallidas | 97 suites y 1349 pruebas aprobadas, 0 fallidas | +17 suites y +134 pruebas | Salida de la ejecución del 2026-11-20 |
| Frontend | `flutter test` en `client/` | 321 pruebas aprobadas, 0 fallidas | 373 pruebas aprobadas, 0 fallidas | +52 pruebas | Salida de la ejecución del 2026-11-20 |

**Fecha de la línea base:** 2026-11-20, sobre el commit `8cb3b5b` de la rama `006-notificaciones-internas`, antes de escribir el código del sprint.

**Duración del backend:** 146 s al inicio y 129 s al cierre.

**Fecha del cierre:** 2026-11-20, sobre la rama `006-notificaciones-internas` (commit `0ced61d` más los ajustes de este documento). Ninguna prueba de la línea base se actualizó ni se reemplazó (H-06). Análisis estático del cliente: `flutter analyze lib` sin problemas.

**Pruebas nuevas del backend (134):** `noticeRules` 15, `noticeValidators` 8, `notificationProjection` 3, `noMessaging` 4, `notifications.flow` 7, `notifications.reception` 8, `notifications.read` 12, `notifications.stock` 7, `notifications.stalled` 11, `notifications.mechanic` 8, `notifications.performance` 6, `clientNotices.flow` 16, `clientNotices.concurrency` 2, `seed.notices` 8, y los contratos `notifications` 4, `notifications.read` 6 y `clientNotices` 9.

**Pruebas nuevas del frontend (52):** `notice_models_test.dart` 7, `notifications_test.dart` 33, `client_notices_test.dart` 11 (10 casos, uno repetido por rol) y 1 prueba agregada a `stock_alerts_test.dart` (refresco del centro tras un movimiento de inventario).

## 9. Control de calidad final

Cinco requisitos funcionales del sprint, elegidos entre los que más pueden fallar (permisos por rol, lectura por usuario, orden detenida, concurrencia y rendimiento), con el mismo formato de la matriz de calidad del MVP.

| ID | Requisito | Criterio de Aceptación | Prueba ejecutada | Resultado | Evidencia / defecto |
|:--:|---|---|---|---|---|
| RF-01 | Spec 006, FR-004 y FR-015: cada rol recibe solo sus avisos; el mecánico solo los de sus órdenes y nunca teléfonos ni la lista de clientes por avisar. | El mecánico recibe solo `STALLED` de sus órdenes sin nombre de cliente ni teléfono; la recepción no recibe stock; el mecánico recibe 403 en `/client-notices`; el rol vigente en la base decide, no el del token. | Jest + supertest: `notifications.mechanic.test.js` (8 casos), `notifications.stock.test.js` (7 casos) y `clientNotices.contract.test.js` (9 casos). | Aprobado | [Requisito](#e-01-requisito) · [Prueba](#e-01-prueba) · [Resultado](#e-01-resultado). Sin defectos. |
| RF-02 | Spec 006, FR-006 y FR-007: la lectura es por usuario, persiste, y el aviso desaparece o reaparece según su condición. | Marcar como leído baja el contador y persiste; otro usuario lo ve sin leer; al pasar de próximo a vencido reaparece sin leer; cinco solicitudes simultáneas dejan una fila. | Jest + supertest: `notifications.read.test.js` (12 casos). | Aprobado | [Requisito](#e-02-requisito) · [Prueba](#e-02-prueba) · [Resultado](#e-02-resultado). Sin defectos. |
| RF-03 | Spec 006, FR-013: una orden abierta con más de 3 días sin cambio de estado es detenida. | Con 3 días exactos no avisa y con 4 sí; usa el último cambio del historial; un cambio de estado la quita y, al volver a detenerse, reaparece sin leer con otra clave. | Jest + supertest: `notifications.stalled.test.js` (11 casos) y `noticeRules.test.js` (15 casos). | Aprobado | [Requisito](#e-03-requisito) · [Prueba](#e-03-prueba) · [Resultado](#e-03-resultado). Sin defectos. |
| RF-04 | Spec 006, FR-016 y FR-021: marcar a un cliente como avisado registra quién y cuándo, es idempotente y soporta concurrencia. | Se crea una sola fila por hecho; el primer POST responde 201 y los demás 200 sin error; el cliente no reaparece por el mismo hecho y un hecho nuevo sí. | Jest + supertest: `clientNotices.flow.test.js` (16 casos) y `clientNotices.concurrency.test.js` (2 casos). | Aprobado | [Requisito](#e-04-requisito) · [Prueba](#e-04-prueba) · [Resultado](#e-04-resultado). Sin defectos. |
| RF-05 | Spec 006, FR-023: con miles de registros los avisos se consultan en un tiempo razonable. | Con 1 000 órdenes, 1 000 citas y 1 000 mantenimientos, `GET /api/notifications` responde en menos de 2 segundos para los tres roles, con el total real y máximo 50 avisos por tipo. | Jest + supertest: `notifications.performance.test.js` (6 casos). | Aprobado | [Requisito](#e-05-requisito) · [Prueba](#e-05-prueba) · [Resultado](#e-05-resultado). Sin defectos. |

## 10. Cierre

| Campo | Valor |
|---|---|
| Criterios de salida cumplidos | 5 de 5: criterios de aceptación aprobados, regresión sin fallas, sin defectos abiertos, matriz final completa y documentos sin contradicciones |
| Defectos abiertos | Ninguno |
| Observaciones | Las capturas de la aplicación y los tiempos con la interfaz de SC-001 (abrir un aviso en menos de 30 s), SC-005 (avisar a un cliente en menos de 1 minuto) y SC-009 (un aviso nuevo en la campana en máximo 60 s) quedan para el recorrido manual del responsable con los datos de ejemplo (`quickstart.md`, secciones 4 a 7). La prueba automática de SC-009 sí pasa con tiempo simulado. Límite conocido: el valor de 3 días de una orden detenida es fijo; el Sprint 7 puede volverlo configurable. |
| Aprobado por | José Adrián Mendoza Hernández, responsable del proyecto |
| Fecha | 2026-11-20 |

# Anexo de evidencias

Cada evidencia tiene tres bloques: **Requisito** (texto de la especificación con archivo y línea), **Prueba** (código o descripción) y **Resultado** (comando y salida real). Las ejecuciones fueron el 2026-11-20 con `npm test` en `server/` y `flutter test` en `client/`.

## E-01 Requisito

Archivo: `specs/006-notificaciones-internas/spec.md`, líneas 229 a 233 y 255 a 256.

> **FR-004**: El servidor DEBE devolver a cada rol solo sus avisos: el administrador, todos; la recepción, mantenimientos, citas y órdenes detenidas; el mecánico, solo los de las órdenes que tiene asignadas. El stock NO DEBE devolverse a recepción ni al mecánico.
>
> **FR-015**: El mecánico NO DEBE acceder a la lista de clientes por avisar ni recibir teléfonos de clientes por este medio; se valida en el servidor.

## E-01 Prueba

Archivos: `server/tests/integration/notifications.mechanic.test.js`, líneas 50 a 100, y `server/tests/integration/notifications.stock.test.js`.

La prueba crea órdenes detenidas de dos mecánicos y una sin asignar, más una cita, un mantenimiento vencido y una refacción agotada, y comprueba que el mecánico solo recibe sus órdenes, sin nombre de cliente ni teléfono, que la recepción no recibe stock y que marcar claves ajenas se ignora.

Fragmento clave:

```js
const res = await consultar(mecanico);

expect(res.body.data.groups.map((g) => g.type)).toEqual(['STALLED']);
expect(JSON.stringify(res.body)).not.toMatch(/APPT_|MAINT_|STOCK_/);
expect(cuerpo).not.toContain('Ana Torres');
expect(cuerpo).not.toContain('7761234567');
```

## E-01 Resultado

Comando: `npm test -- tests/integration/notifications.mechanic.test.js tests/integration/notifications.stock.test.js tests/contract/clientNotices.contract.test.js`

Pasaron las 24 pruebas de las 3 suites. El recorrido contra la API real (E-06, escenarios 3, 4 y 7) lo confirmó: el mecánico recibe `STALLED(3)` sin datos de clientes y responde 403 en la lista y el registro de clientes por avisar.

Resultado: **Aprobado** (24 de 24 casos).

## E-02 Requisito

Archivo: `specs/006-notificaciones-internas/spec.md`, líneas 235 a 240.

> **FR-006**: El usuario DEBE poder marcar un aviso como leído. La lectura se guarda por usuario y persiste entre sesiones.
>
> **FR-007**: Un aviso leído DEBE desaparecer cuando su condición deja de cumplirse, y DEBE volver a mostrarse como no leído si reaparece con otro estado (por ejemplo, de mantenimiento próximo a vencido).

## E-02 Prueba

Archivo: `server/tests/integration/notifications.read.test.js`, líneas 59 a 145.

La prueba marca avisos como leídos con distintos usuarios, cambia la condición del aviso (atiende el mantenimiento, lo hace vencer) y repite la solicitud, incluso cinco veces en paralelo.

Fragmento clave:

```js
const respuestas = await Promise.all(Array.from({ length: 5 }, () => marcar(admin, [`MAINT_OVERDUE:${vencido.id}`])));

for (const res of respuestas) expect(res.status).toBe(200);
expect(await filas()).toBe(1);
```

## E-02 Resultado

Comando: `npm test -- tests/integration/notifications.read.test.js tests/contract/notifications.read.contract.test.js`

Pasaron las 18 pruebas de las 2 suites. El recorrido contra la API real (E-06, escenarios 2 y 3) lo confirmó: el administrador bajó de 15 a 14 no leídos y la recepción siguió viendo 10 de 10.

Resultado: **Aprobado** (18 de 18 casos).

## E-03 Requisito

Archivo: `specs/006-notificaciones-internas/spec.md`, líneas 248 a 251.

> **FR-013**: Una orden se considera detenida cuando está abierta (Recibida, Diagnóstico, En reparación o Esperando refacción) y lleva más de 3 días sin cambio de estado. El valor de 3 días es fijo en este sprint.

## E-03 Prueba

Archivos: `server/tests/integration/notifications.stalled.test.js`, líneas 67 a 160, y `server/tests/unit/noticeRules.test.js`.

La prueba envejece el historial de órdenes 3, 4, 6 y 12 días, compara los estados abiertos y cerrados, cambia de estado una orden y la deja detenerse de nuevo.

Fragmento clave:

```js
await ordenDetenida({ dias: 3 });
expect((await consultar(admin)).body.data.groups).toEqual([]);

await ordenDetenida({ dias: 4 });
expect(grupo(await consultar(admin)).total).toBe(1);
```

## E-03 Resultado

Comando: `npm test -- tests/integration/notifications.stalled.test.js tests/unit/noticeRules.test.js`

Pasaron las 26 pruebas de las 2 suites.

Resultado: **Aprobado** (26 de 26 casos).

## E-04 Requisito

Archivo: `specs/006-notificaciones-internas/spec.md`, líneas 257 a 261 y 267 a 270.

> **FR-016**: Marcar a un cliente como avisado DEBE registrar quién lo avisó y cuándo, sacarlo de la lista y evitar que reaparezca por el mismo hecho (misma orden, misma cita o mismo mantenimiento).
>
> **FR-021**: Las operaciones concurrentes sobre una misma lectura o un mismo aviso de cliente DEBEN dejar un solo registro y NO DEBEN producir un error visible para el usuario.

## E-04 Prueba

Archivos: `server/tests/integration/clientNotices.flow.test.js`, líneas 172 a 270, y `server/tests/integration/clientNotices.concurrency.test.js`, líneas 26 a 50.

La prueba lanza cinco avisos simultáneos del mismo hecho desde dos personas y comprueba que queda una sola fila: uno responde 201 y los demás 200.

Fragmento clave:

```js
const estados = respuestas.map((r) => r.status).sort();
expect(estados).toEqual([200, 200, 200, 200, 201]);
expect(new Set(respuestas.map((r) => r.body.data.id)).size).toBe(1);
expect((await query('SELECT id FROM client_notices')).length).toBe(1);
```

## E-04 Resultado

Comando: `npm test -- tests/integration/clientNotices.flow.test.js tests/integration/clientNotices.concurrency.test.js`

Pasaron las 18 pruebas de las 2 suites. El recorrido contra la API real (E-06, escenario 6) lo confirmó: primer POST 201, repetido por otra persona 200 sin error, y la fila ya no aparece.

Resultado: **Aprobado** (18 de 18 casos).

## E-05 Requisito

Archivo: `specs/006-notificaciones-internas/spec.md`, líneas 271 a 273.

> **FR-023**: Los avisos de un volumen realista de datos (miles de órdenes, citas y mantenimientos) DEBEN consultarse en un tiempo razonable para el usuario.

## E-05 Prueba

Archivo: `server/tests/integration/notifications.performance.test.js`, líneas 81 a 140.

La prueba crea 1 000 vehículos con una orden abierta detenida, un mantenimiento pendiente (500 vencidos y 500 próximos) y una cita de hoy cada uno, y mide el tiempo de respuesta del administrador, la recepción, el mecánico y la lista de clientes por avisar.

Fragmento clave:

```js
const { res, ms } = await medir(request(app).get('/api/notifications').set(auth(admin.token)));

expect(ms).toBeLessThan(LIMITE_MS);
expect(grupos.STALLED.total).toBe(TOTAL);
for (const grupo of Object.values(grupos)) expect(grupo.items.length).toBeLessThanOrEqual(50);
```

## E-05 Resultado

Comando: `npm test -- tests/integration/notifications.performance.test.js`

Pasaron las 6 pruebas en 2.8 s, incluida la creación de los 3 000 registros de prueba. Cada consulta responde en menos de 2 segundos con el total real y máximo 50 avisos por tipo.

Resultado: **Aprobado** (6 de 6 casos).

## E-06 Recorrido de los escenarios contra la API real

Fecha: 2026-11-20. Se levantó la API (`createApp`) sobre la base local `motorix` con los seeds 001 a 006 y las cuentas sembradas `admin`, `recepcion` y `mecanico`. Al terminar se borraron las dos filas que el recorrido registró, para dejar la base como la dejan los seeds.

| # | Escenario | Resultado |
|---|-----------|-----------|
| 0 | Inicio de sesión de las tres cuentas sembradas | Las tres entran |
| 1 | El administrador consulta `GET /api/notifications` | HTTP 200 en 24 ms; 15 no leídos; tipos `MAINT_OVERDUE`(4), `STOCK_OUT`(2), `STALLED`(5), `APPT_TODAY`(1) y `STOCK_LOW`(3) |
| 2 | El administrador marca `STOCK_OUT:10` como leído | HTTP 200; `marked` 1; no leídos 15 → 14 |
| 3 | La recepción consulta sus avisos | HTTP 200; sin avisos de stock; la lectura del administrador no cuenta: 10 no leídos de 10 |
| 4 | El mecánico consulta sus avisos | HTTP 200; solo `STALLED`(3); sin datos de clientes |
| 5 | La recepción abre la lista de clientes por avisar | HTTP 200 en 16 ms; 6 filas con motivos `APPT_TOMORROW`, `MAINT_OVERDUE` y `ORDER_READY`; todas con teléfono |
| 6 | La recepción marca `ORDER_READY:5` como avisado | Primer POST 201; repetido por otra persona 200 sin error; la fila ya no aparece |
| 7 | El mecánico intenta la lista y el registro | `GET` 403 y `POST` 403 |
| 8 | Aviso de un hecho inexistente | HTTP 404 |
| 9 | El aviso con una nota | HTTP 400 `VALIDATION_ERROR` |
| 10 | Consulta sin sesión | HTTP 401 `UNAUTHENTICATED` |

Resultado: **Aprobado** (11 de 11 escenarios).

Alcance: esta comprobación cubre la API real con los datos de ejemplo. Como las fechas de la base local se sembraron el 2026-10-10, no aparecen casos de mantenimiento próximo ni de cita de mañana; el seed 006 y su prueba (`seed.notices.test.js`) comprueban que una instalación nueva sí los trae. El recorrido con la aplicación (campana, panel, sección «Clientes por avisar», confirmaciones, tiempos de SC-001, SC-005 y SC-009 y las capturas) lo hace el responsable con los pasos de `quickstart.md`, secciones 4 a 7.
