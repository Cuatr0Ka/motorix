# Especificación de la funcionalidad: Citas y órdenes de servicio (Sprint 2)

**Rama de la funcionalidad**: `002-citas-ordenes-servicio`

**Creada**: 2026-10-10

**Estado**: Borrador

**Entrada**: Descripción del usuario: "Usa la descripción de docs/sprints/sprint-2-citas-ordenes.md"

## Aclaraciones

### Sesión 2026-10-10

- Q: ¿Puede un vehículo tener más de una orden de servicio abierta (no entregada) al mismo tiempo? → A: No; un vehículo solo puede tener una orden abierta y debe entregarse antes de crear otra.
- Q: ¿Quién puede cambiar el estado de una orden hasta Terminado? → A: Solo el mecánico asignado y el administrador; recepción únicamente registra la entrega (paso a Entregado).
- Q: ¿Qué ve el mecánico por defecto en "Mis órdenes"? → A: Solo las no entregadas; las entregadas que tuvo asignadas se ven al filtrar por estado Entregado.
- Q: ¿Quién confirma una cita y cómo? → A: De forma manual; recepción o administración la marcan como Confirmada.
- Q: ¿Qué pasa si dos personas cambian el estado de la misma orden casi al mismo tiempo? → A: Solo prospera el primer cambio; el segundo se rechaza con un mensaje que muestra el estado vigente.

## Escenarios de usuario y pruebas *(obligatorio)*

### Historia de usuario 1 - Registrar y consultar citas (Prioridad: P1)

Como recepcionista, quiero registrar, consultar, modificar y cancelar citas para organizar la
llegada de los vehículos al taller.

**Por qué esta prioridad**: Es el punto de entrada del flujo del sprint: el taller necesita saber
qué vehículos llegarán y cuándo, antes de crear cualquier orden.

**Prueba independiente**: Con la sesión de recepcionista, se registra una cita para un cliente y
uno de sus vehículos, se localiza en el listado, se cambia su fecha u hora y se cancela.

**Escenarios de aceptación**:

1. **Dado** un cliente con un vehículo registrado, **cuando** registro una cita con fecha, hora,
   motivo y observaciones opcionales, **entonces** la cita queda en estado Pendiente y aparece en
   el listado.
2. **Dado** que hay varias citas, **cuando** filtro por fecha o estado, o busco por cliente o
   placa, **entonces** veo solo las citas que coinciden.
3. **Dado** una cita Pendiente o Confirmada, **cuando** modifico su fecha, hora, motivo u
   observaciones, **entonces** los cambios se guardan y se muestran de inmediato.
4. **Dado** una cita Pendiente o Confirmada, **cuando** la cancelo y confirmo la acción, **entonces**
   queda en estado Cancelada, se conserva en el historial y ya no se puede modificar.
5. **Dado** un vehículo que no pertenece al cliente seleccionado, **cuando** intento guardar la
   cita, **entonces** el sistema la rechaza indicando la inconsistencia.
6. **Dado** una fecha y hora anteriores al momento actual, **cuando** intento registrar la cita,
   **entonces** el sistema la rechaza con un mensaje claro.
7. **Dado** que soy mecánico, **cuando** intento consultar o modificar citas, **entonces** el
   sistema lo rechaza.

---

### Historia de usuario 2 - Crear una orden de servicio asociada a cliente y vehículo (Prioridad: P1)

Como recepcionista, quiero crear órdenes de servicio asociadas a un cliente y a un vehículo, con el
kilometraje de entrada y el problema reportado, para registrar el trabajo a realizar y vincular
correctamente la información.

**Por qué esta prioridad**: La orden es el eje del sprint y de los siguientes; reúne las historias
de creación de órdenes y de asociación con cliente y vehículo, que no tienen sentido por separado.

**Prueba independiente**: Con la sesión de recepcionista, se crea una orden para un vehículo
existente con kilometraje de entrada y se verifica que aparece en el listado y en el detalle con su
cliente, su vehículo y el estado Recibido.

**Escenarios de aceptación**:

1. **Dado** un cliente con un vehículo registrado, **cuando** creo una orden indicando el vehículo,
   el kilometraje de entrada y el problema reportado, **entonces** la orden queda en estado
   Recibido, con un folio único, asociada al cliente propietario y al vehículo.
