---

description: "Lista de tareas del Sprint 5: precios de refacciones y cobro completo"
---

# Tareas: Precios de refacciones y cobro completo (Sprint 5)

**Entrada**: Documentos de diseño en `specs/005-precios-refacciones-cobro/`

**Requisitos previos**: plan.md, spec.md, research.md, data-model.md, contracts/ (api-rest.md e interfaz.md), quickstart.md

**Pruebas**: INCLUIDAS. La constitución (Principio VII) exige pruebas para la lógica de negocio (importes, instantáneas, permisos, estados de pago) y el aseguramiento de la calidad del sprint pide una prueba por cada criterio de aceptación; las del backend usan Jest + supertest contra `motorix_test` y las del frontend `flutter test`. Las pruebas se escriben antes que el código de la misma historia y deben fallar al principio.

**Organización**: Las tareas se agrupan por historia de usuario para poder implementar y probar cada una de forma independiente.

## Formato: `[ID] [P?] [Historia] Descripción`

- **[P]**: se puede ejecutar en paralelo (archivos distintos, sin dependencias pendientes)
- **[USn]**: historia de usuario a la que pertenece la tarea (US1 a US5 de spec.md)
- Todas las rutas son relativas a la raíz del repositorio (`D:\sdd\motorix`)

## Convenciones de rutas

- Backend: `server/` (capas directamente en la raíz de `server/`, sin carpeta `src/`)
- Frontend: `client/lib/` y `client/test/`
- Base de datos: `database/`
- El código backend usa ES Modules (`import`/`export`); los identificadores van en inglés y los comentarios, mensajes y nombres de pruebas en español
- Las pruebas de integración y contrato se ejecutan solo contra `motorix_test`; los errores nuevos usan `AppError` (`server/utils/AppError.js`) con los códigos de `contracts/api-rest.md`
- Los importes se calculan en centavos enteros y se presentan como cadenas con dos decimales; el tope de un precio y del total de una orden es 9 999 999.99
- El precio de compra solo se selecciona en `partModel` para las rutas de refacciones del administrador; ninguna otra respuesta lo incluye
- Las pruebas NUNCA llaman al Mercado Pago real: usan `FakeGateway` (`server/tests/helpers/factories.js`) con `setGateway`

## Orden de las historias (prioridad)

P1: US1 (precios en la refacción), US2 (total con refacciones), US3 (pago y ticket), US4 (conservar lo emitido). P2: US5 (reserva de precios por rol).

> Correspondencia con la especificación: US1 = Historia 1; US2 = Historia 2; US3 = Historia 3; US4 = Historia 4; US5 = Historia 5.

---

## Fase 1: Preparación (infraestructura compartida)

**Propósito**: verificar la base, registrar la condición de la constitución y alinear la documentación

- [X] T001 Verificar la línea base en la rama `005-precios-refacciones-cobro`: MySQL local en ejecución, migraciones 001 a 004 aplicadas en `motorix` y `motorix_test`, `npm test` (en `server/`) con 67 suites y 1003 pruebas y `flutter test` (en `client/`) con 277 pruebas, todo en verde, antes de tocar el código
- [X] T002 ⚠️ PUERTA (aprobada y registrada el 2026-10-31, versión 1.1.0): registrar la enmienda del principio I en `.specify/memory/constitution.md` (los sprints posteriores al MVP quedan permitidos con aprobación del equipo; versión MINOR, fecha de última enmienda y reporte de impacto del encabezado). Requiere la aprobación del director del proyecto y del equipo (hallazgo H-01 de `docs/aseguramiento-calidad-sprint-5.md`). Hasta que esté aprobada y registrada NO se ejecuta `/speckit.implement` ni se modifica código, migraciones ni seeds; solo pueden avanzar T001, T003 y T004
- [X] T003 [P] Actualizar `docs/project-context.md` (FR-018): §6.7 con los datos de la refacción (categoría, marca, precio de compra y de venta) y la regla de que una refacción sin precio de venta no se agrega a una orden; §6.8 y §6.10 con que el total suma servicios, mano de obra y refacciones y que el ticket nuevo detalla las refacciones; la entidad `Part` y la tabla de líneas de orden con `unit_price`; §7 y §14.1 con el Sprint 5; y §27 con las decisiones D-01 a D-10 de la sección Aclaraciones de spec.md
- [X] T004 [P] Actualizar `docs/design-system.md` (FR-018): corregir los indicadores del panel de control a los 10 que existen (hallazgo F1 del Sprint 4, que decía 4) y documentar los elementos nuevos: chip ámbar «Sin precio de venta», columnas de precio del inventario, aviso de importe desfasado, aviso de diferencia por cobrar, diálogo de venta bajo el costo y bloque de desglose del cobro

---

## Fase 2: Fundamentos (requisitos bloqueantes)

**Propósito**: esquema, módulo de totales, consulta de totales, proyección por rol y datos de prueba que DEBEN existir antes de cualquier historia

