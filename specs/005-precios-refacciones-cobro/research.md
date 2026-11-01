# Investigación: Precios de refacciones y cobro completo (Sprint 5)

Resuelve las decisiones técnicas de la Fase 0. No quedan puntos por aclarar: las decisiones de negocio ya
están en la sección Aclaraciones de [spec.md](./spec.md). Cada decisión se verificó contra el código de los
sprints 3 y 4.

## D-01. La instantánea del precio vive en la línea de la orden

- **Decisión**: agregar `unit_price DECIMAL(10,2) NOT NULL DEFAULT 0` a `order_parts`. Toda línea nueva guarda
  el precio de venta vigente (siempre mayor a cero); las líneas anteriores quedan en `0` y no suman al total.
  Un precio `0` identifica sin ambigüedad una línea anterior al sprint.
- **Justificación**: es la forma más simple de cumplir FR-004, FR-015 y la decisión D-03. No hace falta una
  bandera aparte porque FR-002 prohíbe un precio de venta igual a cero.
- **Alternativas**: columna anulable (`NULL` = anterior), descartada porque obliga a tratar `NULL` en cada suma;
  tabla de precios históricos, descartada porque no hay historial de precios en este sprint.

## D-02. Categoría y marca como columnas de texto

- **Decisión**: `category VARCHAR(60) NULL` y `brand VARCHAR(60) NULL` en `parts`, sin catálogo, con búsqueda
  por ambas en el listado (FR-001).
- **Justificación**: el insumo deja fuera catálogos y la categoría no se usa para calcular nada (decisión D-06).
- **Alternativas**: tabla `part_categories` administrable, descartada por ampliar el alcance con una pantalla y
  reglas nuevas.

## D-03. Precios en `parts` con restricciones en la base

- **Decisión**: `purchase_price DECIMAL(10,2) NULL` con `CHECK (purchase_price IS NULL OR purchase_price >= 0)` y
  `sale_price DECIMAL(10,2) NULL` con `CHECK (sale_price IS NULL OR sale_price > 0)`. Las refacciones existentes
  quedan con ambos precios en `NULL`: «sin precio de venta» significa `sale_price IS NULL` (FR-015, FR-020).
- **Justificación**: la base impide un precio de venta en cero o negativo aunque falle la validación del
  servidor. El tope de 9 999 999.99 lo da el tipo `DECIMAL(10,2)` más la validación `zod`.
- **Alternativas**: dejar solo la validación en el servidor, descartada porque la constitución pide integridad
  en la base para las reglas de dinero.

## D-04. El total sigue calculándose, ahora con refacciones

- **Decisión**: `orderWorkModel.totals()` devuelve `{ services, labor, parts, total }` y suma en SQL
  `SUM(quantity * unit_price)` de `order_parts`; las tres sumas pasan a centavos enteros en el servidor. Un
  módulo puro `server/services/orderTotals.js` concentra el importe de una línea, el tope del total y el
  mensaje de rechazo, y se prueba sin base de datos.
- **Justificación**: mantiene el acuerdo del Sprint 4 (el total no se guarda en la orden), un único punto de
  cálculo que usan el detalle, el cobro y el ticket (SC-002), y no cambia la firma que consumen otros servicios.
- **Alternativas**: guardar el total en la orden, descartada porque obliga a mantenerlo sincronizado y rompe el
  acuerdo del Sprint 4.

## D-05. Orden de bloqueos y serialización

- **Decisión**: se conserva el orden de `orderPartService`: bloquear la orden, luego la refacción. El registro
  de pago ya bloquea la orden antes de leer. Por eso los cambios de refacciones y el pago de una misma orden se
  serializan (FR-010) y la operación que llega segunda ve el resultado de la primera. La verificación de «pago
  Pagado» y del tope del total se hace dentro de la misma transacción, después de bloquear.
- **Justificación**: es lo que ya garantiza el código; solo se agregan lecturas dentro del bloqueo.
- **Alternativas**: control optimista con versión de la orden, descartado por añadir una columna y reintentos.

## D-06. Un precio de venta que cambia al mismo tiempo que un alta de línea

