# Investigación: Pagos, tickets y panel de control (Sprint 4)

**Fecha**: 2026-10-11

No quedan marcadores `NEEDS CLARIFICATION`. La pila (Node.js + Express ESM, `mysql2`, `zod`, JWT, Flutter +
Provider, Jest + supertest) está fijada por la constitución y los sprints anteriores; este documento
registra las decisiones de diseño propias del Sprint 4.

## D-01. El total a cobrar se calcula, no se guarda en la orden

- **Decisión**: el total de cobro es `servicios + mano de obra`, calculado con la misma función que ya usa
  el detalle de la orden (`orderWorkModel.totals`, en centavos enteros). El pago guarda el importe con el
  que se creó; el servicio compara el importe recibido (opcional) con el total vigente.
- **Justificación**: aclaración 1 (las refacciones no suman importe) y decisión del Sprint 2 (totales
  calculados, nunca almacenados).
- **Cambios posteriores**: si el total cambia después de crear un pago, el pago conserva su importe y el
  detalle de cobro de la orden lo marca como «importe desactualizado» (`amountOutdated`); un cobro de
  Mercado Pago Pendiente en esa situación debe cancelarse y rehacerse. No se bloquea la edición de la orden
  (no se cambian reglas de los sprints 2 y 3); el ticket está protegido por su instantánea (D-05).
- **Alternativas**: guardar el total en la orden (rechazada: duplica información y se desfasa); bloquear la
  edición de órdenes cobradas (rechazada: cambia el comportamiento ya validado del Sprint 2).

## D-02. Un pago vigente por orden, garantizado por la base

- **Decisión**: columna generada almacenada `active_order_id = IF(status IN ('PENDIENTE','PAGADO'), order_id, NULL)`
  con índice `UNIQUE`. El servicio bloquea la fila de la orden (`FOR UPDATE`) antes de comprobar y crear, y
  traduce `ER_DUP_ENTRY` a `PAYMENT_ALREADY_EXISTS`.
- **Justificación**: FR-005 y SC-005 (dos solicitudes simultáneas). Mismo patrón que `open_vehicle_id`
  (Sprint 2) y `pending_vehicle_id` (Sprint 3).
- **Alternativas**: solo comprobar en el servicio (rechazada: carrera).

## D-03. Máquina de estados del pago como módulo puro

- **Decisión**: `services/paymentRules.js` exporta `PAYMENT_METHODS`, `PAYMENT_STATUSES`, la tabla de
  transiciones y funciones puras: `initialStatusFor(method)` (efectivo, tarjeta y transferencia nacen
  `PAGADO`; Mercado Pago nace `PENDIENTE`), `assertTransition(from, to)` (solo `PENDIENTE → PAGADO | RECHAZADO |
  CANCELADO`; `PAGADO`, `RECHAZADO` y `CANCELADO` son finales), `assertOrderPayable(order, total)` y
  `mapProviderStatus(providerStatus)`.
- **Restricción en la base**: `CHECK (method = 'MERCADO_PAGO' OR status = 'PAGADO')` — solo Mercado Pago puede
  estar Pendiente, Rechazado o Cancelado (FR-004).
- **Justificación**: CA-8; la lógica más sensible del sprint se prueba sin base de datos.
- **Alternativas**: condicionales dispersas en el servicio (rechazada: difícil de probar).

## D-04. Mercado Pago aislado en un adaptador con `fetch`, sin SDK

- **Decisión**: `server/integrations/mercadoPago.js` expone `isConfigured()`, `createCheckout({ reference, amount, title })`
  y `findPaymentByReference(reference)`. Usa el `fetch` global de Node.js, el token de
  `MERCADOPAGO_ACCESS_TOKEN` y la URL base `MERCADOPAGO_API_URL` (por defecto `https://api.mercadopago.com`,
  útil para apuntar a un servidor simulado). El servicio de pagos recibe el adaptador mediante
  `getGateway()`, que las pruebas pueden sustituir.
- **Flujo (Checkout Pro, enlace de cobro)**: `POST /checkout/preferences` con un artículo (título «Orden
  OS-000012», cantidad 1, `unit_price` y `currency_id: MXN`) y `external_reference = motorix-pago-<id>`;
  la respuesta trae `init_point` y `sandbox_init_point`; con un token de pruebas se guarda
  `sandbox_init_point` como enlace de cobro. La consulta usa
  `GET /v1/payments/search?external_reference=<ref>&sort=date_created&criteria=desc`.
