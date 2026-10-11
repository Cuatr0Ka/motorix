# Especificación de la funcionalidad: Historial, mantenimiento e inventario (Sprint 3)

**Rama de la funcionalidad**: `003-historial-inventario`

**Creada**: 2026-10-11

**Estado**: Borrador

**Entrada**: Descripción del usuario: "Usa la descripción de docs/sprints/sprint-3-historial-inventario.md"

## Aclaraciones

### Sesión 2026-10-11

- Q: ¿Qué margen de aviso marca un mantenimiento como «Próximo»? → A: 30 días o 1 000 km (lo que ocurra primero), configurable.
- Q: ¿Hasta qué estado de la orden puede el mecánico agregar, corregir o quitar refacciones? → A: Hasta Terminado inclusive; se bloquea solo al pasar a Entregado.
- Q: ¿Qué ve el mecánico del catálogo de refacciones? → A: Código, nombre, unidad y existencia; sin stock mínimo ni historial de movimientos.
- Q: ¿Quién ve la lista de mantenimientos próximos y vencidos con el teléfono del cliente? → A: Recepcionista y administrador; el mecánico solo ve los mantenimientos de un vehículo dentro de su historial.
- Q: ¿Cómo se captura un ajuste de inventario? → A: Se captura la cantidad contada; el stock queda en ese valor y el movimiento guarda la diferencia.

## Escenarios de usuario y pruebas *(obligatorio)*

### Historia de usuario 1 - Consultar el historial de servicios de un vehículo (Prioridad: P1)

Como mecánico, quiero consultar el historial de servicios de un vehículo, con el kilometraje de cada
servicio, para conocer su estado y sus antecedentes antes de trabajar en él.

**Por qué esta prioridad**: Es el valor central del sprint: convertir las órdenes ya terminadas en
la memoria del vehículo. Sin historial, los mantenimientos y las refacciones no tienen contexto.

**Prueba independiente**: Con un vehículo que tiene varias órdenes Terminadas o Entregadas, se
abre su historial y se verifica que aparecen en orden cronológico con fecha, kilometraje, problema
reportado, diagnóstico, servicios y mecánico.

**Escenarios de aceptación**:

1. **Dado** un vehículo con órdenes Terminadas o Entregadas, **cuando** consulto su historial,
   **entonces** veo esas órdenes en orden cronológico (la más reciente primero) con fecha,
   kilometraje, folio, problema reportado, diagnóstico, servicios realizados, refacciones usadas y
   mecánico.
2. **Dado** un vehículo con una orden aún abierta (Recibido, Diagnóstico, En reparación o Esperando
   refacción), **cuando** consulto su historial, **entonces** esa orden no aparece como servicio
   realizado.
3. **Dado** un vehículo sin servicios terminados, **cuando** consulto su historial, **entonces** veo
   un estado vacío claro, sin errores.
4. **Dado** una orden que acaba de pasar a Terminado, **cuando** consulto el historial de su
   vehículo, **entonces** aparece de inmediato, sin una captura adicional.
5. **Dado** que soy recepcionista o administrador, **cuando** consulto el historial de cualquier
   vehículo, **entonces** puedo verlo igual que un mecánico.
6. **Dado** que soy mecánico, **cuando** consulto el historial de un vehículo que nunca ha estado
   asignado a mí, **entonces** puedo verlo, porque el historial es información de consulta del taller.

---

### Historia de usuario 2 - Registrar el kilometraje del servicio y el próximo mantenimiento (Prioridad: P1)

Como mecánico, quiero registrar el kilometraje de cada servicio y establecer el próximo
mantenimiento por fecha, por kilometraje o por ambos, para mantener actualizado el historial y
programar el siguiente servicio.

**Por qué esta prioridad**: Cierra el ciclo del servicio y alimenta los avisos al cliente. Va con el
historial porque ambos se registran al terminar el trabajo.

