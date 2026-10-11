# Contrato de interfaz: pantallas, navegación y permisos (Sprint 4)

La interfaz sigue `docs/design-system.md` (tema propio de Material 3, tokens, transiciones suaves,
confirmaciones obligatorias) y amplía los contratos de los sprints anteriores. Ocultar una opción nunca
sustituye la validación del backend.

## Navegación

| Opción | Pantalla | ADMIN | RECEPTIONIST | MECHANIC |
|--------|----------|:-----:|:------------:|:--------:|
| Panel de control | Indicadores y actividad reciente del taller | ✔ | — | — |
| Pagos | Listado de pagos y detalle | ✔ | ✔ | — |
| Tickets | Listado de tickets y vista del ticket | ✔ | ✔ | — |
| Clientes, Vehículos, Citas, Órdenes, Mis órdenes, Mantenimientos, Inventario, Usuarios | (sprints 1 a 3) | según rol | según rol | según rol |

El cobro de una orden vive dentro del **detalle de la orden** (sección «Cobro»). Para el administrador, el
Panel de control es la primera opción del menú después de Inicio.

## Pantallas

| Pantalla | Contenido | Acciones | Estados obligatorios |
|----------|-----------|----------|----------------------|
| Panel de control (ADMIN) | Tarjetas numéricas agrupadas en Órdenes, Citas, Mantenimientos, Inventario y Cobros; bloque «Actividad reciente» con tres listas cortas (cambios de orden, pagos y movimientos de inventario); fecha y hora de la última actualización | Seleccionar una tarjeta para ir a su listado; «Actualizar» | Cargando, error con reintento, tarjetas en cero con estado vacío claro |
| Sección «Cobro» del detalle de la orden | Total a cobrar, estado de cobro (chip), pagos de la orden con método, importe, estado y fecha; aviso «El total cambió después del cobro» si el importe está desactualizado; botón y enlace al ticket | «Cobrar» (diálogo con método, referencia opcional y confirmación); en Mercado Pago: «Copiar enlace», «Abrir enlace» y «Actualizar estado»; «Cancelar cobro» (pendientes); «Generar ticket» / «Ver ticket» | Cargando, error, orden no cobrable (con motivo), Mercado Pago no disponible (método deshabilitado con leyenda) |
| Listado de pagos | Tabla con fecha, folio de la orden, cliente, placa, método, importe y chip de estado; búsqueda por folio, cliente o placa; filtros de estado y método; paginación | Abrir la orden; «Actualizar estado» en pendientes de Mercado Pago | Vacío, cargando, error, sin resultados |
| Listado de tickets | Tabla con folio, fecha, folio de la orden, cliente, placa y total; búsqueda por folio, cliente o placa; paginación | Abrir el ticket | Vacío, cargando, error, sin resultados |
| Ticket | Vista con formato de ticket: encabezado del taller, folio y fecha, cliente, vehículo con placas y kilometraje, tablas de servicios, refacciones (cantidad) y mano de obra, subtotales, total, método y estado del pago | «Imprimir» (diálogo de impresión del sistema), volver | Cargando, error |
| Advertencia al entregar sin cobro | Diálogo en el detalle de la orden al pulsar «Registrar entrega» cuando no hay pago Pagado | «Entregar de todos modos» / «Cancelar» | — |

## Chips y colores (convención del sistema de diseño)

| Estado | Color |
|--------|-------|
| Pago Pagado / cobro Pagado | Verde (completado) |
| Pago Pendiente / cobro Pendiente | Ámbar (advertencia) |
| Pago Rechazado | Rojo |
| Pago Cancelado / orden Sin cobrar | Neutro |

El color nunca es la única señal: cada chip lleva texto. En el panel, las tarjetas de mantenimientos vencidos y
de refacciones agotadas usan rojo; las de próximos y stock bajo, ámbar.

## Confirmaciones obligatorias (diálogo con "Confirmar" y "Cancelar")

- Registrar un pago (muestra método e importe; en Mercado Pago aclara que se creará un enlace de cobro).
- Cancelar un pago Pendiente.
- Generar el ticket (indica que conserva los datos tal como están).
- Registrar la entrega de una orden sin pago Pagado (advertencia adicional descrita arriba).

La consulta del estado de Mercado Pago, copiar o abrir el enlace y la impresión no piden confirmación, pero
muestran un mensaje de éxito o error.

## Comportamiento

- El diálogo de cobro nunca pide número de tarjeta, vencimiento ni código de seguridad; para «Tarjeta» solo
  ofrece una referencia opcional (folio de la terminal).
- El campo de referencia rechaza textos con 13 a 19 dígitos seguidos que cumplan la verificación de Luhn y explica que no debe capturarse un número
  de tarjeta.
- Si Mercado Pago no está disponible, el método aparece deshabilitado con la leyenda del servidor y los demás
  métodos siguen operando.
- Tras registrar o cancelar un pago, o generar el ticket, el detalle de la orden se vuelve a consultar.
- La impresión muestra solo el contenido del ticket (sin menús ni botones) y se arma en memoria, sin guardar
  archivos.
- Los importes se muestran con separador de miles y dos decimales; las fechas en formato local.

## Mensajes

Éxito breve mediante *snackbar*; errores en español, sin trazas ni códigos internos visibles. Los mensajes de
reglas de negocio (orden no cobrable, importe distinto, pago ya existente) reproducen el texto del servidor.
