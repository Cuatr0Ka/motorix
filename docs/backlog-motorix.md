# Backlog del producto - Motorix

> **Corte:** 2026-11-19. **Fuente:** `specs/001` a `specs/005` (sprints construidos) y `docs/sprints/sprint-6-*.md` y `sprint-7-*.md` (sprints pendientes).
> **Formato:** estilo Jira. Épica → historia de usuario → criterios de aceptación. Las claves `MOT-n` son consecutivas y el campo *Sprint* indica dónde se entrega.
> **Puntos de historia:** estimación relativa en escala de Fibonacci hecha para este backlog; el equipo la puede recalibrar.
> **Fuera del alcance (descartado):** chatbot de WhatsApp y mensajería al cliente, portal del cliente, facturación electrónica, fotos del vehículo, hosting y puesta en producción.

## Resumen

| Sprint | Tema | Historias | Puntos | Estado |
|---|---|---|---|---|
| 1 | Base, clientes y vehículos | 6 | 31 | Hecho |
| 2 | Citas y órdenes de servicio | 6 | 34 | Hecho |
| 3 | Historial e inventario | 6 | 31 | Hecho |
| 4 | Pagos, tickets y panel | 4 | 26 | Hecho |
| 5 | Precios de refacciones y cobro | 5 | 22 | Hecho |
| 6 | Notificaciones internas | 7 | 29 | Pendiente |
| 7 | Reportes, configuración, términos y seguridad | 10 | 55 | Pendiente |
| **Total** | | **44** | **228** | 27 hechas, 17 pendientes |

## Épicas

| Clave | Épica | Sprints | Historias |
|---|---|---|---|
| MOT-E1 | Acceso y usuarios | 1 | MOT-1, MOT-2 |
| MOT-E2 | Clientes y vehículos | 1 | MOT-3 a MOT-6 |
| MOT-E3 | Citas y órdenes de servicio | 2 | MOT-7 a MOT-12 |
| MOT-E4 | Historial y mantenimientos | 3 | MOT-13 a MOT-15 |
| MOT-E5 | Inventario y precios de refacciones | 3 y 5 | MOT-16 a MOT-18, MOT-27, MOT-31 |
| MOT-E6 | Cobro y tickets | 4 y 5 | MOT-19 a MOT-21, MOT-28 a MOT-30 |
| MOT-E7 | Panel de control | 4 | MOT-22 |
| MOT-E8 | Notificaciones y avisos | 6 | MOT-32 a MOT-38 |
| MOT-E9 | Reportes y configuración | 7 | MOT-39 a MOT-46 |
| MOT-E10 | Términos y seguridad de la información | 7 | MOT-47, MOT-48 |

Roles: **ADMIN** (administrador), **RECEPTIONIST** (recepcionista), **MECHANIC** (mecánico).

---

## MOT-E1 · Acceso y usuarios

### MOT-1 · Iniciar sesión según mi rol
- **Tipo:** Historia · **Prioridad:** Alta (P1) · **Puntos:** 5 · **Sprint:** 1 · **Estado:** Hecho
- **Historia:** Como usuario del taller (administrador, recepcionista o mecánico), quiero iniciar sesión con mi usuario o correo y contraseña para acceder a las funciones según mi rol.
- **Criterios de aceptación:**
  - Dado una cuenta activa, cuando escribo mi usuario o mi correo con la contraseña correcta, entonces entro al sistema con las opciones de mi rol.
  - Dado credenciales incorrectas o una cuenta inactiva, cuando intento entrar, entonces se rechaza el acceso con un mensaje claro.
  - Los permisos se validan en el backend, no solo en la interfaz.

### MOT-2 · Gestionar usuarios y roles
- **Tipo:** Historia · **Prioridad:** Media (P2) · **Puntos:** 5 · **Sprint:** 1 · **Estado:** Hecho
- **Historia:** Como administrador, quiero gestionar usuarios y roles de acceso para controlar quién puede usar el sistema.
- **Criterios de aceptación:**
  - Dado que soy administrador, cuando registro un usuario con nombre de usuario, correo, contraseña y rol, entonces queda creado y puede iniciar sesión.
  - Dado un nombre de usuario o correo que ya existe, cuando intento registrarlo, entonces se rechaza.