**Prueba independiente**: Con una orden Terminada asignada a un mecánico, se registra el
kilometraje del servicio y un próximo mantenimiento a 6 meses o 10 000 km más, y se verifica que
aparecen en el historial y en la lista de mantenimientos próximos.

**Escenarios de aceptación**:

1. **Dado** una orden asignada a mí que está Terminada, **cuando** registro el kilometraje del
   servicio (igual o mayor al de entrada), **entonces** queda guardado en el historial y el
   kilometraje actual del vehículo se actualiza si es mayor al que tenía.
2. **Dado** un kilometraje del servicio menor al de entrada de la orden, **cuando** intento
   guardarlo, **entonces** el sistema lo rechaza con un mensaje claro.
3. **Dado** una orden Terminada o Entregada de mi responsabilidad, **cuando** establezco el próximo
   mantenimiento con una fecha, un kilometraje o ambos, y una descripción del servicio por
   realizar, **entonces** el mantenimiento queda programado para ese vehículo.
4. **Dado** que intento guardar un mantenimiento sin fecha ni kilometraje, **cuando** confirmo,
   **entonces** el sistema lo rechaza indicando que se requiere al menos uno de los dos.
5. **Dado** una fecha pasada o un kilometraje menor o igual al actual del vehículo, **cuando**
   intento programar el mantenimiento, **entonces** el sistema lo rechaza con un mensaje claro.
6. **Dado** un vehículo con un mantenimiento programado, **cuando** registro un nuevo próximo
   mantenimiento desde una orden posterior, **entonces** el anterior queda marcado como Atendido y
   el nuevo queda como el vigente.
7. **Dado** que soy mecánico, **cuando** intento registrar kilometraje o mantenimiento en una orden
   que no tengo asignada, **entonces** el sistema lo rechaza.
8. **Dado** que soy recepcionista, **cuando** intento registrar kilometraje de servicio o programar
   mantenimientos, **entonces** el sistema lo rechaza; solo puedo consultarlos.

---

### Historia de usuario 3 - Consultar mantenimientos próximos y vencidos (Prioridad: P2)

Como recepcionista, quiero consultar los mantenimientos próximos y vencidos, con los datos de
contacto del cliente, para avisarle al cliente que le toca un servicio.

**Por qué esta prioridad**: Es el beneficio comercial del historial (retener al cliente), pero
depende de que ya existan mantenimientos programados.

**Prueba independiente**: Con mantenimientos de ejemplo en estado Normal, Próximo y Vencido, se
abre la lista y se verifica que cada uno aparece con el estado correcto y que los filtros funcionan.

**Escenarios de aceptación**:

1. **Dado** mantenimientos programados, **cuando** abro la lista, **entonces** veo cliente,
   teléfono, vehículo (placa), descripción, fecha y/o kilometraje objetivo y un indicador de estado:
   Normal, Próximo o Vencido.
2. **Dado** un mantenimiento por fecha cuya fecha ya pasó, **cuando** consulto la lista, **entonces**
   figura como Vencido.
3. **Dado** un mantenimiento por kilometraje cuyo objetivo ya fue alcanzado por el kilometraje actual
   del vehículo, **cuando** consulto la lista, **entonces** figura como Vencido.
4. **Dado** un mantenimiento programado por fecha y por kilometraje, **cuando** se cumple cualquiera
   de las dos condiciones de vencimiento, **entonces** figura como Vencido.
5. **Dado** un mantenimiento cuya fecha o kilometraje entra en el margen de aviso, **cuando**
   consulto la lista, **entonces** figura como Próximo.
6. **Dado** la lista de mantenimientos, **cuando** filtro por estado (Normal, Próximo, Vencido) o
   busco por cliente o placa, **entonces** veo solo los que coinciden; por defecto aparecen primero
   los Vencidos y luego los Próximos.
7. **Dado** que un mantenimiento ya fue Atendido, **cuando** consulto la lista de pendientes,
   **entonces** no aparece, pero sigue visible en el historial del vehículo.
8. **Dado** que soy mecánico, **cuando** intento abrir la lista de mantenimientos, **entonces** el
   sistema lo rechaza; solo veo los mantenimientos de un vehículo dentro de su historial.

