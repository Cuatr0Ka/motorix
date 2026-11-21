# Especificación de la funcionalidad: Notificaciones internas y clientes por avisar (Sprint 6)

**Rama de la funcionalidad**: `006-notificaciones-internas`

**Creada**: 2026-11-20

**Estado**: Borrador

**Entrada**: Descripción del usuario: "Sprint 6: Notificaciones internas y lista de clientes por avisar. Usar como insumo docs/sprints/sprint-6-notificaciones-internas.md"

## Aclaraciones

### Sesión 2026-11-20 (primera ronda)

- Q: ¿Qué criterio define una orden detenida y cuánto vale N? → A: Una orden abierta (Recibida, Diagnóstico, En reparación o Esperando refacción) con más de 3 días sin cambio de estado (D-01). Las órdenes Terminadas sin entregar no cuentan como detenidas: se avisan por la lista de clientes por avisar. El valor de 3 días es fijo en este sprint y el Sprint 7 puede volverlo configurable.
- Q: ¿Se guarda una nota al marcar a un cliente como avisado? → A: No; solo se registra quién lo avisó y cuándo, y el cliente sale de la lista aunque no haya contestado (D-02).
- Q: ¿Cuándo se actualiza el contador de la campana? → A: Al iniciar sesión, al navegar entre módulos y de forma automática cada 60 segundos mientras la sesión está abierta (D-03).

### Sesión 2026-11-20 (segunda ronda: decisiones por omisión confirmadas)

- Q: ¿La cita del día incluye solo hoy o también mañana? → A: Solo hoy; las citas de mañana se avisan por la lista de clientes por avisar (D-04).
- Q: ¿Cómo se identifica un aviso para recordar que está leído? → A: Por su tipo y el objeto al que se refiere; un cambio de estado del mismo objeto (de próximo a vencido) cuenta como un aviso nuevo (D-05).
- Q: ¿El mecánico ve avisos de mantenimiento de los vehículos que atiende? → A: No; solo ve avisos de las órdenes que tiene asignadas (D-06).

## Escenarios de usuario y pruebas *(obligatorio)*

### Historia de usuario 1 - Ver cuántos avisos pendientes tengo (Prioridad: P1)

Como administrador, quiero ver en el encabezado cuántos avisos pendientes tengo y abrirlos agrupados por tipo
para atenderlos sin recorrer cada módulo.

**Por qué esta prioridad**: Es el centro de notificaciones; sin él no existe el resto del sprint.

**Prueba independiente**: Con un mantenimiento vencido, una cita para hoy, una refacción con stock bajo y una
orden detenida, el administrador inicia sesión, ve la campana con el total y abre el panel con los cuatro
avisos agrupados por tipo.

**Escenarios de aceptación**:

1. **Dado** que soy administrador y hay avisos pendientes, **cuando** inicio sesión, **entonces** el encabezado
   muestra una campana con el total de avisos no leídos.
2. **Dado** la campana con avisos, **cuando** la abro, **entonces** veo un panel con los avisos agrupados por
   tipo (mantenimiento próximo, mantenimiento vencido, cita del día, stock bajo o agotado y orden detenida).
3. **Dado** que no hay avisos, **cuando** abro el panel, **entonces** veo un mensaje de que no hay avisos
   pendientes y la campana no muestra número.
4. **Dado** que el servidor no responde, **cuando** abro el panel, **entonces** veo un mensaje de error con la
   opción de reintentar, sin perder el resto de la pantalla.
5. **Dado** que el panel tarda en cargar, **cuando** lo abro, **entonces** veo un indicador de carga.
6. **Dado** una sesión abierta, **cuando** aparece un aviso nuevo, **entonces** la campana lo refleja en un
   máximo de 60 segundos sin que yo haga nada, y también al iniciar sesión y al navegar entre módulos.

---

### Historia de usuario 2 - Avisos de mantenimientos y citas para la recepción (Prioridad: P1)

