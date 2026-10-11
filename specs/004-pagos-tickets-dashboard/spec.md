# Especificación de la funcionalidad: Pagos, tickets y panel de control (Sprint 4)

**Rama de la funcionalidad**: `004-pagos-tickets-dashboard`

**Creada**: 2026-10-11

**Estado**: Borrador

**Entrada**: Descripción del usuario: "Usa la descripción de docs/sprints/sprint-4-pagos-tickets-dashboard.md"

## Aclaraciones

### Sesión 2026-10-11

- Q: ¿Las refacciones suman importe al total que se cobra? → A: No; el total es servicios más mano de obra y las refacciones se listan con su cantidad, sin importe (si el taller cobra una pieza, la captura como servicio de la orden).
- Q: ¿Cómo se confirma un cobro de Mercado Pago? → A: Solo por consulta bajo demanda de la recepción; no se recibe aviso automático del proveedor en este sprint.
- Q: ¿Quién puede ver el panel de control? → A: Solo el administrador; recepción y mecánico son rechazados por el servidor.
- Q: ¿El ticket se descarga como archivo PDF? → A: No; solo se visualiza en pantalla y se imprime con formato de ticket, sin generar ni guardar archivos.
- Q: ¿Se puede entregar una orden que aún no está cobrada? → A: Sí; la entrega no depende del cobro, pero el sistema advierte y pide confirmación al entregar una orden sin pago Pagado.

## Escenarios de usuario y pruebas *(obligatorio)*

### Historia de usuario 1 - Registrar el pago de una orden con su método de pago (Prioridad: P1)

Como recepcionista, quiero registrar el pago de una orden eligiendo cómo se cobró (efectivo, tarjeta o
transferencia) para cerrar el ciclo del servicio y dejar constancia del cobro.

**Por qué esta prioridad**: Es el corazón del sprint: sin pago registrado no hay ciclo cerrado ni ticket, y
es la base sobre la que se apoyan Mercado Pago y el panel de control.

**Prueba independiente**: Con una orden Terminada, la recepcionista consulta su total, registra un pago en
efectivo por ese total y verifica que el pago queda como Pagado, asociado a la orden y visible en su detalle.

**Escenarios de aceptación**:

1. **Dado** una orden Terminada o Entregada, **cuando** abro su detalle, **entonces** veo el total a cobrar
   (servicios más mano de obra), los pagos registrados y el estado de cobro de la orden.
2. **Dado** una orden Terminada sin pago vigente, **cuando** registro un pago en efectivo, tarjeta o
   transferencia por el total, **entonces** el pago queda en estado Pagado, relacionado con la orden, con
   el método elegido, la fecha y la persona que lo registró.
3. **Dado** un pago con tarjeta, **cuando** lo registro, **entonces** el sistema solo me pide una referencia
   opcional de la operación (por ejemplo, el folio de la terminal) y nunca el número de la tarjeta, su
   vencimiento ni su código de seguridad.
4. **Dado** un pago por transferencia, **cuando** lo registro, **entonces** puedo capturar la clave de
   rastreo o referencia como texto opcional.
5. **Dado** una orden que aún no está Terminada (Recibido, Diagnóstico, En reparación o Esperando
   refacción), **cuando** intento registrar un pago, **entonces** el sistema lo rechaza indicando que la
   orden debe estar Terminada.
6. **Dado** una orden con un pago Pagado, **cuando** intento registrar otro pago, **entonces** el sistema lo
   rechaza porque la orden ya está cobrada.
7. **Dado** una orden con un pago Pendiente, **cuando** lo cancelo con confirmación, **entonces** queda
   Cancelado, se conserva en el historial de pagos y puedo registrar uno nuevo.
8. **Dado** un importe distinto del total vigente de la orden, **cuando** intento registrar el pago,
   **entonces** el sistema lo rechaza con un mensaje que indica el total a cobrar.