---

### Historia de usuario 4 - Registrar y consultar refacciones y su stock (Prioridad: P1)

Como administrador, quiero registrar y consultar refacciones y su stock disponible para controlar el
inventario del taller.

**Por qué esta prioridad**: Sin catálogo de refacciones y existencias no puede haber uso en órdenes
ni alertas de stock.

**Prueba independiente**: Con la sesión de administrador, se registra una refacción con stock
inicial, se localiza en el listado, se edita su stock mínimo y se registra una entrada de
mercancía; el stock refleja cada cambio.

**Escenarios de aceptación**:

1. **Dado** que soy administrador, **cuando** registro una refacción con código, nombre,
   unidad de medida, stock inicial y stock mínimo, **entonces** queda disponible en el inventario y
   el stock inicial genera un movimiento de entrada.
2. **Dado** un código ya registrado, **cuando** intento registrar otra refacción con el mismo
   código, **entonces** el sistema lo rechaza.
3. **Dado** el inventario, **cuando** busco por código o nombre o filtro por estado de stock
   (suficiente, bajo, agotado), **entonces** veo solo las refacciones que coinciden.
4. **Dado** una refacción existente, **cuando** edito su nombre, descripción, unidad o stock mínimo,
   **entonces** los cambios se guardan sin alterar su stock ni su historial de movimientos.
5. **Dado** una refacción, **cuando** registro una entrada de mercancía con cantidad y motivo
   opcional, **entonces** el stock aumenta y se registra un movimiento de tipo entrada.
6. **Dado** una refacción, **cuando** registro un ajuste de inventario (por conteo físico, merma o
   corrección) indicando la cantidad contada y un motivo obligatorio, **entonces** el stock queda
   en la cantidad contada y el movimiento de ajuste conserva la diferencia calculada, el motivo y
   la persona.
7. **Dado** una refacción, **cuando** consulto su detalle, **entonces** veo su stock actual y su
   historial de movimientos (tipo, cantidad, fecha, persona y orden relacionada, si aplica).
8. **Dado** una refacción sin movimientos en órdenes, **cuando** la desactivo, **entonces** deja de
   ofrecerse para nuevas órdenes pero se conserva en el historial; las refacciones no se eliminan.
9. **Dado** que soy recepcionista, **cuando** intento registrar o modificar refacciones o movimientos,
   **entonces** el sistema lo rechaza.
10. **Dado** que soy mecánico, **cuando** consulto el catálogo, **entonces** puedo ver código, nombre,
    unidad y existencia, pero no el stock mínimo ni los movimientos, y no puedo registrar
    entradas, ajustes ni editar refacciones.

---

### Historia de usuario 5 - Agregar refacciones utilizadas a una orden (Prioridad: P1)

Como mecánico, quiero agregar a una orden las refacciones que utilicé, con la cantidad, para reflejar
su uso y que el inventario se actualice solo.

**Por qué esta prioridad**: Es el enlace entre el trabajo del taller y el control del inventario; es
el momento donde las reglas de stock se aplican.

**Prueba independiente**: Con una refacción con stock de 10 y una orden asignada al mecánico, se
agregan 3 unidades a la orden y se verifica que la orden las lista, que el stock baja a 7 y que
existe un movimiento de salida ligado a la orden.

**Escenarios de aceptación**:

1. **Dado** una orden no Entregada asignada a mí y una refacción activa con stock suficiente,
   **cuando** agrego una cantidad entera positiva, **entonces** la refacción aparece en la orden, el
   stock disminuye en esa cantidad y se registra un movimiento de salida ligado a la orden.
2. **Dado** una cantidad mayor al stock disponible, **cuando** intento agregarla, **entonces** el
   sistema la rechaza indicando el stock disponible y no cambia nada.
3. **Dado** una cantidad cero, negativa, decimal o no numérica, **cuando** intento agregarla,
   **entonces** el sistema la rechaza con un mensaje claro.