**⚠️ CRÍTICO**: esta fase no empieza hasta que la enmienda de la constitución (T002) esté aprobada, y ninguna historia puede empezar hasta terminarla

### Base de datos

- [X] T005 Crear `database/migrations/005_sprint5_part_prices.sql` (InnoDB, `utf8mb4`, aditiva, sin editar migraciones anteriores ni tocar datos de `payments` ni `tickets`; encabezado en español). Según data-model.md:
  - `parts`: `ADD COLUMN category VARCHAR(60) NULL`; `ADD COLUMN brand VARCHAR(60) NULL`; `ADD COLUMN purchase_price DECIMAL(10,2) NULL` con `CONSTRAINT chk_parts_purchase_price CHECK (purchase_price IS NULL OR purchase_price >= 0)`; `ADD COLUMN sale_price DECIMAL(10,2) NULL` con `CONSTRAINT chk_parts_sale_price CHECK (sale_price IS NULL OR sale_price > 0)`
  - `order_parts`: `ADD COLUMN unit_price DECIMAL(10,2) NOT NULL DEFAULT 0` con `CONSTRAINT chk_order_parts_unit_price CHECK (unit_price >= 0)`; las líneas existentes quedan en `0` (D-03)
  - Se conserva la llave única `uq_order_parts_line (order_id, part_id)`; sin tablas nuevas
- [X] T006 Aplicar la migración con `database/scripts/aplicar-migraciones.ps1 -Base motorix` y `-Base motorix_test`, y verificar que quede registrada en `schema_migrations`, que las refacciones existentes tengan los cuatro campos en `NULL`, que todas las líneas de `order_parts` existentes tengan `unit_price = 0`, que el número y los importes de `payments` y el contenido de `tickets` no cambien, y que repetir el comando no la vuelva a ejecutar
- [X] T007 [P] Actualizar `database/README.md` con la migración `005_sprint5_part_prices.sql`, el seed `005_part_prices.sql` y el procedimiento de reversa manual de `quickstart.md` (sección 6)

### Backend base

- [X] T008 [P] Crear `server/services/orderTotals.js` (módulo puro, sin base ni Express): `MAX_AMOUNT_CENTS` (999999999, es decir 9 999 999.99), `lineAmountCents(quantity, unitPriceCents)` (cantidad entera por centavos enteros), `isLegacyLine(unitPriceCents)` (verdadero si es `0`) y `assertTotalWithinLimit(totalCents)` que lanza `AppError.unprocessable('ORDER_TOTAL_LIMIT', 'El total de la orden no puede pasar de 9 999 999.99. Reduce la cantidad.', { limit: '9999999.99' })`
- [X] T009 [P] Crear `server/tests/unit/orderTotals.test.js`: importe de línea con cantidades 1, 2 y 100000, precios 0.01 y 9999999.99, total igual al tope y un centavo arriba, línea anterior (precio 0) y suma exacta de dos decimales sin fracciones; nombres y aserciones en español
- [X] T010 Modificar `server/models/orderWorkModel.js`: `totals(orderId, connection)` devuelve `{ services, labor, parts, total }`; `parts` es `SUM(quantity * unit_price)` de `order_parts` y las tres sumas pasan a centavos enteros antes de sumarse (FR-005)
- [X] T011 Modificar `server/models/orderPartModel.js`: el SELECT incluye `op.unit_price`; `toLine` agrega `unitPrice` (cadena con dos decimales), `amount` (cantidad por precio, dos decimales) y `legacy` (verdadero si `unit_price` es `0`); `insert` recibe `unitPrice` y lo guarda; `updateQuantity` no cambia el precio
- [X] T012 Crear en `server/services/orderTotals.js` (importado por `orderService`, `orderWorkService` y `orderPartService`, para no crear ciclos): `presentOrderPart(line, role)` (ADMIN y RECEPTIONIST reciben `unitPrice`, `amount` y `legacy`; MECHANIC solo `id`, `partId`, `code`, `name`, `unit` y `quantity`) y `presentTotals(totals, role)` (ADMIN y RECEPTIONIST reciben `services`, `labor`, `parts` y `total`; MECHANIC recibe `services`, `labor` y `total` calculado solo con servicios y mano de obra, sin `parts`, research D-10); `buildDetail` usa ambas
- [X] T013 [P] Modificar `server/tests/helpers/factories.js`: `createPart` acepta `category`, `brand`, `purchasePrice` y `salePrice` (por omisión sin categoría, marca ni precio de compra y con `salePrice` en 100, para que las pruebas que agregan la refacción a una orden no choquen con `PART_PRICE_MISSING`; las pruebas de «sin precio» pasan `salePrice: null`); `createOrderPart` acepta un quinto parámetro opcional `unitPrice` (por omisión `0`, para no alterar las pruebas existentes)

**Punto de control**: migración aplicada, módulo de totales probado y proyección por rol disponible; las 1003 pruebas de backend siguen en verde