9. **Dado** una orden sin servicios ni mano de obra (total cero), **cuando** intento registrar un pago,
   **entonces** el sistema lo rechaza porque no hay nada que cobrar.
10. **Dado** que soy mecánico, **cuando** intento registrar o consultar pagos, **entonces** el sistema lo
    rechaza; solo recepción y administración gestionan pagos.
11. **Dado** una orden Entregada, **cuando** consulto sus pagos, **entonces** los veo en modo de solo
    lectura y conservados como historial.

---

### Historia de usuario 2 - Cobrar con Mercado Pago en modo de pruebas (Prioridad: P1)

Como recepcionista, quiero cobrar una orden mediante Mercado Pago para ofrecer una opción digital al
cliente, sin que Motorix guarde datos de su tarjeta.

**Por qué esta prioridad**: Es el requisito diferenciador del sprint (CA-3 y CA-7), pero depende del
registro de pagos de la historia 1.

**Prueba independiente**: Con las credenciales de pruebas configuradas, se inicia un cobro con Mercado Pago
para una orden Terminada, se completa en el entorno de pruebas del proveedor, se consulta el estado del pago
y se verifica que pasa de Pendiente a Pagado sin que el sistema guarde ningún dato de tarjeta.

**Escenarios de aceptación**:

1. **Dado** una orden Terminada sin pago vigente y las credenciales de pruebas configuradas, **cuando**
   elijo Mercado Pago, **entonces** se crea un pago en estado Pendiente por el total y obtengo un enlace de
   cobro de Mercado Pago que puedo abrir o compartir con el cliente.
2. **Dado** un pago de Mercado Pago Pendiente, **cuando** el cliente lo completa en el entorno de pruebas y
   consulto su estado, **entonces** el pago pasa a Pagado y guarda la referencia externa de la operación.
3. **Dado** un pago de Mercado Pago Pendiente, **cuando** el proveedor lo rechaza, **entonces** el pago
   queda Rechazado, se conserva en el historial y puedo iniciar un nuevo cobro.
4. **Dado** un pago de Mercado Pago Pendiente, **cuando** consulto su estado y el proveedor aún no lo
   confirma, **entonces** sigue Pendiente y veo la fecha de la última consulta.
5. **Dado** que las credenciales de Mercado Pago no están configuradas, **cuando** intento cobrar con ese
   método, **entonces** el sistema indica que no está disponible, sin exponer detalles internos, y los demás
   métodos siguen funcionando.
6. **Dado** que Mercado Pago no responde o devuelve un error, **cuando** intento iniciar o consultar un
   cobro, **entonces** veo un mensaje claro en español, no queda un pago a medias y puedo reintentar.
7. **Dado** cualquier pago de Mercado Pago, **cuando** reviso lo que Motorix almacena, **entonces** solo hay
   importe, método, estado, referencias de la operación y fechas; no hay números de tarjeta, vencimientos ni
   códigos de seguridad, y las credenciales no aparecen en pantalla, respuestas ni registros.
8. **Dado** un pago Pagado por Mercado Pago, **cuando** consulto de nuevo su estado, **entonces** no cambia
   ni se duplica.

---

### Historia de usuario 3 - Generar, visualizar e imprimir el ticket de servicio (Prioridad: P1)

Como recepcionista, quiero generar el ticket de una orden cobrada para entregar un comprobante al cliente.

**Por qué esta prioridad**: Es el entregable visible para el cliente y cierra el flujo de atención; depende
de que exista un pago Pagado.

**Prueba independiente**: Con una orden Terminada con pago Pagado, se genera el ticket, se visualiza con
todos sus datos y se imprime desde la pantalla.

**Escenarios de aceptación**:

1. **Dado** una orden con un pago Pagado, **cuando** genero el ticket, **entonces** se crea con un folio
   único y legible, relacionado con la orden y con el pago, y se muestra en pantalla.
