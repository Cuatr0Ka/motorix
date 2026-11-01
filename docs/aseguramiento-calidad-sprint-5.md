# Aseguramiento de la calidad - Sprint 5: Precios de refacciones y cobro completo

Este documento es el registro de calidad del Sprint 5. Se llena durante la preparación, antes de ejecutar `/speckit.implement`, y se completa al cierre del sprint. Al terminar se pasa a Word.

**Estados permitidos:** Pendiente · En curso · Aprobado · Aprobado con observación · Fallido · No aplica.

## 0. Datos del documento

| Campo | Valor |
|---|---|
| Sprint | 5 - Precios de refacciones y cobro completo |
| Insumo | `docs/sprints/sprint-5-precios-refacciones-cobro.md` |
| Rama | (por definir al ejecutar `/speckit.specify`) |
| Responsable | |
| Fecha de inicio | |
| Fecha de cierre | |
| Estado general | Pendiente |

## 1. Objetivo y alcance

**Objetivo.** Asegurar que el Sprint 5 salga con calidad: que los requisitos estén completos, sean medibles y no se contradigan, que las pruebas estén planeadas antes del código y que el cambio no rompa lo construido en los sprints 1 a 4.

**Dentro del alcance:** categoría, marca y precios de las refacciones; total de la orden con refacciones; pago y ticket con el nuevo total; conservación de pagos y tickets ya emitidos; visibilidad del precio de compra por rol.

**Fuera del alcance:** lo que el insumo del sprint lista en su sección 8 (costeo, impuestos, descuentos, reembolsos, notificaciones, reportes, WhatsApp y puesta en producción).

## 2. Criterios de entrada y de salida

**Entrada (para permitir `/speckit.implement`):**

- [ ] Las 8 puertas de la sección 3 están Aprobadas o Aprobadas con observación.
- [ ] Las 10 decisiones de la sección 4 están resueltas y registradas.
- [ ] No hay hallazgos críticos ni altos abiertos en `/speckit.analyze`.
- [ ] Cada criterio de aceptación tiene al menos una prueba planeada (sección 6).
- [ ] La línea base de regresión está registrada (sección 8).
- [ ] La documentación desfasada de los sprints anteriores está identificada.

**Salida (para cerrar el sprint):**

- [ ] Los 14 criterios de aceptación están Aprobados.
- [ ] Todas las pruebas de los sprints 1 a 4 siguen pasando.
- [ ] No hay defectos críticos ni altos abiertos (sección 7).
- [ ] La matriz de calidad final (sección 9) está completa, con evidencia.
- [ ] Reporte, análisis y matriz no se contradicen.

## 3. Puertas de calidad

| ID | Puerta | Cómo se verifica | Criterio de paso | Estado | Fecha | Evidencia |
|:--:|---|---|---|---|---|---|
| G-01 | Insumo del sprint revisado | Lectura contra el código y el contexto maestro | Sin contradicciones con `project-context.md`; decisiones abiertas listadas | Pendiente | | |
| G-02 | Especificación (`/speckit.specify`) | `specs/005-*/spec.md` | Historias en formato "Como... quiero... para..." y escenarios Dado / Cuando / Entonces | Pendiente | | |
| G-03 | Aclaraciones (`/speckit.clarify`) | Sección 4 de este documento | Cero marcadores `[NEEDS CLARIFICATION]` y 10 decisiones registradas | Pendiente | | |
| G-04 | Lista de calidad de requisitos (`/speckit.checklist`) | `specs/005-*/checklists/` | Requisitos completos, medibles, sin ambigüedad ni contradicción | Pendiente | | |
| G-05 | Plan (`/speckit.plan`) | `plan.md`, `data-model.md`, `contracts/` | Cumple la constitución; migración `005` aditiva; contratos de API definidos | Pendiente | | |
| G-06 | Tareas (`/speckit.tasks`) | `tasks.md` | Tareas ordenadas, con las pruebas antes del código y cobertura de cada historia | Pendiente | | |
| G-07 | Consistencia (`/speckit.analyze`) | Informe del análisis | Sin hallazgos críticos ni altos; todo requisito con tarea y toda tarea con requisito | Pendiente | | |
| G-08 | Pruebas planeadas y línea base | Secciones 6 y 8 | Cada criterio de aceptación con prueba; regresión de los sprints 1 a 4 registrada | Pendiente | | |

## 4. Decisiones de aclaración

Las 10 decisiones pendientes de la sección 9 del insumo del sprint. No se asumen: se resuelven en `/speckit.clarify` y se anotan aquí.

