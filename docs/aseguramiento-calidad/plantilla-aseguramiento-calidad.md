# Aseguramiento de la calidad - Sprint N: <Título del sprint>

<!--
PLANTILLA. Copia este archivo como `docs/aseguramiento-calidad-sprint-N.md` y reemplaza todo lo que esté entre < >.
Sigue `docs/aseguramiento-calidad/guia-aseguramiento-calidad.md`.
Elimina estos comentarios y las notas «(Guía: ...)» antes de convertir a Word.
Al cierre no debe quedar ningún < >, «Pendiente» ni «Captura pendiente» como estado.
-->

Este documento es el registro de calidad del Sprint N de <Proyecto>. Reúne las puertas de calidad, las decisiones, los riesgos, la trazabilidad de los criterios de aceptación, los hallazgos, la regresión de los sprints anteriores y el control de calidad final, con sus evidencias.

Resultado general: <el sprint se aprobó el AAAA-MM-DD | el sprint se aprobó con observaciones el AAAA-MM-DD | el sprint no se aprobó>.

## 0. Datos del documento

| Campo | Valor |
|---|---|
| Sprint | <N - Título del sprint> |
| Insumo | `docs/sprints/<archivo-del-insumo>.md` |
| Rama | `<NNN-nombre-de-la-rama>` |
| Responsable | <nombre y rol> |
| Fecha de inicio | <AAAA-MM-DD> |
| Fecha de cierre | <AAAA-MM-DD> |
| Estado general | <Aprobado | Aprobado con observación | Fallido> |

## 1. Objetivo y alcance

**Objetivo.** Asegurar que el Sprint N salga con calidad: que los requisitos estén completos, sean medibles y no se contradigan, que las pruebas estén planeadas antes del código y que el cambio no rompa lo construido en los sprints anteriores.

**Dentro del alcance:** <lista corta de lo que el sprint entrega>.

**Fuera del alcance:** <lo que el insumo del sprint deja fuera, por ejemplo la sección «Fuera de alcance»>.

## 2. Criterios de entrada y de salida

Todos los criterios se cumplieron: los de entrada, antes de comenzar la implementación, y los de salida, al cierre del sprint.

**Criterios de entrada (para comenzar la implementación):**

- [ ] Las 8 puertas de la sección 3 están Aprobadas o Aprobadas con observación.
- [ ] Si el sprint exige un cambio a la constitución del proyecto, la enmienda está aprobada y registrada (hallazgo H-01).
- [ ] Las decisiones de la sección 4 están resueltas y registradas.
- [ ] No hay hallazgos críticos ni altos abiertos en el análisis de consistencia.
- [ ] Cada criterio de aceptación tuvo al menos una prueba planeada (sección 6).
- [ ] La línea base de regresión está registrada (sección 8).
- [ ] La documentación desfasada de los sprints anteriores está identificada.

**Criterios de salida (para cerrar el sprint):**

- [ ] Los <N> criterios de aceptación están Aprobados.
- [ ] Todas las pruebas de los sprints anteriores siguen pasando.
- [ ] No hay defectos críticos ni altos abiertos (sección 7).
- [ ] La matriz de calidad final (sección 9) está completa, con evidencia.
- [ ] Reporte, análisis y matriz no se contradicen.

(Guía: cambia `[ ]` por `[x]` solo cuando el criterio de verdad se cumplió.)

## 3. Puertas de calidad

Cada puerta se verificó antes de comenzar la implementación. El detalle de cada una está en los documentos citados en la columna de evidencia.

| ID | Puerta | Estado | Evidencia |
|:--:|---|---|---|
| G-01 | Insumo del sprint revisado contra el código | <estado> | <documento y observación> |
| G-02 | Especificación (`/speckit.specify`) | <estado> | <ruta de `spec.md` y observación> |
| G-03 | Aclaraciones (`/speckit.clarify`) | <estado> | <decisiones resueltas y marcadores restantes> |
| G-04 | Lista de calidad de requisitos (`/speckit.checklist`) | <estado> | <ruta del checklist y puntos resueltos> |
| G-05 | Plan (`/speckit.plan`) | <estado> | <ruta de `plan.md`, `data-model.md`, `contracts/`> |
| G-06 | Tareas (`/speckit.tasks`) | <estado> | <ruta de `tasks.md` y número de tareas> |
| G-07 | Consistencia (`/speckit.analyze`) | <estado> | <pasadas, hallazgos por severidad, cobertura> |
| G-08 | Pruebas planeadas y línea base | <estado> | <criterios con prueba y línea base> |

## 4. Decisiones de aclaración

<Las N decisiones abiertas del insumo del sprint (D-01 a D-NN) se resolvieron en la etapa de aclaraciones el AAAA-MM-DD con la aprobación de <quién>. Su texto completo y los requisitos que afectan están en `specs/<carpeta-del-sprint>/spec.md`.>

(Guía: si las decisiones son pocas, puedes dejar aquí una tabla `ID | Decisión | Resolución | Requisito afectado`.)

## 5. Riesgos y mitigaciones

| ID | Riesgo | Impacto | Mitigación | Prueba que lo cubre | Estado |
|:--:|---|---|---|---|---|
| R-01 | <qué puede salir mal> | <Alto/Medio/Bajo: consecuencia> | <qué se hace para evitarlo> | <archivo de prueba o revisión> | <Mitigado | Aceptado | Abierto> |

## 6. Trazabilidad

Cada criterio de aceptación (CA) se enlaza con su requisito, su tarea, su prueba y el resultado verificado.