Como recepcionista, quiero ver los mantenimientos próximos y vencidos y las citas del día para avisar a los
clientes a tiempo.

**Por qué esta prioridad**: Es la razón de ser de los avisos: que recepción actúe antes de que el cliente se
olvide del servicio.

**Prueba independiente**: Con un mantenimiento próximo, uno vencido y una cita para hoy, la recepcionista
inicia sesión y ve esos tres avisos.

**Escenarios de aceptación**:

1. **Dado** un mantenimiento programado que está próximo según el indicador existente, **cuando** la
   recepcionista abre el centro, **entonces** ve un aviso de mantenimiento próximo con el cliente y el vehículo.
2. **Dado** un mantenimiento vencido, **cuando** abre el centro, **entonces** ve un aviso de mantenimiento
   vencido, separado de los próximos.
3. **Dado** una cita con fecha de hoy, **cuando** abre el centro, **entonces** ve un aviso de cita del día con
   la hora, el cliente y el vehículo.
4. **Dado** una cita cancelada o ya atendida, **cuando** abre el centro, **entonces** no aparece como aviso.

---

### Historia de usuario 3 - Aviso de stock bajo o agotado (Prioridad: P2)

Como administrador, quiero ver las refacciones con stock bajo o agotado para reabastecer a tiempo.

**Por qué esta prioridad**: El dato ya existe en el inventario; aquí solo se reúne con los demás avisos.

**Prueba independiente**: Con una refacción en su mínimo y otra en cero, el administrador ve los dos avisos y
distingue la agotada.

**Escenarios de aceptación**:

1. **Dado** una refacción cuya existencia es menor o igual a su mínimo, **cuando** el administrador abre el
   centro, **entonces** ve un aviso de stock bajo con el nombre y la existencia.
2. **Dado** una refacción con existencia en cero, **cuando** abre el centro, **entonces** el aviso la señala
   como agotada.
3. **Dado** que soy recepcionista o mecánico, **cuando** abro el centro, **entonces** no veo avisos de stock.

---

### Historia de usuario 4 - Avisos de órdenes detenidas (Prioridad: P2)

Como administrador o recepcionista, quiero ver las órdenes detenidas para destrabarlas.

**Por qué esta prioridad**: Evita que una orden quede olvidada, pero requiere definir qué es "detenida".

**Prueba independiente**: Con una orden que lleva más tiempo del permitido sin cambiar de estado, el
administrador y la recepcionista ven el aviso y llegan a la orden.

**Escenarios de aceptación**:

1. **Dado** una orden abierta (Recibida, Diagnóstico, En reparación o Esperando refacción) con más de 3 días
   sin cambio de estado, **cuando** el administrador o la recepcionista abre el centro, **entonces** ve un
   aviso con el folio, el cliente, el estado y los días sin cambio.
2. **Dado** una orden Terminada, Entregada o cancelada, **cuando** se calculan los avisos, **entonces** no se
   considera detenida.
3. **Dado** una orden abierta con 3 días o menos sin cambio de estado, **cuando** se calculan los avisos,
   **entonces** no genera aviso.
4. **Dado** que la orden cambia de estado, **cuando** se vuelve a consultar, **entonces** el aviso desaparece
   y el conteo de días empieza de nuevo.

---

### Historia de usuario 5 - El mecánico ve solo lo que le corresponde (Prioridad: P2)

Como mecánico, quiero ver solo los avisos de mis órdenes asignadas para no recibir información que no me
corresponde.

**Por qué esta prioridad**: Protege la información por rol y evita ruido; es una regla del proyecto.

**Prueba independiente**: Con avisos de órdenes de dos mecánicos y avisos de stock y citas, cada mecánico ve
solo los de sus órdenes.

**Escenarios de aceptación**:

1. **Dado** una orden detenida asignada a mí, **cuando** abro el centro, **entonces** veo su aviso.
2. **Dado** una orden detenida asignada a otro mecánico, **cuando** abro el centro, **entonces** no veo su
   aviso, ni siquiera consultando directamente la información del servidor.
3. **Dado** avisos de citas, de mantenimientos o de stock, **cuando** abro el centro como mecánico,
   **entonces** no los veo.

---

### Historia de usuario 6 - Marcar como leído y abrir el módulo relacionado (Prioridad: P1)

Como usuario, quiero marcar un aviso como leído y abrir el módulo relacionado desde él para dar seguimiento
rápido.

**Por qué esta prioridad**: Sin marcar como leído el contador nunca baja; sin enlace el aviso no ayuda a actuar.

**Prueba independiente**: El administrador abre el aviso de stock, llega a Inventario, marca un aviso como
leído y el contador baja.

**Escenarios de aceptación**:

1. **Dado** un aviso no leído, **cuando** lo marco como leído, **entonces** deja de contar en la campana y
   sigue visible en el panel como leído.
2. **Dado** un aviso que marqué como leído, **cuando** cierro sesión y vuelvo a entrar, **entonces** sigue
   marcado como leído.
3. **Dado** un aviso que leí yo, **cuando** otro usuario con el mismo rol abre el centro, **entonces** el aviso
   sigue como no leído para él; la lectura es por usuario.
4. **Dado** un aviso leído cuya condición deja de cumplirse, **cuando** se consulta de nuevo, **entonces**
   desaparece del panel.
5. **Dado** un aviso leído de un mantenimiento próximo que pasa a vencido, **cuando** se consulta de nuevo,
   **entonces** aparece como un aviso nuevo, no leído.
6. **Dado** un aviso, **cuando** lo abro, **entonces** llego a la pantalla relacionada (orden, cita, vehículo o
   inventario).

---

### Historia de usuario 7 - Lista de clientes por avisar (Prioridad: P1)

Como recepcionista, quiero una lista de clientes por avisar (vehículo listo, cita de mañana, mantenimiento
próximo o vencido) con su teléfono, y marcar cada uno como avisado, para contactarlos por teléfono o en persona
sin olvidar ni repetir avisos.

**Por qué esta prioridad**: El sistema no envía mensajes al cliente; esta lista es la forma en que el cliente se
entera, así que cierra el flujo del taller.

**Prueba independiente**: Con una orden Terminada sin entregar, la recepcionista abre "Clientes por avisar", ve
al cliente con su teléfono, lo marca como avisado y el cliente sale de la lista.

**Escenarios de aceptación**:

1. **Dado** una orden Terminada que aún no se entrega, **cuando** la recepcionista abre la lista, **entonces**
   ve al cliente con su teléfono, el vehículo y el motivo "vehículo listo".
2. **Dado** una cita para mañana, **cuando** abre la lista, **entonces** ve al cliente con el motivo "cita de
   mañana".
3. **Dado** un mantenimiento próximo o vencido, **cuando** abre la lista, **entonces** ve al cliente con el
   motivo correspondiente.
4. **Dado** un cliente de la lista, **cuando** lo marca como avisado, **entonces** sale de la lista y queda
   registrado quién lo avisó y cuándo; no se pide ninguna nota y el cliente sale aunque no haya contestado.
5. **Dado** un cliente ya avisado por un hecho, **cuando** se vuelve a consultar, **entonces** no reaparece por
   ese mismo hecho.
6. **Dado** un cliente ya avisado, **cuando** surge un hecho nuevo (otra orden terminada u otra cita),
   **entonces** aparece de nuevo en la lista.
7. **Dado** que soy mecánico, **cuando** intento abrir la lista, **entonces** el sistema lo rechaza, incluso si
   consulto la información directamente del servidor.
8. **Dado** que el sistema solo registra el aviso, **cuando** marco a un cliente como avisado, **entonces** no
   se envía ningún mensaje al cliente por ningún canal.

---

### Casos límite

