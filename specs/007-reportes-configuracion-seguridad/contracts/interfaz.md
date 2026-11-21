# Contrato de interfaz (Sprint 7: reportes, configuración, términos y seguridad)

Cambios en el cliente Flutter. Todo sigue `docs/design-system.md` (Material 3, tema propio, tokens de color, espaciado y
radios; sin valores sueltos) y **no agrega dependencias**: se reutilizan `PageHeader`, `AppDataTable`, `ConfirmDialog`,
`state_views`, `StatusChip`, `fl_chart` y `url_launcher`. Los textos van en español. Las secciones nuevas son solo para
el administrador; la validación real está en el servidor.

## Menú

Secciones nuevas (`AppSection`), solo para ADMIN, en este orden debajo de Usuarios: **Reportes**, **Configuración**,
**Bitácora** y **Términos**. Ícono de contorno y de relleno como las demás. El mecánico y la recepción no las ven.

## Aceptación de términos (todos los roles)

- Pantalla completa que aparece **después de iniciar sesión** y antes del contenido, y también cuando el servidor
  responde `TERMS_NOT_ACCEPTED` en medio de una sesión. No tiene menú ni encabezado de navegación.
- Muestra el título, la versión («Versión 1.0») y el texto en una zona con desplazamiento; debajo, una casilla «He leído
  y acepto los términos y condiciones y el aviso de privacidad» y dos botones: **Rechazar y salir** y **Aceptar y
  continuar** (deshabilitado hasta marcar la casilla).
- **Rechazar y salir** cierra la sesión y vuelve al acceso con el aviso «Para usar Motorix debes aceptar los términos y
  condiciones».
- **Aceptar y continuar** envía la aceptación; si el servidor responde que la versión cambió, recarga el texto y avisa.
- Estados: cargando (indicador), error al cargar con **Reintentar** (no se puede continuar sin el texto).

## Cierre por inactividad (todos los roles)

- Un `InactivityGuard` rodea la aplicación autenticada y reinicia su temporizador con cualquier movimiento del puntero,
  clic, desplazamiento o tecla.
- A los **28 minutos** sin actividad aparece un diálogo no cerrable por fuera: «Tu sesión se cerrará por inactividad en
  2:00» con cuenta regresiva y el botón **Seguir conectado**. Pulsarlo reinicia el temporizador.
- A los **30 minutos** se cierra la sesión, se limpian los datos y el acceso muestra «Tu sesión se cerró por
  inactividad. Inicia sesión de nuevo.».
- Mientras la persona trabaja, el cliente consulta `GET /api/auth/me` como máximo cada 5 minutos para que el servidor vea
  la actividad. Si el servidor responde `SESSION_INACTIVE`, se cierra la sesión con el mismo mensaje.

## Configuración (solo ADMIN)

Pantalla con tres pestañas: **Taller**, **Mantenimiento** y **Tipos de servicio**.

- **Taller**: campos Nombre, Dirección y Teléfono con su límite de caracteres y el origen de cada valor (chip «Guardado»,
  «Variable de entorno» o «Predeterminado»). Botón **Guardar cambios** (deshabilitado sin cambios). Mensaje «Datos del taller
  guardados. Los tickets nuevos los usarán; los emitidos no cambian».
- **Mantenimiento**: campos «Margen de Próximo (días)» y «Margen de Próximo (km)» con sus límites y el texto de ayuda
  «Un mantenimiento es Próximo cuando falta este margen o menos».
- **Tipos de servicio**: tabla con Nombre, Cada (días), Cada (km), Estado (chip «Activo» o «Inactivo») y Acciones
  (editar y activar o desactivar). Botón **Nuevo tipo de servicio**. El formulario valida nombre y que haya al menos un
  intervalo. Desactivar pide confirmación y dice «Las órdenes anteriores conservan el tipo».
- Estados: cargando, error con **Reintentar** y vacío («Todavía no hay tipos de servicio»).

## Servicios de la orden y próximo mantenimiento

- **Formulario de servicio** (`order_work_section`): selector opcional **Tipo de servicio** (los activos) junto a la
  descripción; la línea muestra el tipo en un chip. Sin elegir, funciona como hasta ahora.
- **Programar el próximo mantenimiento** (`maintenance_dialog`): botón **Usar el intervalo del servicio** que consulta la
  propuesta y rellena fecha y kilometraje; la persona los corrige antes de guardar. Sin propuesta, el botón explica «Ningún
  servicio de la orden tiene un intervalo».

## Ticket

La vista y la impresión del ticket de versión 3 agregan, bajo el total, el bloque **Próximo servicio** con la fecha y el
kilometraje (los que existan). Los tickets de versión 1 y 2 se ven e imprimen igual que antes.

## Reportes (solo ADMIN)

- Encabezado con título y, a la derecha, **Exportar CSV**.
- **Selector de periodo**: botones Hoy, Esta semana, Este mes y Rango, con dos selectores de fecha para el rango libre;
  muestra el periodo elegido. Máximo un año: si se pasa, el campo se marca con «El periodo no puede pasar de un año».
- Pestañas: **Ingresos**, **Servicios y productividad** y **Refacciones y rotación**.
  - **Ingresos**: tarjetas con total y número de pagos, barras por día (`fl_chart`) y tabla por método de pago.
  - **Servicios y productividad**: tabla de servicios por frecuencia y tabla de mecánicos (órdenes terminadas e importe de
    mano de obra).
  - **Refacciones y rotación**: tabla con unidades, ingreso, costo, margen y %; las refacciones sin precio de compra
    muestran el chip ámbar «Sin costo»; debajo, la tabla de rotación (salidas, existencia inicial y final, promedio y
    rotación).
- **Exportar CSV**: descarga el reporte de la pestaña activa con el periodo elegido y lo guarda en la carpeta de
  descargas; mensaje «Archivo guardado en [ruta]» con el botón **Abrir carpeta**. Si no se puede guardar, muestra el
  error. Sin datos exporta solo los encabezados.
- Estados: cargando, vacío («No hay datos en este periodo»), error con **Reintentar**.

## Bitácora (solo ADMIN)

- Tabla con Fecha, Usuario, Acción (chip con el nombre en español), Entidad y Resumen, de la más reciente a la más antigua,
  con paginación.
- Filtros: rango de fechas, usuario y acción; botón **Limpiar filtros**.
- Sin acciones de edición ni de borrado. Estados: cargando, vacío («No hay registros con esos filtros»), error con
  **Reintentar**.

## Términos (solo ADMIN)

- Muestra la versión vigente (título, versión, fecha de publicación y texto) y, debajo, la tabla de aceptaciones
  (usuario, nombre y fecha) con el contador «N pendientes de aceptar». No hay botón de edición: el texto lo entrega el
  sistema.

## Contraseñas

El formulario de alta y edición de usuarios y la pantalla «Cambiar contraseña» muestran la ayuda «Mínimo 10 caracteres, con
una mayúscula, una minúscula y un número» y validan al escribir con la regla nueva; el servidor responde con el mensaje
del campo si no se cumple.

## Documentación de diseño

`docs/design-system.md` se actualiza en este sprint con una sección nueva «Reportes, configuración, términos y seguridad
(Sprint 7)»: pestañas, selector de periodo, chip «Sin costo», pantalla de aceptación y diálogo de inactividad.
