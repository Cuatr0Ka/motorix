# Lista de calidad de requisitos de cobro y dinero: Precios de refacciones y cobro completo

**Propósito**: Validar la calidad de los requisitos de `spec.md` que tocan dinero (totales, instantáneas, límites), la compatibilidad con pagos y tickets anteriores, los permisos por rol y Mercado Pago. Es la puerta G-04 del aseguramiento de la calidad del Sprint 5.
**Creada**: 2026-10-31
**Funcionalidad**: [spec.md](../spec.md)

**Nota**: Esta lista de calidad la genera el comando `/speckit-checklist` a partir de la especificación. Evalúa si los requisitos están bien escritos, no si el sistema funciona.
**Responsable de la revisión**: Esta lista la revisa una persona. Marca un punto con `[x]` solo cuando la revisión confirma que el criterio de calidad del requisito se cumple.
**Significado de la marca**: `[x]` quiere decir que el criterio se revisó y se cumple en los requisitos. No quiere decir que la implementación esté terminada.
**Alcance y rigor**: Puerta formal previa a `/speckit.plan`. Profundidad estándar, con énfasis en dinero, compatibilidad con lo emitido, permisos por rol y Mercado Pago. No cubre rendimiento de interfaz ni accesibilidad más allá de lo indicado.

## Completitud de los requisitos de dinero

- [x] CHK001 ¿Está definido en qué momento se calcula el «total vigente» (al consultar, al registrar el pago o al generar el ticket) y cuál prevalece si cambia entre un paso y otro? [Ambigüedad, Spec §FR-005, §FR-006]
- [x] CHK002 ¿Se define qué ocurre si se agrega, quita o cambia la cantidad de una refacción mientras se registra el pago de esa misma orden? [Vacío, Escenario de concurrencia, Spec §FR-006, §FR-010]
- [x] CHK003 ¿Se define qué pasa con una orden que ya tiene un pago Pagado cuando después se agregan refacciones, dado que solo se permite un pago vigente y esos importes quedarían sin cobrar? [Vacío, Spec Casos límite, §FR-010]
- [x] CHK004 ¿Se especifica cómo se señala y se resuelve el cobro desfasado de un pago Pagado, y no solo el de un pago de Mercado Pago pendiente? [Vacío, Spec §FR-012]
- [x] CHK005 ¿Se define qué hace el sistema si Mercado Pago aprueba un pago después de que el total de la orden cambió y el pago quedó con el importe anterior? [Vacío, Excepción, Spec §FR-011, §FR-012]
- [x] CHK006 ¿Se indica qué roles pueden cancelar un pago de Mercado Pago desfasado y generar uno nuevo? [Vacío, Spec §FR-012]
- [x] CHK007 ¿Está especificado si un precio de venta de 0 es un valor válido o equivale a «sin precio» para efectos del bloqueo de agregar la refacción a una orden? [Ambigüedad, Spec §FR-002, §FR-020]
- [x] CHK008 ¿Se define la moneda de los importes y el formato en que se presentan (separadores y dos decimales) en el cobro, el ticket y el envío a Mercado Pago? [Vacío, Spec §FR-005, §FR-007, §FR-011]
- [x] CHK009 ¿Se define qué datos muestra el desglose del total para una línea con precio 0 de una orden anterior, de modo que no parezca un error de captura? [Vacío, Spec §FR-015, §FR-023]

## Claridad de los requisitos