2. **Dado** una cita Pendiente o Confirmada, **cuando** recibo el vehículo y creo la orden desde
   esa cita, **entonces** la orden toma el cliente, el vehículo y el motivo de la cita, y la cita
   pasa a En proceso.
3. **Dado** un vehículo que llega sin cita, **cuando** creo la orden directamente, **entonces** la
   orden se crea con normalidad sin requerir una cita previa.
4. **Dado** un vehículo inexistente, **cuando** intento crear una orden, **entonces** el sistema la
   rechaza.
5. **Dado** que no capturo el kilometraje de entrada, **cuando** intento guardar la orden,
   **entonces** el sistema indica que es obligatorio y no la guarda.
6. **Dado** un vehículo cuyo kilometraje actual es 50 000, **cuando** capturo un kilometraje de
   entrada menor sin marcar una corrección explícita, **entonces** el sistema lo rechaza y explica
   el motivo.
7. **Dado** un kilometraje de entrada válido, **cuando** la orden se crea, **entonces** el
   kilometraje actual del vehículo se actualiza con ese valor.
8. **Dado** que soy mecánico, **cuando** intento crear una orden, **entonces** el sistema lo
   rechaza.

---

### Historia de usuario 3 - Asignar una orden a un mecánico (Prioridad: P1)

Como recepcionista, quiero asignar una orden a un mecánico para que sepa qué trabajo le
corresponde.

**Por qué esta prioridad**: Sin asignación, el mecánico no puede ver ni trabajar sus órdenes; es el
enlace entre la recepción y el taller.

**Prueba independiente**: Se crea una orden, se asigna a un mecánico activo y se verifica que ese
mecánico la ve en su lista y que otro mecánico no.

**Escenarios de aceptación**:

1. **Dado** una orden sin mecánico, **cuando** selecciono un mecánico activo y la asigno, **entonces**
   la orden queda asignada a esa persona y se muestra en el detalle y en el listado.
2. **Dado** una orden asignada que aún no está terminada, **cuando** la reasigno a otro mecánico,
   **entonces** deja de aparecer para el anterior y aparece para el nuevo.
3. **Dado** un usuario desactivado o con un rol distinto de mecánico, **cuando** intento asignarle
   una orden, **entonces** el sistema lo rechaza.
4. **Dado** una orden en estado Terminado o Entregado, **cuando** intento reasignarla, **entonces**
   el sistema lo rechaza.

---

### Historia de usuario 4 - Consultar mis órdenes asignadas (Prioridad: P1)

Como mecánico, quiero consultar las órdenes que tengo asignadas para saber qué trabajar.

**Por qué esta prioridad**: Es la vista principal del mecánico y la condición para que pueda
documentar el trabajo.

**Prueba independiente**: Con la sesión de un mecánico, se verifica que el listado muestra solo sus
órdenes y que abrir la de otro mecánico es rechazado.

**Escenarios de aceptación**:

1. **Dado** que tengo órdenes asignadas, **cuando** abro mi sección de órdenes, **entonces** veo
   únicamente esas órdenes, con folio, vehículo, cliente, problema reportado y estado.
2. **Dado** una orden asignada a otro mecánico, **cuando** intento consultarla por cualquier
   medio, **entonces** el sistema lo rechaza sin revelar sus datos.
3. **Dado** que filtro por estado, **cuando** aplico el filtro, **entonces** veo solo mis órdenes
   en ese estado.
4. **Dado** que soy recepcionista o administrador, **cuando** consulto órdenes, **entonces** veo
   todas, con filtros por estado, mecánico y búsqueda por folio, cliente o placa.
5. **Dado** que no tengo órdenes asignadas, **cuando** abro mi sección, **entonces** veo un estado
   vacío claro.

---

### Historia de usuario 5 - Registrar diagnóstico, servicios y recomendaciones (Prioridad: P2)

Como mecánico, quiero registrar el diagnóstico, los servicios realizados, la mano de obra y las
observaciones y recomendaciones de una orden para documentar el trabajo y dejar constancia del
estado del vehículo.

**Por qué esta prioridad**: Es el valor central del taller, pero depende de que existan órdenes
asignadas (Historias 2 a 4). Reúne las historias de diagnóstico y servicios, y de observaciones y
recomendaciones.

**Prueba independiente**: Con la sesión del mecánico asignado, se abre una orden y se registran un
diagnóstico, dos servicios, una línea de mano de obra y una recomendación, y se verifica que se
conservan al reabrir la orden.

