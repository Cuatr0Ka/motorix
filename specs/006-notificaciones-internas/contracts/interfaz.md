# Contrato de interfaz (Sprint 6: notificaciones internas y clientes por avisar)

Cambios en el cliente Flutter. Todo sigue `docs/design-system.md` (Material 3, tema propio, tokens de color,
espaciado y radios; sin valores sueltos) y no agrega dependencias. Los textos van en español. Se agrega una
sección de menú y un panel en el encabezado; las demás pantallas no cambian, salvo lo indicado.

## Encabezado: campana de notificaciones (todos los roles)

- Se agrega al `_Header` de `app_shell.dart`, entre el nombre de la sección y el usuario actual. Es un botón de
  ícono con la insignia del total de avisos **no leídos**. Sin avisos no leídos no se muestra número. Más de 99 se
  muestra «99+».
- La insignia usa el color de advertencia (ámbar) del sistema de diseño; si hay avisos vencidos o de stock
  agotado sin leer, usa el color de error (rojo).
- Etiqueta de accesibilidad: «Notificaciones, N sin leer». Se puede abrir con el teclado.
- El contador se actualiza al iniciar sesión, al cambiar de sección y cada 60 segundos mientras la sesión esté
  abierta. Al cerrar sesión se limpia y el temporizador se detiene.

## Panel de notificaciones

Panel anclado a la campana (no pantalla completa), de ancho fijo, con desplazamiento vertical y botón de cierre.

- **Estructura**: un encabezado con el título «Notificaciones» y el texto «N sin leer»; debajo, una sección por
  tipo con su nombre, su total y sus avisos, en este orden: **Mantenimientos vencidos**, **Stock agotado**,
  **Órdenes detenidas**, **Citas de hoy**, **Mantenimientos próximos**, **Stock bajo**. Solo aparecen las
  secciones con avisos.
- **Cada aviso** muestra un indicador de color por tipo (rojo para vencido y agotado, ámbar para próximo, bajo y
  detenida, neutro para la cita), el título, el detalle y, si está leído, el texto atenuado. Los no leídos se
  distinguen con un punto y texto normal.
- **Acciones por aviso**: pulsar el aviso lo marca como leído y abre la pantalla relacionada (la orden, la cita,
  el vehículo o el inventario) y cierra el panel; un botón «Marcar como leído» solo marca. No hay confirmación
  porque no es una acción destructiva.
- **Límite**: si un tipo tiene más de 50 avisos, se muestra «Mostrando 50 de N» al final de su sección.
- **Estados** (sección 8.4 del sistema de diseño):
  - Cargando: indicador de carga centrado en el panel (la primera vez; después se conserva el contenido anterior).
  - Vacío: ícono, «No hay avisos pendientes» y el texto «Cuando haya algo que atender aparecerá aquí».
  - Error: mensaje «No se pudieron consultar los avisos» con el botón **Reintentar**; si había datos previos se
    conservan y se muestra el error arriba.
- **Por rol**: el administrador ve todas las secciones; la recepción no ve las de stock; el mecánico solo ve
  «Órdenes detenidas» de sus órdenes y sin nombre de cliente.

## Sección «Clientes por avisar» (ADMIN y RECEPTIONIST)

- **Menú**: elemento nuevo «Clientes por avisar» (`AppSection.clientNotices`) visible solo para administrador y
  recepción, debajo de «Mantenimientos». El mecánico no lo ve y, si llegara a la ruta, el servidor responde 403.
- **Pantalla**: encabezado de página con el título y el texto «Llama o avisa en persona y marca al cliente como
  avisado. El sistema no envía mensajes.»; después, una tabla (`AppDataTable`) con las columnas **Cliente**,
  **Teléfono**, **Vehículo**, **Motivo**, **Fecha** y **Acción**.
- **Motivo**: chip con el texto «Vehículo listo», «Cita de mañana», «Mantenimiento próximo» o «Mantenimiento
  vencido» y los colores de la convención (verde para listo, ámbar para próximo y cita, rojo para vencido).
- **Teléfono**: se muestra tal cual; si está vacío, «Sin teléfono registrado» en texto atenuado.
- **Acción**: botón **Avisado**. Abre un diálogo de confirmación: «¿Ya avisaste a [cliente] por [motivo]?» con
  **Cancelar** y **Sí, avisado**. Al confirmar, la fila sale de la lista y se muestra el mensaje «Cliente
  marcado como avisado». Si el servidor responde que ya estaba avisado, se trata como éxito (la fila sale). Si
  responde `NOTICE_NOT_APPLICABLE`, se muestra «Este aviso ya no aplica» y se actualiza la lista.
- **Estados**: cargando, vacío («No hay clientes por avisar»), error con **Reintentar**, igual que las demás
  tablas.
- Al marcar un cliente, además se refresca la campana.

## Pantallas existentes: cambios

- **Inventario y pantalla de inicio**: sin cambios visuales; la insignia de Inventario y el aviso de stock siguen
  como están. Tras un movimiento de inventario, se refresca también el centro de notificaciones.
- **Navegación**: `NavigationProvider` suma `AppSection.clientNotices` y la incluye en `sectionsFor` para ADMIN y
  RECEPTIONIST.

## Documentación de diseño

`docs/design-system.md` se actualiza en este sprint: la sección 7 («Header») describe la campana y el panel, y
se agrega una sección nueva «Notificaciones y avisos a clientes (Sprint 6)» con los tipos, los colores, los
estados y el comportamiento de la insignia.