## MOT-E2 · Clientes y vehículos

### MOT-3 · Registrar y consultar clientes
- **Tipo:** Historia · **Prioridad:** Alta (P1) · **Puntos:** 5 · **Sprint:** 1 · **Estado:** Hecho
- **Historia:** Como recepcionista, quiero registrar y consultar clientes para mantener actualizada la información de los propietarios.
- **Criterios de aceptación:**
  - Dado que soy recepcionista, cuando registro un cliente con los datos obligatorios, entonces queda guardado y aparece en la lista.
  - Dado datos obligatorios faltantes o con formato inválido, cuando intento guardar, entonces se rechaza con el error del campo.

### MOT-4 · Editar clientes
- **Tipo:** Historia · **Prioridad:** Media (P2) · **Puntos:** 3 · **Sprint:** 1 · **Estado:** Hecho
- **Historia:** Como recepcionista, quiero editar la información de los clientes para corregir o actualizar sus datos.
- **Criterios de aceptación:**
  - Dado un cliente existente, cuando cambio sus datos y confirmo, entonces los cambios se guardan.
  - Dado una edición con datos inválidos, cuando intento guardar, entonces se rechaza y se conservan los datos anteriores.

### MOT-5 · Registrar vehículos
- **Tipo:** Historia · **Prioridad:** Alta (P1) · **Puntos:** 5 · **Sprint:** 1 · **Estado:** Hecho
- **Historia:** Como recepcionista, quiero registrar vehículos para llevar el control de los automóviles atendidos.
- **Criterios de aceptación:**
  - Dado que soy recepcionista, cuando registro un vehículo con placa, marca, modelo y año, entonces queda guardado.
  - Dado una placa que ya pertenece a otro vehículo, cuando intento registrarlo, entonces se rechaza.

### MOT-6 · Asociar un vehículo con su propietario
- **Tipo:** Historia · **Prioridad:** Alta (P1) · **Puntos:** 8 · **Sprint:** 1 · **Estado:** Hecho
- **Historia:** Como recepcionista, quiero asociar un vehículo con su propietario para vincular la información correctamente.
- **Criterios de aceptación:**
  - Dado un cliente existente, cuando registro un vehículo y lo asocio a ese cliente, entonces el vehículo aparece en la ficha del cliente.
  - Dado que no selecciono propietario o selecciono uno inexistente, cuando intento guardar, entonces se rechaza.
- **Nota:** incluye la base del sistema (estructura, conexión a MySQL, JWT) que sostiene los demás sprints.

## MOT-E3 · Citas y órdenes de servicio

### MOT-7 · Registrar y consultar citas
- **Tipo:** Historia · **Prioridad:** Alta (P1) · **Puntos:** 5 · **Sprint:** 2 · **Estado:** Hecho
- **Historia:** Como recepcionista, quiero registrar y consultar citas para organizar la agenda del taller.
- **Criterios de aceptación:**
  - Dado un cliente con un vehículo registrado, cuando registro una cita con fecha, hora y motivo, entonces queda en la agenda.
  - Dado que hay varias citas, cuando filtro por fecha o estado, o busco por cliente o vehículo, entonces veo solo las que coinciden.

### MOT-8 · Crear una orden de servicio asociada a cliente y vehículo
- **Tipo:** Historia · **Prioridad:** Alta (P1) · **Puntos:** 8 · **Sprint:** 2 · **Estado:** Hecho
- **Historia:** Como recepcionista, quiero crear una orden de servicio asociada a un cliente y a su vehículo para iniciar la atención.
- **Criterios de aceptación:**
  - Dado un cliente con un vehículo registrado, cuando creo una orden indicando el vehículo y el motivo, entonces queda en estado Recibida con su folio.
  - Dado una cita Pendiente o Confirmada, cuando recibo el vehículo y creo la orden desde la cita, entonces la cita queda vinculada a la orden.