| ID | Decisión pendiente | Resolución | Decidió | Fecha | Requisito afectado |
|:--:|---|---|---|---|---|
| D-01 | Refacciones existentes y líneas ya registradas sin precio: ¿se asigna 0, se exige capturar el precio o se bloquea agregarlas a una orden? | | | | |
| D-02 | Orden con solo refacciones: hoy se rechaza con `NOTHING_TO_CHARGE`. ¿Pasa a ser cobrable? | | | | |
| D-03 | Órdenes abiertas al desplegar: ¿qué precio toman sus refacciones ya agregadas? | | | | |
| D-04 | Pago de Mercado Pago pendiente cuando cambia el total: ¿se cancela, se actualiza o se marca como desfasado? | | | | |
| D-05 | Corrección del precio de una línea de una orden abierta: ¿se permite y con qué permiso o motivo? | | | | |
| D-06 | Categoría: ¿lista cerrada administrable o texto libre? Marca: ¿texto libre? | | | | |
| D-07 | Precio de venta menor al de compra: ¿se permite, se advierte o se rechaza? | | | | |
| D-08 | Redondeo del importe de una línea y límites máximos de precio y de total. | | | | |
| D-09 | Cómo se muestran los tickets anteriores (sin precio de refacciones) junto a los nuevos. | | | | |
| D-10 | Visibilidad del precio de venta para el mecánico. | | | | |

## 5. Riesgos y mitigaciones

| ID | Riesgo | Impacto | Mitigación | Prueba que lo cubre | Estado |
|:--:|---|---|---|---|---|
| R-01 | Un cambio de precio altera órdenes abiertas o documentos ya emitidos | Alto: importes incorrectos en el historial | Guardar el precio de venta en `order_parts` al agregar la refacción | | Pendiente |
| R-02 | Los pagos y tickets anteriores se muestran mal o cambian de importe | Alto | Migración aditiva; no tocar `payments` ni `tickets.content` existentes | | Pendiente |
| R-03 | Se rompe el pago único vigente al cambiar el cálculo del total (RF-05 de la matriz anterior) | Alto | Mantener las pruebas de concurrencia y de segundo pago | | Pendiente |
| R-04 | Un pago pendiente de Mercado Pago queda con un importe distinto al total | Medio | Aplicar la decisión D-04 y probar `amountOutdated` | | Pendiente |
| R-05 | El precio de compra llega al mecánico o a recepción por la API | Alto: fuga de información financiera | Proyecciones por rol en el backend y pruebas de permisos | | Pendiente |
| R-06 | Errores de redondeo en el importe de una línea | Medio | Cálculo en centavos enteros y pruebas de borde | | Pendiente |
| R-07 | Una orden con solo refacciones queda incobrable o se cobra en cero | Medio | Aplicar la decisión D-02 y ajustar `assertOrderPayable` con pruebas | | Pendiente |
| R-08 | La documentación vuelve a desfasarse del código (como el panel de 4 y 10 indicadores) | Bajo: confusión y contradicciones | Actualizar `project-context.md` y `design-system.md` dentro del sprint (CA-14) | | Pendiente |
| R-09 | El panel de control o los listados fallan con el nuevo total | Medio | Pruebas de regresión del dashboard y de los listados de órdenes y pagos | | Pendiente |

## 6. Trazabilidad

Se llena después de `/speckit.tasks` y se actualiza durante la implementación. Cada criterio de aceptación debe llegar a un resultado verificado.

| CA | Criterio de aceptación (resumen) | Requisito (FR) | Tarea | Prueba | Resultado | Evidencia |
|:--:|---|---|---|---|---|---|
| CA-1 | Refacción con categoría, marca y precios persistidos | | | | Pendiente | |
| CA-2 | Validación de precios (negativos, no numéricos, decimales, límites) | | | | Pendiente | |
| CA-3 | El precio vigente se guarda al agregar la refacción a una orden | | | | Pendiente | |
| CA-4 | Total = servicios + mano de obra + refacciones, en centavos | | | | Pendiente | |
| CA-5 | El pago se registra por el nuevo total; importe distinto se rechaza | | | | Pendiente | |
| CA-6 | Pagos y tickets anteriores conservan importe y contenido | | | | Pendiente | |
| CA-7 | El ticket nuevo detalla las refacciones, subtotal y total | | | | Pendiente | |
| CA-8 | Un solo pago vigente, incluso con solicitudes simultáneas; sin datos de tarjeta | | | | Pendiente | |
| CA-9 | Mercado Pago recibe el importe correcto; pago pendiente desfasado resuelto | | | | Pendiente | |
| CA-10 | El precio de compra solo lo ve el administrador | | | | Pendiente | |
| CA-11 | Dashboard y listados funcionan con el nuevo total | | | | Pendiente | |
| CA-12 | Seeds con precios y una orden cobrable con refacciones, idempotentes | | | | Pendiente | |
| CA-13 | Pruebas de total, instantáneas, redondeo, permisos, concurrencia y compatibilidad | | | | Pendiente | |
| CA-14 | Documentación del proyecto actualizada | | | | Pendiente | |

