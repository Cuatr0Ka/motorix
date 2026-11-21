# Guía de validación: Precios de refacciones y cobro completo (Sprint 5)

Escenarios para comprobar de extremo a extremo que el sprint funciona. Los detalles del esquema están en
[data-model.md](./data-model.md) y los de la API en [contracts/api-rest.md](./contracts/api-rest.md).

## Requisitos previos

- MySQL 8 local con las bases `motorix` y `motorix_test` y el usuario `motorix_app` (ver `database/README.md`).
- `server/.env` configurado (sin secretos en el repositorio). Mercado Pago no es necesario: las pruebas usan un
  proveedor simulado.
- Dependencias instaladas en `server/` (`npm install`) y en `client/` (`flutter pub get`).

## 1. Preparar la base

```powershell
database\scripts\aplicar-migraciones.ps1 -Base motorix
database\scripts\aplicar-seeds.ps1 -Base motorix
```

Resultado esperado: se aplica la migración `005` y el seed `005`. Volver a ejecutar ambos no duplica ni falla.

Para la base de pruebas, repetir con `-Base motorix_test`.

## 2. Línea base y regresión

```powershell
cd server; npm test
cd ..\client; flutter test
```

Resultado esperado: pasan las 1003 pruebas de backend y las 277 de frontend de la línea base del 2026-10-31,
más las pruebas nuevas del sprint. Las pruebas de `NOTHING_TO_CHARGE` siguen pasando (total cero).

## 3. Pruebas del sprint

```powershell
cd server; npm test -- tests/unit/orderTotals.test.js tests/unit/partPrices.test.js tests/unit/ticketContent.test.js tests/integration/parts.prices.test.js tests/integration/orderParts.prices.test.js tests/integration/orderParts.prices.concurrency.test.js tests/integration/billing.parts.test.js tests/integration/payments.paidOrder.test.js tests/integration/emitted.compat.test.js tests/integration/tickets.v2.test.js tests/integration/prices.leak.test.js tests/integration/orders.mechanicView.test.js tests/integration/dashboard.listings.regression.test.js tests/integration/seeds.sprint5.test.js
```

Resultado esperado: todas aprobadas. Los nombres exactos de los archivos los fija `tasks.md`.

## 4. Recorrido manual (aplicación en marcha)

Iniciar la API (`npm start` en `server/`) y el cliente (`flutter run -d windows` en `client/`). Entrar con los
usuarios de ejemplo.

| # | Escenario | Pasos | Resultado esperado |
|---|-----------|-------|--------------------|
| 1 | Registrar precios (HU1) | Como administrador, crear una refacción con categoría, marca, compra 120 y venta 180 | Aparece en el inventario con ambos datos; recepción y mecánico no ven el precio de compra |
| 2 | Venta bajo el costo (HU1) | Editar una refacción con venta 90 y compra 120 | Aparece el aviso; solo guarda al confirmar |
| 3 | Refacción sin precio (HU2) | Con la refacción `BOM-AGU` (sin precio) intentar agregarla a una orden | Se rechaza con el mensaje de avisar al administrador; en el inventario muestra «Sin precio de venta» |
| 4 | Total con refacciones (HU2) | Abrir la orden Terminada nueva del seed 005 («Mantenimiento con refacciones (ejemplo Sprint 5)») y consultar el cobro | El desglose muestra servicios, mano de obra y refacciones, y el total es su suma |
| 5 | Pago y ticket (HU3) | Registrar el pago en efectivo y generar el ticket | El pago y el ticket tienen el mismo total, y el ticket detalla las refacciones con precio |
| 6 | Instantánea (HU4) | Cambiar el precio de venta de una refacción ya cobrada | La orden, el pago y el ticket conservan sus importes |
| 7 | Orden pagada (HU4) | En la orden cobrada, intentar agregar o quitar una refacción | Se rechaza: «La orden ya está cobrada» |
| 8 | Pago desfasado (HU3) | Abrir la orden con el pago de Mercado Pago pendiente del seed | Aviso de importe desfasado y botón para cancelar el pago con confirmación |
| 9 | Compatibilidad (HU4) | Abrir un ticket emitido en el Sprint 4 y compararlo con uno nuevo | El anterior se ve como se emitió; el nuevo trae precios e importes |
| 10 | Mecánico (HU5) | Entrar como mecánico, ver el inventario y una orden asignada | No aparece ningún precio ni importe |

## 5. Comprobaciones de integridad

- Todas las respuestas de la API a recepción y al mecánico carecen de `purchasePrice` (y el mecánico, de
  `salePrice`, `unitPrice` y `amount`).
- Cinco cobros simultáneos sobre una misma orden con refacciones dejan un solo pago vigente.
- Cambiar refacciones y registrar el pago al mismo tiempo no deja un pago por debajo del total.

## 6. Reversa manual (solo si hace falta deshacer la migración)

El DDL de MySQL no es transaccional, así que la reversa se hace a mano, sobre una copia de la base:

1. Respaldar la base.
2. Quitar `order_parts.unit_price` y las columnas `category`, `brand`, `purchase_price` y `sale_price` de `parts`
   con `ALTER TABLE … DROP COLUMN`.
3. Borrar el registro `005_sprint5_part_prices.sql` de `schema_migrations`.

Los pagos y tickets emitidos no se modifican con la migración ni con su reversa.

## Cierre

Cronometrar el escenario 1 (SC-001, menos de 2 minutos) y el recorrido de los escenarios 4 y 5 (SC-008, menos
de 3 minutos), y anotar los tiempos. Registrar en `docs/aseguramiento-calidad-sprint-5.md` los resultados de los
pasos 2 a 5, con sus capturas en
`docs/evidencias/sprint-5/`, y repetir la línea base de la sección 8.