- **Correspondencia de estados** (`mapProviderStatus`): `approved` → `PAGADO` (guarda el identificador del
  pago del proveedor); `rejected` y `cancelled` → `RECHAZADO`; `pending`, `in_process`, `authorized`,
  `in_mediation` o ninguna operación encontrada → sigue `PENDIENTE`. Si hay varias operaciones, gana la
  aprobada y, si no, la más reciente.
- **Seguridad**: el token solo se lee del entorno, nunca se registra ni se devuelve; los errores del
  proveedor se traducen a `PROVIDER_ERROR` (502) o `PROVIDER_NOT_CONFIGURED` (503) con mensajes genéricos en
  español, sin reenviar cuerpos del proveedor. No se envía ni se recibe ningún dato de tarjeta: el cliente
  paga en la página de Mercado Pago.
- **Validación**: los campos exactos de la API del proveedor (`init_point`, `sandbox_init_point` y la
  búsqueda por `external_reference`) deben confirmarse contra el entorno de pruebas real al implementar;
  el adaptador concentra ese riesgo en un solo archivo y las pruebas usan un `fetch` simulado.
- **Alternativas**: SDK oficial (rechazada: dependencia nueva para dos llamadas); notificaciones/webhooks
  (rechazada por la aclaración 2); API de pagos directos con tarjeta (rechazada: exigiría manejar datos de
  tarjeta, prohibido por RN-14).

## D-05. El ticket guarda una instantánea de su contenido

- **Decisión**: `tickets.content` (columna `JSON`) guarda el contenido tal como se generó: datos del taller,
  cliente, vehículo (placa, marca, modelo), kilometraje, servicios, refacciones con cantidad, mano de obra,
  subtotales, total, método y estado del pago, y fecha. `services/ticketContent.js` (puro) arma ese objeto
  a partir de los datos leídos; las pruebas verifican todos los campos de CA-4.
- **Justificación**: FR-014 y SC-007 (el ticket no cambia aunque cambien la orden, el cliente o el
  vehículo). Un comprobante debe ser inmutable.
- **Folio**: `TK-` más el identificador con 6 dígitos (`TK-000012`), igual que el folio de la orden; es
  único porque el identificador lo es.
- **Alternativas**: componer el ticket al consultarlo con datos vivos (rechazada: se desfasa); tablas de
  líneas del ticket (rechazada: sobredimensionada para un comprobante de solo lectura).

## D-06. Un ticket por orden, con generación idempotente

- **Decisión**: índice `UNIQUE (order_id)`. Generar de nuevo no crea otro: el servicio devuelve el existente
  (`200`, `created: false`); la primera vez responde `201`. Solo se genera con un pago `PAGADO`. Dos
  solicitudes simultáneas se resuelven por el índice (la perdedora relee y devuelve el existente).
- **Justificación**: FR-012 y escenario 5 de la historia 3.
- **Alternativas**: permitir reemisiones con folio nuevo (rechazada: duplicaría comprobantes).

## D-07. Impresión sin archivos

- **Decisión**: el ticket se muestra en una pantalla con formato de ticket y se imprime con el diálogo de
  impresión del sistema; el documento de impresión se arma en memoria y no se guarda (aclaración 4). El
  backend solo entrega el contenido del ticket.
- **Justificación**: CA-5 pide visualizar e imprimir; no pide archivo PDF. «Guardar como PDF» sigue
  disponible en el diálogo de impresión de Windows.
- **Alternativas**: PDF generado y guardado en el servidor (rechazada por la aclaración 4).

## D-08. Datos del taller configurables por entorno

- **Decisión**: `SHOP_NAME`, `SHOP_ADDRESS` y `SHOP_PHONE` (opcionales, con valores de ejemplo por defecto:
  «Motorix Taller Mecánico») se leen en `config/env.js` y se incluyen en la instantánea del ticket.
- **Justificación**: FR-016 (configurable sin tocar el código) sin crear una pantalla de ajustes que el MVP
  no pide.
- **Alternativas**: tabla de configuración con pantalla (rechazada: fuera de alcance).

## D-09. Dependencias nuevas del cliente: `printing` y `url_launcher`

- **Decisión**: agregar `printing` (con su dependencia `pdf`) y `url_launcher`.
- **Justificación** (la constitución exige justificar toda dependencia nueva): Flutter de escritorio no
  incluye impresión ni apertura del navegador. Sin `printing` no se cumple CA-5; sin `url_launcher` la
  recepción solo podría copiar el enlace de Mercado Pago. Ambas son paquetes muy usados y mantenidos, y
  escribir el código de impresión de Windows propio sería mucho mayor. `pdf` solo construye el documento
  en memoria para el diálogo de impresión.