**Escenarios de aceptación**:

1. **Dado** una orden asignada a mí, **cuando** registro o edito el diagnóstico, **entonces** queda
   guardado en la orden.
2. **Dado** una orden asignada a mí, **cuando** agrego un servicio realizado con su descripción y
   su importe, **entonces** aparece en la lista de servicios de la orden y se refleja en el
   subtotal.
3. **Dado** una orden asignada a mí, **cuando** agrego una línea de mano de obra con descripción y
   su importe, **entonces** aparece en la orden y se refleja en el subtotal.
4. **Dado** un servicio o línea de mano de obra ya registrados, **cuando** los corrijo o los
   elimino, **entonces** la orden refleja el cambio y el subtotal se recalcula.
5. **Dado** una orden asignada a mí, **cuando** agrego observaciones y recomendaciones, **entonces**
   quedan visibles para el resto del personal en el detalle de la orden.
6. **Dado** una orden en estado Entregado, **cuando** intento modificar su diagnóstico, servicios,
   mano de obra, observaciones o recomendaciones, **entonces** el sistema lo rechaza porque la
   orden es historial.
7. **Dado** una orden asignada a otro mecánico, **cuando** intento registrar información en ella,
   **entonces** el sistema lo rechaza.
8. **Dado** datos inválidos (descripción vacía, importe negativo), **cuando** intento guardar,
   **entonces** el sistema indica qué corregir y no guarda nada.

---

### Historia de usuario 6 - Cambiar el estado de una orden (Prioridad: P2)

Como mecánico, quiero cambiar el estado de una orden para reflejar su avance, hasta terminar el
trabajo.

**Por qué esta prioridad**: Cierra el flujo demostrable del sprint y concentra la lógica de negocio
más sensible (secuencia de estados y permisos).

**Prueba independiente**: Con la sesión del mecánico asignado, se avanza una orden desde Recibido
hasta Terminado, se intenta saltar un estado (debe fallar) y se usa Esperando refacción.

**Escenarios de aceptación**:

1. **Dado** una orden Recibida y asignada a mí, **cuando** la paso a Diagnóstico, **entonces**
   cambia de estado y queda registrado quién lo hizo y cuándo.
2. **Dado** una orden en Diagnóstico o En reparación, **cuando** la paso a Esperando refacción,
   **entonces** cambia de estado; **y cuando** la reanudo, **entonces** regresa a En reparación.
3. **Dado** una orden en En reparación, **cuando** la paso a Terminado, **entonces** cambia de
   estado y, si venía de una cita, la cita pasa a Completada.
4. **Dado** una orden Terminada, **cuando** recepción confirma la entrega, **entonces** pasa a
   Entregado y se conserva como historial.
5. **Dado** una transición fuera de la secuencia (por ejemplo, de Recibido a Terminado o de
   Terminado a Diagnóstico), **cuando** intento aplicarla, **entonces** el sistema la rechaza
   indicando los estados permitidos desde el actual.
6. **Dado** que soy mecánico, **cuando** intento marcar una orden como Entregada, **entonces** el
   sistema lo rechaza; la entrega solo la registran recepción o administración.
7. **Dado** una orden sin mecánico asignado, **cuando** intento avanzarla a Diagnóstico, **entonces**
   el sistema lo rechaza y pide asignar un mecánico primero.
8. **Dado** una orden Entregada, **cuando** intento eliminarla o cambiar su estado, **entonces** el
   sistema lo rechaza.

---

### Casos límite

- Registrar una cita para un vehículo en la misma fecha y hora que otra cita activa del mismo
  vehículo (se rechaza).
- Cancelar una cita que ya tiene una orden asociada (no se permite: solo se cancelan citas
  Pendientes o Confirmadas).
- Crear dos órdenes activas para el mismo vehículo al mismo tiempo (se rechaza: un vehículo no
  puede tener más de una orden abierta, es decir, que no esté Entregada).
- Crear una orden desde una cita que ya fue cancelada o que ya tiene orden.
- Capturar un kilometraje de entrada igual al actual del vehículo (se acepta) o de un vehículo
  sin kilometraje previo (se acepta cualquier valor no negativo).
- Capturar un kilometraje con corrección explícita menor al previo: se exige confirmación y un
  motivo, y queda registrado.