## 7. Hallazgos y defectos

Se registra todo lo que se encuentre, sea en los documentos, en el análisis o en las pruebas.

| ID | Descripción | Severidad (crítica, alta, media, baja) | Origen (puerta o prueba) | Estado | Resolución | Evidencia |
|:--:|---|---|---|---|---|---|
| H-01 | | | | | | |

## 8. Línea base de regresión

Se ejecuta la suite completa **antes** de tocar el código y de nuevo **al cierre**. Ninguna prueba de los sprints 1 a 4 debe pasar de verde a rojo.

| Suite | Comando | Antes del sprint 5 | Después del sprint 5 | Diferencia | Evidencia |
|---|---|---|---|---|---|
| Backend (Jest) | `npm test` en `server/` | 67 suites y 1003 pruebas aprobadas, 0 fallidas | | | [Resultado backend](#e-00-resultado-del-backend) |
| Frontend (Flutter) | `flutter test` en `client/` | 277 pruebas aprobadas ("All tests passed!"), 0 fallidas | | | [Resultado frontend](#e-00-resultado-del-frontend) |

**Fecha de la línea base:** 2026-10-31, sobre el commit `4fdfaf1` de la rama `004-pagos-tickets-dashboard`, antes de crear la rama del Sprint 5.

**Duración del backend:** 133 s.

## 9. Control de calidad final

Se llena al cerrar el sprint, con el mismo formato de la matriz de calidad del MVP: al menos 5 requisitos funcionales del sprint 5, con prioridad en los que pueden fallar (instantáneas, redondeo, concurrencia, permisos por rol y compatibilidad con tickets anteriores).

| ID | Requisito | Criterio de Aceptación | Prueba ejecutada | Resultado | Evidencia / defecto |
|:--:|---|---|---|---|---|
| RF-01 | | | | | |
| RF-02 | | | | | |
| RF-03 | | | | | |
| RF-04 | | | | | |
| RF-05 | | | | | |

## 10. Cierre

| Campo | Valor |
|---|---|
| Criterios de salida cumplidos | |
| Defectos abiertos | |
| Observaciones | |
| Aprobado por | |
| Fecha | |

# Anexo de evidencias

Cada evidencia tiene tres bloques, como en la matriz de calidad del MVP: **Requisito** (texto del spec con archivo y línea), **Prueba** (código o descripción) y **Resultado** (comando, salida real y captura). Las capturas se guardan en `docs/evidencias/sprint-5/` con nombres en minúsculas y guiones, por ejemplo `captura-total-con-refacciones.png`.

## E-00 Resultado del backend

Línea base del 2026-10-31, commit `4fdfaf1`, antes del Sprint 5.

Comando: `npm test` en `server/`

Pasaron las 67 suites y las 1003 pruebas; no hubo fallos.

![Línea base del backend](evidencias/sprint-5/captura-linea-base-backend.png)

Resultado: **Aprobado** (1003 de 1003 pruebas).

## E-00 Resultado del frontend

Línea base del 2026-10-31, commit `4fdfaf1`, antes del Sprint 5.

Comando: `flutter test` en `client/`

Pasaron las 277 pruebas; no hubo fallos.

![Línea base del frontend](evidencias/sprint-5/captura-linea-base-frontend.png)

Resultado: **Aprobado** (277 de 277 pruebas).

## Modelo para nuevas evidencias

Para agregar una evidencia, copia el modelo siguiente, cambia el identificador y enlaza los tres bloques desde la columna de evidencia de la tabla correspondiente: `[Requisito](#e-01-requisito) · [Prueba](#e-01-prueba) · [Resultado](#e-01-resultado)`.

## E-01 Requisito

Archivo: `specs/005-.../spec.md`, línea N.

> (cita literal del requisito)

## E-01 Prueba

Archivo: `server/tests/...`, líneas N a M.

(qué comprueba la prueba y fragmento clave)

## E-01 Resultado

Comando: `npm test -- ...`

(salida real de la ejecución)

![Descripción de la captura](evidencias/sprint-5/captura-nombre.png)

Resultado: **Pendiente**