---

## Fase 3: Historia de usuario 1 - Registrar categoría, marca y precios de una refacción (Prioridad: P1) 🎯 MVP

**Objetivo**: el administrador registra y edita categoría, marca y precios de las refacciones, con validaciones y aviso de venta bajo el costo

**Prueba independiente**: el administrador crea una refacción con categoría, marca, precio de compra y precio de venta, la edita y la consulta, y los datos se conservan; recepción y mecánico no pueden modificarlos

### Pruebas de la historia 1 (escribir primero y comprobar que fallan)

- [X] T014 [P] [US1] Crear `server/tests/unit/partPrices.test.js`: los esquemas `createPartSchema` y `updatePartSchema` aceptan precios válidos y rechazan negativos, no numéricos, con más de dos decimales, mayores a 9999999.99 y un precio de venta igual a cero; la categoría y la marca aceptan 60 caracteres y rechazan 61; el precio de venta capturado no acepta `null` y el precio de compra sí (borra el dato)
- [X] T015 [P] [US1] Crear `server/tests/integration/parts.prices.test.js`: alta con precios (201 y datos persistidos), edición parcial que no altera código ni existencia, precios inválidos con `400 VALIDATION_ERROR` por campo, precio de venta menor al de compra con `422 PRICE_BELOW_COST` sin guardar y con `confirmBelowCost: true` guardado, comparación contra el valor vigente en una edición parcial que cambia un solo precio, edición que solo cambia el nombre de una refacción que ya está bajo el costo (se guarda sin pedir confirmación), búsqueda por categoría y por marca, `priceMissing` verdadero en una refacción sin precio de venta, y `403` para recepción y mecánico al crear o editar
- [X] T016 [P] [US1] Modificar `server/tests/contract/parts.contract.test.js`: el listado, el detalle y las alertas del administrador incluyen `category`, `brand`, `purchasePrice`, `salePrice` y `priceMissing` con la forma de api-rest.md; el listado del mecánico conserva su forma sin ningún precio

### Implementación de la historia 1

- [X] T017 [US1] Modificar `server/validators/partValidators.js`: agregar `category` y `brand` (opcionales, hasta 60 caracteres), `purchasePrice` (opcional, no negativo) y `salePrice` (opcional, mayor a cero) con a lo sumo dos decimales y máximo 9999999.99 (número o cadena decimal), y `confirmBelowCost` (booleano opcional) a `createPartSchema` y `updatePartSchema`; ajustar el mensaje `.strict` de `updatePartSchema`, rechazar `salePrice: null` y aceptar `purchasePrice: null` (el precio de compra es opcional y puede borrarse); mensajes en español
- [X] T018 [US1] Modificar `server/models/partModel.js`: `COLUMNS` incluye `category, brand, purchase_price, sale_price`; `toPart` agrega `category`, `brand`, `purchasePrice`, `salePrice` (cadenas con dos decimales o `null`) y `priceMissing`; `toMechanicPart` no cambia; `insert` y `EDITABLE` incluyen los campos nuevos; `list` busca también en `category` y `brand`
- [X] T019 [US1] Modificar `server/services/partService.js`: en `create` y `update`, cuando el cuerpo trae `salePrice` o `purchasePrice`, calcular el precio de venta y de compra resultantes (los enviados o los vigentes) y, si la venta es menor a la compra y falta `confirmBelowCost: true`, lanzar `AppError.unprocessable('PRICE_BELOW_COST', 'El precio de venta es menor al de compra. Confirma para guardarlo.', { salePrice, purchasePrice })` sin guardar nada; si el cuerpo no trae ningún precio (por ejemplo, solo cambia el nombre) no se exige la confirmación aunque la refacción ya esté bajo el costo; el controlador y las rutas de `/api/parts` no cambian
- [X] T020 [P] [US1] Modificar `client/lib/models/part.dart`: `Part` agrega `category`, `brand`, `purchasePrice`, `salePrice` (opcionales, porque el mecánico no los recibe) y `priceMissing`; `PartInput` agrega los cuatro campos y `confirmBelowCost`, y `toJson` los envía solo cuando tienen valor
- [X] T021 [US1] Modificar `client/lib/services/parts_service.dart` (el proveedor `parts_provider.dart` no necesita cambios): enviar y leer los campos nuevos y dejar disponible el error `PRICE_BELOW_COST` con sus dos precios para que la pantalla pida confirmación, usando el mecanismo de errores de la capa de servicios existente
- [X] T022 [US1] Modificar `client/lib/screens/part_form_screen.dart` según contracts/interfaz.md: campos Categoría, Marca, Precio de compra y Precio de venta con sus validaciones en pantalla, diálogo «El precio de venta ($X) es menor al de compra ($Y). ¿Guardar de todos modos?» con Cancelar y Guardar de todos modos que reenvía con `confirmBelowCost`, y el precio de venta obligatorio al editar una refacción que ya lo tiene
- [X] T023 [US1] Modificar `client/lib/screens/inventory_screen.dart` y `client/lib/screens/part_detail_screen.dart`: columnas Categoría, Marca y Precio de venta, chip ámbar «Sin precio de venta» cuando `priceMissing`, buscador con ayuda que menciona categoría y marca, y detalle con ambos precios para el administrador; el mecánico conserva su vista sin precios
- [X] T024 [US1] Modificar `client/test/inventory_screens_test.dart` y `client/test/helpers/fake_api.dart`: formulario con los campos nuevos, validaciones en pantalla, diálogo de venta bajo el costo (cancelar no guarda y confirmar reenvía con la bandera), listado con columnas y chip, y vista del mecánico sin precios