- **Dos usuarios marcan lo mismo**: si dos recepcionistas marcan al mismo cliente como avisado casi al mismo
  tiempo, queda un solo registro del hecho y no se produce un error visible.
- **Aviso que desaparece mientras se lee**: si un aviso deja de cumplirse mientras el panel está abierto, al
  actualizarse desaparece sin romper la pantalla; marcarlo como leído después no produce un error.
- **Cliente sin teléfono**: aparece en la lista con la indicación "Sin teléfono registrado" para que recepción
  lo avise en persona.
- **Una orden con varios motivos**: un cliente con una orden terminada y un mantenimiento vencido aparece una
  vez por cada motivo, y cada uno se marca por separado.
- **Cantidad grande de avisos**: el panel muestra los avisos agrupados y limita la lista visible; la campana
  muestra el total y, si pasa de 99, la indicación "99+".
- **Usuario con el rol cambiado**: al cambiar el rol de un usuario, sus avisos se recalculan con el nuevo rol
  la próxima vez que consulta.
- **Datos anteriores al sprint**: las órdenes, citas y mantenimientos existentes se evalúan igual que los
  nuevos; ninguno se modifica.
- **Información del cliente**: la lista muestra el teléfono solo a administrador y recepcionista; el mecánico
  nunca lo recibe.

## Requisitos *(obligatorio)*

### Requisitos funcionales

- **FR-001**: El sistema DEBE mostrar en el encabezado de toda pantalla, para todo usuario autenticado, una
  campana con el total de avisos no leídos de ese usuario y un panel que los lista agrupados por tipo.
- **FR-002**: Los tipos de aviso DEBEN ser cinco: mantenimiento próximo, mantenimiento vencido, cita del día,
  stock bajo o agotado y orden detenida.
- **FR-003**: Los avisos DEBEN calcularse al consultar, con los datos reales del taller; el sistema NO DEBE
  copiarlos a otro almacén. Lo único que se guarda es qué avisos leyó cada usuario.
- **FR-004**: El servidor DEBE devolver a cada rol solo sus avisos: el administrador, todos; la recepción,
  mantenimientos, citas y órdenes detenidas; el mecánico, solo los de las órdenes que tiene asignadas. El
  stock NO DEBE devolverse a recepción ni al mecánico. La restricción se valida en el servidor, no solo en la
  pantalla.
- **FR-005**: Los avisos DEBEN usar el mismo cálculo que el panel de control, la lista de Mantenimientos y las
  alertas de stock, de modo que los números coincidan entre pantallas.
- **FR-006**: El usuario DEBE poder marcar un aviso como leído. La lectura se guarda por usuario y persiste
  entre sesiones.
- **FR-007**: Un aviso leído DEBE desaparecer cuando su condición deja de cumplirse, y DEBE volver a mostrarse
  como no leído si reaparece con otro estado (por ejemplo, de mantenimiento próximo a vencido).
- **FR-008**: Cada aviso DEBE abrir la pantalla relacionada: la orden, la cita, el vehículo o el inventario.
- **FR-009**: La insignia actual de Inventario y el aviso de la pantalla de inicio DEBEN seguir funcionando y
  NO DEBEN contradecir al centro de notificaciones.
- **FR-010**: El centro de notificaciones DEBE manejar los estados de carga, vacío y error según el sistema de
  diseño (`docs/design-system.md`).
- **FR-011**: Un mantenimiento próximo o vencido DEBE determinarse con el indicador y los márgenes que ya usa
  la lista de Mantenimientos.
- **FR-012**: Un aviso de cita del día DEBE incluir las citas con fecha de hoy que estén pendientes o
  confirmadas; las canceladas y las ya atendidas no generan aviso.
- **FR-013**: Una orden se considera detenida cuando está abierta (Recibida, Diagnóstico, En reparación o
  Esperando refacción) y lleva más de 3 días sin cambio de estado. El valor de 3 días es fijo en este sprint.
  Las órdenes Terminadas, Entregadas o canceladas no son detenidas; las Terminadas sin entregar se avisan por
  la lista de clientes por avisar.