4. **Dado** una refacción ya agregada a la orden, **cuando** la agrego otra vez, **entonces** la
   cantidad se suma a la línea existente (o se corrige la línea) sin duplicar renglones.
5. **Dado** una refacción de la orden, **cuando** corrijo su cantidad, **entonces** el stock y los
   movimientos reflejan la diferencia (más salida o devolución) y el stock nunca queda negativo.
6. **Dado** una refacción de la orden, **cuando** la quito, **entonces** su cantidad regresa al
   inventario mediante un movimiento de entrada que referencia la orden y la línea desaparece de la
   orden.
7. **Dado** una orden Entregada, **cuando** intento agregar, corregir o quitar refacciones, **entonces**
   el sistema lo rechaza, porque la orden es de solo lectura.
8. **Dado** que soy mecánico, **cuando** intento modificar las refacciones de una orden asignada a
   otro mecánico, **entonces** el sistema lo rechaza; recepcionistas no pueden modificarlas.
9. **Dado** una refacción desactivada, **cuando** intento agregarla a una orden, **entonces** el sistema
   lo rechaza.
10. **Dado** una orden con refacciones, **cuando** consulto su detalle o el historial del vehículo,
    **entonces** veo las refacciones usadas con su cantidad.

---

### Historia de usuario 6 - Visualizar alertas de stock bajo (Prioridad: P2)

Como administrador, quiero ver alertas de stock bajo para reabastecer a tiempo.

**Por qué esta prioridad**: Da valor al control de inventario, pero requiere refacciones con stock
mínimo y movimientos ya funcionando.

**Prueba independiente**: Con refacciones de ejemplo en estado suficiente, bajo y agotado, se abre la
interfaz como administrador y se verifica que las alertas listan las refacciones bajo el mínimo; al
registrar una entrada que las supera, la alerta desaparece.

**Escenarios de aceptación**:

1. **Dado** refacciones cuyo stock es menor o igual a su mínimo, **cuando** el administrador entra al
   sistema o abre el inventario, **entonces** ve una alerta visible con el número de refacciones en
   alerta y puede abrir la lista con su stock y su mínimo.
2. **Dado** una refacción con stock en cero, **cuando** se muestra la alerta, **entonces** se
   distingue como Agotada frente a las de stock bajo.
3. **Dado** una salida (uso en una orden) que deja el stock en el mínimo o por debajo, **cuando**
   consulto las alertas, **entonces** la refacción aparece sin recargar manualmente más allá de
   volver a consultar la pantalla.
4. **Dado** una entrada de mercancía que sube el stock por encima del mínimo, **cuando** consulto las
   alertas, **entonces** la refacción deja de aparecer.
5. **Dado** que no hay refacciones en alerta, **cuando** consulto las alertas, **entonces** veo un
   mensaje indicando que el inventario está en orden.
6. **Dado** que soy mecánico o recepcionista, **cuando** intento abrir la lista de alertas de stock
   bajo, **entonces** el sistema lo rechaza; la alerta es para administración.

---

### Casos límite

- Dos mecánicos agregan al mismo tiempo cantidades de la misma refacción que juntas superan el
  stock: solo prospera la que cabe y la otra se rechaza con el stock vigente, sin dejar negativos.
- Corregir la cantidad de una refacción en una orden a un valor mayor que el stock disponible
  (se rechaza si la diferencia excede el stock).
- Ajuste de inventario con una cantidad contada negativa o no entera (se rechaza).
- Ajuste cuya cantidad contada es igual al stock actual (se rechaza por no generar diferencia).
- Una refacción cuyo stock mínimo es cero (solo se alerta cuando llega a cero).
- Registrar un stock mínimo o inicial negativo, decimal o no numérico.
- Cantidades absurdas (por ejemplo, mayores a 100 000 unidades en un solo movimiento).
- Desactivar una refacción con stock existente (se permite; sigue visible en el inventario como
  inactiva y sin alertas).