**Punto de control**: la historia 1 funciona sola; el administrador gestiona precios y las refacciones sin precio quedan señaladas

---

## Fase 4: Historia de usuario 2 - Cobrar las refacciones dentro del total de la orden (Prioridad: P1)

**Objetivo**: las refacciones agregadas a una orden guardan su precio y suman al total, con las reglas de refacción sin precio, línea existente, línea anterior y tope del total

**Prueba independiente**: con una orden Terminada con un servicio, mano de obra y dos refacciones con precio, la recepción consulta el total y es la suma de los tres conceptos; un cambio de precio posterior no altera la línea

### Pruebas de la historia 2 (escribir primero y comprobar que fallan)

- [X] T025 [P] [US2] Crear `server/tests/integration/orderParts.prices.test.js`: la línea guarda el precio de venta vigente al agregarla; un cambio posterior del precio de la refacción no altera la línea ni el total; agregar una refacción sin precio de venta responde `422 PART_PRICE_MISSING` y no crea la línea ni el movimiento; agregar otra vez una refacción que ya está suma la cantidad y conserva el precio guardado; aumentar una línea anterior (precio 0) responde `422 LEGACY_LINE_LOCKED` y disminuirla o quitarla se permite; el total de la orden suma servicios, mano de obra y refacciones con dos decimales exactos; una línea o aumento que haría pasar el total de 9 999 999.99 responde `422 ORDER_TOTAL_LIMIT` y no cambia stock ni línea; una orden con solo refacciones con precio tiene total mayor a cero
- [X] T026 [P] [US2] Crear `server/tests/integration/orderParts.prices.concurrency.test.js`: editar el precio de venta de una refacción mientras otra solicitud la agrega a una orden deja la línea con el precio anterior o con el nuevo, nunca otro; dos altas simultáneas que juntas superarían el tope del total dejan una sola aceptada y el total dentro del límite
- [X] T027 [P] [US2] Modificar `server/tests/contract/orderParts.contract.test.js`: las líneas y la respuesta de agregar, cambiar y quitar para administración y recepción incluyen `unitPrice`, `amount` y `legacy`, y `totals` incluye `parts`, con la forma de api-rest.md

### Implementación de la historia 2

- [X] T028 [US2] Modificar `server/services/orderPartService.js` (`add`): dentro de la transacción y tras bloquear la orden y la refacción, rechazar con `PART_PRICE_MISSING` (422, «La refacción no tiene precio de venta. Avisa al administrador para que lo capture.») si `sale_price` es `NULL`; si la refacción ya está en la orden y su línea es anterior (precio 0) rechazar con `LEGACY_LINE_LOCKED` (422, «Esta línea es anterior a los precios: quítala y vuelve a agregarla.»); registrar el movimiento de inventario existente; calcular el total con `orderWorkModel.totals` más el incremento de la línea y llamar a `assertTotalWithinLimit`; insertar con `unitPrice = sale_price` o sumar la cantidad conservando el precio de la línea; devolver la línea con `presentOrderPart` según el rol del actor
- [X] T029 [US2] Modificar `server/services/orderPartService.js` (`updateQuantity` y `remove`): aumentar la cantidad aplica `LEGACY_LINE_LOCKED` y `assertTotalWithinLimit` además de las reglas de stock existentes; disminuir y quitar siguen igual; el precio de la línea nunca cambia (FR-024); las respuestas usan `presentOrderPart`
- [X] T030 [P] [US2] Modificar `client/lib/models/order_work.dart`: `OrderPart` agrega `unitPrice`, `amount` y `legacy` opcionales (el mecánico no los recibe) y `OrderTotals` agrega `parts` opcional
- [X] T031 [US2] Modificar `client/lib/widgets/order_parts_section.dart` según contracts/interfaz.md: administración y recepción ven precio unitario, importe y subtotal de refacciones, con «Anterior a los precios» en las líneas anteriores; el mecánico conserva la lista sin precios; los errores `PART_PRICE_MISSING`, `ORDER_TOTAL_LIMIT` y `LEGACY_LINE_LOCKED` se muestran con el mensaje del servidor en el error del diálogo de agregar o de corregir cantidad (que conserva lo capturado)
- [X] T032 [US2] Modificar `client/test/order_parts_test.dart`: líneas con precio e importe para administración y recepción, línea anterior con su indicación, subtotal, mensajes de error de los tres códigos nuevos y lista sin precios para el mecánico