2. **Dado** un ticket generado, **cuando** lo visualizo, **entonces** incluye: folio, datos del taller
   (nombre, dirección y teléfono), cliente, vehículo con placas y kilometraje, servicios realizados,
   refacciones utilizadas, mano de obra, subtotal de servicios, subtotal de mano de obra, total, método de
   pago, estado del pago y fecha.
3. **Dado** un ticket visualizado, **cuando** pulso imprimir, **entonces** se abre la impresión con un
   formato legible de ticket (solo su contenido, sin menús ni botones).
4. **Dado** una orden sin pago Pagado (sin pago, Pendiente, Rechazado o Cancelado), **cuando** intento
   generar el ticket, **entonces** el sistema lo rechaza indicando que primero debe estar cobrada.
5. **Dado** una orden que ya tiene ticket, **cuando** intento generarlo otra vez, **entonces** el sistema
   me lleva al ticket existente en lugar de crear otro; no se generan folios duplicados.
6. **Dado** un ticket generado, **cuando** el contenido de la orden cambia después, **entonces** el ticket
   sigue mostrando los conceptos e importes tal como se generó.
7. **Dado** una orden con refacciones, **cuando** veo el ticket, **entonces** las refacciones aparecen con
   su cantidad y no suman importe al total (los precios de refacciones no forman parte de este sprint).
8. **Dado** un ticket existente, **cuando** lo consulto desde la orden o desde la lista de tickets,
   **entonces** puedo volver a visualizarlo e imprimirlo las veces que haga falta.
9. **Dado** que soy mecánico, **cuando** intento generar o consultar tickets, **entonces** el sistema lo
   rechaza.

---

### Historia de usuario 4 - Consultar el panel de control del taller (Prioridad: P2)

Como administrador, quiero consultar un panel de control con la información general del taller para
supervisar la operación sin recorrer cada módulo.

**Por qué esta prioridad**: Da visión de conjunto, pero se alimenta de los módulos anteriores y no bloquea
el cobro ni el ticket.

**Prueba independiente**: Con los datos de ejemplo, el administrador abre el panel y verifica que cada
indicador coincide con lo que muestran los listados de órdenes, citas, mantenimientos e inventario.

**Escenarios de aceptación**:

1. **Dado** que soy administrador, **cuando** abro el panel, **entonces** veo, con datos reales: vehículos
   atendidos en los últimos 30 días, vehículos en reparación, órdenes pendientes, órdenes terminadas
   pendientes de entrega, citas próximas, mantenimientos próximos, mantenimientos vencidos y refacciones con
   stock bajo o agotadas.
2. **Dado** el panel, **cuando** reviso un indicador, **entonces** su valor coincide con el resultado del
   listado correspondiente aplicando el mismo criterio (por ejemplo, los mantenimientos vencidos son los
   mismos de la lista de Mantenimientos).
3. **Dado** un indicador, **cuando** lo selecciono, **entonces** voy al listado correspondiente.
4. **Dado** el panel, **cuando** lo reviso, **entonces** veo también la actividad reciente del taller: las
   últimas órdenes que cambiaron de estado y los últimos pagos y movimientos de inventario.
5. **Dado** una acción que cambia los datos (por ejemplo, terminar una orden), **cuando** vuelvo a consultar
   el panel, **entonces** los indicadores reflejan el cambio sin pasos adicionales.
6. **Dado** un taller sin datos en alguno de los indicadores, **cuando** abro el panel, **entonces** el
   indicador muestra cero con un estado vacío claro, sin errores.
7. **Dado** que soy recepcionista o mecánico, **cuando** intento abrir el panel o consultar sus datos,
   **entonces** el sistema lo rechaza; el panel es para administración.
8. **Dado** el panel, **cuando** reviso los pagos, **entonces** veo cuántas órdenes terminadas están
   pendientes de cobro y cuántos pagos de Mercado Pago siguen Pendientes.

---

### Casos límite