- **Alternativas**: copiar el enlace al portapapeles y no imprimir (no cumple CA-5); canal de plataforma
  propio hacia las API de Windows (rechazada: costo y riesgo desproporcionados).

## D-10. Permisos

- **Decisión**: `authorize` por ruta. Pagos y tickets: `ADMIN` y `RECEPTIONIST`. Panel: solo `ADMIN`. El
  mecánico recibe `403` en todo. En el detalle de la orden, el bloque de cobro (`billing`) se incluye
  solo para `ADMIN` y `RECEPTIONIST`; el mecánico no lo recibe.
- **Justificación**: aclaración 3, FR-021 y Constitución IV.

## D-11. El panel compone consultas existentes

- **Decisión**: `GET /api/dashboard` (solo ADMIN) ejecuta, en paralelo, consultas de conteo y actividad:
  - Órdenes: conteos por estado en `service_orders` (en reparación = `EN_REPARACION` y
    `ESPERANDO_REFACCION`; pendientes = no `TERMINADO` ni `ENTREGADO`; terminadas pendientes de entrega =
    `TERMINADO`). Vehículos atendidos = vehículos distintos con orden `ENTREGADO` cuya entrega ocurrió en los
    últimos 30 días.
  - Citas próximas: `PENDIENTE` o `CONFIRMADA` con fecha dentro de los próximos 7 días.
  - Mantenimientos próximos y vencidos: el total de `maintenanceModel.list` con el mismo indicador (mismo
    criterio que la pantalla de Mantenimientos).
  - Stock bajo y agotadas: `partService.alerts()`.
  - Cobros: órdenes `TERMINADO` sin pago `PAGADO`, y pagos `PENDIENTE`.
  - Actividad reciente: últimos 5 cambios de `order_status_history`, últimos 5 pagos y últimos 5
    movimientos de `inventory_movements`.
- **Justificación**: FR-018 y SC-009 (coinciden con los listados, sin tablas de estadísticas ni
  duplicados). Una prueba de integración compara cada indicador con el resultado del listado respectivo.
- **Actualización**: el cliente vuelve a consultar al abrir el panel y con un botón «Actualizar»; no hay
  tiempo real.
- **Alternativas**: tablas de resumen o vistas materializadas (rechazadas por RN y por FR-018).

## D-12. Entrega sin cobro: advertencia en la interfaz

- **Decisión**: el detalle de la orden (para ADMIN y RECEPTIONIST) incluye `billing.collectionStatus`
  (`SIN_COBRAR`, `PENDIENTE` o `PAGADO`). Al pulsar «Registrar entrega» sin pago `PAGADO`, la pantalla
  muestra una advertencia con confirmación adicional y solo entonces envía el cambio de estado. El
  endpoint de cambio de estado del Sprint 2 no cambia.
- **Justificación**: aclaración 5. Cambiar el endpoint para exigir una bandera rompería el contrato y las
  pruebas del Sprint 2 sin aportar seguridad (es una advertencia, no una restricción).
- **Alternativas**: exigir `confirmUnpaid` en el servidor (rechazada: rompe el contrato del Sprint 2).

## D-13. Datos de ejemplo idempotentes y sin llamar al proveedor

- **Decisión**: el seed 004 usa claves naturales: pagos por `(orden, método, estado)` con referencias
  fijas de ejemplo; tickets por orden. La instantánea de los tickets sembrados se arma en SQL con
  `JSON_OBJECT`/`JSON_ARRAYAGG` con la misma forma que `ticketContent`, y una prueba verifica que ambas
  coinciden en sus claves. Incluye pagos en los cuatro estados y los cuatro métodos, un cobro de Mercado
  Pago Pendiente con un enlace de ejemplo, tickets de órdenes cobradas y la orden Terminada del Sprint 2
  sin cobro, para que todos los indicadores del panel tengan valores.
- **Justificación**: FR-026 y las restricciones de seeds de la constitución.
- **Alternativas**: seed escrito en JavaScript (rechazada: el proyecto usa seeds SQL).

## D-14. Pruebas de concurrencia y de seguridad

- **Decisión**: una prueba de integración lanza varias solicitudes simultáneas de pago sobre la misma
  orden (solo una prospera) y otra de generación de ticket (un solo ticket). Una prueba revisa que ni la
  base, ni las respuestas, ni lo escrito en la consola contienen el token de Mercado Pago ni campos de
  tarjeta.
- **Justificación**: SC-005 y SC-006.