### MOT-9 · Asignar una orden a un mecánico
- **Tipo:** Historia · **Prioridad:** Alta (P1) · **Puntos:** 5 · **Sprint:** 2 · **Estado:** Hecho
- **Historia:** Como recepcionista, quiero asignar una orden a un mecánico para repartir el trabajo del taller.
- **Criterios de aceptación:**
  - Dado una orden sin mecánico, cuando selecciono un mecánico activo y la asigno, entonces queda asignada.
  - Dado una orden asignada que aún no está terminada, cuando la reasigno a otro mecánico, entonces cambia de responsable.

### MOT-10 · Consultar mis órdenes asignadas
- **Tipo:** Historia · **Prioridad:** Alta (P1) · **Puntos:** 5 · **Sprint:** 2 · **Estado:** Hecho
- **Historia:** Como mecánico, quiero consultar mis órdenes asignadas para saber qué trabajo tengo.
- **Criterios de aceptación:**
  - Dado que tengo órdenes asignadas, cuando abro mi sección de órdenes, entonces veo solo las mías.
  - Dado una orden asignada a otro mecánico, cuando intento consultarla por cualquier vía, entonces el backend la rechaza.

### MOT-11 · Registrar diagnóstico, servicios y recomendaciones
- **Tipo:** Historia · **Prioridad:** Media (P2) · **Puntos:** 5 · **Sprint:** 2 · **Estado:** Hecho
- **Historia:** Como mecánico, quiero registrar el diagnóstico, los servicios realizados y las recomendaciones para documentar el trabajo sobre el vehículo.
- **Criterios de aceptación:**
  - Dado una orden asignada a mí, cuando registro o edito el diagnóstico, entonces queda guardado en la orden.
  - Dado una orden asignada a mí, cuando agrego un servicio realizado con su descripción y su mano de obra, entonces se suma a la orden.

### MOT-12 · Cambiar el estado de una orden
- **Tipo:** Historia · **Prioridad:** Media (P2) · **Puntos:** 6 · **Sprint:** 2 · **Estado:** Hecho
- **Historia:** Como mecánico, quiero cambiar el estado de una orden para reflejar el avance real de la reparación.
- **Criterios de aceptación:**
  - Dado una orden Recibida y asignada a mí, cuando la paso a Diagnóstico, entonces el estado cambia.
  - Dado una orden en Diagnóstico o En reparación, cuando la paso a Esperando refacción, entonces el estado cambia y se registra el movimiento.
  - Los cambios de estado no válidos se rechazan.

## MOT-E4 · Historial y mantenimientos

### MOT-13 · Consultar el historial de servicios de un vehículo
- **Tipo:** Historia · **Prioridad:** Alta (P1) · **Puntos:** 5 · **Sprint:** 3 · **Estado:** Hecho
- **Historia:** Como recepcionista o mecánico, quiero consultar el historial de servicios de un vehículo para conocer lo que se le ha hecho.
- **Criterios de aceptación:**
  - Dado un vehículo con órdenes Terminadas o Entregadas, cuando consulto su historial, entonces veo cada servicio con su fecha y detalle.
  - Dado una orden aún abierta, cuando consulto el historial, entonces se distingue de las ya cerradas.

### MOT-14 · Registrar el kilometraje del servicio y el próximo mantenimiento
- **Tipo:** Historia · **Prioridad:** Alta (P1) · **Puntos:** 5 · **Sprint:** 3 · **Estado:** Hecho
- **Historia:** Como mecánico, quiero registrar el kilometraje del servicio y el próximo mantenimiento para programar el siguiente servicio del vehículo.
- **Criterios de aceptación:**
  - Dado una orden asignada a mí que está Terminada, cuando registro el kilometraje y el próximo mantenimiento, entonces quedan guardados.
  - Dado un kilometraje menor al de entrada de la orden, cuando intento guardarlo, entonces se rechaza.

### MOT-15 · Consultar mantenimientos próximos y vencidos
- **Tipo:** Historia · **Prioridad:** Media (P2) · **Puntos:** 5 · **Sprint:** 3 · **Estado:** Hecho
- **Historia:** Como recepcionista, quiero consultar los mantenimientos próximos y vencidos para avisar a los clientes.
- **Criterios de aceptación:**
  - Dado mantenimientos programados, cuando abro la lista, entonces veo cliente, vehículo y su estado.
  - Dado un mantenimiento por fecha cuya fecha ya pasó, cuando consulto la lista, entonces aparece como vencido.