- **FR-014**: El sistema DEBE ofrecer a administrador y recepción una lista de clientes por avisar con
  cliente, teléfono, vehículo y motivo. Los motivos son: orden Terminada sin entregar, cita de mañana,
  mantenimiento próximo y mantenimiento vencido.
- **FR-015**: El mecánico NO DEBE acceder a la lista de clientes por avisar ni recibir teléfonos de clientes por
  este medio; se valida en el servidor.
- **FR-016**: Marcar a un cliente como avisado DEBE registrar quién lo avisó y cuándo, sacarlo de la lista y
  evitar que reaparezca por el mismo hecho (misma orden, misma cita o mismo mantenimiento).
- **FR-017**: Si surge un hecho nuevo para un cliente ya avisado, el cliente DEBE aparecer de nuevo en la lista.
- **FR-018**: Al marcar como avisado a un cliente, el sistema DEBE registrar solo quién lo avisó y cuándo; NO
  DEBE pedir ni guardar una nota. El cliente sale de la lista aunque no haya contestado.
- **FR-019**: El sistema NO DEBE enviar ningún mensaje al cliente por ningún canal (WhatsApp, correo o SMS); el
  aviso lo hace la persona de recepción y el sistema solo lo registra.
- **FR-020**: El contador de la campana DEBE actualizarse al iniciar sesión, al navegar entre módulos y de
  forma automática cada 60 segundos mientras la sesión está abierta, de modo que un aviso nuevo se refleje en
  un máximo de 60 segundos.
- **FR-021**: Las operaciones concurrentes sobre una misma lectura o un mismo aviso de cliente DEBEN dejar un
  solo registro y NO DEBEN producir un error visible para el usuario.
- **FR-022**: Los datos de ejemplo del sprint DEBEN incluir al menos un caso de cada tipo de aviso y de cada
  motivo de la lista de clientes por avisar, y DEBEN poder cargarse varias veces sin duplicarse.
- **FR-023**: Los avisos de un volumen realista de datos (miles de órdenes, citas y mantenimientos) DEBEN
  consultarse en un tiempo razonable para el usuario.
- **FR-024**: La documentación del proyecto (sección 6.12 del contexto maestro y el sistema de diseño) DEBE
  actualizarse en este sprint.
- **FR-025**: Toda la funcionalidad NO DEBE alterar los datos existentes de clientes, vehículos, citas, órdenes,
  mantenimientos, pagos ni tickets.

### Entidades clave *(incluir si la funcionalidad involucra datos)*

- **Aviso**: condición detectada sobre los datos del taller (mantenimiento próximo o vencido, cita del día,
  stock bajo o agotado, orden detenida). No se guarda: se calcula al consultar.
- **Lectura de aviso**: constancia de que un usuario marcó un aviso como leído, con la identidad del aviso y la
  fecha. Es el único estado que se guarda de las notificaciones.
- **Aviso al cliente**: constancia de que la recepción avisó a un cliente por un hecho (orden, cita o
  mantenimiento), con quién lo avisó y cuándo.
- **Cliente por avisar**: vista de un cliente con su teléfono, su vehículo y el motivo por el que debe avisarse;
  se calcula con los datos existentes y los avisos ya registrados.
- **Usuario y rol**: determinan qué avisos se devuelven y si se accede a la lista de clientes por avisar.

## Criterios de éxito *(obligatorio)*

### Resultados medibles

- **SC-001** (FR-001, FR-002, FR-006): El administrador ve el total de avisos y abre uno en menos de 30
  segundos desde que inicia sesión, cronometrado en el entorno de demostración.
- **SC-009** (FR-020): Un aviso nuevo aparece en la campana en un máximo de 60 segundos sin que el usuario
  haga nada, cronometrado en el entorno de demostración.
