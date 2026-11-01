# Especificación de la funcionalidad: Precios de refacciones y cobro completo (Sprint 5)

**Rama de la funcionalidad**: `005-precios-refacciones-cobro`

**Creada**: 2026-10-31

**Estado**: Borrador

**Entrada**: Descripción del usuario: "Usa como insumo docs/sprints/sprint-5-precios-refacciones-cobro.md"

## Aclaraciones

### Sesión 2026-10-31 (primera ronda)

- Q: ¿Qué debe pasar cuando se intenta agregar a una orden una refacción sin precio de venta? → A: Se bloquea agregarla hasta que el administrador le capture el precio de venta (D-01).
- Q: ¿Se puede cobrar una orden que solo tiene refacciones, sin servicios ni mano de obra? → A: Sí; se puede cobrar cualquier orden Terminada o Entregada cuyo total, con refacciones, sea mayor a cero (D-02).
- Q: Si el total de una orden cambia mientras un pago de Mercado Pago sigue pendiente, ¿qué debe hacer el sistema con ese pago? → A: Lo señala como desfasado y la recepción lo cancela con confirmación para generar uno nuevo con el total vigente; no es automático (D-04).
- Q: ¿Qué ve el mecánico de los precios de las refacciones: nada, o solo el precio de venta? → A: Ningún precio; conserva la vista reducida actual (código, nombre, unidad y existencia) (D-10).
- Q: Las refacciones ya agregadas a órdenes abiertas antes de este sprint no tienen precio guardado. ¿Cómo deben contar en el total de esas órdenes? → A: Cuentan con precio 0 y no suman al total; solo suman las líneas agregadas desde el sprint, así ningún total, pago ni ticket existente cambia (D-03).

### Sesión 2026-10-31 (segunda ronda)

- Q: ¿Cuál debe ser el precio máximo de una refacción y el máximo del total de una orden? → A: Ambos hasta 9 999 999.99, el mismo tope de servicios, mano de obra y pagos; se rechaza agregar una línea que lo supere (D-08).
- Q: ¿Cómo debe verse un ticket emitido antes de este sprint, que lista las refacciones sin precio, junto a los tickets nuevos que sí traen precios? → A: Los anteriores se muestran e imprimen exactamente como se emitieron (refacciones solo con cantidad); los nuevos muestran precio e importe (D-09).
- Q: Si antes del sprint la recepción cobraba una pieza capturándola como un servicio de la orden, ¿cómo se evita cobrarla otra vez como refacción? → A: No se detecta de forma automática; la pantalla de cobro muestra el desglose del total para que la recepción lo revise y se documenta que las piezas ya no se capturan como servicio.
- Q: ¿Cómo se corrige el precio de una línea de refacción en una orden abierta, por ejemplo una que quedó en 0? → A: El precio de una línea no se edita; se quita la línea y se vuelve a agregar con el precio vigente, mientras la orden permita modificar refacciones (D-05).
- Q: ¿La categoría de una refacción se escribe libremente o se elige de una lista? → A: Texto libre, igual que la marca, con longitud máxima y sin catálogo; el inventario puede buscar por ambas (D-06).

### Sesión 2026-10-31 (tercera ronda)

- Q: Si el administrador guarda una refacción con precio de venta menor al precio de compra, ¿qué debe hacer el sistema? → A: Se permite, pero avisa de la posible venta bajo el costo y pide confirmación antes de guardar (D-07).

## Escenarios de usuario y pruebas *(obligatorio)*

### Historia de usuario 1 - Registrar categoría, marca y precios de una refacción (Prioridad: P1)

Como administrador, quiero registrar la categoría, la marca y los precios de compra y de venta de una
refacción para conocer el costo y el precio de cada pieza del taller.

**Por qué esta prioridad**: Sin precios en las refacciones no hay nada que sumar al cobro; es la base de todo
el sprint.

**Prueba independiente**: El administrador crea una refacción con categoría, marca, precio de compra y precio
de venta, la edita y la consulta, y verifica que los datos se conservan.