- Registrar un pago para una orden Entregada que nunca se cobró (se permite: Entregada también se cobra).
- Dos personas intentan registrar el pago de la misma orden al mismo tiempo (solo prospera uno; el otro
  recibe un mensaje claro).
- Confirmar una consulta de Mercado Pago de un pago ya Cancelado en Motorix.
- Cancelar un pago Pagado (no se permite; cualquier reembolso se gestiona fuera del sistema).
- Una orden con servicios o mano de obra que cambian después de crear un cobro de Mercado Pago Pendiente
  (el pago conserva el importe con el que se creó; si el total cambió, se debe cancelar y crear uno nuevo).
- Importes con centavos y redondeo del total (se maneja siempre con dos decimales).
- Cobro de Mercado Pago iniciado y nunca completado por el cliente (queda Pendiente hasta cancelarlo).
- Generar el ticket de una orden cuyo cliente o vehículo cambió de datos (el ticket conserva los datos de
  su generación).
- Intentar eliminar un pago o un ticket (no existe esa operación; los pagos se cancelan y los tickets se
  conservan).
- Orden con pago Pagado y Terminada: sigue pudiendo entregarse por recepción.
- Entregar una orden sin cobrar (se permite tras una advertencia y una confirmación explícita; la orden
  aparece en el panel como pendiente de cobro).
- Tickets con textos largos (descripciones de 255 caracteres) que deben seguir siendo legibles al imprimir.
- Panel con 1 000 órdenes, citas y movimientos (debe responder con rapidez).
- Reejecutar la carga de datos de ejemplo: no debe duplicar pagos ni tickets.
- Sesión cuyo rol cambió o cuenta desactivada: la siguiente solicitud se valida con el estado vigente.

## Requisitos *(obligatorio)*

### Requisitos funcionales

- **FR-001**: Recepcionistas y administradores DEBEN poder consultar, en el detalle de una orden Terminada
  o Entregada, el total a cobrar, los pagos registrados y el estado de cobro. El total se calcula como la
  suma de los servicios y la mano de obra de la orden.
- **FR-002**: Recepcionistas y administradores DEBEN poder registrar el pago de una orden Terminada o
  Entregada por el total vigente, eligiendo el método: efectivo, tarjeta, transferencia o Mercado Pago.
  Todo pago DEBE estar relacionado con una orden (RN-13).
- **FR-003**: Los pagos en efectivo, tarjeta y transferencia DEBEN registrarse directamente como Pagado, con
  importe, método, referencia opcional (hasta 100 caracteres), fecha y persona que los registró. El sistema
  NO DEBE solicitar ni almacenar números de tarjeta, vencimientos ni códigos de seguridad (RN-14).
- **FR-004**: Los pagos DEBEN manejar los estados Pendiente, Pagado, Rechazado y Cancelado. Solo los pagos de
  Mercado Pago pueden estar Pendiente o Rechazado; un pago Pagado no se modifica ni se cancela.
- **FR-005**: Una orden DEBE tener a lo sumo un pago vigente (Pendiente o Pagado). El sistema DEBE rechazar
  un segundo pago vigente, incluso si dos solicitudes llegan al mismo tiempo.
- **FR-006**: El sistema DEBE rechazar pagos para órdenes que no estén Terminadas o Entregadas, con un
  importe distinto del total vigente, o para una orden con total cero.
- **FR-007**: Recepcionistas y administradores DEBEN poder cancelar un pago Pendiente, previa confirmación;
  el pago cancelado se conserva en el historial y libera la orden para un nuevo cobro. NO existe operación
  para eliminar pagos.
- **FR-008**: Para cobrar con Mercado Pago, el sistema DEBE crear un pago Pendiente por el total vigente y
  obtener del proveedor, en modo de pruebas, un enlace de cobro que la recepción pueda abrir o compartir
  con el cliente.