- [x] CHK010 ¿Se usa un único término definido para el total («total vigente», «total de la orden», «total con refacciones»), o los tres pueden entenderse como cosas distintas? [Claridad, Spec §FR-005, §FR-006, §FR-021]
- [x] CHK011 ¿Está definido qué es una «orden abierta» y en qué estados se pueden modificar refacciones, en lugar de remitir a «mientras la orden permita modificar refacciones»? [Ambigüedad, Spec Casos límite, §FR-024]
- [x] CHK012 ¿Se cuantifica «sin errores de redondeo» en el requisito del total, o se sustituye por la regla que lo justifica (cantidad entera por precio de dos decimales)? [Medibilidad, Spec §FR-005, Casos límite]
- [x] CHK013 ¿Se define qué significa «instantánea» para una línea de orden (qué dato se guarda y cuándo), sin depender de que se entienda por el contexto? [Claridad, Spec §FR-004, Entidades clave]
- [x] CHK014 ¿Se define en qué consiste el «aviso y confirmación» de un precio de venta menor al de compra, de modo que se pueda verificar sin suponer el diseño de la pantalla? [Ambigüedad, Spec §FR-025]
- [x] CHK015 ¿Se precisa qué es «subtotal por concepto» en el ticket nuevo (servicios, mano de obra y refacciones) frente al «subtotal» que lista el contexto maestro? [Ambigüedad, Spec §FR-007]
- [x] CHK016 ¿Se define qué muestra «la indicación de que le falta el precio» en el inventario y quién la ve? [Ambigüedad, Spec Historia 2, escenario 6]
- [x] CHK017 ¿Se define qué significa que el panel y los listados «sigan funcionando y muestren el nuevo total», incluyendo qué indicadores del panel dependen del total? [Ambigüedad, Spec §FR-016]

## Consistencia de los requisitos

- [x] CHK018 ¿La historia 5 («Mantener reservado el precio de compra») es coherente con FR-014, que oculta al mecánico también el precio de venta? [Conflicto, Spec Historia 5, §FR-014]
- [x] CHK019 ¿Los permisos de la historia 5 (recepción sin precio de compra, administrador con ambos precios, mecánico sin ninguno) coinciden con FR-003, FR-013 y FR-014? [Consistencia, Spec §FR-003, §FR-013, §FR-014]
- [x] CHK020 ¿FR-015 (líneas anteriores con precio 0) y FR-020 (rechazar refacciones sin precio de venta) son consistentes en cómo distinguen «sin precio» de «precio 0»? [Conflicto, Spec §FR-015, §FR-020]
- [x] CHK021 ¿El caso límite de una orden Pagada a la que se agregan refacciones es coherente con FR-009 y FR-010, que impiden cambiar el importe de un pago y tener un segundo pago? [Conflicto, Spec Casos límite, §FR-009, §FR-010]
- [x] CHK022 ¿El tope de 9 999 999.99 se aplica igual en FR-002, FR-022 y el caso límite correspondiente, y coincide con el tope vigente de pagos de los sprints anteriores? [Consistencia, Spec §FR-002, §FR-022]
- [x] CHK023 ¿La suposición «el precio de compra solo lo ve el administrador» sigue siendo una suposición, cuando FR-013 ya la fija como requisito? [Suposición, Spec Suposiciones, §FR-013]
- [x] CHK024 ¿FR-019 («sin cambios de comportamiento» de los sprints 1 a 4) es compatible con FR-021, que cambia la regla de «nada que cobrar» del Sprint 4? [Conflicto, Spec §FR-019, §FR-021]

## Calidad de los criterios de éxito

- [x] CHK025 ¿SC-001 y SC-008 (2 y 3 minutos) indican quién los mide, con qué datos y bajo qué condiciones, o son metas sin forma de comprobarse? [Medibilidad, Spec §SC-001, §SC-008]
- [x] CHK026 ¿SC-002 define con qué conjunto de órdenes de prueba se mide el «100 %» y si incluye órdenes con líneas anteriores de precio 0? [Medibilidad, Spec §SC-002]
- [x] CHK027 ¿SC-007 se mantiene verificable cuando el número de pruebas crezca con el sprint, o depende de las cifras fijas de la línea base? [Medibilidad, Spec §SC-007]
- [x] CHK028 ¿Cada criterio de éxito se puede relacionar con al menos un requisito funcional y con los criterios de aceptación CA-1 a CA-14 del insumo del sprint? [Trazabilidad, Spec §SC-001 a §SC-008]
- [x] CHK029 ¿Existe un criterio de éxito para la reserva del precio de compra frente a recepción y mecánico en todos los puntos de consulta, no solo en «ninguna respuesta»? [Cobertura, Spec §SC-006]