**Escenarios de aceptación**:

1. **Dado** que soy administrador, **cuando** registro una refacción con categoría, marca, precio de compra y
   precio de venta válidos, **entonces** queda guardada y la veo con esos datos en el inventario y en su detalle.
2. **Dado** una refacción existente, **cuando** edito su categoría, su marca o sus precios, **entonces** los
   cambios se guardan y el código y la existencia no se alteran.
3. **Dado** un precio negativo, no numérico o con más de dos decimales, **cuando** intento guardarlo,
   **entonces** el sistema lo rechaza indicando el campo y el motivo.
4. **Dado** un precio por encima de 9 999 999.99, **cuando** intento guardarlo, **entonces** el sistema lo
   rechaza indicando el límite.
5. **Dado** un precio de venta menor al de compra, **cuando** intento guardarlo, **entonces** el sistema me
   avisa de la posible venta bajo el costo y guarda solo si lo confirmo.
6. **Dado** que soy recepcionista o mecánico, **cuando** intento crear o editar los precios de una refacción,
   **entonces** el sistema lo rechaza; solo el administrador gestiona precios.

---

### Historia de usuario 2 - Cobrar las refacciones utilizadas dentro del total de la orden (Prioridad: P1)

Como recepcionista, quiero que el total de la orden incluya las refacciones utilizadas para cobrar el trabajo
completo y no solo los servicios y la mano de obra.

**Por qué esta prioridad**: Corrige el vacío principal del MVP: hoy una pieza usada no se cobra a menos que
se capture como servicio.

**Prueba independiente**: Con una orden Terminada que tiene un servicio, mano de obra y dos refacciones con
precio, la recepcionista consulta el total y verifica que es la suma de los tres conceptos.

**Escenarios de aceptación**:

1. **Dado** una orden con servicios, mano de obra y refacciones con precio, **cuando** consulto su total,
   **entonces** el total es la suma de servicios, mano de obra y de cada refacción (cantidad por precio de
   venta).
2. **Dado** que agrego una refacción a una orden, **cuando** el sistema la registra, **entonces** conserva el
   precio de venta vigente en ese momento como el precio de esa línea.
3. **Dado** que el administrador cambia después el precio de venta de esa refacción, **cuando** consulto la
   orden, **entonces** la línea conserva su precio original y el total de la orden no cambia.
4. **Dado** una línea con cantidad mayor a uno, **cuando** se calcula su importe, **entonces** es la cantidad
   por el precio de la línea, con dos decimales y sin errores de redondeo en el total.
5. **Dado** una orden sin servicios ni mano de obra pero con refacciones con precio, **cuando** consulto su
   total, **entonces** el total es el de las refacciones y la orden se puede cobrar; solo se rechaza el cobro
   cuando el total con refacciones es cero.
6. **Dado** una refacción sin precio de venta, **cuando** intento agregarla a una orden, **entonces** el
   sistema lo rechaza indicando que primero el administrador debe capturar su precio de venta; la refacción
   sigue visible en el inventario con la indicación de que le falta el precio.

---

### Historia de usuario 3 - Registrar el pago y entregar un ticket con el total correcto (Prioridad: P1)

Como recepcionista, quiero que el pago y el ticket reflejen el nuevo total para entregar al cliente un
comprobante correcto.

**Por qué esta prioridad**: El dinero cobrado y el comprobante deben coincidir con el trabajo realizado; si no,
el sprint no cumple su objetivo.

**Prueba independiente**: Con la orden de la historia 2, la recepcionista registra el pago en efectivo, genera
el ticket y verifica que el importe del pago y el total del ticket incluyen las refacciones.

**Escenarios de aceptación**:

1. **Dado** una orden Terminada con refacciones con precio, **cuando** registro un pago, **entonces** el
   importe es el total con refacciones.
2. **Dado** un importe enviado que no coincide con el total vigente, **cuando** intento registrar el pago,
   **entonces** el sistema lo rechaza indicando el total a cobrar.
