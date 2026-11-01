# Contrato de interfaz (Sprint 5: precios de refacciones y cobro completo)

Cambios en las pantallas del cliente Flutter. Todas siguen `docs/design-system.md` (Material 3, tema propio,
tokens de color, espaciado y radios; sin valores sueltos). Los importes se muestran con `formatMoney`. Los
textos van en español. Ninguna pantalla nueva: se modifican las existentes.

## Inventario (administrador)

### Listado de refacciones (`inventory_screen.dart`)

- Columnas nuevas: **Categoría**, **Marca** y **Precio de venta**. El precio de compra no se muestra en el
  listado.
- Una refacción sin precio de venta muestra el chip ámbar **«Sin precio de venta»** en lugar del precio.
- El buscador acepta también categoría y marca; el texto de ayuda lo indica.
- El mecánico conserva su vista reducida (código, nombre, unidad y existencia), sin ninguna columna de precio.

### Formulario de refacción (`part_form_screen.dart`)

- Campos nuevos: **Categoría**, **Marca** (texto libre de hasta 60 caracteres), **Precio de compra** (opcional) y
  **Precio de venta**.
- Los precios se validan al escribir: numérico, sin negativos, hasta dos decimales y hasta 9 999 999.99; el
  precio de venta debe ser mayor a cero. Los errores del servidor se muestran en el campo que corresponde.
- Si el precio de venta es menor al de compra, el servidor responde `PRICE_BELOW_COST` y la pantalla abre un
  diálogo de confirmación: «El precio de venta ($X) es menor al de compra ($Y). ¿Guardar de todos modos?» con
  **Cancelar** y **Guardar de todos modos**. Al confirmar se reenvía con `confirmBelowCost: true`.
- Al editar una refacción que ya tiene precio de venta, ese campo no se puede dejar vacío.

### Detalle de refacción (`part_detail_screen.dart`)

Muestra categoría, marca y ambos precios al administrador, y la etiqueta «Sin precio de venta» cuando
corresponde.

## Refacciones de la orden (`order_parts_section.dart`)

- **Administración y recepción**: cada línea muestra cantidad, **precio unitario** e **importe**, y debajo de la
  lista el subtotal de refacciones. Una línea anterior al sprint muestra el importe 0.00 con la indicación
  **«Anterior a los precios»**.
- **Mecánico**: la lista es la actual (código, nombre, unidad y cantidad), sin precio ni importe.
- Al intentar agregar una refacción sin precio de venta, un `SnackBar` rojo muestra: «La refacción no tiene
  precio de venta. Avisa al administrador para que lo capture.»
- Con un pago Pagado, los botones de agregar, quitar y cambiar cantidad se deshabilitan y la sección muestra
  «La orden ya está cobrada: no se pueden modificar las refacciones.» (el servidor igualmente lo rechaza).
- Errores `ORDER_TOTAL_LIMIT` y `LEGACY_LINE_LOCKED` se muestran con el mensaje del servidor.

## Cobro de la orden (bloque `billing` del detalle)

- Antes de registrar el pago se muestra el **desglose**: servicios, mano de obra y refacciones (cantidad, precio
  e importe), con tres subtotales y el total (FR-023). Las líneas anteriores muestran 0.00 y la indicación
  «Anterior a los precios».
- Una orden con solo refacciones con precio se puede cobrar; el botón de cobro sigue las reglas de `canCharge`.
- Si hay un pago de Mercado Pago pendiente y `amountOutdated` es verdadero, se muestra un aviso ámbar: «El importe
  del pago pendiente ya no coincide con el total de la orden» con el botón **Cancelar pago y generar uno
  nuevo**, que pide confirmación antes de cancelar. Nada se cancela ni se crea sin esa confirmación.
- Si hay un pago Pagado con `amountDifference` distinto de 0.00, se muestra el aviso: «El total de la orden
  supera el pago registrado por $X. La diferencia se cobra fuera del sistema», sin botón de cobro.

## Ticket (`ticket_view.dart`, `ticket_printer.dart`)

- Se elige el diseño por `formatVersion`:
  - **Versión 2**: cada refacción con cantidad, precio e importe, tres subtotales (servicios, mano de obra y
    refacciones) y el total.
  - **Versión 1 (sin `formatVersion`)**: se muestra e imprime exactamente como se emitió, con las refacciones
    solo con su cantidad, sin leyendas ni columnas agregadas.
- La vista previa y la impresión usan el mismo diseño para cada versión.

## Estados comunes

Todas las vistas modificadas conservan sus estados de carga, vacío y error, y los mensajes de éxito o error de
los sprints anteriores. Las acciones destructivas (cancelar un pago, quitar una línea) piden confirmación.