## MOT-E5 · Inventario y precios de refacciones

### MOT-16 · Registrar y consultar refacciones y su stock
- **Tipo:** Historia · **Prioridad:** Alta (P1) · **Puntos:** 5 · **Sprint:** 3 · **Estado:** Hecho
- **Historia:** Como administrador, quiero registrar y consultar refacciones y su stock para controlar el inventario.
- **Criterios de aceptación:**
  - Dado que soy administrador, cuando registro una refacción con código, nombre, stock y mínimo, entonces queda en el inventario.
  - Dado un código ya registrado, cuando intento registrar otra refacción con el mismo código, entonces se rechaza.

### MOT-17 · Agregar refacciones utilizadas a una orden
- **Tipo:** Historia · **Prioridad:** Alta (P1) · **Puntos:** 8 · **Sprint:** 3 · **Estado:** Hecho
- **Historia:** Como mecánico, quiero agregar las refacciones utilizadas a una orden para que el inventario y la orden reflejen lo que se usó.
- **Criterios de aceptación:**
  - Dado una orden no entregada asignada a mí y una refacción activa con stock suficiente, cuando la agrego, entonces el stock se descuenta.
  - Dado una cantidad mayor al stock disponible, cuando intento agregarla, entonces se rechaza y el stock no cambia.

### MOT-18 · Visualizar alertas de stock bajo
- **Tipo:** Historia · **Prioridad:** Media (P2) · **Puntos:** 3 · **Sprint:** 3 · **Estado:** Hecho
- **Historia:** Como administrador, quiero visualizar las alertas de stock bajo para reabastecer a tiempo.
- **Criterios de aceptación:**
  - Dado refacciones cuyo stock es menor o igual a su mínimo, cuando entro al inventario, entonces se señalan como stock bajo.
  - Dado una refacción con stock en cero, cuando se muestra la alerta, entonces se distingue como agotada.

### MOT-27 · Registrar categoría, marca y precios de una refacción
- **Tipo:** Historia · **Prioridad:** Alta (P1) · **Puntos:** 5 · **Sprint:** 5 · **Estado:** Hecho
- **Historia:** Como administrador, quiero registrar la categoría, la marca y los precios de compra y de venta de una refacción para tener claro su costo y lo que se cobra.
- **Criterios de aceptación:**
  - Dado que soy administrador, cuando registro una refacción con categoría, marca, precio de compra y precio de venta, entonces quedan guardados.
  - Dado una refacción existente, cuando edito su categoría, su marca o sus precios, entonces los cambios se guardan sin alterar lo ya cobrado.

### MOT-31 · Mantener reservados los precios según el rol
- **Tipo:** Historia · **Prioridad:** Media (P2) · **Puntos:** 3 · **Sprint:** 5 · **Estado:** Hecho
- **Historia:** Como administrador, quiero que los precios queden reservados según el rol para que el mecánico y el recepcionista no vean información que no les corresponde.
- **Criterios de aceptación:**
  - Dado que soy mecánico, cuando agrego refacciones a una orden y consulto el inventario, entonces no veo precios.
  - Dado que soy recepcionista, cuando consulto refacciones, órdenes, pagos y tickets, entonces solo veo lo que mi rol permite.
  - La respuesta del backend no incluye los precios reservados; no basta con ocultarlos en pantalla.

## MOT-E6 · Cobro y tickets

### MOT-19 · Registrar el pago de una orden con su método de pago
- **Tipo:** Historia · **Prioridad:** Alta (P1) · **Puntos:** 5 · **Sprint:** 4 · **Estado:** Hecho
- **Historia:** Como recepcionista, quiero registrar el pago de una orden con su método de pago para cerrar el cobro del servicio.
- **Criterios de aceptación:**
  - Dado una orden Terminada o Entregada, cuando abro su detalle, entonces veo el total a cobrar.
  - Dado una orden Terminada sin pago vigente, cuando registro un pago en efectivo, tarjeta o transferencia, entonces queda registrado.

