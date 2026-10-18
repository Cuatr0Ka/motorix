# Análisis de consistencia (`/speckit.analyze`): sprint 4

Ejecutado el 2026-10-17 sobre `specs/004-pagos-tickets-dashboard` (spec, plan y tasks, contra `.specify/memory/constitution.md`). Es de solo lectura: no modificó ningún archivo. El script resuelve la funcionalidad de la rama activa, así que los sprints 1 a 3 no están incluidos. No hay hooks registrados en `.specify/extensions.yml`.

## Hallazgos

| ID | Categoría | Severidad | Ubicación | Resumen | Recomendación |
|----|-----------|-----------|-----------|---------|---------------|
| F1 | Inconsistencia | ALTA | spec FR-017 y escenario 1 de la historia 4; `docs/project-context.md` L1082; `docs/design-system.md` L259 | El spec exige 10 indicadores en el panel; la guía de diseño y el contexto limitan el panel a 4 indicadores y una gráfica principal. El código entregado muestra 4 más una gráfica | Alinear el spec con lo implementado o justificar la excepción |
| F2 | Inconsistencia | ALTA | plan L78 («`fl_chart` no se necesita») contra `client/pubspec.yaml` L44 y `client/lib/widgets/dashboard_charts.dart` | El plan descarta `fl_chart` y las tareas T057–T061 solo prevén tarjetas. El commit `0e4709f` agregó `fl_chart` y gráficas sin tarea ni actualización del plan | Anotar la decisión en el plan o en `research.md` |
| F3 | Inconsistencia | MEDIA | plan L77 y L141, tasks T059 | Las gráficas del rediseño (`0e4709f`) no tienen tarea. `735e5be` actualizó contrato y modelo de datos, pero no spec, plan ni tasks | Agregar una tarea retroactiva o una nota de «cambios posteriores» |
| C1 | Cobertura | MEDIA | tasks (T001–T070) | Ninguna tarea cita un FR o SC por ID; solo la historia `[USn]` | Agregar IDs a las tareas o mantener `trazabilidad.md` |
| C2 | Cobertura | MEDIA | spec SC-001 a SC-004 y SC-010 | Criterios de tiempo de uso que ninguna tarea mide; T069 solo recorre el quickstart | Agregar una tarea de medición con personas o reclasificarlos |
| C3 | Cobertura | BAJA | spec FR-016 | Sin prueba explícita de que cambiar `SHOP_*` cambie el ticket | Agregar un caso a `ticketContent.test.js` |
| A1 | Ambigüedad | BAJA | spec, caso límite del panel con 1 000 registros | «Con rapidez» sin medida; SC-012 sí la mide (menos de 2 s) | Referenciar SC-012 |
| A2 | Ambigüedad | BAJA | spec L7 | Estado «Borrador» con el sprint ya implementado | Cambiar el estado |
| D1 | Duplicación | BAJA | spec FR-005 y FR-006 y escenarios 6 y 8 | Reglas repetidas entre requisito y escenarios, sin conflicto | Sin acción |
| I1 | Inconsistencia | BAJA | plan L27 | Dice Flutter 3.47.2; el entorno usa 3.47.7 | Actualizar el plan |
| I2 | Inconsistencia | BAJA | plan L33, T005 y T048 | `pdf` está en el plan y en el `pubspec`, pero T005 no lo declara | Mencionarlo en T005 |
| I3 | Orden de tareas | BAJA | T005 y T048 | T048 usa `pdf` antes de que T005 lo declare; funciona como dependencia transitiva de `printing` | Declararlo en T005 |

## Alineación con la constitution
- Sin violaciones críticas de los principios «no negociable» (I, II, IV, V y VIII).
- Principio III: `printing` y `url_launcher` están justificadas en `research.md` D-09. Falta la justificación de `fl_chart` en el sprint 4 (ver F2); la constitution la lista entre las librerías de apoyo permitidas.

## Cobertura

| Requisito | ¿Tiene tarea? | Tareas |
|---|---|---|
| FR-001 a FR-007 | Sí | T006, T009, T016–T022, T025, T034, T035, T037 |
| FR-008 a FR-011 | Sí | T008, T011, T012, T031–T038 |
| FR-012 a FR-016 | Sí | T003, T008, T039–T051 |
| FR-017 a FR-020 | Sí | T052–T061 |
| FR-021 a FR-027 y FR-029 | Sí | T014, T017, T021, T025, T026, T060–T068 |
| FR-028 | No aplica | Fuera de alcance |

Tareas sin requisito asociado: T001 a T005 y T065 a T070 (preparación, validación y pulido).

## Métricas

| Métrica | Valor |
|---|---|
| Requisitos funcionales | 29 |
| Criterios de éxito | 12 |
| Tareas | 70 (todas terminadas) |
| Cobertura de requisitos construibles | 28 de 28 (100 %) |
| Hallazgos críticos | 0 |
| Hallazgos altos | 2 (F1, F2) |
| Ambigüedades | 2 |
| Duplicaciones | 1 |

## Conclusión
Sin hallazgos críticos. Los dos altos son desviaciones documentales: el panel y las gráficas cambiaron en el commit `0e4709f` y el spec, el plan y las tareas no se actualizaron.
