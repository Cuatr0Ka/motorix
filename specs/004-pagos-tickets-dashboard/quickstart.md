# Guía de inicio rápido y validación: Sprint 4

Guía para comprobar de extremo a extremo que la funcionalidad cumple la [especificación](./spec.md). El
esquema está en [data-model.md](./data-model.md) y la API en [contracts/api-rest.md](./contracts/api-rest.md).
El entorno base (MySQL, `.env`, Node.js y Flutter) es el del Sprint 1: ver
`specs/001-base-clientes-vehiculos/quickstart.md`.

## Requisitos previos

- Sprints 1 a 3 instalados y funcionando (usuarios, clientes, vehículos, órdenes, inventario y mantenimientos de
  ejemplo).
- MySQL 8.0 local en ejecución y `.env` configurado.
- Opcional para probar Mercado Pago: una cuenta de pruebas de Mercado Pago y su token de pruebas en
  `MERCADOPAGO_ACCESS_TOKEN` (en `.env`, nunca en el repositorio). Sin él, el método aparece como no disponible
  y el resto del sprint funciona.
- Opcionales: `SHOP_NAME`, `SHOP_ADDRESS` y `SHOP_PHONE` (datos del taller en el ticket).

## 1. Aplicar la base de datos del Sprint 4

```powershell
database/scripts/aplicar-migraciones.ps1 -Base motorix
database/scripts/aplicar-migraciones.ps1 -Base motorix_test
database/scripts/aplicar-seeds.ps1 -Base motorix
```

Repetir `aplicar-seeds.ps1` no duplica registros. Para recrear todo desde cero:
`database/scripts/reiniciar-local.ps1 -Base motorix`.

## 2. Ejecutar

```powershell
cd server;  npm install;  npm run dev                       # API en http://localhost:3000/api
cd client;  flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3000/api
```

## 3. Pruebas automatizadas

```powershell
cd server; npm test        # incluye reglas de pago, adaptador de Mercado Pago, tickets, panel y concurrencia
cd client; flutter test
```

## 4. Escenarios de validación manual

Cuentas de ejemplo: `recepcion`, `mecanico`, `mecanico2` y `admin` (contraseñas del estándar del MVP en
`docs/project-context.md`, solo para entornos locales).

| # | Escenario | Resultado esperado | Referencia |
|---|-----------|--------------------|------------|
| 1 | Con la base recién sembrada, abrir el Panel de control como `admin` | Todos los indicadores muestran valores, hay actividad reciente y no se capturó nada a mano | FR-026, SC-011 |
| 2 | Abrir Pagos y Tickets como `recepcion` | Hay pagos en los cuatro estados y con los cuatro métodos, y tickets de órdenes cobradas | FR-026 |
| 3 | En una orden Terminada sin cobrar, ver la sección «Cobro» | Muestra el total (servicios más mano de obra), estado «Sin cobrar» y el botón «Cobrar» | US1, CA-1 |
| 4 | Cobrar en efectivo con confirmación | El pago queda Pagado, ligado a la orden, con método, fecha y persona | US1, CA-2 |
| 5 | Intentar un segundo cobro en la misma orden | Se rechaza (`PAYMENT_ALREADY_EXISTS`) | FR-005 |
| 6 | Intentar cobrar una orden En reparación | Se rechaza (`ORDER_NOT_PAYABLE`) | FR-006 |
| 7 | Cobrar con tarjeta y capturar un texto de 16 dígitos como referencia | El formulario lo rechaza; nunca se pide el número de tarjeta | RN-14, SC-006 |
| 8 | Cobrar con Mercado Pago (con token de pruebas) | Pago Pendiente con enlace de cobro; se puede copiar y abrir | US2, CA-3 |
| 9 | Pagar en el entorno de pruebas de Mercado Pago y pulsar «Actualizar estado» | El pago pasa a Pagado con su referencia externa; repetir la consulta no lo cambia | US2 |
| 10 | Quitar el token y abrir el diálogo de cobro | Mercado Pago aparece como no disponible; los demás métodos funcionan | FR-010 |
| 11 | Cancelar un cobro de Mercado Pago Pendiente (con confirmación) | Queda Cancelado y se puede cobrar de nuevo | FR-007 |
| 12 | Generar el ticket de una orden cobrada | Se crea con folio único y se muestra con todos los datos del apartado FR-013 | US3, CA-4 |
| 13 | Imprimir el ticket | Se abre el diálogo de impresión con solo el contenido del ticket | CA-5 |
| 14 | Generar otra vez el ticket de la misma orden | Lleva al ticket existente; no hay folio nuevo | FR-012 |
| 15 | Cambiar un servicio de la orden y reabrir el ticket | El ticket conserva los importes originales | FR-014, SC-007 |
| 16 | Intentar generar el ticket sin pago Pagado | Se rechaza (`TICKET_REQUIRES_PAYMENT`) | US3 |
| 17 | Como `recepcion`, abrir el Panel (o llamar a la API) | `403 FORBIDDEN`; la sección no aparece en el menú | SC-008 |
| 18 | Como `mecanico`, llamar a pagos, tickets y panel | `403` en los tres; el detalle de la orden no trae `billing` | SC-008 |
| 19 | Registrar la entrega de una orden Terminada sin cobrar | Aparece la advertencia; solo con confirmación se entrega | Aclaración 5 |
| 20 | Terminar y cobrar una orden y volver al Panel | Los indicadores reflejan el cambio y coinciden con los listados | US4, SC-009 |
| 21 | Dos cobros simultáneos sobre la misma orden (prueba automatizada) | Solo uno prospera | SC-005 |
| 22 | Ejecutar de nuevo `aplicar-seeds.ps1` | No se duplican pagos ni tickets | SC-011 |