**Punto de control**: las historias 1 y 2 funcionan; el total de una orden incluye refacciones con precio

---

## Fase 5: Historia de usuario 3 - Registrar el pago y entregar un ticket con el total correcto (Prioridad: P1)

**Objetivo**: el cobro, el desglose, Mercado Pago y el ticket nuevo reflejan el total con refacciones, y el pago desfasado se señala y se resuelve

**Prueba independiente**: con la orden de la historia 2, la recepción registra el pago en efectivo, genera el ticket y comprueba que el importe del pago y el total del ticket incluyen las refacciones

### Pruebas de la historia 3 (escribir primero y comprobar que fallan)

- [X] T033 [P] [US3] Modificar `server/tests/unit/ticketContent.test.js`: el contenido nuevo incluye `formatVersion: 2`, `parts[].unitPrice` y `parts[].amount`, `totals.parts` y los tres subtotales, y `totals.total` igual al importe del pago recibido; un contenido sin `formatVersion` (ticket del Sprint 4) sigue siendo válido y no se transforma
- [X] T034 [P] [US3] Crear `server/tests/integration/billing.parts.test.js`: `billing.total` y `breakdown` incluyen servicios, mano de obra y refacciones con sus subtotales; una orden con solo refacciones con precio es cobrable (`canCharge`) y una orden sin ningún concepto responde `422 NOTHING_TO_CHARGE`; el pago nace por el total con refacciones y un `amount` distinto responde `422 AMOUNT_MISMATCH` con `details.total`; el importe enviado a Mercado Pago (con `FakeGateway`) es el total con refacciones; un pago pendiente desfasado hace que `PAYMENT_ALREADY_EXISTS` incluya `details.outdated: true`; cancelarlo y crear otro con el total vigente funciona; un pago pendiente aprobado por el proveedor tras el cambio queda `PAGADO` con su importe original y `billing.amountDifference` muestra la diferencia; el mecánico recibe `403` al consultar, cancelar o actualizar un pago (se apoya en `payments.permissions.test.js` y se verifica con la orden de esta prueba)
- [X] T035 [P] [US3] Crear `server/tests/integration/tickets.v2.test.js`: el ticket de una orden cobrada con refacciones trae `formatVersion: 2`, las refacciones con precio e importe, los tres subtotales y el total igual al importe del pago; las líneas anteriores aparecen con `"0.00"`; cambiar el precio de una refacción después de generar el ticket no altera su contenido; si los servicios o la mano de obra cambian después del pago, el total del ticket sigue siendo el importe del pago y los subtotales reflejan las líneas actuales (comportamiento del Sprint 4 que se documenta y no se corrige aquí)
- [X] T036 [P] [US3] Modificar `server/tests/contract/payments.contract.test.js` y `server/tests/contract/tickets.contract.test.js`: el bloque `billing` incluye `amountDifference` y `breakdown` con la forma de api-rest.md, y el ticket nuevo usa la versión 2 sin romper la forma del ticket anterior

### Implementación de la historia 3

- [X] T037 [US3] Modificar `server/services/paymentRules.js`: el mensaje de `NOTHING_TO_CHARGE` pasa a «La orden no tiene nada que cobrar: el total es cero.» sin cambiar el código ni la condición
- [X] T038 [US3] Modificar `server/services/paymentService.js`: `getBilling` agrega `breakdown` (servicios y mano de obra con `orderWorkModel.listServices` y `listLabor`, refacciones con `orderPartModel.listByOrder`, y los tres subtotales) y `amountDifference` (total vigente menos el pago `PAGADO` cuando difieren, `"0.00"` en otro caso); `create` agrega `details.outdated` al error `PAYMENT_ALREADY_EXISTS` cuando el pago vigente es pendiente y su importe difiere del total calculado; el total sigue saliendo de `orderWorkModel.totals`, que ahora incluye refacciones, y se calcula dentro de la transacción tras bloquear la orden
- [X] T039 [US3] Modificar `server/services/ticketContent.js`: el contenido nuevo agrega `formatVersion: 2`, `unitPrice` y `amount` por refacción, `totals.parts` y el `total` igual al importe del pago (nuevo parámetro `payment.amount`); retirar los comentarios que dicen que las refacciones no suman importe
- [X] T040 [US3] Modificar `server/services/ticketService.js`: pasar a `buildTicketContent` el importe del pago `PAGADO` y las líneas de refacción con su precio guardado
- [X] T041 [P] [US3] Modificar `client/lib/models/payment.dart`: el bloque de cobro agrega `amountDifference` y `breakdown` (servicios, mano de obra y refacciones con cantidad, precio, importe y `legacy`, y los tres subtotales)
- [X] T042 [P] [US3] Modificar `client/lib/models/ticket.dart`: `TicketContent` lee `formatVersion` (1 si falta), `unitPrice` y `amount` de cada refacción y `totals.parts`
- [X] T043 [US3] Modificar `client/lib/widgets/order_billing_section.dart` según contracts/interfaz.md: desglose del total antes de registrar el pago; cobro permitido para una orden con solo refacciones; aviso ámbar de importe desfasado con el botón «Cancelar pago y generar uno nuevo» que pide confirmación; aviso de diferencia por cobrar sin botón de cobro
- [X] T044 [US3] Modificar `client/lib/widgets/ticket_view.dart` y `client/lib/utils/ticket_printer.dart`: elegir el diseño por `formatVersion`; versión 2 con precio e importe por refacción, tres subtotales y total; versión 1 exactamente como se emitió, y la misma lógica en pantalla e impresión
- [X] T045 [US3] Modificar `client/test/order_billing_test.dart`, `client/test/ticket_screens_test.dart`, `client/test/ticket_printer_test.dart` y `client/test/helpers/billing_fake.dart`: desglose, orden con solo refacciones cobrable, aviso de desfase con confirmación, aviso de diferencia, ticket en versión 2 y en versión 1, y misma salida en vista previa e impresión