| CA | Criterio de aceptación (resumen) | Requisito (FR) | Tarea | Prueba | Resultado | Evidencia |
|:--:|---|---|---|---|---|---|
| CA-1 | <resumen> | <FR-001> | <T0xx> | <T0xx de prueba> | <Aprobado | Aprobado con observación | Fallido> | <archivo de prueba y enlace a la evidencia> |

## 7. Hallazgos y defectos

Se registra todo lo que se encuentre, sea en los documentos, en el análisis o en las pruebas.

| ID | Descripción | Severidad (crítica, alta, media, baja) | Origen (puerta o prueba) | Estado | Resolución | Evidencia |
|:--:|---|---|---|---|---|---|
| H-01 | <qué se encontró> | <severidad> | <puerta o prueba> | <Resuelto | Aceptado | Abierto> | <cómo se resolvió> | <archivo o enlace> |

## 8. Línea base de regresión

Se ejecuta la suite completa **antes** de tocar el código y de nuevo **al cierre**. Ninguna prueba de los sprints anteriores debe pasar de verde a rojo.

| Suite | Comando | Antes del sprint | Después del sprint | Diferencia | Evidencia |
|---|---|---|---|---|---|
| <Backend> | `<comando>` en `<carpeta>` | <N suites y N pruebas aprobadas, 0 fallidas> | <N suites y N pruebas aprobadas, 0 fallidas> | <+N suites y +N pruebas> | Capturas abajo |
| <Frontend> | `<comando>` en `<carpeta>` | <N pruebas aprobadas, 0 fallidas> | <N pruebas aprobadas, 0 fallidas> | <+N pruebas> | Capturas abajo |

**Fecha de la línea base:** <AAAA-MM-DD>, sobre el commit `<hash>` de la rama `<rama>`, antes de crear la rama del sprint.

**Capturas de la línea base (<AAAA-MM-DD>):**

![Línea base del backend](evidencias/sprint-N/captura-linea-base-backend.png)

![Línea base del frontend](evidencias/sprint-N/captura-linea-base-frontend.png)

**Capturas del cierre (<AAAA-MM-DD>):**

![Regresión del backend](evidencias/sprint-N/captura-regresion-backend.png)

![Regresión del frontend](evidencias/sprint-N/captura-regresion-frontend.png)

**Duración del backend:** <N s al inicio y N s al cierre>.

**Fecha del cierre:** <AAAA-MM-DD>, sobre la rama `<rama>`. <Cuántas pruebas de la línea base se actualizaron o reemplazaron y por qué (con el ID del hallazgo)>. <Resultado del análisis estático, si aplica>.

## 9. Control de calidad final

Cinco requisitos funcionales del sprint, elegidos entre los que más pueden fallar (<temas>), con el mismo formato de la matriz de calidad del MVP.

| ID | Requisito | Criterio de Aceptación | Prueba ejecutada | Resultado | Evidencia / defecto |
|:--:|---|---|---|---|---|
| RF-01 | <Spec NNN, FR-0xx: texto del requisito.> | <Qué debe cumplirse, observable.> | <Capa (Jest + supertest, Flutter...): archivo de prueba, N casos.> | <Aprobado | Aprobado con observación> | [Requisito](#e-01-requisito) · [Prueba](#e-01-prueba) · [Resultado](#e-01-resultado). <Sin defectos | descripción del defecto u observación>. |
| RF-02 | | | | | |
| RF-03 | | | | | |
| RF-04 | | | | | |
| RF-05 | | | | | |

## 10. Cierre

| Campo | Valor |
|---|---|
| Criterios de salida cumplidos | <N de 5: lista> |
| Defectos abiertos | <Ninguno crítico, alto ni medio. Lista de los aceptados> |
| Observaciones | <tiempos medidos con la interfaz, observaciones de la matriz, límites conocidos> |
| Aprobado por | <nombre y rol> |
| Fecha | <AAAA-MM-DD> |

# Anexo de evidencias

Cada evidencia tiene tres bloques: **Requisito** (texto de la especificación con archivo y línea), **Prueba** (código o descripción) y **Resultado** (comando, salida real y captura). Las capturas están en `docs/evidencias/sprint-N/`.

## E-01 Requisito

Archivo: `specs/<carpeta-del-sprint>/spec.md`, líneas <N> a <M>.

> **FR-0xx**: <cita literal del requisito>

## E-01 Prueba

Archivo: `<ruta de la prueba>`, líneas <N> a <M>.

<Qué comprueba la prueba, con los datos de ejemplo y el resultado esperado.>

Fragmento clave:

```js
// <fragmento corto y representativo de la prueba>
```

## E-01 Resultado

Comando: `<comando que se ejecutó>`

Pasaron las <N> pruebas de <las suites>. <Si hubo recorrido manual o por API, qué escenario lo confirmó.>

![<Descripción de la captura>](evidencias/sprint-N/captura-<nombre>.png)

Resultado: **<Aprobado | Aprobado con observación | Fallido>** (<N de N casos>).

(Guía: repite los tres bloques E-02 a E-05, uno por cada requisito RF-02 a RF-05.)

## E-06 Recorrido de los escenarios contra la API real

Fecha: <AAAA-MM-DD>. <Cómo se arrancó la API, con qué base de datos y con qué cuentas.>

| # | Escenario | Resultado |
|---|-----------|-----------|
| 1 | <escenario del quickstart> | <qué se obtuvo> |

Resultado: **<Aprobado>** (<N de N escenarios>).

Alcance: <qué cubre esta comprobación y qué se hizo a mano en la aplicación, con sus tiempos y capturas>.