3. **Dado** un pago registrado, **cuando** genero el ticket, **entonces** muestra cada refacción con su
   cantidad, precio e importe, además del subtotal por concepto y el total.
4. **Dado** una orden con un pago vigente, **cuando** llega un segundo cobro, incluso al mismo tiempo que
   otro, **entonces** solo uno queda vigente y los demás se rechazan.
5. **Dado** un cobro con Mercado Pago, **cuando** se inicia, **entonces** el importe enviado al proveedor es
   el total con refacciones y el sistema sigue sin guardar datos de tarjeta.
6. **Dado** un pago de Mercado Pago pendiente cuyo importe ya no coincide con el total de la orden, **cuando**
   intento cobrar o consulto la orden, **entonces** el sistema me indica que el importe quedó desfasado y me
   permite cancelar ese pago pendiente con confirmación; el pago cancelado se conserva en el historial y puedo
   generar uno nuevo con el total vigente. El sistema no cancela ni crea pagos por sí solo.

---

### Historia de usuario 4 - Conservar sin cambios los pagos y tickets ya emitidos (Prioridad: P1)

Como administrador, quiero que un cambio de precio no altere órdenes abiertas ni pagos y tickets ya emitidos
para conservar la integridad del historial.

**Por qué esta prioridad**: Un comprobante o un pago que cambia de importe después de emitido invalida el
historial financiero del taller.

**Prueba independiente**: Con un pago y un ticket emitidos antes del sprint, se verifica que conservan su
importe y contenido y que siguen consultándose y mostrándose; luego se cambia el precio de una refacción y se
verifica que un pago y un ticket nuevos emitidos antes del cambio tampoco se alteran.

**Escenarios de aceptación**:

1. **Dado** pagos y tickets generados antes de este sprint, **cuando** los consulto o los imprimo, **entonces**
   conservan su importe y su contenido y se muestran e imprimen exactamente como se emitieron, con las
   refacciones solo con su cantidad y sin leyendas ni columnas agregadas.
2. **Dado** un pago y un ticket emitidos con precios vigentes, **cuando** el administrador cambia el precio de
   una refacción, **entonces** el pago y el ticket conservan su importe.
3. **Dado** una orden ya Entregada, **cuando** cambia el precio de sus refacciones, **entonces** la orden se
   conserva como historial con los importes con que se cobró.
4. **Dado** órdenes abiertas al activar esta funcionalidad con refacciones ya agregadas, **cuando** consulto
   su total, **entonces** esas líneas anteriores cuentan con precio 0 y no suman al total, de modo que ningún
   total, pago ni ticket existente cambia; solo suman las líneas agregadas desde este sprint.

---

### Historia de usuario 5 - Mantener reservado el precio de compra (Prioridad: P2)

Como mecánico, quiero seguir usando las refacciones en una orden sin ver los precios de compra para no exponer
información financiera del taller.

**Por qué esta prioridad**: Protege información sensible, pero el cobro funciona sin ella; por eso va después
del flujo principal.

**Prueba independiente**: Se consulta el inventario y las refacciones de una orden con cada rol y se verifica
que el precio de compra solo llega al administrador.

**Escenarios de aceptación**:

1. **Dado** que soy mecánico, **cuando** agrego refacciones a una orden y consulto el inventario, **entonces**
   puedo hacerlo sin ver el precio de compra.
2. **Dado** que soy recepcionista, **cuando** consulto refacciones, órdenes, pagos y tickets, **entonces** no
   recibo el precio de compra de ninguna refacción.
3. **Dado** que soy administrador, **cuando** consulto una refacción, **entonces** veo ambos precios.
4. **Dado** que soy mecánico, **cuando** consulto el precio de venta de una refacción,
   **entonces** el sistema no me muestra ningún precio; solo veo código, nombre, unidad y existencia, y el
   servidor no los incluye en sus respuestas.

---

### Casos límite