**Punto de control**: las historias 1 a 3 funcionan; el flujo de cobro completo, de la refacción al ticket, usa el nuevo total

---

## Fase 6: Historia de usuario 4 - Conservar sin cambios los pagos y tickets ya emitidos (Prioridad: P1)

**Objetivo**: los documentos emitidos y las órdenes anteriores no cambian; una orden pagada no admite cambios de refacciones; el seed deja los casos de compatibilidad a la vista

**Prueba independiente**: con un pago y un ticket del Sprint 4, se verifica que conservan su importe y contenido; al cambiar el precio de una refacción, la orden, el pago y el ticket nuevos tampoco se alteran

### Pruebas de la historia 4 (escribir primero y comprobar que fallan)

- [X] T046 [P] [US4] Crear `server/tests/integration/payments.paidOrder.test.js`: con un pago `PAGADO`, agregar, cambiar la cantidad y quitar una refacción responde `409 ORDER_ALREADY_PAID` y no cambia línea, stock ni movimientos; con un pago `PENDIENTE` los tres cambios se permiten y el pago queda desfasado; con una orden Entregada sigue respondiendo `409 ORDER_READ_ONLY`; registrar el pago y modificar refacciones al mismo tiempo no deja un pago por debajo del total
- [X] T047 [P] [US4] Crear `server/tests/integration/emitted.compat.test.js`: con los pagos y tickets del seed 004 se verifica que el importe, el estado y el contenido no cambian tras la migración y tras cambiar precios de refacciones; las líneas anteriores (precio 0) no suman al total; el ticket anterior se devuelve sin `formatVersion` y tal como se emitió; cambiar el precio después de cobrar no altera orden, pago ni ticket
- [X] T048 [P] [US4] Crear `server/tests/integration/seeds.sprint5.test.js`: el seed 005 es idempotente (dos ejecuciones no duplican refacciones ni líneas), deja refacciones con precio y una sin precio de venta, una orden cobrable con refacciones y un pago de Mercado Pago pendiente y desfasado, y no modifica pagos ni tickets del seed 004 ni líneas anteriores

### Implementación de la historia 4

- [X] T049 [US4] Modificar `server/services/orderPartService.js` (`add`, `updateQuantity` y `remove`): tras bloquear la orden y rechazar las Entregadas, buscar el pago vigente con `paymentModel.findActiveByOrder` y, si está `PAGADO`, lanzar `AppError.conflict('ORDER_ALREADY_PAID', 'La orden ya está cobrada: no se pueden modificar las refacciones.')`; con un pago `PENDIENTE` no se bloquea (FR-026). Antes de implementar, buscar con `grep` en `server/tests/` las pruebas existentes que agreguen, cambien o quiten refacciones de una orden con pago `PAGADO` y ajustarlas, registrando cada una en el documento de aseguramiento
- [X] T050 [US4] Crear `database/seeds/005_part_prices.sql` (idempotente, sin llamar a Mercado Pago ni incluir credenciales). Los seeds anteriores solo dejan una orden Terminada (`STU-901-G`, con un pago de Mercado Pago pendiente) y ninguna Terminada sin pago vigente, así que el seed: (1) asigna categoría, marca y precios de compra y de venta a las refacciones del seed 003 donde `sale_price IS NULL`, dejando `BOM-AGU` sin precio de venta; (2) crea una orden Terminada nueva y cobrable, identificada por (placa, problema reportado) = (`VWX-234-H`, «Mantenimiento con refacciones (ejemplo Sprint 5)»), para un vehículo que solo tiene órdenes Entregadas, con mecánico asignado, historial de estados hasta Terminada, servicios, mano de obra y al menos dos refacciones con precio (`unit_price` igual al `sale_price`), cada una con su movimiento de inventario `OUT` ligado a la orden, y recalcula el stock de las refacciones afectadas como la suma de sus movimientos, igual que el seed 003, sin dejarlas en negativo; (3) agrega una línea con precio a la orden `STU-901-G` (pago de Mercado Pago pendiente) para mostrar el pago desfasado; clave natural de las líneas `(orden, refacción)`; no modifica órdenes con pago `PAGADO` ni Entregadas, líneas anteriores, pagos ni tickets existentes
- [X] T051 [US4] Modificar `client/lib/widgets/order_parts_section.dart` y `client/test/order_parts_test.dart`: cuando el cobro de la orden está `PAGADO` se deshabilitan agregar, quitar y cambiar cantidad y se muestra «La orden ya está cobrada: no se pueden modificar las refacciones.»; el servidor rechaza igualmente