- **Decisión**: el alta de la línea lee `sale_price` con la refacción ya bloqueada (`FOR UPDATE`), y la edición
  del precio es un `UPDATE` de la misma fila. InnoDB las ordena: la línea toma el precio anterior o el nuevo,
  nunca un valor intermedio (FR-004).
- **Alternativas**: leer el precio fuera de la transacción, descartado porque abriría una ventana de lectura
  desfasada.

## D-07. Bloqueo de refacciones con un pago Pagado

- **Decisión**: en `orderPartService`, tras bloquear la orden, buscar el pago vigente; si está `PAGADO`, rechazar
  con `409 ORDER_ALREADY_PAID` el alta, el cambio de cantidad y la baja (FR-026). Con un pago `PENDIENTE` se
  permite y el pago queda desfasado (FR-012).
- **Justificación**: un pago Pagado es final y solo se admite un pago vigente; sin este bloqueo las refacciones
  agregadas después no podrían cobrarse nunca.
- **Alternativas**: bloquear también servicios y mano de obra, descartado porque cambia el comportamiento del
  Sprint 4 (queda como suposición fuera de alcance en la especificación).

## D-08. Confirmación de un precio de venta menor al de compra

- **Decisión**: el cuerpo de alta y edición acepta `confirmBelowCost: true`. Si el precio de venta resultante es
  menor al de compra y falta la confirmación, el servidor responde `422 PRICE_BELOW_COST` con ambos precios en
  `details` y no guarda nada. La pantalla muestra el aviso y reenvía con la confirmación (FR-025).
- **Justificación**: la confirmación explícita se prueba en el servidor y no depende de la interfaz.
- **Alternativas**: solo advertir en la pantalla, descartado porque no queda comprobable en el servidor.

## D-09. Dónde existe cada precio y cómo se proyecta por rol

- **Decisión**: el precio de compra solo se selecciona en `partModel` para las rutas de refacciones
  (`GET/POST/PATCH /api/parts…`, todas del administrador salvo el listado, que para el mecánico usa
  `toMechanicPart` sin precios). Las líneas de la orden nunca incluyen el precio de compra; incluyen
  `unitPrice` y `amount` solo para administración y recepción. Recepción no accede a `/api/parts` (el catálogo es
  de administrador y mecánico), así que no tiene ninguna ruta por la que obtener el precio de compra (FR-013).
- **Justificación**: reduce la superficie de fuga a una sola proyección. Una prueba recorre todas las rutas con
  cada rol y busca las claves `purchasePrice`, `salePrice`, `unitPrice` y `amount` (SC-006).
- **Alternativas**: filtrar en el controlador, descartado porque la regla pertenece a la proyección del servicio.

## D-10. Totales del mecánico

- **Decisión**: la respuesta para el mecánico conserva `totals` con `services`, `labor` y `total` calculados solo
  con servicios y mano de obra, y sin el campo `parts`. El detalle de sus líneas de refacción omite `unitPrice`
  y `amount`.
- **Justificación**: es compatible hacia atrás con la pantalla actual y no revela precios de refacciones (FR-014).
  El `total` que ve el mecánico no incluye refacciones, y el contrato lo documenta.
- **Alternativas**: quitar `totals` al mecánico, descartado por romper el modelo actual del cliente; incluir el
  total completo, descartado porque permitiría despejar el precio de las refacciones.

## D-11. Formato versión 2 del ticket

- **Decisión**: el contenido nuevo lleva `formatVersion: 2`; los tickets anteriores no tienen ese campo y se
  tratan como versión 1. Cada refacción del ticket nuevo agrega `unitPrice` y `amount`, y `totals` agrega
  `parts`. El `total` es el importe del pago registrado (FR-007). La pantalla y la impresión eligen el diseño
  por `formatVersion`, no por revisar si hay precios (FR-008).
- **Justificación**: el contenido ya es una instantánea JSON, así que no se requiere cambio de esquema en
  `tickets`.
- **Riesgo conocido**: si los servicios o la mano de obra cambian después de pagar (hueco del Sprint 4 que no se
  cierra aquí), los subtotales pueden no sumar el total del pago. Se documenta y se cubre con una prueba que
  fija que el total del ticket es el importe del pago.