- **Pieza ya cobrada como servicio**: antes de este sprint la recepción capturaba una pieza como servicio de
  la orden (acuerdo del Sprint 4). Con las refacciones sumando al total, una orden podría cobrar la misma pieza
  dos veces. El sistema no lo detecta de forma automática: la pantalla de cobro muestra el desglose del total
  (servicios, mano de obra y refacciones) para que la recepción lo revise, y se documenta que desde este sprint
  las piezas ya no se capturan como servicio.
- Refacción cuyo precio de venta es menor al de compra: se permite, pero el sistema avisa de la posible venta
  bajo el costo y pide confirmación antes de guardar.
- Cantidad grande por precio alto que haría pasar el total de la orden de 9 999 999.99: se rechaza agregar o
  aumentar esa línea indicando el límite, para que la orden siga siendo cobrable.
- Importes de línea: la cantidad es un entero y el precio tiene dos decimales, así que el importe de cada línea
  siempre tiene dos decimales exactos y el total coincide con la suma de las líneas mostradas.
- Corrección del precio de una línea de una orden abierta: el precio de una línea no se edita; se quita la
  línea (se devuelve el stock) y se vuelve a agregar con el precio vigente, mientras la orden permita
  modificar refacciones.
- Refacción desactivada con líneas en órdenes existentes: las líneas conservan su precio.
- Orden con pago Pagado a la que se agregan refacciones después: el pago conserva su importe y la orden queda
  con el cobro desfasado visible.
- Tickets anteriores sin precios junto a tickets nuevos con precios en el mismo listado: cada uno se muestra en
  el formato con que se emitió, sin convertir los anteriores.
- Seeds corridos por segunda vez: no duplican refacciones ni precios.

## Requisitos *(obligatorio)*

### Requisitos funcionales

- **FR-001**: El sistema DEBE permitir registrar y editar, para cada refacción, su categoría, su marca, su
  precio de compra y su precio de venta. Categoría y marca son texto libre, de hasta 60 caracteres, sin
  catálogo, y el inventario DEBE poder buscar también por ellas.
- **FR-002**: El sistema DEBE validar los precios en el servidor: no negativos, numéricos, con a lo sumo dos
  decimales y con un máximo de 9 999 999.99 (el mismo tope de servicios, mano de obra y pagos); los rechazos
  indican el campo y el motivo.
- **FR-003**: Solo el administrador DEBE poder crear o editar categoría, marca y precios de una refacción.
- **FR-004**: Al agregar una refacción a una orden, el sistema DEBE guardar en esa línea el precio de venta
  vigente en ese momento; los cambios posteriores del precio de la refacción NO DEBEN modificar la línea.
- **FR-005**: El total de una orden DEBE ser la suma de servicios, mano de obra y refacciones (cantidad por
  precio de la línea), calculado sin errores de redondeo y con dos decimales.
- **FR-006**: El pago de una orden DEBE registrarse por el total vigente con refacciones; un importe distinto
  se rechaza indicando el total.
- **FR-007**: El ticket nuevo DEBE detallar cada refacción con cantidad, precio e importe, e incluir subtotal
  por concepto y total.
- **FR-008**: Los pagos y tickets generados antes de este sprint DEBEN conservar su importe y su contenido sin
  cambios y seguir consultándose e imprimiéndose exactamente como se emitieron; solo los tickets nuevos
  muestran precio e importe de las refacciones.
- **FR-009**: Un pago o ticket ya emitido NO DEBE cambiar de importe por cambios posteriores en los precios de
  las refacciones.
- **FR-010**: El sistema DEBE mantener que una orden tenga a lo sumo un pago vigente (Pendiente o Pagado),
  también ante solicitudes simultáneas, y NO DEBE almacenar datos de tarjeta.
- **FR-011**: El importe enviado a Mercado Pago DEBE ser el total con refacciones.
- **FR-012**: El sistema DEBE señalar como desfasado un pago de Mercado Pago pendiente cuyo importe ya no
  coincide con el total, y permitir cancelarlo (con confirmación, conservándolo como Cancelado en el historial)
  para generar uno nuevo con el total vigente; NO DEBE cancelarlo ni crearlo automáticamente.