- Intentar eliminar una refacción, un movimiento de inventario o una línea de historial (no existe
  esa operación; los errores se corrigen con ajustes y los movimientos se conservan).
- Orden que pasa a Entregado con refacciones: sus movimientos y líneas quedan intactos.
- Un vehículo con mantenimientos por fecha y por kilometraje a la vez, donde solo una condición
  está vencida.
- Un vehículo cuyo kilometraje actual no cambia por mucho tiempo (el vencimiento por fecha sigue
  aplicando).
- Un mantenimiento programado para un vehículo cuyo kilometraje actual ya rebasó el objetivo
  después de programarse (aparece como Vencido).
- Un mantenimiento programado en una orden cuyo mecánico se desactivó después (se conserva).
- Vehículo sin kilometraje previo al registrar el kilometraje del servicio (se acepta cualquier valor
  no negativo razonable).
- Reejecutar la carga de datos de ejemplo: no debe duplicar refacciones, movimientos, líneas de
  refacciones ni mantenimientos.
- Sesión cuyo rol cambió o cuenta desactivada: la siguiente solicitud se valida con el estado vigente.

## Requisitos *(obligatorio)*

### Requisitos funcionales

- **FR-001**: El sistema DEBE ofrecer, para cada vehículo, un historial de servicios derivado de las
  órdenes de servicio Terminadas o Entregadas, ordenado cronológicamente (más reciente primero), sin
  duplicar información ya registrada en las órdenes. Cada elemento DEBE mostrar fecha, folio,
  kilometraje, problema reportado, diagnóstico, servicios y mano de obra realizados, refacciones
  usadas y mecánico.
- **FR-002**: Las órdenes que aún no están Terminadas NO DEBEN aparecer como servicios realizados en
  el historial.
- **FR-003**: Mecánicos, recepcionistas y administradores DEBEN poder consultar el historial de
  cualquier vehículo; el historial es de solo lectura.
- **FR-004**: El mecánico asignado (y los administradores) DEBEN poder registrar el kilometraje del
  servicio de una orden Terminada, que DEBE ser un número entero no negativo, igual o mayor al
  kilometraje de entrada, y razonable (hasta 2 000 000). Si es mayor al kilometraje actual del
  vehículo, el sistema DEBE actualizar el kilometraje actual con ese valor.
- **FR-005**: El mecánico asignado (y los administradores) DEBEN poder establecer un próximo
  mantenimiento para el vehículo de una orden Terminada o Entregada, con descripción del servicio
  por realizar y una fecha objetivo, un kilometraje objetivo, o ambos. El sistema DEBE rechazar un
  mantenimiento sin ninguno de los dos, con una fecha anterior a hoy o con un kilometraje objetivo
  menor o igual al kilometraje actual del vehículo.
- **FR-006**: El sistema DEBE permitir editar la descripción, la fecha y el kilometraje objetivo de un
  mantenimiento mientras no esté Atendido, y marcarlo como Atendido; al registrar un nuevo próximo
  mantenimiento para un vehículo, los anteriores no atendidos de ese vehículo DEBEN pasar a Atendido.
- **FR-007**: El sistema DEBE ofrecer a recepcionistas y administradores una lista de mantenimientos con cliente, teléfono, vehículo, descripción, objetivo
  y estado calculado (Normal, Próximo o Vencido), con filtro por estado y búsqueda por cliente o
  placa. Por defecto se ordena Vencidos, Próximos y Normales; los Atendidos no aparecen en la lista
  de pendientes, pero sí en el historial del vehículo.
- **FR-008**: El estado de un mantenimiento DEBE calcularse, no capturarse: es Vencido si la fecha
  objetivo ya pasó o si el kilometraje actual del vehículo alcanzó o superó el objetivo (basta una
  de las dos condiciones); es Próximo si queda dentro del margen de aviso, que por
  defecto es de 30 días o 1 000 km (lo que ocurra primero) y es configurable; en otro caso es Normal.