## D-12. Aprobación tardía de Mercado Pago

- **Decisión**: no cambia `paymentService.refresh`: un pago pendiente aprobado por el proveedor pasa a `PAGADO`
  con su importe original. El bloque de cobro agrega `amountDifference` (total vigente menos pago Pagado) para
  mostrar la diferencia por cobrar (FR-027). No se crea ni se cobra la diferencia.
- **Alternativas**: rechazar la aprobación, descartado porque el cobro real ya ocurrió en el proveedor.

## D-13. Intento de cobro con un pago pendiente desfasado

- **Decisión**: cuando `POST /api/orders/:id/payments` encuentra un pago pendiente, calcula si su importe coincide
  con el total vigente y agrega `details.outdated` al error `PAYMENT_ALREADY_EXISTS` para que la pantalla ofrezca
  cancelarlo y generar uno nuevo (FR-012). La cancelación ya existe y es de recepción y administración.

## D-14. Migración aditiva y repetible

- **Decisión**: `005_sprint5_part_prices.sql` solo agrega columnas con valores nulos o por omisión. El ejecutor
  actual registra cada script en `schema_migrations`, así que una repetición tras un fallo no vuelve a aplicar
  lo ya registrado. Como el DDL de MySQL no es transaccional, el script se escribe en pasos que se pueden
  repetir (`ADD COLUMN` seguido de las restricciones) y se documenta cómo revertirlo a mano en
  [quickstart.md](./quickstart.md).

## D-15. Datos de ejemplo del sprint

- **Decisión**: el seed `005_part_prices.sql` es idempotente. Asigna categoría, marca y precios a las
  refacciones del seed 003 donde `sale_price IS NULL`, dejando una sin precio (`BOM-AGU`) para mostrar el
  bloqueo. Agrega líneas con precio a órdenes Terminadas sin pago y a la orden con pago de Mercado Pago pendiente
  (para el pago desfasado), y no toca las líneas anteriores (quedan en `0`). La claves naturales son
  (orden, refacción), así que repetir el seed no duplica.
- **Nota**: no se modifican órdenes con pago Pagado (FR-026) ni se llama a Mercado Pago.

## D-16. Frontend sin dependencias nuevas

- **Decisión**: se reutilizan los widgets y proveedores de los sprints 3 y 4. Los modelos de Dart aceptan los
  campos de precio como opcionales, porque el mecánico no los recibe. Los textos nuevos van en español y los
  colores salen de los tokens del sistema de diseño (chip ámbar «Sin precio de venta»).

## D-17. Documentación que se actualiza en el sprint

- **Decisión** (FR-018): `docs/project-context.md` (secciones 6.7, 6.10, la entidad `Part` y la tabla de
  sprints) y `docs/design-system.md`, que además corrige el desfase conocido de los indicadores del panel
  (hallazgo F1 del Sprint 4: 4 frente a 10). También se retiran los comentarios de `ticketContent.js` que dicen
  que las refacciones no suman importe.

## Estrategia de pruebas

- **Unitarias**: `orderTotals` (importe, tope y casos de borde), validadores de precios, `ticketContent` versión 2
  y compatibilidad con la versión anterior, y `assertOrderPayable` con total cero.
- **Integración**: precios de refacciones (alta, edición, permisos, confirmación, búsqueda); líneas de orden
  (instantánea, refacción sin precio, línea anterior, tope, pago Pagado, solicitudes simultáneas); cobro con
  refacciones (total, importe, Mercado Pago, orden con solo refacciones, pago desfasado, aprobación tardía);
  ticket versión 2 y ticket anterior; fuga de precios por rol en todas las rutas; seeds idempotentes.
- **Regresión**: toda la línea base de los sprints 1 a 4. Las pruebas de `NOTHING_TO_CHARGE` siguen vigentes
  porque una orden sin servicios, mano de obra ni refacciones con precio mantiene total cero; solo cambia el
  mensaje (hallazgo H-03).
- **Frontend**: modelos con y sin precios, formulario con el aviso, listado con la etiqueta, líneas de la orden
  por rol, desglose del cobro y ticket en ambas versiones.