- **FR-013**: El precio de compra DEBE ser visible solo para el administrador; el servidor NO DEBE enviarlo a
  recepción ni al mecánico en ninguna consulta.
- **FR-014**: El mecánico DEBE seguir pudiendo agregar refacciones a una orden y consultar el inventario con
  la información reducida que ya tenía (código, nombre, unidad y existencia), sin ningún precio: ni el de
  compra ni el de venta.
- **FR-015**: Las refacciones existentes antes de este sprint DEBEN conservarse sin precio de venta hasta que
  el administrador lo capture, y las líneas de orden existentes antes de este sprint DEBEN conservarse con
  precio 0 (sin sumar al total), sin perder datos ni modificar pagos y tickets previos.
- **FR-016**: El panel de control, los listados de órdenes y los listados de pagos DEBEN seguir funcionando y
  mostrar el nuevo total.
- **FR-017**: Los datos de ejemplo del sprint DEBEN incluir refacciones con categoría, marca y precios, y al
  menos una orden cobrable con refacciones; DEBEN poder cargarse varias veces sin duplicar registros.
- **FR-018**: La documentación del proyecto (contexto maestro y sistema de diseño) y los comentarios que
  afirman que las refacciones no suman importe DEBEN actualizarse dentro del sprint.
- **FR-019**: Las reglas de los sprints 1 a 4 (stock no negativo, salida de inventario al usar una refacción,
  permisos por rol, pago único vigente) DEBEN seguir cumpliéndose sin cambios de comportamiento.
- **FR-020**: El sistema DEBE rechazar agregar a una orden una refacción sin precio de venta, indicando el
  motivo; el precio de compra no es obligatorio para poder usarla.
- **FR-021**: El sistema DEBE considerar cobrable una orden Terminada o Entregada cuyo total con refacciones
  sea mayor a cero, aunque no tenga servicios ni mano de obra, y rechazar el cobro solo cuando ese total sea
  cero.
- **FR-022**: El sistema DEBE rechazar agregar o aumentar una línea de refacción cuando el total de la orden
  pasaría de 9 999 999.99, indicando el límite, y NO DEBE modificar el tope del pago de los sprints anteriores.
- **FR-023**: La consulta del cobro de una orden DEBE mostrar el desglose del total (servicios, mano de obra y
  refacciones con su cantidad, precio e importe) para que la recepción lo revise antes de registrar el pago; el
  sistema NO DEBE intentar detectar piezas capturadas como servicio.
- **FR-024**: El sistema NO DEBE permitir editar el precio guardado en una línea de refacción de una orden.
  Para corregirlo, se quita la línea y se vuelve a agregar, de modo que toma el precio de venta vigente; la
  cantidad de una línea puede seguir cambiando y conserva el precio guardado.
- **FR-025**: Cuando el precio de venta de una refacción sea menor a su precio de compra, el sistema DEBE
  avisar de la posible venta bajo el costo y guardar solo tras la confirmación del administrador; NO DEBE
  rechazarlo.

### Entidades clave *(incluir si la funcionalidad involucra datos)*

- **Refacción**: pieza del inventario. Se le agregan categoría, marca, precio de compra y precio de venta; ya
  tiene código, nombre, descripción, unidad, existencia, mínimo y estado activo.
- **Línea de refacción de la orden**: uso de una refacción en una orden, con su cantidad y, desde este sprint,
  el precio de venta vigente al momento de agregarla (instantánea).
- **Orden de servicio**: su total pasa a incluir las refacciones; el total se calcula y no se guarda en la
  orden.
- **Pago**: cobro de una orden por el total vigente; conserva el importe con que se registró.
- **Ticket**: comprobante instantánea del cobro; los emitidos antes del sprint no traen precios de refacciones.

## Criterios de éxito *(obligatorio)*

### Resultados medibles

- **SC-001**: Una refacción con categoría, marca y ambos precios se registra en menos de 2 minutos.
- **SC-002**: En el 100 % de las órdenes de prueba con refacciones, el total consultado, el importe del pago y
  el total del ticket coinciden entre sí.