- **FR-009**: Los intervalos y márgenes de aviso de los mantenimientos DEBEN ser configurables; el
  sistema NO DEBE asumir intervalos universales (por ejemplo, un cambio de aceite a cierto
  kilometraje) ni imponerlos al registrar un mantenimiento.
- **FR-010**: Los administradores DEBEN poder registrar refacciones con código único, nombre,
  descripción opcional, unidad de medida, stock mínimo y stock inicial, y editar sus datos (excepto
  el stock, que solo cambia por movimientos). Las refacciones NO se eliminan; pueden desactivarse y
  reactivarse.
- **FR-011**: Administradores y mecánicos DEBEN poder consultar el catálogo de refacciones con
  búsqueda por código o nombre y filtro por estado de stock (suficiente, bajo, agotado). Los
  administradores ven además el detalle con stock mínimo e historial de movimientos; los mecánicos
  ven solo código, nombre, unidad y existencia.
- **FR-012**: El sistema DEBE llevar un registro de movimientos de inventario de solo
  agregar, con tres tipos: Entrada (ingreso de mercancía, stock inicial o devolución de una orden),
  Salida (uso en una orden) y Ajuste (corrección por conteo, merma o error). Cada movimiento DEBE
  guardar refacción, tipo, cantidad, motivo (obligatorio en los ajustes), persona, fecha y hora y la
  orden relacionada cuando exista. Los movimientos NO se editan ni se eliminan.
- **FR-013**: Los administradores DEBEN poder registrar entradas de mercancía y ajustes de
  inventario; el stock de una refacción DEBE ser siempre la suma de sus movimientos.
- **FR-014**: El mecánico asignado (y los administradores) DEBEN poder agregar a una orden en cualquier
  estado hasta Terminado inclusive (no Entregada) refacciones activas con una cantidad entera positiva. Toda refacción usada DEBE estar
  asociada a una orden (RN-6).
- **FR-015**: Agregar una refacción a una orden DEBE generar, en la misma operación, un movimiento de
  Salida ligado a la orden que descuente el stock (RN-7). Si la operación falla, no debe quedar
  ni la línea en la orden ni el movimiento.
- **FR-016**: El sistema NO DEBE permitir que el stock de una refacción quede negativo en ninguna
  operación, ni siquiera con solicitudes simultáneas; en tal caso rechaza la operación e informa el
  stock disponible (RN-8).
- **FR-017**: El mecánico asignado (y los administradores) DEBEN poder corregir la cantidad o quitar
  una refacción de una orden no Entregada; el sistema DEBE registrar el movimiento compensatorio
  correspondiente (salida adicional o entrada de devolución) para que el stock siempre refleje el uso
  real. Agregar la misma refacción dos veces a una orden suma sobre una sola línea.
- **FR-018**: Una orden Entregada DEBE seguir siendo de solo lectura: no admite agregar, corregir ni
  quitar refacciones ni cambios de kilometraje de servicio.
- **FR-019**: Los administradores DEBEN ver alertas de stock bajo: refacciones activas con stock
  menor o igual a su mínimo, distinguiendo las Agotadas (stock cero), con un indicador visible con
  el conteo y una lista con stock actual y mínimo; las alertas se actualizan al consultarse tras
  cualquier movimiento.
- **FR-020**: El sistema DEBE validar los permisos por rol en cada operación del lado del servidor,
  con independencia de lo que muestre la interfaz: catálogo, entradas, ajustes y alertas solo para
  administradores (con consulta de catálogo para mecánicos); refacciones de orden, kilometraje de
  servicio y mantenimientos solo para el mecánico asignado y administradores; consulta de historial
  para todos los roles; lista de mantenimientos con datos del cliente solo para recepcionistas y
  administradores.
- **FR-021**: El sistema DEBE validar en el servidor todos los datos recibidos y devolver mensajes
  claros en español, sin exponer detalles internos.
- **FR-022**: El sistema DEBE pedir confirmación antes de aplicar un ajuste de inventario, quitar una
  refacción de una orden, desactivar una refacción y marcar un mantenimiento como Atendido, y mostrar
  mensajes de éxito o error tras cada acción.