- Capturar un kilometraje no numérico, negativo o con un valor absurdo (por ejemplo, mayor a
  2 000 000).
- Intentar eliminar una orden o una cita (no existe esa operación en el sistema; las citas se
  cancelan y las órdenes se conservan).
- Asignar una orden a un mecánico que se desactiva después; la orden conserva su asignación pero
  se señala para reasignar.
- Un mecánico con una orden abierta en pantalla cuyo estado cambió por otra persona: el sistema
  rechaza la transición obsoleta y muestra el estado vigente.
- Dos personas cambian el estado de la misma orden casi al mismo tiempo (solo una transición
  prospera).
- Reejecutar la carga de datos de ejemplo: no debe duplicar citas ni órdenes.
- Sesión cuyo rol cambió o cuenta desactivada: la siguiente solicitud se valida con el estado
  vigente.

## Requisitos *(obligatorio)*

### Requisitos funcionales

- **FR-001**: Recepcionistas y administradores DEBEN poder registrar citas asociadas a un cliente y
  a un vehículo de ese cliente, con fecha, hora, motivo y observaciones opcionales.
- **FR-002**: Las citas DEBEN manejar los estados Pendiente, Confirmada, En proceso, Completada y
  Cancelada. Toda cita nueva inicia en Pendiente y recepcionistas o administradores pueden pasarla
  manualmente a Confirmada mediante una acción explícita; no se confirma de forma automática.
- **FR-003**: El sistema DEBE ofrecer un listado de citas con filtros por fecha y estado y búsqueda
  por cliente o placa, y un detalle de cita.
- **FR-004**: Recepcionistas y administradores DEBEN poder modificar fecha, hora, motivo y
  observaciones de una cita solo mientras esté Pendiente o Confirmada.
- **FR-005**: Recepcionistas y administradores DEBEN poder cancelar una cita Pendiente o Confirmada
  previa confirmación; la cita cancelada se conserva, no se elimina y no admite más cambios. No se
  puede cancelar una cita En proceso o Completada.
- **FR-006**: El sistema DEBE rechazar citas con fecha y hora pasadas, con un vehículo que no
  pertenezca al cliente indicado, o que repitan fecha y hora de otra cita activa del mismo vehículo.
- **FR-007**: Recepcionistas y administradores DEBEN poder crear una orden de servicio asociada a
  un cliente y a un vehículo existentes, ya sea desde una cita o de forma directa, con problema
  reportado, kilometraje de entrada y mecánico opcional. Toda orden nueva inicia en el estado
  Recibido y recibe un folio único y legible.
- **FR-008**: El sistema DEBE rechazar la creación de una orden para un vehículo inexistente y
  DEBE derivar el cliente de la orden del propietario del vehículo.
- **FR-009**: El kilometraje de entrada DEBE ser obligatorio, un número entero no negativo. El
  sistema DEBE rechazar un valor menor al kilometraje actual del vehículo, salvo que
  recepcionistas o administradores indiquen una corrección explícita con motivo y confirmación,
  que DEBE quedar registrada. Si el vehículo no tiene kilometraje previo, se acepta cualquier valor
  válido.
- **FR-010**: Al crear una orden con kilometraje válido, el sistema DEBE actualizar el
  kilometraje actual del vehículo con ese valor.
- **FR-011**: Al crear una orden desde una cita, la cita DEBE pasar a En proceso y, cuando la orden
  llegue a Terminado, a Completada.
- **FR-012**: El sistema DEBE impedir que un vehículo tenga más de una orden abierta
  (no Entregada) al mismo tiempo.
- **FR-013**: Recepcionistas y administradores DEBEN poder asignar y reasignar una orden a un
  mecánico activo mientras la orden no esté Terminada ni Entregada; el sistema DEBE rechazar
  asignar a usuarios desactivados o que no sean mecánicos.
- **FR-014**: Un mecánico DEBE ver y poder abrir únicamente las órdenes que tiene asignadas;
  recepcionistas y administradores DEBEN ver todas. El listado de órdenes DEBE permitir filtrar por
  estado y mecánico y buscar por folio, cliente o placa. En "Mis órdenes", el mecánico ve por
  defecto solo las órdenes no entregadas; las entregadas que tuvo asignadas se muestran al filtrar
  por estado Entregado.
- **FR-015**: El mecánico asignado (y los administradores) DEBEN poder registrar y editar el
  diagnóstico, las observaciones y las recomendaciones de una orden.