### MOT-20 · Cobrar con Mercado Pago en modo de pruebas
- **Tipo:** Historia · **Prioridad:** Alta (P1) · **Puntos:** 8 · **Sprint:** 4 · **Estado:** Hecho
- **Historia:** Como recepcionista, quiero cobrar con Mercado Pago en modo de pruebas para validar el cobro digital sin mover dinero real.
- **Criterios de aceptación:**
  - Dado una orden Terminada sin pago vigente y las credenciales de pruebas configuradas, cuando inicio el cobro, entonces se genera un pago Pendiente.
  - Dado un pago de Mercado Pago Pendiente, cuando el cliente lo completa en el entorno de pruebas, entonces el pago pasa a Pagado.

### MOT-21 · Generar, visualizar e imprimir el ticket de servicio
- **Tipo:** Historia · **Prioridad:** Alta (P1) · **Puntos:** 8 · **Sprint:** 4 · **Estado:** Hecho
- **Historia:** Como recepcionista, quiero generar, visualizar e imprimir el ticket de servicio para entregarlo al cliente.
- **Criterios de aceptación:**
  - Dado una orden con un pago Pagado, cuando genero el ticket, entonces se crea con un folio.
  - Dado un ticket generado, cuando lo visualizo, entonces incluye folio, datos del taller, cliente, vehículo, servicios, refacciones, total y método de pago.

### MOT-28 · Cobrar las refacciones utilizadas dentro del total de la orden
- **Tipo:** Historia · **Prioridad:** Alta (P1) · **Puntos:** 5 · **Sprint:** 5 · **Estado:** Hecho
- **Historia:** Como recepcionista, quiero que el total de la orden incluya las refacciones utilizadas para cobrar el servicio completo.
- **Criterios de aceptación:**
  - Dado una orden con servicios, mano de obra y refacciones con precio, cuando consulto su total, entonces suma todo.
  - Dado que agrego una refacción a una orden, cuando el sistema la registra, entonces conserva el precio vigente en ese momento.

### MOT-29 · Registrar el pago y entregar un ticket con el total correcto
- **Tipo:** Historia · **Prioridad:** Alta (P1) · **Puntos:** 5 · **Sprint:** 5 · **Estado:** Hecho
- **Historia:** Como recepcionista, quiero que el pago y el ticket reflejen el total con refacciones para entregar al cliente un comprobante correcto.
- **Criterios de aceptación:**
  - Dado una orden Terminada con refacciones con precio, cuando registro un pago, entonces el importe es el total completo.
  - Dado un importe enviado que no coincide con el total vigente, cuando intento registrar el pago, entonces se rechaza.

### MOT-30 · Conservar sin cambios los pagos y tickets ya emitidos
- **Tipo:** Historia · **Prioridad:** Alta (P1) · **Puntos:** 4 · **Sprint:** 5 · **Estado:** Hecho
- **Historia:** Como administrador, quiero que los pagos y tickets ya emitidos conserven su importe para que el historial contable no cambie.
- **Criterios de aceptación:**
  - Dado pagos y tickets generados antes del sprint, cuando los consulto o los imprimo, entonces muestran el mismo importe.
  - Dado un pago y un ticket emitidos, cuando el administrador cambia el precio de una refacción, entonces no se modifican.

## MOT-E7 · Panel de control

### MOT-22 · Consultar el panel de control del taller
- **Tipo:** Historia · **Prioridad:** Media (P2) · **Puntos:** 5 · **Sprint:** 4 · **Estado:** Hecho
- **Historia:** Como administrador, quiero consultar el panel de control del taller para conocer el estado general de la operación.
- **Criterios de aceptación:**
  - Dado que soy administrador, cuando abro el panel, entonces veo con datos reales los vehículos en el taller, las citas, las órdenes y el stock bajo.
  - Dado el panel, cuando reviso un indicador, entonces su valor coincide con el resultado de la consulta del módulo correspondiente.

---

## MOT-E8 · Notificaciones y avisos (Sprint 6, pendiente)

> Los avisos se calculan al consultar con datos reales; solo se guarda quién los marcó como leídos y a quién ya se avisó. No hay mensajería automática: recepción avisa al cliente por teléfono o en persona.