- **FR-023**: El sistema DEBE conservar toda la información de forma persistente y permitir recrear
  el esquema completo desde cero, sin modificar los scripts de los sprints anteriores.
- **FR-024**: El sistema DEBE incluir datos de ejemplo suficientes para mostrar información al primer
  arranque: refacciones en estado suficiente, bajo y agotado con sus movimientos de entrada, salida y
  ajuste; refacciones usadas en órdenes de ejemplo; órdenes Terminadas y Entregadas que formen
  historial de varios vehículos; y mantenimientos en estado Normal, Próximo, Vencido y Atendido. La
  carga DEBE ser repetible sin duplicar registros.
- **FR-025**: Toda pantalla nueva DEBE seguir el sistema de diseño del proyecto
  (`docs/design-system.md`), con estados vacío, cargando y error, y mostrar en el menú solo las
  secciones permitidas al rol: Inventario y alertas para administradores, Mantenimientos para
  recepcionistas y administradores, y el historial dentro del detalle del vehículo y de la orden.
- **FR-026**: El sistema DEBE mantener fuera del alcance de este sprint: pagos, Mercado Pago, tickets,
  panel de indicadores y notificaciones externas (correo, WhatsApp). Los avisos de mantenimiento son
  solo consulta en pantalla; el taller contacta al cliente por su cuenta.
- **FR-027**: Las pruebas automatizadas de la lógica de inventario (stock, movimientos, uso en
  órdenes y no negatividad) y de mantenimiento (cálculo de estado y validaciones) DEBEN existir y
  pasar.

### Entidades clave *(incluir si la funcionalidad involucra datos)*

- **Refacción**: Pieza o insumo del inventario. Tiene código único, nombre, descripción opcional,
  unidad de medida, stock actual (derivado de sus movimientos), stock mínimo y estado activo o
  inactivo.
- **Movimiento de inventario**: Registro inmutable de un cambio de stock de una refacción. Tiene
  tipo (Entrada, Salida o Ajuste), cantidad, motivo, persona, fecha y hora y, cuando aplica, la
  orden de servicio relacionada.
- **Refacción de la orden**: Línea que indica qué refacción y qué cantidad se usó en una orden de
  servicio. Una orden tiene cero o más; una misma refacción aparece una sola vez por orden.
- **Mantenimiento**: Próximo servicio programado para un vehículo, con descripción, fecha objetivo,
  kilometraje objetivo (al menos uno), orden de origen, estado de seguimiento (Pendiente o Atendido)
  e indicador calculado (Normal, Próximo o Vencido).
- **Historial del vehículo**: Vista de solo lectura derivada de las órdenes Terminadas o Entregadas
  de un vehículo; no es una entidad con datos propios.
- **Orden de servicio, Vehículo, Cliente y Usuario**: Ya existen desde los sprints anteriores; el
  historial, los mantenimientos y las refacciones se relacionan con ellos.

## Criterios de éxito *(obligatorio)*

### Resultados medibles

- **SC-001**: Un mecánico localiza el historial completo de un vehículo y lo lee en menos de
  30 segundos desde que inicia sesión.
- **SC-002**: Un mecánico agrega una refacción a una orden, con su cantidad, en menos de 1 minuto y
  el stock refleja el cambio de inmediato.
- **SC-003**: Un administrador registra una refacción nueva con su stock inicial y mínimo en menos de
  2 minutos, sin ayuda.
- **SC-004**: El flujo completo "terminar servicio → verlo en historial → programar próximo
  mantenimiento → usar refacciones en la orden → ver el stock actualizado → ver la alerta de stock
  bajo" se ejecuta de principio a fin, con los tres roles, en menos de 10 minutos durante una
  demostración.
- **SC-005**: Cero operaciones dejan una refacción con stock negativo, verificado con pruebas
  automatizadas que incluyen solicitudes simultáneas.
- **SC-006**: El 100 % de las salidas de inventario por uso en órdenes tiene un movimiento ligado a
  su orden, y en todas las refacciones el stock coincide con la suma de sus movimientos.