- **FR-009**: El sistema DEBE permitir consultar el estado de un pago de Mercado Pago Pendiente con el
  proveedor y reflejarlo como Pagado (guardando la referencia externa de la operación), Rechazado o
  Pendiente. La consulta repetida de un pago ya resuelto NO DEBE cambiarlo ni duplicarlo.
- **FR-010**: Las credenciales de Mercado Pago DEBEN manejarse únicamente mediante variables de entorno y
  NO DEBEN aparecer en el repositorio, en pantallas, en respuestas de la API ni en registros. Si faltan, el
  método Mercado Pago DEBE aparecer como no disponible con un mensaje claro y los demás métodos DEBEN seguir
  funcionando.
- **FR-011**: Ante un fallo o falta de respuesta de Mercado Pago, el sistema DEBE mostrar un mensaje claro
  en español, no dejar un pago a medias y permitir reintentar.
- **FR-012**: Recepcionistas y administradores DEBEN poder generar el ticket de una orden con un pago
  Pagado. El ticket DEBE tener un folio único y legible y relacionarse con la orden y con el pago. Una
  orden DEBE tener a lo sumo un ticket; generar de nuevo lleva al existente.
- **FR-013**: El ticket DEBE incluir folio, datos del taller (nombre, dirección y teléfono), cliente,
  vehículo, placas, kilometraje, servicios, refacciones con su cantidad, mano de obra, subtotal de
  servicios, subtotal de mano de obra, total, método de pago, estado del pago y fecha. Las refacciones no
  suman importe al total.
- **FR-014**: El ticket DEBE conservar los datos e importes con los que se generó; cambios posteriores en la
  orden, el cliente o el vehículo NO DEBEN alterarlo.
- **FR-015**: El ticket DEBE poder visualizarse en pantalla e imprimirse con un formato propio para
  impresión, y consultarse de nuevo desde la orden o desde una lista de tickets. NO existe operación para
  eliminar tickets.
- **FR-016**: Los datos del taller que aparecen en el ticket DEBEN ser configurables sin modificar el
  código.
- **FR-017**: Los administradores DEBEN poder consultar un panel de control con: vehículos atendidos en los
  últimos 30 días, vehículos en reparación, órdenes pendientes, órdenes terminadas pendientes de entrega,
  citas próximas (los próximos 7 días), mantenimientos próximos, mantenimientos vencidos, refacciones con
  stock bajo o agotadas, órdenes terminadas pendientes de cobro y pagos de Mercado Pago pendientes.
- **FR-018**: Cada indicador del panel DEBE calcularse con los datos reales de los módulos, con el mismo
  criterio que el listado correspondiente, sin copiar ni duplicar información; y DEBE llevar al listado
  correspondiente al seleccionarlo.
- **FR-019**: El panel DEBE mostrar la actividad reciente del taller: las últimas órdenes que cambiaron de
  estado, los últimos pagos y los últimos movimientos de inventario.
- **FR-020**: El panel DEBE mostrar estados de carga, vacío y error, y actualizarse al consultarlo de nuevo.
- **FR-021**: El sistema DEBE validar los permisos por rol en cada operación del lado del servidor, con
  independencia de lo que muestre la interfaz: pagos y tickets solo para recepcionistas y administradores;
  panel de control solo para administradores; los mecánicos no acceden a ninguno de los tres.
- **FR-022**: El sistema DEBE validar en el servidor todos los datos recibidos y devolver mensajes claros en
  español, sin exponer detalles internos ni respuestas crudas del proveedor de pagos.
- **FR-023**: El sistema DEBE pedir confirmación antes de registrar un pago, cancelar un pago Pendiente y
  generar un ticket, y mostrar mensajes de éxito o error tras cada acción.
- **FR-024**: Una orden Entregada DEBE seguir siendo historial: sus pagos y su ticket se conservan y no se
  pueden modificar ni eliminar (RN-9). La entrega NO depende del cobro: al registrar la entrega de una orden
  sin pago Pagado, el sistema DEBE advertirlo y pedir confirmación adicional, y permitirla si se confirma.