- **SC-002** (FR-004, FR-015): En el 100 % de las pruebas por rol, cada rol recibe únicamente los avisos que le
  corresponden; el mecánico nunca recibe avisos de órdenes ajenas, de stock ni teléfonos de clientes.
- **SC-003** (FR-005): En el 100 % de las comparaciones de prueba, los números del centro coinciden con los del
  panel de control, la lista de Mantenimientos y las alertas de stock.
- **SC-004** (FR-006, FR-007): Un aviso marcado como leído se conserva tras cerrar e iniciar sesión, y
  desaparece o reaparece como no leído según su condición, en el 100 % de los casos de prueba.
- **SC-005** (FR-014, FR-016, FR-017): La recepción avisa a un cliente y lo marca como avisado en menos de 1
  minuto, y ningún cliente reaparece por el mismo hecho en el 100 % de los casos de prueba.
- **SC-006** (FR-019): En ninguna prueba el sistema envía mensajes al cliente por algún canal.
- **SC-007** (FR-023): Con un volumen de datos de prueba de 1 000 órdenes, 1 000 citas y 1 000 mantenimientos,
  el centro de notificaciones carga en menos de 2 segundos.
- **SC-008** (FR-009, FR-025): Toda prueba de los sprints 1 a 5 sigue pasando al cierre del sprint, salvo las
  que deban actualizarse por cambios declarados en esta especificación, y cada actualización se registra en el
  documento de aseguramiento.

## Suposiciones

- Este sprint es posterior al MVP. La constitución (principio I, enmienda 1.1.0) lo permite con su insumo, la
  aprobación registrada del responsable del proyecto y el flujo de Spec Kit; el insumo es
  `docs/sprints/sprint-6-notificaciones-internas.md`.
- Una cita del día es una con fecha de hoy; la lista de clientes por avisar usa las citas de mañana. Confirmada en la
  sesión de aclaraciones (D-04).
- La identidad de un aviso para la lectura es su tipo más el objeto al que se refiere, de modo que un cambio de
  estado del mismo objeto (de próximo a vencido) cuenta como un aviso nuevo.
- Un mantenimiento próximo o vencido usa los márgenes que ya existen (30 días y 1 000 km por omisión); el
  Sprint 7 los vuelve configurables.
- El mecánico recibe solo avisos de las órdenes que tiene asignadas; no recibe avisos de mantenimiento de los
  vehículos que atiende, porque los mantenimientos se avisan desde recepción.
- El aviso de orden terminada se da por cada orden; una orden se avisa una sola vez por el mismo hecho.
- No hay preferencias por usuario sobre qué avisos recibir ni historial de avisos pasados.
- Quedan fuera: envío automático de avisos al cliente, notificaciones en tiempo real por empuje (WebSocket) o del sistema operativo,
  reportes y configuración del taller (Sprint 7).
- Se reutilizan la autenticación, los roles y los cálculos de mantenimiento, stock y panel de los sprints
  anteriores; el servidor sigue siendo el único que accede a la base de datos.

## Decisiones pendientes para /speckit.clarify

Vienen de la sección 9 del insumo. Todas se resolvieron el 2026-11-20 y están registradas en la sección
Aclaraciones:

- **D-01** *(resuelta el 2026-11-20)*: Orden detenida: abierta con más de 3 días sin cambio de estado.
- **D-02** *(resuelta el 2026-11-20)*: Al marcar como avisado solo se registra quién y cuándo, sin nota.
- **D-03** *(resuelta el 2026-11-20)*: El contador se actualiza al iniciar sesión, al navegar y cada 60 segundos.
- **D-04** *(resuelta el 2026-11-20)*: La cita del día es solo la de hoy.
- **D-05** *(resuelta el 2026-11-20)*: Un aviso se identifica por su tipo y su objeto.
- **D-06** *(resuelta el 2026-11-20)*: El mecánico no ve avisos de mantenimiento.