### MOT-32 · Ver el total de avisos pendientes en el encabezado
- **Tipo:** Historia · **Prioridad:** Alta · **Puntos:** 5 · **Sprint:** 6 · **Estado:** Por hacer
- **Historia:** Como administrador, quiero ver en el encabezado cuántos avisos pendientes tengo para atenderlos sin recorrer cada módulo.
- **Criterios de aceptación:**
  - El encabezado muestra una campana con el total de avisos no leídos del usuario y abre un panel con los avisos agrupados por tipo.
  - Los avisos se calculan con datos reales y no se copian a otra tabla.
  - El centro maneja estados de carga, vacío y error según `docs/design-system.md`.

### MOT-33 · Ver mantenimientos próximos y vencidos y las citas del día
- **Tipo:** Historia · **Prioridad:** Alta · **Puntos:** 5 · **Sprint:** 6 · **Estado:** Por hacer
- **Historia:** Como recepcionista, quiero ver los mantenimientos próximos y vencidos y las citas del día para avisar a los clientes a tiempo.
- **Criterios de aceptación:**
  - Los tipos de aviso incluyen mantenimientos próximos, mantenimientos vencidos y citas del día.
  - Los números coinciden con el dashboard y con la lista de Mantenimientos (mismo cálculo).

### MOT-34 · Ver las refacciones con stock bajo o agotado
- **Tipo:** Historia · **Prioridad:** Media · **Puntos:** 3 · **Sprint:** 6 · **Estado:** Por hacer
- **Historia:** Como administrador, quiero ver las refacciones con stock bajo o agotado para reabastecer a tiempo.
- **Criterios de aceptación:**
  - El aviso de stock bajo o agotado aparece solo para el administrador; el backend no lo devuelve a RECEPTIONIST ni a MECHANIC.
  - La insignia actual de Inventario y el aviso de la pantalla de inicio siguen funcionando y no se contradicen con el centro.

### MOT-35 · Ver las órdenes detenidas
- **Tipo:** Historia · **Prioridad:** Media · **Puntos:** 3 · **Sprint:** 6 · **Estado:** Por hacer
- **Historia:** Como administrador o recepcionista, quiero ver las órdenes detenidas para destrabarlas.
- **Criterios de aceptación:**
  - El aviso de órdenes detenidas aparece para ADMIN y RECEPTIONIST con enlace a la orden.
  - Si la condición deja de cumplirse, el aviso desaparece.

### MOT-36 · Ver solo los avisos de mis órdenes asignadas
- **Tipo:** Historia · **Prioridad:** Media · **Puntos:** 3 · **Sprint:** 6 · **Estado:** Por hacer
- **Historia:** Como mecánico, quiero ver solo los avisos de mis órdenes asignadas para no recibir información que no me corresponde.
- **Criterios de aceptación:**
  - El backend devuelve a cada rol únicamente sus avisos: ADMIN todos; RECEPTIONIST mantenimientos, citas y órdenes detenidas; MECHANIC solo avisos de órdenes asignadas a él.
  - Existen pruebas de permisos por rol.

### MOT-37 · Marcar un aviso como leído y abrir el módulo relacionado
- **Tipo:** Historia · **Prioridad:** Media · **Puntos:** 5 · **Sprint:** 6 · **Estado:** Por hacer
- **Historia:** Como usuario, quiero marcar un aviso como leído y abrir el módulo relacionado desde él para dar seguimiento rápido.
- **Criterios de aceptación:**
  - Marcar un aviso como leído persiste por usuario.
  - Si el aviso reaparece con otro estado, vuelve a mostrarse como no leído.
  - Cada aviso abre la pantalla relacionada (orden, cita, vehículo o inventario).