## Cobertura de escenarios

- [x] CHK030 ¿Se enumeran todas las consultas donde podría aparecer el precio de compra (inventario, alertas de stock, movimientos, historial del vehículo, panel, órdenes, pagos y tickets) en lugar de decir «en ninguna consulta»? [Completitud, Spec §FR-013]
- [x] CHK031 ¿Se definen requisitos para la edición simultánea del precio de una refacción mientras se agrega a una orden, de modo que el precio guardado sea el esperado? [Vacío, Concurrencia, Spec §FR-004]
- [x] CHK032 ¿Se define el comportamiento cuando dos personas agregan líneas a la misma orden y juntas superan el tope del total? [Cobertura, Concurrencia, Spec §FR-022]
- [x] CHK033 ¿Se define el comportamiento de una refacción desactivada o sin existencias cuyo precio cambia mientras está en órdenes abiertas? [Cobertura, Spec Casos límite]
- [x] CHK034 ¿Se define si cambiar la cantidad de una línea (permitido por FR-024) está sujeto a los mismos controles de total, de stock y de permisos que agregarla? [Cobertura, Spec §FR-022, §FR-024]
- [x] CHK035 ¿Se define cómo se recupera la recepción cuando el cobro se rechaza por el tope del total o por una refacción sin precio, es decir, qué mensaje y qué paso siguiente se especifican? [Cobertura, Excepción, Spec §FR-020, §FR-022]

## Compatibilidad con pagos, tickets y datos anteriores

- [x] CHK036 ¿Se define cómo se identifica un ticket «anterior» frente a uno «nuevo» para mostrarlo con su formato original, sin depender de ver si trae precios? [Claridad, Spec §FR-008, Historia 4, escenario 1]
- [x] CHK037 ¿Se define si la migración de datos puede revertirse o qué se espera si falla a medias, dado que modifica refacciones y líneas de orden? [Vacío, Recuperación, Spec §FR-015]
- [x] CHK038 ¿Se especifica qué datos de ejemplo deben cubrir los casos de compatibilidad (refacción sin precio, línea anterior con precio 0, ticket anterior y un pago desfasado), además de la orden cobrable? [Completitud, Spec §FR-017]
- [x] CHK039 ¿Se define si los cambios de precio quedan registrados (quién y cuándo) o se declara expresamente que no hay historial de precios? [Vacío, Spec §FR-001]

## No funcionales, dependencias y suposiciones

- [x] CHK040 ¿Se define un requisito de tiempo de respuesta o de volumen para el cálculo del total y para los listados con el nuevo total, o se declara que no hay cambio respecto al Sprint 4? [Vacío, No funcional, Spec §FR-016]
- [ ] CHK041 ¿Está resuelta o asignada a una persona la enmienda de la constitución que permita un sprint posterior al MVP, de la que depende la especificación? [Dependencia, Spec Suposiciones]
- [x] CHK042 ¿Se define el entorno y los datos de Mercado Pago (modo de pruebas) con los que debe comprobarse el importe enviado y la cancelación del pago desfasado? [Dependencia, Spec §FR-011, §FR-012]

## Notas

- Marca un punto con `[x]` solo después de que la revisión confirme que el criterio de calidad del requisito se cumple.
- Deja el punto sin marcar si todavía requiere aclaración, corrección o evaluación de la persona que revisa.
- `/speckit-implement` lee el estado de esta lista como una puerta y no modifica las marcas.
- `checklists/requirements.md` tiene un ciclo aparte que mantienen `/speckit-specify` y `/speckit-clarify`.
- Los puntos que resulten en un cambio de la especificación se registran como hallazgos en la sección 7 de `docs/aseguramiento-calidad-sprint-5.md`.
- Los puntos están numerados de forma consecutiva para poder citarlos.