- **SC-003**: El 100 % de los pagos y tickets existentes antes del sprint conserva el mismo importe y contenido
  tras activar la funcionalidad.
- **SC-004**: Después de cambiar el precio de una refacción, el 100 % de las órdenes, pagos y tickets ya
  emitidos conserva sus importes originales.
- **SC-005**: Con cinco cobros simultáneos sobre una misma orden, queda exactamente un pago vigente.
- **SC-006**: En ninguna respuesta del servidor a recepción o al mecánico aparece el precio de compra.
- **SC-007**: Toda prueba de los sprints 1 a 4 que pasaba antes del sprint (1003 de backend y 277 de frontend
  en la línea base del 2026-10-31) sigue pasando al cierre.
- **SC-008**: La recepción cobra una orden con refacciones, de la consulta del total al ticket, en menos de 3
  minutos.

## Decisiones pendientes para /speckit.clarify

Vienen de la sección 9 del insumo y no se asumen en esta especificación. Ninguna tiene valor por omisión. Se
resuelven en `/speckit.clarify` y se marcan aquí como resueltas al registrarse en la sección Aclaraciones:

- **D-01** *(resuelta el 2026-10-31)*: Refacción sin precio de venta: se bloquea agregarla a una orden hasta
  que el administrador capture el precio.
- **D-02** *(resuelta el 2026-10-31)*: Orden con solo refacciones: es cobrable si su total con refacciones es
  mayor a cero.
- **D-03** *(resuelta el 2026-10-31)*: Órdenes abiertas al activar: sus refacciones ya agregadas cuentan con
  precio 0 y no suman al total.
- **D-04** *(resuelta el 2026-10-31)*: Pago de Mercado Pago pendiente cuando cambia el total: se señala como
  desfasado y la recepción lo cancela con confirmación para generar uno nuevo; no es automático.
- **D-05** *(resuelta el 2026-10-31)*: Corrección del precio de una línea: no se edita; se quita y se vuelve a
  agregar con el precio vigente, mientras la orden permita modificar refacciones.
- **D-06** *(resuelta el 2026-10-31)*: Categoría y marca son texto libre de hasta 60 caracteres, sin catálogo.
- **D-07** *(resuelta el 2026-10-31)*: Precio de venta menor al de compra: se permite, con aviso y
  confirmación antes de guardar.
- **D-08** *(resuelta el 2026-10-31)*: Límites: precio de refacción y total de la orden hasta 9 999 999.99. El
  redondeo no aplica: cantidad entera por precio de dos decimales da siempre dos decimales exactos.
- **D-09** *(resuelta el 2026-10-31)*: Tickets anteriores (sin precios) junto a los nuevos: se muestran e
  imprimen como se emitieron; solo los nuevos llevan precio e importe.
- **D-10** *(resuelta el 2026-10-31)*: Visibilidad de precios para el mecánico: no ve ninguno; conserva la
  vista reducida actual.

## Suposiciones

- Este sprint es posterior al MVP. La constitución (principio I) fija los sprints 1 a 4 y exige aprobación del
  equipo para agregar alcance; se asume que el equipo aprueba el Sprint 5 y que la constitución se enmendará
  para reflejarlo.
- El precio de compra solo lo ve el administrador (suposición del insumo, no sale del contexto maestro).
- Los roles y sus permisos de los sprints anteriores no cambian: administrador, recepcionista y mecánico.
- Se conserva el acuerdo del Sprint 4 de que el total se calcula y no se guarda en la orden.
- Los cambios de esquema se agregan como una migración nueva y no se editan las de sprints anteriores.
- Quedan fuera de alcance: costeo, margen y utilidad, impuestos y facturación, descuentos y pagos parciales,
  reembolsos, proveedores y órdenes de compra, y los sprints 6 a 10.
- Dependencias: inventario y refacciones de la orden (Sprint 3) y pagos, tickets y Mercado Pago en modo de
  pruebas (Sprint 4).