- **FR-016**: El mecánico asignado (y los administradores) DEBEN poder agregar, corregir y quitar
  servicios realizados y líneas de mano de obra de una orden, cada uno con descripción e importe
  no negativo. La orden DEBE mostrar el subtotal de servicios, el de mano de obra y el total
  (suma de ambos).
- **FR-017**: Una orden Entregada DEBE ser de solo lectura: no admite cambios de datos, de
  servicios, de mano de obra, de asignación ni de estado, y NO se puede eliminar.
- **FR-018**: El sistema NO DEBE ofrecer ninguna operación para eliminar órdenes ni citas de forma
  ordinaria.
- **FR-019**: Las órdenes DEBEN seguir la secuencia de estados Recibido → Diagnóstico → En
  reparación → Terminado → Entregado, sin saltar estados ni retroceder. Además, desde Diagnóstico
  o En reparación PUEDE pasar a Esperando refacción y, desde ahí, volver únicamente a En
  reparación. El sistema DEBE rechazar cualquier otra transición e indicar las permitidas desde el
  estado actual. Si dos cambios de estado de la misma orden coinciden, solo prospera el primero;
  el segundo DEBE rechazarse con un mensaje que muestre el estado vigente.
- **FR-020**: El mecánico asignado y los administradores DEBEN poder cambiar el estado hasta
  Terminado; el paso a Entregado SOLO lo realizan recepcionistas o administradores, previa
  confirmación. Una orden sin mecánico asignado no puede salir de Recibido.
- **FR-021**: Cada cambio de estado DEBE registrarse con el estado anterior, el nuevo, la persona y
  la fecha y hora, y consultarse en el detalle de la orden.
- **FR-022**: El sistema DEBE validar los permisos por rol en cada operación del lado del
  servidor, con independencia de lo que muestre la interfaz: citas solo para recepcionistas y
  administradores; creación y asignación de órdenes solo para recepcionistas y administradores;
  registro de trabajo y avance de estado solo para el mecánico asignado y administradores.
- **FR-023**: El sistema DEBE validar en el servidor todos los datos recibidos y devolver mensajes
  claros en español, sin exponer detalles internos.
- **FR-024**: El sistema DEBE pedir confirmación antes de cancelar una cita, registrar una entrega
  o aplicar una corrección de kilometraje, y mostrar mensajes de éxito o error tras cada acción.
- **FR-025**: El sistema DEBE conservar toda la información de forma persistente y permitir
  recrear el esquema completo desde cero, sin modificar los scripts del Sprint 1.
- **FR-026**: El sistema DEBE incluir datos de ejemplo (citas en distintos estados y órdenes en
  cada estado del flujo, asignadas a mecánicos, con servicios y mano de obra) suficientes para
  mostrar información al primer arranque, y su carga DEBE ser repetible sin duplicar registros.
- **FR-027**: Toda pantalla nueva DEBE seguir el sistema de diseño del proyecto
  (`docs/design-system.md`), con estados vacío, cargando y error, y mostrar en el menú solo las
  secciones permitidas al rol: Citas y Órdenes para recepcionistas y administradores, y Mis
  órdenes para mecánicos.
- **FR-028**: El sistema DEBE mantener fuera del alcance de este sprint: historial de mantenimiento
  por vehículo, próximo mantenimiento, inventario y refacciones, pagos, Mercado Pago, tickets,
  panel de indicadores, y la cancelación o anulación de órdenes.

### Entidades clave *(incluir si la funcionalidad involucra datos)*

- **Cita**: Visita programada de un vehículo al taller. Tiene cliente, vehículo, fecha y hora,
  motivo, observaciones opcionales, estado (Pendiente, Confirmada, En proceso, Completada o
  Cancelada) y, si se canceló, la fecha de cancelación. Puede originar a lo sumo una orden.
- **Orden de servicio**: Trabajo realizado durante una visita. Tiene folio único, cliente,
  vehículo, cita de origen opcional, mecánico asignado opcional, problema reportado, kilometraje de
  entrada, diagnóstico, observaciones, recomendaciones y estado (Recibido, Diagnóstico, En
  reparación, Esperando refacción, Terminado o Entregado). Conserva el historial de sus cambios de
  estado.
- **Servicio de la orden**: Servicio realizado dentro de una orden, con descripción e importe.
  Una orden tiene cero o más.