### MOT-38 · Lista de clientes por avisar
- **Tipo:** Historia · **Prioridad:** Alta · **Puntos:** 5 · **Sprint:** 6 · **Estado:** Por hacer
- **Historia:** Como recepcionista, quiero una lista de clientes por avisar (vehículo listo, cita de mañana, mantenimiento próximo o vencido) con su teléfono, y marcar cada uno como avisado, para contactarlos por teléfono o en persona sin olvidar ni repetir avisos.
- **Criterios de aceptación:**
  - RECEPTIONIST y ADMIN ven cliente, teléfono, vehículo y motivo; MECHANIC no accede (validado en backend).
  - Marcar como avisado guarda quién y cuándo, y saca al cliente de la lista.
  - Si surge un hecho nuevo (otra orden u otra cita), el cliente aparece de nuevo.
  - Los seeds incluyen un caso de cada tipo y son idempotentes.

## MOT-E9 · Reportes y configuración (Sprint 7, pendiente)

> Si el tiempo no alcanza, el sprint se divide: primero configuración, catálogo, términos y seguridad (MOT-39 a MOT-41, MOT-46, MOT-47 y MOT-48) y después reportes (MOT-42 a MOT-45).

### MOT-39 · Editar los datos del taller
- **Tipo:** Historia · **Prioridad:** Alta · **Puntos:** 3 · **Sprint:** 7 · **Estado:** Por hacer
- **Historia:** Como administrador, quiero editar el nombre, la dirección y el teléfono del taller para que el ticket muestre datos correctos sin tocar el servidor.
- **Criterios de aceptación:**
  - Dado que soy administrador, cuando cambio los datos del taller, entonces los tickets nuevos los muestran.
  - Los datos dejan de depender del archivo `.env`.
  - Los tickets ya emitidos no cambian.

### MOT-40 · Ajustar los márgenes de "Próximo" del mantenimiento
- **Tipo:** Historia · **Prioridad:** Media · **Puntos:** 3 · **Sprint:** 7 · **Estado:** Por hacer
- **Historia:** Como administrador, quiero ajustar los márgenes de "Próximo" del mantenimiento para adaptarlos a la operación del taller.
- **Criterios de aceptación:**
  - Dado un nuevo margen en días o en kilómetros, cuando consulto los mantenimientos, entonces la clasificación Próximo usa ese margen.
  - Los avisos del Sprint 6 y el panel usan el mismo margen.

### MOT-41 · Catálogo de tipos de servicio con intervalos
- **Tipo:** Historia · **Prioridad:** Alta · **Puntos:** 8 · **Sprint:** 7 · **Estado:** Por hacer
- **Historia:** Como administrador, quiero mantener un catálogo de tipos de servicio con su intervalo en días y en kilómetros para que el próximo mantenimiento se proponga sin asumir intervalos universales.
- **Criterios de aceptación:**
  - Dado el catálogo, cuando el mecánico registra el próximo mantenimiento, entonces se propone según el intervalo del tipo de servicio.
  - El administrador puede crear, editar y desactivar tipos de servicio.

### MOT-42 · Consultar los ingresos por periodo
- **Tipo:** Historia · **Prioridad:** Alta · **Puntos:** 5 · **Sprint:** 7 · **Estado:** Por hacer
- **Historia:** Como administrador, quiero consultar los ingresos por periodo para conocer cómo avanza el taller.
- **Criterios de aceptación:**
  - Dado un rango de fechas, cuando consulto el reporte, entonces veo los ingresos pagados del periodo.
  - Solo el administrador accede, validado en backend.

### MOT-43 · Ver los servicios más frecuentes y la productividad por mecánico
- **Tipo:** Historia · **Prioridad:** Media · **Puntos:** 5 · **Sprint:** 7 · **Estado:** Por hacer
- **Historia:** Como administrador, quiero ver los servicios más frecuentes y la productividad por mecánico para tomar decisiones de operación.
- **Criterios de aceptación:**
  - Dado un periodo, cuando consulto el reporte, entonces veo los servicios ordenados por frecuencia y las órdenes terminadas por mecánico.

### MOT-44 · Ver costo, precio y margen de las refacciones y la rotación del inventario
- **Tipo:** Historia · **Prioridad:** Media · **Puntos:** 8 · **Sprint:** 7 · **Estado:** Por hacer
- **Historia:** Como administrador, quiero ver el costo, el precio y el margen de las refacciones usadas y la rotación del inventario para controlar la rentabilidad.
- **Criterios de aceptación:**
  - Dado un periodo, cuando consulto el reporte, entonces veo por refacción el costo, el precio, el margen y las unidades usadas.
  - La rotación se calcula con los movimientos reales del inventario.