## 5. Criterios de aceptación del sprint

Cada criterio CA-1 a CA-8 de `docs/sprints/sprint-4-pagos-tickets-dashboard.md` debe poder demostrarse con los
escenarios anteriores o con las pruebas automatizadas (CA-8: pruebas unitarias de `paymentRules` y
`ticketContent` en `server/tests/unit/`), sin secretos en el repositorio.

## 6. Resultado de la validación

Validado el 2026-10-11.

### Pruebas automatizadas

- Backend: 67 suites y 1001 pruebas pasando (reglas de pago, adaptador de Mercado Pago simulado, tickets, panel,
  permisos, seguridad, concurrencia, contratos, seeds y rendimiento con 1 000 pagos y 1 000 tickets en menos de 2 s).
- Cliente: 265 pruebas pasando y `flutter analyze lib` sin incidencias.

### Recorrido contra la API real

Servidor real y MySQL local (`motorix_test`, recién reiniciada con sus seeds) y un Mercado Pago simulado en local
mediante `MERCADOPAGO_API_URL`. Resultado: 18 de 18 comprobaciones correctas.

| # | Resultado | Cómo se comprobó |
|---|-----------|------------------|
| 1, 2 | Correcto | Panel con todos los indicadores mayores que cero y pagos en los cuatro estados y métodos |
| 3 a 7 | Correcto | Cobro en efectivo, `PAYMENT_ALREADY_EXISTS`, `ORDER_NOT_PAYABLE` y referencia con aspecto de tarjeta rechazada |
| 8, 9, 11 | Correcto | Cobro Pendiente con enlace, paso a Pagado al actualizar (repetir no cambia) y cancelación seguida de nuevo cobro |
| 10 | Correcto | Sin token, Mercado Pago aparece como no disponible |
| 12, 14, 15, 16 | Correcto | Ticket con folio `TK-######`, segunda generación devuelve el mismo, importes originales y `TICKET_REQUIRES_PAYMENT` |
| 17, 18 | Correcto | Recepción sin panel (`403`); mecánico con `403` en pagos, tickets y panel y sin `billing` |
| 20 | Correcto | El panel refleja el cobro nuevo (órdenes por cobrar de 1 a 0) |
| 22 | Correcto | `aplicar-seeds.ps1` dos veces sobre `motorix`: 9 pagos y 5 tickets antes y después |
| 13, 19, 21 | Cubiertos por pruebas automatizadas | Impresión (`ticket_printer_test`), advertencia de entrega sin cobro (`order_billing_test`) y concurrencia (`payments.concurrency`) |

### Criterios de aceptación

CA-1 a CA-8 demostrados con los escenarios anteriores y las pruebas automatizadas; CA-8 con las pruebas unitarias de
`paymentRules` y `ticketContent`. No hay secretos en el repositorio y `.env` no está en `git status`.

### Pendiente de validar con una cuenta real

El adaptador se probó solo con un proveedor simulado. Falta confirmar con una cuenta de pruebas de Mercado Pago los
campos `sandbox_init_point` y la búsqueda por `external_reference` (research D-04). Para ejecutar el cliente con
`flutter run -d windows` puede hacer falta activar el Modo de desarrollador de Windows (soporte de enlaces simbólicos).