- **FR-025**: El sistema DEBE conservar toda la información de forma persistente y permitir recrear el
  esquema completo desde cero, sin modificar los scripts de los sprints anteriores.
- **FR-026**: El sistema DEBE incluir datos de ejemplo suficientes para mostrar información al primer
  arranque: pagos en los cuatro estados y con los cuatro métodos, tickets de órdenes cobradas, órdenes
  Terminadas pendientes de cobro y la información necesaria para que todos los indicadores del panel
  muestren valores. La carga DEBE ser repetible sin duplicar registros ni llamar al proveedor de pagos.
- **FR-027**: Toda pantalla nueva DEBE seguir el sistema de diseño del proyecto (`docs/design-system.md`),
  con estados vacío, cargando y error, y mostrar en el menú solo las secciones permitidas al rol: Panel de
  control para administradores; Pagos y Tickets para recepcionistas y administradores.
- **FR-028**: El sistema DEBE mantener fuera del alcance de este sprint: chatbot de WhatsApp, facturación
  electrónica, envío automático de correos o mensajes al cliente, reportes avanzados o analítica histórica,
  aplicación móvil nativa, pagos parciales o a plazos, reembolsos dentro del sistema, precios de
  refacciones y archivos PDF de tickets.
- **FR-029**: Las pruebas automatizadas de la lógica de pagos (reglas de estado, un solo pago vigente,
  importes y permisos) y de generación de tickets (contenido, folio único y conservación de datos) DEBEN
  existir y pasar.

### Entidades clave *(incluir si la funcionalidad involucra datos)*

- **Pago**: Cobro de una orden de servicio. Tiene orden, importe, método (efectivo, tarjeta, transferencia o
  Mercado Pago), estado (Pendiente, Pagado, Rechazado o Cancelado), referencia opcional de la operación,
  referencia externa y enlace de cobro cuando es de Mercado Pago, fecha de creación, fecha en que se pagó y
  persona que lo registró. Nunca contiene datos de tarjeta.
- **Ticket**: Comprobante de una orden cobrada. Tiene folio único, orden, pago, fecha de generación, persona
  que lo generó y el contenido tal como se generó (datos del taller, cliente, vehículo, conceptos e
  importes). Una orden tiene a lo sumo uno.
- **Indicadores del panel**: Valores calculados al consultar a partir de órdenes, citas, mantenimientos,
  inventario y pagos; no son una entidad con datos propios.
- **Orden de servicio, Cliente, Vehículo, Refacción, Mantenimiento y Usuario**: Ya existen desde los
  sprints anteriores; pagos, tickets y panel se relacionan con ellos.

## Criterios de éxito *(obligatorio)*

### Resultados medibles

- **SC-001**: Una recepcionista registra el pago de una orden en efectivo, tarjeta o transferencia en menos
  de 1 minuto desde que abre la orden.
- **SC-002**: Una recepcionista inicia un cobro con Mercado Pago y obtiene el enlace en menos de 1 minuto,
  y el estado se actualiza a Pagado en menos de 10 segundos tras consultarlo, una vez completado el pago.
- **SC-003**: Una recepcionista genera e imprime el ticket de una orden cobrada en menos de 1 minuto.
- **SC-004**: El flujo completo "orden terminada → consultar total → registrar pago → generar ticket →
  consultar el panel" se ejecuta de principio a fin, con recepción y administración, en menos de 10 minutos
  durante una demostración.
- **SC-005**: Cero pagos se registran sin una orden asociada, y cero órdenes quedan con dos pagos vigentes,
  verificado con pruebas automatizadas que incluyen solicitudes simultáneas.
- **SC-006**: Cero datos de tarjeta y cero credenciales de Mercado Pago aparecen en la base de datos, las
  respuestas de la API, los registros ni el repositorio.