### MOT-45 · Exportar cada reporte
- **Tipo:** Historia · **Prioridad:** Media · **Puntos:** 5 · **Sprint:** 7 · **Estado:** Por hacer
- **Historia:** Como administrador, quiero exportar cada reporte para compartirlo o archivarlo.
- **Criterios de aceptación:**
  - Dado un reporte en pantalla, cuando lo exporto, entonces obtengo un archivo con los mismos datos y filtros.

### MOT-46 · Mostrar la fecha del próximo servicio en el ticket
- **Tipo:** Historia · **Prioridad:** Media · **Puntos:** 5 · **Sprint:** 7 · **Estado:** Por hacer
- **Historia:** Como cliente, quiero que mi ticket indique cuándo toca mi próximo servicio para recordarlo sin que nadie me escriba.
- **Criterios de aceptación:**
  - Dado una orden con próximo mantenimiento registrado, cuando se genera el ticket, entonces incluye la línea "Próximo servicio" con la fecha o el kilometraje.
  - Dado una orden sin próximo mantenimiento, cuando se genera el ticket, entonces la línea no aparece.
  - Los tickets ya emitidos no cambian.

---

## MOT-E10 · Términos y seguridad de la información (Sprint 7, pendiente)

> Complementa lo que ya existe desde el Sprint 1: contraseñas con hash, sesión con vencimiento, bloqueo por intentos fallidos y permisos validados en backend. No incluye cifrado de la base, respaldos, HTTPS ni despliegue.

### MOT-47 · Aceptar los términos y condiciones al ingresar
- **Tipo:** Historia · **Prioridad:** Alta · **Puntos:** 5 · **Sprint:** 7 · **Estado:** Por hacer
- **Historia:** Como usuario del taller, quiero leer y aceptar los términos y condiciones y el aviso de privacidad al ingresar al sistema para conocer las reglas de uso y cómo se protege la información de los clientes.
- **Criterios de aceptación:**
  - Dado un usuario que no ha aceptado la versión vigente, cuando inicia sesión, entonces ve la pantalla de aceptación antes de usar el sistema; si la rechaza, se cierra la sesión.
  - La aceptación guarda usuario, versión y fecha, y se pide de nuevo solo cuando se publica una versión nueva.
  - Los términos cubren el uso permitido, la confidencialidad de los datos de clientes y vehículos, la responsabilidad de las cuentas personales y el aviso de privacidad.
  - La aceptación se valida en backend, no solo en la pantalla.

### MOT-48 · Proteger la información del sistema
- **Tipo:** Historia · **Prioridad:** Alta · **Puntos:** 8 · **Sprint:** 7 · **Estado:** Por hacer
- **Historia:** Como administrador, quiero una bitácora de acciones sensibles, una política de contraseñas, cierre de sesión por inactividad y respuestas sin datos reservados para detectar usos indebidos y proteger los datos del taller y de sus clientes.
- **Criterios de aceptación:**
  - La bitácora registra inicios de sesión fallidos y bloqueos, cambios de usuarios y roles, de configuración y de precios, y pagos cancelados; el administrador la consulta con filtros y nadie puede editarla desde la aplicación.
  - La bitácora no guarda contraseñas, hashes, tokens ni datos de tarjeta.
  - La política de contraseñas (longitud y complejidad) se aplica al crear y al cambiar la contraseña.
  - La sesión se cierra tras un periodo de inactividad.
  - Ninguna respuesta de la API incluye el hash, el token ni los precios reservados al rol, y hay pruebas que lo verifican.

## Notas

- Los criterios de aceptación de los sprints 1 a 5 se resumen de `specs/00N-*/spec.md`, donde está el detalle completo. Los de los sprints 6 y 7 se resumen de sus insumos en `docs/sprints/` y se afinarán en `/speckit.specify` y `/speckit.clarify`.
- Para importarlo a Jira, cada bloque `MOT-n` es una historia y cada `MOT-En` una épica; el campo *Sprint* ya está asignado.