**Punto de control**: las historias 1 a 4 funcionan; la base de ejemplo muestra los casos de compatibilidad

---

## Fase 7: Historia de usuario 5 - Mantener reservados los precios según el rol (Prioridad: P2)

**Objetivo**: el precio de compra solo llega al administrador y el mecánico no recibe ningún precio, en todas las consultas

**Prueba independiente**: se consultan inventario, órdenes, cobro, pagos y tickets con cada rol y el precio de compra solo aparece para el administrador

### Pruebas de la historia 5 (escribir primero y comprobar que fallan)

- [X] T052 [P] [US5] Crear `server/tests/integration/prices.leak.test.js`: con datos que tienen precios de compra y de venta, recorrer con cada rol las rutas de refacciones (listado, detalle, alertas, movimientos), órdenes (listado y detalle), cobro, pagos, tickets, panel de control, historial del vehículo y mantenimientos, y verificar que `purchasePrice` solo aparece para el administrador y que el mecánico no recibe `purchasePrice`, `salePrice`, `unitPrice`, `priceMissing`, `legacy`, `breakdown`, `billing`, `totals.parts` ni el importe (`amount`) de una línea de refacción (los importes de sus propios servicios y mano de obra sí los recibe, como antes)
- [X] T053 [P] [US5] Crear `server/tests/integration/orders.mechanicView.test.js`: el detalle de una orden para el mecánico omite `unitPrice`, `amount` y `legacy` de las líneas y `totals.parts`; su `totals.total` es servicios más mano de obra; las respuestas de agregar, cambiar y quitar refacciones tampoco llevan precios; recepción recibe precios de venta pero nunca el de compra
- [X] T054 [P] [US5] Modificar `client/test/order_parts_test.dart` y `client/test/inventory_screens_test.dart`: con el rol de mecánico las líneas de la orden y el inventario no muestran precios ni importes; con recepción se muestran precios de venta y nunca el de compra

### Implementación de la historia 5

- [X] T055 [US5] Verificar con las pruebas de T052 y T053 que ninguna respuesta filtra precios; corregir en `server/services/orderService.js`, `server/services/orderPartService.js`, `server/services/paymentService.js` o `server/services/partService.js` cualquier punto donde falte `presentOrderPart` o `presentTotals`, sin duplicar lógica de proyección

**Punto de control**: las cinco historias funcionan y los precios están reservados por rol

---

## Fase 8: Pulido y asuntos transversales

**Propósito**: regresión completa, seguridad, documentación y cierre del aseguramiento de la calidad

- [X] T056 [P] Buscar y retirar referencias obsoletas: `grep` de «no suman importe», «no forman parte del MVP», «sin precios de refacciones» y «servicios más mano de obra» en `server/`, `client/lib/` y `docs/`, y corregir las que ya no sean ciertas
- [X] T057 [P] Revisión de seguridad: confirmar con `grep` que `purchase_price` y `purchasePrice` solo aparecen en `partModel`, `partService`, `partValidators`, migraciones, seeds y pruebas; que no hay secretos en el código; y que `flutter analyze lib` y `npm test` no emiten advertencias nuevas
- [X] T058 [P] Crear `server/tests/integration/dashboard.listings.regression.test.js` (FR-016, CA-11): con refacciones con precio en órdenes de prueba, el panel de control (`/api/dashboard`) y los listados de órdenes y de pagos devuelven la misma forma y los mismos importes que antes (sus importes salen de los pagos registrados), ningún listado calcula el total de la orden y el total con refacciones solo aparece en el detalle de la orden
- [X] T059 Ejecutar la regresión completa: `npm test` en `server/` (debe superar las 1003 pruebas de la línea base, con las del sprint) y `flutter test` en `client/` (debe superar las 277), y confirmar que ninguna prueba de la línea base pasó de verde a rojo; registrar los conteos en la sección 8 de `docs/aseguramiento-calidad-sprint-5.md`
- [ ] T060 Recorrer los 10 escenarios de `quickstart.md` sobre la base `motorix` con los seeds aplicados y registrar el resultado de cada uno, con sus capturas en `docs/evidencias/sprint-5/`; cronometrar el escenario 1 (SC-001, menos de 2 minutos) y el recorrido de los escenarios 4 y 5 (SC-008, menos de 3 minutos) en el entorno de demostración, y anotar los tiempos. **Avance:** los 10 escenarios ya se recorrieron contra la API real (E-07 del aseguramiento, 10 de 10); falta el recorrido manual en la aplicación con sus capturas y el cronometraje
- [X] T061 Completar `docs/aseguramiento-calidad-sprint-5.md`: llenar las columnas de tarea, prueba y resultado de la sección 6 (trazabilidad de CA-1 a CA-14), actualizar G-06 a G-08, registrar los hallazgos que aparezcan en la sección 7 y enlazar cada evidencia en el anexo
- [X] T062 Control de calidad final: llenar la sección 9 de `docs/aseguramiento-calidad-sprint-5.md` con cinco requisitos funcionales del sprint, priorizando los que pueden fallar (instantáneas, orden pagada, aprobación tardía de Mercado Pago, fuga de precios y compatibilidad de tickets), cada uno con criterio de aceptación, prueba ejecutada, resultado y evidencia
- [ ] T063 Cerrar el sprint: confirmar que la enmienda de la constitución (T002) sigue aprobada y registrada, que no quedan defectos críticos ni altos abiertos, y que la sección 10 del aseguramiento queda firmada