- **SC-007**: El 100 % de los tickets generados contiene todos los campos requeridos y conserva sus importes
  aunque la orden cambie después, verificado con pruebas automatizadas.
- **SC-008**: El 100 % de las solicitudes que un rol no tiene permitido (por ejemplo, un mecánico
  registrando un pago o un recepcionista abriendo el panel) es rechazado, aun cuando no provenga de la
  interfaz.
- **SC-009**: Cada indicador del panel coincide al 100 % con el listado correspondiente tras cualquier
  cambio de datos, verificado con pruebas automatizadas.
- **SC-010**: El administrador identifica, en una sola pantalla y en menos de 30 segundos, cuántas órdenes
  están pendientes, cuántos mantenimientos están vencidos, cuántas refacciones están en alerta y cuántas
  órdenes esperan cobro.
- **SC-011**: Tras una instalación nueva, el sistema muestra pagos, tickets y un panel con valores sin
  capturar nada a mano, y repetir la carga no genera duplicados.
- **SC-012**: Los listados de pagos y tickets y el panel, con hasta 1 000 registros, responden en menos de
  2 segundos.

## Suposiciones

Las decisiones que el documento del sprint dejó pendientes para `/speckit-clarify` se resolvieron aquí con
valores por defecto razonables, que pueden revisarse en esa fase:

- **Total de la orden**: servicios más mano de obra. Los precios de refacciones se difirieron en el
  Sprint 3, por lo que las refacciones se listan con su cantidad pero no suman importe.
- **Un pago por cobro**: el pago cubre el total completo y una orden tiene a lo sumo un pago vigente. No hay
  pagos parciales, abonos ni propinas en este sprint.
- **Reembolsos y cancelaciones**: un pago Pendiente se puede cancelar; un pago Pagado no se modifica ni se
  cancela. Cualquier devolución de dinero se gestiona fuera del sistema y no se registra.
- **Mercado Pago**: se usa el entorno de pruebas del proveedor mediante un enlace de cobro creado para la
  orden. Como el entorno local no recibe notificaciones del proveedor, la recepción consulta el estado del
  pago bajo demanda; no se recibe ningún aviso automático del proveedor en este sprint.
- **Pagos con tarjeta**: se refieren a una terminal física externa; Motorix solo registra que se cobró y una
  referencia opcional de la operación.
- **Cuándo se puede generar el ticket**: solo con un pago Pagado, y se crea un único ticket por orden que
  conserva los datos de su generación.
- **Formato del ticket**: visualización en pantalla e impresión desde la pantalla; no se generan ni se
  guardan archivos PDF (la impresión del sistema permite «Guardar como PDF» si se necesita).
- **Datos del taller**: nombre, dirección y teléfono configurables; el seed incluye valores de ejemplo.
- **Indicadores del panel**: vehículos atendidos = vehículos con orden Entregada en los últimos 30 días;
  vehículos en reparación = órdenes En reparación o Esperando refacción; órdenes pendientes = no
  Terminadas ni Entregadas; citas próximas = Pendientes o Confirmadas en los próximos 7 días; los demás
  indicadores reutilizan los criterios de Mantenimientos e Inventario.
- **Permisos**: ADMIN puede todo; RECEPTIONIST gestiona pagos y tickets; MECHANIC no accede a pagos,
  tickets ni panel. El panel es exclusivo de administración.
- Las decisiones de tecnología (librería de tickets, integración con el proveedor) ya están acotadas por la
  constitución del proyecto (`.specify/memory/constitution.md`) y se tratarán en la fase de planeación,
  no aquí.
- Dependencias: órdenes, servicios y mano de obra del Sprint 2; refacciones, mantenimientos e inventario del
  Sprint 3; usuarios y roles del Sprint 1; `docs/project-context.md` (alcance), `docs/design-system.md`
  (interfaz) y `docs/reglas.md` (reglas del proyecto).