- **SC-007**: El 100 % de los mantenimientos de ejemplo se clasifica correctamente como Normal,
  Próximo o Vencido según las reglas definidas, verificado con pruebas automatizadas.
- **SC-008**: El 100 % de las solicitudes que un rol no tiene permitido (por ejemplo, un mecánico
  ajustando inventario o un recepcionista modificando refacciones de una orden) es rechazado, aun
  cuando no provenga de la interfaz.
- **SC-009**: Una recepcionista identifica los mantenimientos vencidos y obtiene el teléfono del cliente
  en menos de 30 segundos.
- **SC-010**: Un administrador ve las refacciones en stock bajo o agotadas en una sola pantalla al
  entrar, sin buscarlas.
- **SC-011**: Tras una instalación nueva, el sistema muestra historial, mantenimientos, refacciones y
  alertas de ejemplo sin capturar nada a mano, y repetir la carga no genera duplicados.
- **SC-012**: Los listados de refacciones, mantenimientos e historial, con hasta 1 000 registros,
  muestran búsquedas y filtros en menos de 2 segundos.

## Suposiciones

Las decisiones que el documento del sprint dejó pendientes para `/speckit-clarify` se resolvieron
aquí con valores por defecto razonables, que pueden revisarse en esa fase:

- **Modelo de historial**: vista calculada a partir de las órdenes Terminadas o Entregadas (RN-10);
  no se crea una copia de los datos de las órdenes.
- **Reglas de vencimiento**: Vencido por fecha cuando la fecha objetivo ya pasó; Vencido por
  kilometraje cuando el kilometraje actual del vehículo es mayor o igual al objetivo; Próximo
  cuando faltan 30 días o menos, o 1 000 km o menos; estos márgenes son configurables (RN-12).
- **Política de stock negativo**: prohibido en todos los casos (RN-8); no hay configuración que lo
  permita en este sprint.
- **Tipos de movimiento**: Entrada (ingreso de mercancía, stock inicial y devolución desde una
  orden), Salida (uso en una orden) y Ajuste (corrección manual con motivo obligatorio, que fija el
  stock al valor contado).
- **Kilometraje del servicio**: el kilometraje de entrada ya existe desde el Sprint 2; en este
  sprint se agrega el kilometraje al terminar el servicio, que puede ser igual o mayor.
- **Refacciones por orden**: se pueden modificar mientras la orden no esté Entregada, incluso ya
  Terminada, para corregir omisiones; el movimiento compensatorio mantiene el stock exacto.
- **Matriz de permisos asumida**: ADMIN puede todo; MECHANIC consulta historial (que incluye los mantenimientos del vehículo) y
  catálogo, sin acceso a la lista de mantenimientos con datos del cliente, y registra kilometraje, mantenimientos y refacciones solo en sus órdenes asignadas;
  RECEPTIONIST consulta historial y mantenimientos para avisar al cliente y no gestiona inventario.
- **Unidades de medida**: texto libre breve (pieza, litro, juego, etc.); sin conversión entre
  unidades. Las cantidades son enteros.
- **Costos y precios**: las refacciones no tienen precio ni costo en este sprint y no afectan el total
  de las órdenes; eso corresponde a los sprints de pagos y tickets.
- **Alertas**: se consultan en pantalla y no se envían por ningún canal externo.
- **Datos de ejemplo**: incluyen órdenes ya Terminadas y Entregadas de más de un vehículo, para que
  el historial muestre información desde el primer arranque.
- Las decisiones de tecnología ya están fijadas por la constitución del proyecto
  (`.specify/memory/constitution.md`) y se tratarán en la fase de planeación, no aquí.
- Dependencias: clientes, vehículos, usuarios y roles del Sprint 1; citas y órdenes de servicio del
  Sprint 2; `docs/project-context.md` (alcance), `docs/design-system.md` (interfaz) y
  `docs/reglas.md` (reglas del proyecto).