---

## Dependencias y orden de ejecución

### Dependencias entre fases

- **Preparación (Fase 1)**: sin dependencias; T001 antes de modificar código. T003 y T004 pueden ir en paralelo; T002 es una puerta: sin su aprobación no empieza la Fase 2.
- **Fundamentos (Fase 2)**: depende de T001 y de la aprobación de T002. T005 → T006; T008 y T009 pueden ir en paralelo con T005; T010 a T012 dependen de T006 y T008; T013 depende de T006. **Bloquea todas las historias.**
- **Historias (Fases 3 a 7)**: todas dependen de la Fase 2.
  - **US1** no depende de otras historias.
  - **US2** usa el precio de venta de la refacción, así que necesita T018 de US1 para tener refacciones con precio (o las fábricas de T013).
  - **US3** depende de US2 (totales con refacciones y líneas con precio).
  - **US4** depende de US2 y US3 (pagos y tickets con refacciones); T049 comparte archivo con T028 y T029, por lo que va después.
  - **US5** se prueba al final, pero su proyección ya está en T012; las pruebas T052 y T053 necesitan US1 a US3.
- **Pulido (Fase 8)**: depende de las historias que se vayan a entregar.

### Dentro de cada historia

- Las pruebas se escriben primero y deben fallar.
- Modelo → validadores → servicio → pantalla → pruebas del cliente.
- Las tareas del mismo archivo (T028, T029 y T049; T038 y T043) no son paralelas entre sí.

### Oportunidades de ejecución en paralelo

- Fase 1: T002, T003, T004
- Fase 2: T007, T008, T009, T013
- US1: T014, T015, T016 (pruebas) y T020 (modelo del cliente)
- US2: T025, T026, T027 (pruebas) y T030
- US3: T033, T034, T035, T036 (pruebas) y T041, T042
- US4: T046, T047, T048 (pruebas)
- US5: T052, T053, T054
- Fase 8: T056, T057, T058

---

## Ejemplo de ejecución en paralelo: Historia 1

```text
Tarea: "Crear server/tests/unit/partPrices.test.js"                    (T014)
Tarea: "Crear server/tests/integration/parts.prices.test.js"          (T015)
Tarea: "Modificar server/tests/contract/parts.contract.test.js"       (T016)
Tarea: "Modificar client/lib/models/part.dart"                        (T020)
```

---

## Estrategia de implementación

### Primero el valor mínimo (historia 1)

1. Completar la Fase 1 y la Fase 2.
2. Completar la Fase 3 (historia 1) y validar con `quickstart.md`, escenarios 1 y 2.
3. Hacer una demostración: el administrador gestiona precios y el inventario señala lo que falta.

### Entrega incremental

1. Preparación + Fundamentos → base lista.
2. Historia 1 → precios en el inventario.
3. Historia 2 → total con refacciones en la orden.
4. Historia 3 → pago y ticket con el total correcto (flujo completo).
5. Historia 4 → integridad de lo emitido y datos de ejemplo.
6. Historia 5 → reserva de precios por rol (cierre de seguridad).
7. Pulido y aseguramiento de la calidad.

### Notas

- Las tareas [P] tocan archivos distintos y no dependen de tareas incompletas.
- La etiqueta [USn] relaciona cada tarea con su historia para la trazabilidad (sección 6 del aseguramiento).
- Verificar que las pruebas fallen antes de implementar.
- Hacer commit (en español, formato Conventional Commits) después de cada tarea o grupo lógico.
- Detenerse en cada punto de control para validar la historia de forma independiente.