- **Mano de obra de la orden**: Trabajo de mano de obra registrado en una orden, con descripción e
  importe. Una orden tiene cero o más.
- **Cambio de estado**: Registro de cada transición de una orden con estado anterior, estado nuevo,
  persona y fecha y hora.
- **Cliente, Vehículo y Usuario**: Ya existen desde el Sprint 1; las citas y órdenes se relacionan
  con ellos.

## Criterios de éxito *(obligatorio)*

### Resultados medibles

- **SC-001**: Una recepcionista registra una cita completa (cliente, vehículo, fecha, hora y
  motivo) en menos de 2 minutos, sin ayuda.
- **SC-002**: Una recepcionista crea una orden desde una cita, con kilometraje y mecánico
  asignado, en menos de 3 minutos.
- **SC-003**: El flujo completo "registrar cita → crear orden → asignar mecánico → registrar
  diagnóstico y servicios → avanzar hasta Terminado → entregar" se ejecuta de principio a fin, con
  los tres roles, en menos de 15 minutos durante una demostración.
- **SC-004**: El 100 % de las transiciones de estado fuera de la secuencia definida se rechaza,
  y el 100 % de las permitidas se acepta, verificado con pruebas automatizadas.
- **SC-005**: El 100 % de las solicitudes de un mecánico sobre órdenes no asignadas a él, o de un
  rol sobre operaciones que no le corresponden, es rechazado, aun cuando no provenga de la
  interfaz.
- **SC-006**: Cero órdenes se crean sin vehículo existente, sin kilometraje de entrada o con un
  kilometraje menor al previo sin corrección explícita.
- **SC-007**: Un mecánico identifica sus órdenes pendientes en menos de 10 segundos tras iniciar
  sesión.
- **SC-008**: Ninguna orden entregada puede modificarse ni eliminarse.
- **SC-009**: Tras una instalación nueva, el sistema muestra citas y órdenes de ejemplo en todos los
  estados del flujo sin capturar nada a mano, y repetir la carga no genera duplicados.
- **SC-010**: Los listados de citas y órdenes, con hasta 1 000 registros, muestran resultados de
  búsqueda y filtros en menos de 2 segundos.

## Suposiciones

Las decisiones que el documento del sprint dejó pendientes para `/speckit-clarify` se resolvieron
aquí con valores por defecto razonables, que pueden revisarse en esa fase:

- **Modelo de estados**: los de FR-019 y las transiciones descritas; Esperando refacción solo
  entra desde Diagnóstico o En reparación y solo regresa a En reparación. No existe un estado de
  orden cancelada en este sprint.
- **Asignación de mecánico**: manual, por parte de recepción o administración, sin asignación
  automática ni control de disponibilidad o carga de trabajo. Una orden puede crearse sin mecánico
  y asignarse después.
- **Kilometraje sin valor previo**: si el vehículo no tiene kilometraje registrado, se acepta
  cualquier entero no negativo (hasta un máximo razonable de 2 000 000) como primer valor.
- **Cancelación de citas**: solo se cancelan citas Pendientes o Confirmadas, que por definición
  aún no tienen orden; por ello la cancelación nunca afecta órdenes. Una vez iniciada la orden, la
  cita queda En proceso y deja de poder cancelarse.
- Las citas no se eliminan y las órdenes entregadas se conservan como historial (RN-9).
- Matriz de permisos asumida: ADMIN puede todo; RECEPTIONIST gestiona citas, crea y asigna
  órdenes y registra la entrega; MECHANIC solo consulta y trabaja sus órdenes asignadas y no ve
  citas.
- Los importes son informativos y en una sola moneda; no hay impuestos, descuentos ni refacciones
  en este sprint, y no sustituyen a los pagos, que quedan para un sprint posterior.
- Los datos de ejemplo incluyen un segundo mecánico para demostrar que cada uno ve solo sus órdenes.
- Se asume horario laboral estándar para las citas, sin calendario de disponibilidad ni límite de
  citas simultáneas distintas.
- Las decisiones de tecnología ya están fijadas por la constitución del proyecto
  (`.specify/memory/constitution.md`) y se tratarán en la fase de planeación, no aquí.
- Dependencias: clientes, vehículos, usuarios y roles del Sprint 1; `docs/project-context.md`
  (alcance), `docs/design-system.md` (interfaz) y `docs/reglas.md` (reglas del proyecto).
