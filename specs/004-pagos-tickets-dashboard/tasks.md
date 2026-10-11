---

description: "Lista de tareas del Sprint 4: pagos, tickets y panel de control"
---

# Tareas: Pagos, tickets y panel de control (Sprint 4)

**Entrada**: Documentos de diseño en `specs/004-pagos-tickets-dashboard/`

**Requisitos previos**: plan.md, spec.md, research.md, data-model.md, contracts/ (api-rest.md e interfaz.md), quickstart.md

**Pruebas**: INCLUIDAS. La constitución (Principio VII) exige pruebas para la lógica de negocio (estados de pago, importes, permisos, contenido del ticket) y el sprint exige CA-8; las del backend usan Jest + supertest contra `motorix_test` y las del frontend `flutter test`.

**Organización**: Las tareas se agrupan por historia de usuario para poder implementar y probar cada una de forma independiente.

## Formato: `[ID] [P?] [Historia] Descripción`

- **[P]**: se puede ejecutar en paralelo (archivos distintos, sin dependencias pendientes)
- **[USn]**: historia de usuario a la que pertenece la tarea (US1 a US4 de spec.md)
- Todas las rutas son relativas a la raíz del repositorio (`D:\sdd\motorix`)

## Convenciones de rutas

- Backend: `server/` (capas directamente en la raíz de `server/`, sin carpeta `src/`)
- Frontend: `client/lib/` y `client/test/`
- Base de datos: `database/`
- El código backend usa ES Modules (`import`/`export`); los identificadores van en inglés y los comentarios, mensajes y nombres de pruebas en español
- Las pruebas de integración y contrato se ejecutan solo contra `motorix_test`; los errores nuevos usan `AppError` (`server/utils/AppError.js`) con los códigos de `contracts/api-rest.md`
- Solo `paymentService` cambia el estado de los pagos y solo él usa el adaptador de Mercado Pago; ninguna pantalla, respuesta ni registro incluye datos de tarjeta ni el token de Mercado Pago
- Las pruebas NUNCA llaman al Mercado Pago real: usan el proveedor simulado (`setGateway`) o un `fetch` simulado

## Orden de las historias (prioridad)

P1: US1 (registrar el pago con su método), US2 (Mercado Pago en modo de pruebas), US3 (ticket). P2: US4 (panel de control).

> Correspondencia con la especificación: US1 = Historia 1; US2 = Historia 2; US3 = Historia 3; US4 = Historia 4.

---

## Fase 1: Preparación (infraestructura compartida)

**Propósito**: verificar la base de los sprints 1 a 3, declarar dependencias y alinear la documentación

- [X] T001 Verificar la línea base: MySQL local en ejecución, migraciones 001 a 003 aplicadas en `motorix` y `motorix_test`, y `npm test` (en `server/`) y `flutter test` (en `client/`) en verde antes de empezar
- [X] T002 [P] Actualizar `docs/project-context.md`: en las entidades `Payment` y `Ticket` usar los campos de data-model.md (`order_id`, importe, método, estado, referencias, enlace de cobro, instantánea del ticket); registrar que el total es servicios más mano de obra, que las refacciones no suman importe, que el ticket no genera PDF y que el panel es exclusivo de administración; y anotar en §27 la decisión de agregar `printing` y `url_launcher` al cliente (research D-09)
- [X] T003 [P] Actualizar `.env.example` con `MERCADOPAGO_ACCESS_TOKEN=` (vacío, con un comentario en español: token de pruebas de Mercado Pago, nunca se sube), `MERCADOPAGO_API_URL=https://api.mercadopago.com`, `SHOP_NAME=Motorix Taller Mecánico`, `SHOP_ADDRESS=` y `SHOP_PHONE=`
- [X] T004 [P] Actualizar `database/README.md` con la migración `004_sprint4_payments_tickets.sql` y el seed `004_payments_tickets.sql`
- [X] T005 Agregar `printing` y `url_launcher` a `client/pubspec.yaml` (`flutter pub add printing url_launcher`), ejecutar `flutter pub get` y confirmar que `flutter analyze lib` y `flutter test` siguen en verde; sin otras dependencias nuevas

---

## Fase 2: Fundamentos (requisitos bloqueantes)

**Propósito**: esquema, configuración, reglas puras, adaptador del proveedor y plantillas de prueba que DEBEN existir antes de cualquier historia

**⚠️ CRÍTICO**: ninguna historia puede empezar hasta terminar esta fase

### Base de datos

- [X] T006 Crear `database/migrations/004_sprint4_payments_tickets.sql` (InnoDB, `utf8mb4`, intercolado `utf8mb4_0900_ai_ci`, sin editar migraciones anteriores; `ON DELETE RESTRICT` en todas las llaves foráneas). Según data-model.md:
  - `payments`: `id` INT UNSIGNED AUTO_INCREMENT PK; `order_id` INT UNSIGNED NOT NULL FK → `service_orders(id)`; `amount` DECIMAL(10,2) NOT NULL con CHECK (`amount > 0`); `method` ENUM('EFECTIVO','TARJETA','TRANSFERENCIA','MERCADO_PAGO') NOT NULL; `status` ENUM('PENDIENTE','PAGADO','RECHAZADO','CANCELADO') NOT NULL; `reference` VARCHAR(100) NULL; `external_reference` VARCHAR(100) NULL; `external_payment_id` VARCHAR(40) NULL; `checkout_url` VARCHAR(500) NULL; `last_checked_at` DATETIME NULL; `paid_at` DATETIME NULL; `active_order_id` INT UNSIGNED GENERATED ALWAYS AS (IF(status IN ('PENDIENTE','PAGADO'), order_id, NULL)) STORED con `UNIQUE uq_payments_active_order (active_order_id)`; `created_by` INT UNSIGNED NOT NULL FK → `users(id)`; `created_at` y `updated_at` DATETIME NOT NULL (`DEFAULT CURRENT_TIMESTAMP`, y `ON UPDATE CURRENT_TIMESTAMP` en `updated_at`); CHECK `(method = 'MERCADO_PAGO' OR status = 'PAGADO')` y CHECK `(status <> 'PAGADO' OR paid_at IS NOT NULL)`; índices `idx_payments_order (order_id)` e `idx_payments_status (status, created_at)`; sin columnas de tarjeta ni credenciales
  - `tickets`: `id` INT UNSIGNED AUTO_INCREMENT PK; `order_id` INT UNSIGNED NOT NULL FK → `service_orders(id)` con `UNIQUE uq_tickets_order (order_id)`; `payment_id` INT UNSIGNED NOT NULL FK → `payments(id)`; `content` JSON NOT NULL; `generated_by` INT UNSIGNED NOT NULL FK → `users(id)`; `generated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP; sin `updated_at`; índice `idx_tickets_generated (generated_at)`
- [X] T007 Aplicar la migración con `database/scripts/aplicar-migraciones.ps1 -Base motorix` y `-Base motorix_test`, y verificar que quede registrada en `schema_migrations`, que existan las 2 tablas y que repetir el comando no la vuelva a ejecutar

### Configuración, reglas puras y proveedor de pagos

- [X] T008 [P] Modificar `server/config/env.js`: añadir `getMercadoPagoConfig(source = process.env)` (devuelve `{ accessToken, apiUrl }`; `accessToken` vacío si no hay variable; `apiUrl` por defecto `https://api.mercadopago.com`; no exige las variables de la base y nunca imprime el token) y `getShopConfig(source = process.env)` (`{ name, address, phone }` con «Motorix Taller Mecánico», cadena vacía y cadena vacía por defecto)
- [X] T009 [P] Crear `server/services/paymentRules.js` (módulo puro, sin base ni Express): `PAYMENT_METHODS`, `PAYMENT_STATUSES`, `initialStatusFor(method)` (EFECTIVO, TARJETA y TRANSFERENCIA → `PAGADO`; MERCADO_PAGO → `PENDIENTE`), `assertTransition(from, to)` (solo `PENDIENTE → PAGADO | RECHAZADO | CANCELADO`; los demás estados son finales; lanza `PAYMENT_NOT_CANCELLABLE` para cancelar un no pendiente), `assertOrderPayable({ status, total })` (orden `TERMINADO` o `ENTREGADO` o `ORDER_NOT_PAYABLE` 409; total mayor a cero o `NOTHING_TO_CHARGE` 422), `assertAmountMatches({ amount, total })` (`AMOUNT_MISMATCH` 422 con `details.total`), `assertSafeReference(text)` (máximo 100 caracteres y rechaza 13 a 19 dígitos seguidos, con o sin espacios o guiones, como posible número de tarjeta) y `mapProviderStatus(statuses)` (`approved` → `PAGADO`; `rejected` y `cancelled` → `RECHAZADO`; `pending`, `in_process`, `authorized`, `in_mediation` o lista vacía → `PENDIENTE`; si hay varias gana la aprobada y, si no, la más reciente)
- [X] T010 [P] Crear `server/tests/unit/paymentRules.test.js`: estado inicial por método, todas las transiciones válidas e inválidas (12 pares), orden en cada uno de los seis estados, total cero y negativo, importe igual y distinto, referencias válidas, de 100 y 101 caracteres y con 13, 16 y 19 dígitos (con espacios y guiones), y `mapProviderStatus` con cada estado del proveedor, listas mezcladas y vacías; nombres y aserciones en español
- [X] T011 [P] Crear `server/integrations/mercadoPago.js` (adaptador aislado, ES Modules, usa el `fetch` global; sin SDK): `createMercadoPagoGateway({ accessToken, apiUrl, fetchImpl = fetch })` que devuelve `{ isConfigured(), createCheckout({ reference, amount, title }), findPaymentByReference(reference) }`. `createCheckout` hace `POST {apiUrl}/checkout/preferences` con un artículo (título, cantidad 1, `unit_price` como número y `currency_id: 'MXN'`) y `external_reference`, y devuelve `{ checkoutUrl }` con `sandbox_init_point` si el token es de pruebas (empieza con `TEST-`) y, si no, `init_point`; `findPaymentByReference` hace `GET {apiUrl}/v1/payments/search?external_reference=…&sort=date_created&criteria=desc` y devuelve `[ { id, status } ]`. Agrega `Authorization: Bearer` solo en la petición, aplica un tiempo máximo de 15 s, traduce cualquier fallo o respuesta no exitosa a `AppError` 502 `PROVIDER_ERROR` («No se pudo comunicar con Mercado Pago. Inténtalo de nuevo.») y la falta de token a 503 `PROVIDER_NOT_CONFIGURED`; NUNCA registra ni devuelve el token ni el cuerpo del proveedor. Exporta además `getGateway()` (construye el adaptador real desde `getMercadoPagoConfig()` una sola vez) y `setGateway(fake)` / `resetGateway()` para que las pruebas lo sustituyan
- [X] T012 [P] Crear `server/tests/unit/mercadoPagoAdapter.test.js` con un `fetch` simulado: crea la preferencia con el cuerpo esperado y el encabezado de autorización, elige el enlace de pruebas o real según el token, busca por `external_reference`, traduce errores HTTP, tiempos agotados y JSON inválido a `PROVIDER_ERROR` sin incluir el token ni el cuerpo del proveedor en el mensaje, reporta `PROVIDER_NOT_CONFIGURED` sin token, y `isConfigured()` verdadero o falso según el token

### Plantillas de prueba y validadores

- [X] T013 [P] Ampliar `server/tests/helpers/factories.js` con `createPayment(orderId, createdBy, overrides)` (por defecto efectivo `PAGADO` con `paid_at`), `createTicket(orderId, paymentId, createdBy, overrides)`, `createPayableOrder(vehicleId, createdBy, mechanicId)` (orden `TERMINADO` con un servicio de `850.00` y mano de obra de `400.00`, total `1250.00`), un `FakeGateway` (`isConfigured`, `createCheckout`, `findPaymentByReference` con respuestas programables y contador de llamadas) y la limpieza de `payments` y `tickets` en `resetDatabase` respetando el orden de las llaves foráneas (antes de `order_status_history`)
- [X] T014 [P] Crear `server/validators/paymentValidators.js` con esquemas `zod` y mensajes en español: `createPaymentSchema` (`method` uno de EFECTIVO|TARJETA|TRANSFERENCIA|MERCADO_PAGO; `amount` opcional, número o cadena decimal positivo con hasta dos decimales; `reference` opcional de hasta 100 caracteres, recortada, vacía → ausente), `listPaymentsQuery` (`search`, `status`, `method`, `page`, `pageSize`) y reutilizar `idParams`; y `server/validators/ticketValidators.js` con `listTicketsQuery` (`search`, `page`, `pageSize`)

**Punto de control**: la migración está aplicada, las reglas puras y el adaptador tienen pruebas en verde; las historias pueden comenzar.

---

## Fase 3: Historia de usuario 1 - Registrar el pago de una orden con su método de pago (Prioridad: P1) 🎯 MVP

**Objetivo**: la recepción (y la administración) consulta el total de una orden Terminada o Entregada y registra su pago en efectivo, tarjeta o transferencia; consulta los pagos; y se advierte al entregar sin cobrar.

**Prueba independiente**: con una orden Terminada de total `1250.00`, `POST /api/orders/:id/payments` con método EFECTIVO crea un pago `PAGADO`; un segundo pago se rechaza; el detalle de la orden muestra el bloque `billing`; el mecánico recibe `403`.

### Pruebas de la historia 1

- [X] T015 [P] [US1] Crear `server/tests/contract/payments.contract.test.js`: forma del objeto pago, de `POST /orders/:id/payments`, `GET /orders/:id/payments`, `GET /payments` (con `meta`), `GET /payments/:id`, `GET /payments/methods` y del bloque `billing` en `GET /orders/:id` según contracts/api-rest.md; códigos `400`, `401`, `403`, `404`, `409` y `422`
- [X] T016 [P] [US1] Crear `server/tests/integration/payments.flow.test.js`: pago en efectivo, tarjeta y transferencia (siempre `PAGADO`, con `paid_at`, orden, método, importe igual al total y persona), referencia opcional válida y rechazada con 13 a 19 dígitos, importe distinto (`AMOUNT_MISMATCH` con `details.total`), importe igual enviado explícitamente, total cero (`NOTHING_TO_CHARGE`), cada estado de orden no cobrable (`ORDER_NOT_PAYABLE`), orden Entregada que sí se cobra, segundo pago (`PAYMENT_ALREADY_EXISTS` con `details.paymentId`), `billing.collectionStatus` (`SIN_COBRAR` → `PAGADO`), `amountOutdated` al cambiar un servicio después del cobro, listado con filtros de estado y método y búsqueda por folio, cliente y placa, ausencia de `DELETE`/`PUT`/`PATCH`, la base rechaza un pago `PENDIENTE` de efectivo y un importe `0`, y que no existe ninguna columna de tarjeta
- [X] T017 [P] [US1] Crear `server/tests/integration/payments.permissions.test.js`: recepción y administración pueden registrar y consultar; el mecánico recibe `403` en todas las rutas de pagos y no recibe `billing` en el detalle de la orden; sin sesión `401`; el detalle de una orden Entregada conserva sus pagos (solo lectura)
- [X] T018 [P] [US1] Crear `server/tests/integration/payments.concurrency.test.js`: varias solicitudes simultáneas de pago sobre la misma orden (por ejemplo 5, con métodos distintos) → exactamente una respuesta `201` y el resto `409 PAYMENT_ALREADY_EXISTS`; la base queda con un solo pago vigente (SC-005)

### Implementación de la historia 1

- [X] T019 [P] [US1] Crear `server/models/paymentModel.js`: `insert`, `findById` (con orden, cliente, vehículo y persona), `listByOrder`, `list` (filtros `status`, `method`, `search` por folio, cliente o placa; orden descendente; paginación), `findActiveByOrder`, `update` (lista blanca: `status`, `paid_at`, `last_checked_at`, `external_payment_id`, `checkout_url`, `external_reference`) y `summaryByOrder`; formatea importes como cadenas con dos decimales; traduce `ER_DUP_ENTRY` de `uq_payments_active_order` a un error reconocible
- [X] T020 [US1] Crear `server/services/paymentService.js` (parte 1): `getBilling(order)` (total vía `orderWorkModel.totals`, `paidAmount`, `collectionStatus`, `amountOutdated`, `canCharge`, pagos y ticket), `listMethods()` (Mercado Pago disponible según `getGateway().isConfigured()` con `reason` si no), `create(orderId, data, actor)` para EFECTIVO, TARJETA y TRANSFERENCIA (en una transacción: bloquea la orden con `orderModel.lockById` ANTES de cualquier lectura normal, `assertOrderPayable`, `assertAmountMatches` si viene importe, `assertSafeReference`, comprueba que no haya pago vigente y lo inserta como `PAGADO` con `paid_at`; traduce la carrera a `PAYMENT_ALREADY_EXISTS`), `list`, `getById` y `listByOrder`
- [X] T021 [US1] Modificar `server/services/orderService.js` (`buildDetail`): incluir `billing` solo si el actor es `ADMIN` o `RECEPTIONIST` (usa `paymentService.getBilling`); el mecánico no lo recibe
- [X] T022 [US1] Crear `server/controllers/paymentController.js` y `server/routes/paymentRoutes.js` (`authenticate` + `authorize(ROLES.ADMIN, ROLES.RECEPTIONIST)`): `GET /methods` (declarada ANTES de `/:id`), `GET /`, `GET /:id`; sin rutas `DELETE`, `PUT` ni `PATCH`; ampliar `server/routes/orderRoutes.js` con `GET /:id/payments` y `POST /:id/payments` (mismos roles, validadores de T014); montar `/payments` en `server/routes/index.js`
- [X] T023 [P] [US1] Ampliar `client/lib/utils/status_labels.dart` con `PaymentStatus` (Pendiente ámbar, Pagado verde, Rechazado rojo, Cancelado neutro), `PaymentMethod` (etiquetas Efectivo, Tarjeta, Transferencia, Mercado Pago) y `CollectionStatus` (Sin cobrar neutro, Pendiente ámbar, Pagado verde); crear `client/lib/widgets/payment_chip.dart` (siempre con texto)
- [X] T024 [P] [US1] Crear `client/lib/models/payment.dart` (`Payment`, `Billing`, `PaymentMethodOption` con `fromJson`) y `client/lib/services/payments_service.dart` (`methods`, `listByOrder`, `create`, `list`, `get`); ampliar `client/lib/models/service_order.dart` con `billing` opcional (`null` para el mecánico)
- [X] T025 [US1] Crear `client/lib/widgets/order_billing_section.dart` y mostrarla en `client/lib/screens/order_detail_screen.dart` solo para ADMIN y RECEPTIONIST: total, chip de cobro, pagos de la orden (método, importe, estado, fecha), aviso «El total cambió después del cobro» si `amountOutdated`, y botón «Cobrar» (si `canCharge`) que abre un diálogo con método (los de `GET /payments/methods`, Mercado Pago deshabilitado con su leyenda si no está disponible), referencia opcional con validación local (máximo 100 caracteres y sin 13 a 19 dígitos seguidos, explicando que no se debe capturar un número de tarjeta) y un diálogo de confirmación que muestra método e importe; nunca pide número de tarjeta, vencimiento ni código de seguridad; mensajes de éxito y de error del servidor; ajustar `client/lib/providers/order_detail_provider.dart` (`createPayment`)
- [X] T026 [US1] Modificar `client/lib/screens/order_detail_screen.dart` (`_changeStatus`): al pulsar «Registrar entrega» sin pago `PAGADO` (`billing.collectionStatus != PAGADO`) mostrar la advertencia «La orden no está cobrada» con «Entregar de todos modos» / «Cancelar» además de la confirmación existente; sin cambiar el endpoint de estados (research D-12)
- [X] T027 [P] [US1] Crear `client/lib/providers/payments_provider.dart` (listado paginado con búsqueda y filtros de estado y método) y `client/lib/screens/payments_list_screen.dart` (tabla con fecha, folio de la orden, cliente, placa, método, importe y chip; búsqueda; filtros; paginación; estados vacío, cargando, error y sin resultados; abre la orden al seleccionar una fila)
- [X] T028 [US1] Modificar `client/lib/providers/navigation_provider.dart` (añadir `AppSection.payments` «Pagos» para ADMIN y RECEPTIONIST), `client/lib/widgets/app_shell.dart` (ícono), `client/lib/main.dart` (registrar `PaymentsService`, `PaymentsProvider` y la pantalla) y `client/lib/screens/home_screen.dart` (descripción del acceso directo)
- [X] T029 [P] [US1] Crear `client/test/order_billing_test.dart`: sección de cobro con total y estados; cobro en efectivo con confirmación y llamada a la API; diálogo sin campos de tarjeta; referencia con 16 dígitos rechazada sin llamar a la API; Mercado Pago deshabilitado con leyenda; error de pago existente; orden no cobrable; el mecánico no ve la sección; la advertencia al entregar sin cobro (cancelar no llama a la API, confirmar entrega) y la entrega de una orden cobrada sin advertencia
- [X] T030 [P] [US1] Crear `client/test/payments_list_test.dart`: listado con los cuatro estados y métodos, búsqueda, filtros, estados vacío y error, y que MECHANIC no ve la sección Pagos

**Punto de control**: escenarios 3 a 7, 18 y 19 de `quickstart.md` funcionan sin Mercado Pago.

---

## Fase 4: Historia de usuario 2 - Cobrar con Mercado Pago en modo de pruebas (Prioridad: P1)

**Objetivo**: crear un cobro de Mercado Pago (pago Pendiente con enlace), consultarlo bajo demanda hasta que quede Pagado o Rechazado, y cancelarlo si no se completa; sin datos de tarjeta ni credenciales expuestas.

**Prueba independiente**: con el proveedor simulado, `POST /orders/:id/payments` con `MERCADO_PAGO` crea un pago `PENDIENTE` con `checkoutUrl`; `POST /payments/:id/refresh` lo pasa a `PAGADO` cuando el proveedor reporta `approved`; sin credenciales el método responde `503`.

**Dependencia**: requiere la Historia 1 (modelo, servicio y rutas de pagos) y T011.

### Pruebas de la historia 2

- [X] T031 [P] [US2] Crear `server/tests/integration/payments.mercadoPago.test.js` (con `FakeGateway`): crea el pago `PENDIENTE` con `external_reference`, `checkout_url` y el importe del total; la consulta con `approved` pasa a `PAGADO` guardando `external_payment_id` y `paid_at`; con `rejected` a `RECHAZADO` y permite un nuevo cobro; con `pending` o sin operaciones sigue `PENDIENTE` y actualiza `last_checked_at`; consultar de nuevo un pago resuelto no cambia nada ni llama al proveedor; cancelar un pendiente (`CANCELADO`) y rechazar cancelar un pagado, rechazado o cancelado (`PAYMENT_NOT_CANCELLABLE`); sin credenciales `503 PROVIDER_NOT_CONFIGURED` sin crear pago y con los demás métodos funcionando; fallo del proveedor `502 PROVIDER_ERROR` sin dejar un pago a medias; consulta con fallo del proveedor conserva el estado; el total cambia después de crear el cobro (`amountOutdated`); un solo pago vigente también con Mercado Pago
- [X] T032 [P] [US2] Crear `server/tests/integration/payments.security.test.js`: ni las respuestas de la API, ni los registros de consola, ni las filas de `payments` contienen el token de Mercado Pago (se usa uno de prueba reconocible) ni números de tarjeta; los mensajes de error del proveedor no reenvían su cuerpo; `GET /payments/methods` no expone el token (SC-006, CA-7)
- [X] T033 [P] [US2] Ampliar `server/tests/contract/payments.contract.test.js` con `POST /payments/:id/refresh`, `POST /payments/:id/cancel`, el pago de Mercado Pago con `checkoutUrl` y los errores `409`, `502` y `503`

### Implementación de la historia 2

- [X] T034 [US2] Ampliar `server/services/paymentService.js` (parte 2): en `create` para `MERCADO_PAGO` (bloqueando la orden primero): inserta el pago `PENDIENTE` y su `external_reference` (`motorix-pago-<id>`), llama a `getGateway().createCheckout` con título «Orden OS-xxxxxx», y guarda `checkout_url`; si el proveedor falla, la transacción se revierte y se responde `502`/`503` sin dejar pago; `refresh(id)` (solo pendientes de Mercado Pago; consulta `findPaymentByReference`, aplica `mapProviderStatus` y `assertTransition`, guarda `external_payment_id`, `paid_at` y `last_checked_at`; si el pago ya está resuelto responde sin llamar al proveedor); `cancel(id)` (solo `PENDIENTE`, con `assertTransition`)
- [X] T035 [US2] Ampliar `server/routes/paymentRoutes.js` y `server/controllers/paymentController.js` con `POST /:id/refresh` y `POST /:id/cancel` (mismos roles, sin cuerpo)
- [X] T036 [P] [US2] Ampliar `client/lib/services/payments_service.dart` (`refresh`, `cancel`) y `client/lib/models/payment.dart` (`checkoutUrl`, `lastCheckedAt`, `externalPaymentId`); crear `client/lib/utils/link_opener.dart` que abre una URL con `url_launcher` (con un `LinkOpener` sustituible en pruebas)
- [X] T037 [US2] Ampliar `client/lib/widgets/order_billing_section.dart` y `client/lib/screens/payments_list_screen.dart` para pagos de Mercado Pago `PENDIENTE`: mostrar el enlace con «Copiar enlace» (portapapeles) y «Abrir enlace», «Actualizar estado» (muestra la fecha de la última consulta y el mensaje de éxito o error) y «Cancelar cobro» (con confirmación); pagos Rechazado y Cancelado quedan en el historial y la orden vuelve a poder cobrarse; el diálogo de cobro aclara que se creará un enlace de cobro
- [X] T038 [P] [US2] Crear `client/test/mercado_pago_payments_test.dart`: cobro con Mercado Pago muestra el enlace; copiar y abrir (con `LinkOpener` simulado); actualizar estado Pendiente → Pagado; Rechazado permite cobrar de nuevo; cancelar pide confirmación; error de proveedor y Mercado Pago no disponible con mensajes en español; nunca aparece el token

**Punto de control**: escenarios 8 a 11 de `quickstart.md` funcionan.

---

## Fase 5: Historia de usuario 3 - Generar, visualizar e imprimir el ticket de servicio (Prioridad: P1)

**Objetivo**: generar un ticket único por orden cobrada con una instantánea de su contenido, visualizarlo, listarlo e imprimirlo.

**Prueba independiente**: con una orden con pago `PAGADO`, `POST /api/orders/:id/ticket` crea el ticket con folio y todos los campos; repetir devuelve el mismo; cambiar la orden después no altera el ticket; sin pago `PAGADO` responde `409`.

**Dependencia**: requiere la Historia 1 (pagos `PAGADO`).

### Pruebas de la historia 3

- [X] T039 [P] [US3] Crear `server/tests/unit/ticketContent.test.js`: `buildTicketContent` incluye todos los campos de CA-4 (taller, cliente, vehículo con placas y kilometraje, folio de la orden, servicios, refacciones con cantidad y sin importe, mano de obra, subtotales y total en centavos exactos, método, estado y fecha del pago, fecha de generación), usa el kilometraje del servicio cuando existe y, si no, el de entrada, no suma las refacciones al total, y no incluye campos de tarjeta; `formatTicketFolio` (`TK-000012`)
- [X] T040 [P] [US3] Crear `server/tests/contract/tickets.contract.test.js`: forma del ticket, de `POST /orders/:id/ticket` (`201` con `created: true`, `200` con `created: false`), `GET /orders/:id/ticket`, `GET /tickets` (sin `content`, con `meta`) y `GET /tickets/:id` según contracts/api-rest.md; `401`, `403`, `404` y `409`
- [X] T041 [P] [US3] Crear `server/tests/integration/tickets.flow.test.js`: genera con pago `PAGADO` (folio, orden, pago, persona, fecha y contenido completo), genera de nuevo y devuelve el existente sin otro folio, rechaza sin pago, con pago `PENDIENTE`, `RECHAZADO` y `CANCELADO` (`TICKET_REQUIRES_PAYMENT`), el ticket conserva los importes, el cliente y el vehículo originales tras cambiar servicios de la orden o datos del cliente y del vehículo, listado con búsqueda por folio de ticket, folio de orden, cliente y placa, ausencia de `DELETE`/`PUT`/`PATCH`, orden Entregada conserva su ticket, el mecánico recibe `403` y `billing.ticket` aparece en el detalle de la orden
- [X] T042 [P] [US3] Crear `server/tests/integration/tickets.concurrency.test.js`: varias solicitudes simultáneas de generación para la misma orden producen un solo ticket (una `201` y el resto `200` con el mismo identificador)

### Implementación de la historia 3

- [X] T043 [P] [US3] Crear `server/services/ticketContent.js` (módulo puro): `formatTicketFolio(id)` → `TK-` + id con 6 dígitos y `buildTicketContent({ shop, order, customer, vehicle, services, parts, labor, payment, now })` que devuelve la estructura de data-model.md (sin importes en refacciones; subtotales y total calculados en centavos)
- [X] T044 [P] [US3] Crear `server/models/ticketModel.js`: `insert`, `findById`, `findByOrder`, `list` (búsqueda por folio de ticket, folio de orden, cliente o placa; orden descendente; paginación; sin `content`); traduce `ER_DUP_ENTRY` de `uq_tickets_order` a un error reconocible; `content` se guarda y se lee como JSON
- [X] T045 [US3] Crear `server/services/ticketService.js`: `generate(orderId, actor)` (lee la orden, su pago `PAGADO` y los servicios, mano de obra, refacciones, cliente y vehículo; arma el contenido con `ticketContent` y `getShopConfig`; inserta en una transacción que bloquea la orden primero; si ya existe devuelve el existente con `created: false`; sin pago `PAGADO` lanza `TICKET_REQUIRES_PAYMENT` 409; resuelve la carrera releyendo el existente), `getByOrder`, `getById` y `list`
- [X] T046 [US3] Crear `server/controllers/ticketController.js` y `server/routes/ticketRoutes.js` (`authorize(ADMIN, RECEPTIONIST)`; `GET /`, `GET /:id`; sin `DELETE`/`PUT`/`PATCH`); ampliar `server/routes/orderRoutes.js` con `POST /:id/ticket` y `GET /:id/ticket`; montar `/tickets` en `server/routes/index.js`; añadir `ticket` al bloque `billing` (`paymentService.getBilling`)
- [X] T047 [P] [US3] Crear `client/lib/models/ticket.dart` (`Ticket`, `TicketContent` y sus partes), `client/lib/services/tickets_service.dart` (`generate`, `getByOrder`, `get`, `list`) y `client/lib/providers/tickets_provider.dart` (listado paginado con búsqueda)
- [X] T048 [P] [US3] Crear `client/lib/widgets/ticket_view.dart` (vista con formato de ticket: encabezado del taller, folio y fecha, cliente, vehículo con placas y kilometraje, tablas de servicios, refacciones con cantidad y mano de obra, subtotales, total, método y estado del pago; texto largo ajustado) y `client/lib/utils/ticket_printer.dart` (arma en memoria el documento de impresión con `pdf` y lo envía a `Printing.layoutPdf`; sin guardar archivos; con una interfaz `TicketPrinter` sustituible en pruebas)
- [X] T049 [US3] Crear `client/lib/screens/ticket_screen.dart` («Imprimir» y volver; estados cargando y error) y `client/lib/screens/tickets_list_screen.dart` (tabla con folio, fecha, folio de la orden, cliente, placa y total; búsqueda; paginación; estados vacío, cargando, error y sin resultados); añadir a `client/lib/widgets/order_billing_section.dart` «Generar ticket» (visible con pago `PAGADO` y sin ticket, con confirmación) y «Ver ticket» (si existe)
- [X] T050 [US3] Modificar `client/lib/providers/navigation_provider.dart` (añadir `AppSection.tickets` «Tickets» para ADMIN y RECEPTIONIST), `client/lib/widgets/app_shell.dart`, `client/lib/main.dart` y `client/lib/screens/home_screen.dart`
- [X] T051 [P] [US3] Crear `client/test/ticket_screens_test.dart`: generar con confirmación, ticket con todos los campos y las refacciones sin importe, imprimir con `TicketPrinter` simulado, no se ofrece generar sin pago `PAGADO`, «Ver ticket» cuando existe, listado con búsqueda y estados vacío y error, y que MECHANIC no ve la sección Tickets

**Punto de control**: escenarios 12 a 16 de `quickstart.md` funcionan.

---

## Fase 6: Historia de usuario 4 - Consultar el panel de control del taller (Prioridad: P2)

**Objetivo**: el administrador consulta indicadores reales de órdenes, citas, mantenimientos, inventario y cobros, y la actividad reciente; cada indicador coincide con su listado.

**Prueba independiente**: con datos de ejemplo, `GET /api/dashboard` devuelve cada indicador igual al total del listado correspondiente; recepción y mecánico reciben `403`.

**Dependencia**: usa órdenes, citas, mantenimientos e inventario existentes; los indicadores de cobro usan la Historia 1.

### Pruebas de la historia 4

- [X] T052 [P] [US4] Crear `server/tests/contract/dashboard.contract.test.js`: forma completa de `GET /api/dashboard` según contracts/api-rest.md (todos los grupos e indicadores numéricos, `generatedAt`, tres listas de actividad), `401`, `403` para RECEPTIONIST y MECHANIC
- [X] T053 [P] [US4] Crear `server/tests/integration/dashboard.test.js`: con un escenario de datos conocido, cada indicador es el esperado (vehículos atendidos en 30 días solo cuenta Entregadas dentro del periodo y vehículos distintos; en reparación; pendientes; terminadas pendientes de entrega; citas próximas solo Pendientes o Confirmadas dentro de 7 días; mantenimientos próximos y vencidos; stock bajo y agotadas; terminadas sin cobrar; pagos pendientes de Mercado Pago); cada indicador coincide con el total del listado correspondiente (`GET /orders?status=…`, `GET /appointments?…`, `GET /maintenance?indicator=…`, `GET /parts/alerts`, `GET /payments?status=PENDIENTE`) antes y después de cambiar datos (terminar una orden, cobrarla, registrar una salida de inventario); actividad reciente con máximo 5 elementos por lista, del más reciente al más antiguo; un taller sin datos devuelve ceros y listas vacías

### Implementación de la historia 4

- [X] T054 [P] [US4] Crear `server/models/dashboardModel.js`: consultas de conteo y actividad (`countOrdersByStatuses`, `countAttendedVehicles(days)` con vehículos distintos de órdenes `ENTREGADO` cuya `delivered_at` está en los últimos 30 días, `countUpcomingAppointments(days)` para `PENDIENTE`/`CONFIRMADA`, `countFinishedWithoutPayment` para órdenes `TERMINADO` sin pago `PAGADO`, `countPaymentsByStatus`, `recentOrderChanges(5)`, `recentPayments(5)`, `recentInventoryMovements(5)`); sin tablas ni copias de datos
- [X] T055 [US4] Crear `server/services/dashboardService.js`: compone en paralelo los conteos del modelo, `maintenanceModel.list` (mismo criterio y márgenes que la lista de Mantenimientos, `pageSize: 1` para leer el total) y `partService.alerts()`; devuelve la estructura de contracts/api-rest.md con `generatedAt`
- [X] T056 [US4] Crear `server/controllers/dashboardController.js` y `server/routes/dashboardRoutes.js` (`authenticate` + `authorize(ROLES.ADMIN)`; `GET /`); montar `/dashboard` en `server/routes/index.js`
- [X] T057 [P] [US4] Crear `client/lib/models/dashboard.dart`, `client/lib/services/dashboard_service.dart` y `client/lib/providers/dashboard_provider.dart` (carga, error, actualización manual y `generatedAt`)
- [X] T058 [P] [US4] Crear `client/lib/widgets/indicator_card.dart` (valor, etiqueta, tono rojo/ámbar/neutro y acción al seleccionar; el color nunca es la única señal)
- [X] T059 [US4] Crear `client/lib/screens/dashboard_screen.dart`: tarjetas agrupadas en Órdenes, Citas, Mantenimientos, Inventario y Cobros que llevan a Órdenes, Citas, Mantenimientos, Inventario y Pagos; bloque «Actividad reciente» con tres listas cortas; «Actualizar» y fecha de la última actualización; estados cargando, error con reintento y ceros con estado vacío; sigue `docs/design-system.md`
- [X] T060 [US4] Modificar `client/lib/providers/navigation_provider.dart` (añadir `AppSection.dashboard` «Panel de control» solo para ADMIN, justo después de Inicio), `client/lib/widgets/app_shell.dart`, `client/lib/main.dart` y `client/lib/screens/home_screen.dart`
- [X] T061 [P] [US4] Crear `client/test/dashboard_test.dart`: tarjetas con valores y tonos, navegación al seleccionar cada una, actividad reciente, actualizar, ceros con estado vacío, error con reintento, y que RECEPTIONIST y MECHANIC no ven la sección

**Punto de control**: escenarios 1, 17 y 20 de `quickstart.md` funcionan.

---

## Fase 7: Datos de ejemplo, pulido y validación (transversal)

**Propósito**: seeds idempotentes, rendimiento, documentación y validación completa del sprint

- [X] T062 Crear `database/seeds/004_payments_tickets.sql` (idempotente, requiere los seeds 001 a 003; claves naturales de research D-13; sin llamar al proveedor ni contener credenciales): pagos sobre las órdenes entregadas de los sprints 2 y 3 en los cuatro estados y con los cuatro métodos (por ejemplo: efectivo, transferencia y tarjeta `PAGADO`; Mercado Pago `PAGADO` con `external_payment_id` de ejemplo; Mercado Pago `RECHAZADO` seguido de un pago en efectivo `PAGADO` en otra orden; Mercado Pago `CANCELADO`), un cobro de Mercado Pago `PENDIENTE` con `checkout_url` de ejemplo sobre la orden Terminada del Sprint 2, y tickets de varias órdenes cobradas con `content` armado con `JSON_OBJECT`/`JSON_ARRAYAGG` en la misma forma que `buildTicketContent`; dejar al menos una orden Terminada sin pago `PAGADO`, citas próximas, mantenimientos próximos y vencidos y alertas de stock (ya sembrados) para que todos los indicadores del panel tengan valores
- [X] T063 [P] Crear `server/tests/integration/seeds.sprint4.test.js`: pagos en los cuatro estados y métodos, un único pago vigente por orden, tickets con todos los campos y claves iguales a las de `buildTicketContent`, `GET /api/dashboard` con todos los indicadores distintos de cero donde corresponde, ningún dato de tarjeta ni credenciales, y que ejecutar el seed tres veces seguidas no duplica pagos ni tickets (SC-011)
- [X] T064 [P] Ampliar `server/tests/integration/performance.test.js` con 1 000 pagos y 1 000 tickets: listados y filtros de pagos y tickets, detalle de una orden con `billing` y `GET /api/dashboard` responden en menos de 2 s (SC-012)
- [X] T065 Aplicar el seed con `database/scripts/aplicar-seeds.ps1 -Base motorix`, repetirlo y verificar que no hay duplicados
- [X] T066 [P] Actualizar `database/README.md` (tablas nuevas, seed 004, variables de entorno) y `README.md` (sección «Estado del Sprint 4» y mención de que Mercado Pago es opcional y de pruebas)
- [X] T067 Revisar que la interfaz nueva cumpla `docs/design-system.md` (tokens, estados vacío/cargando/error, confirmaciones de contracts/interfaz.md, accesibilidad: el color nunca es la única señal) y ejecutar `flutter analyze lib` sin avisos
- [X] T068 Ejecutar `npm test` en `server/` y `flutter test` en `client/` completos; corregir regresiones de los sprints 1 a 3
- [X] T069 Recorrer los 22 escenarios de `specs/004-pagos-tickets-dashboard/quickstart.md` con las cuentas `recepcion`, `mecanico`, `mecanico2` y `admin` contra la API real y MySQL local; para Mercado Pago, usar un servidor local simulado del proveedor mediante `MERCADOPAGO_API_URL` (y, si el equipo dispone de una cuenta de pruebas, también contra el entorno de pruebas real, confirmando los campos `sandbox_init_point` y la búsqueda por `external_reference` de research D-04); completar la sección 6 «Resultado de la validación» con pruebas, comprobaciones y criterios CA-1 a CA-8
- [X] T070 Verificar que no hay secretos en el repositorio (ni token de Mercado Pago ni contraseñas) y que `git status` no incluye `.env`

---

## Dependencias y orden de ejecución

### Dependencias entre fases

- **Fase 1 (Preparación)**: sin dependencias.
- **Fase 2 (Fundamentos)**: depende de la Fase 1 y **bloquea** todas las historias.
- **Fases 3 a 6 (historias)**: dependen de la Fase 2.
- **Fase 7 (Pulido)**: depende de las historias que se quieran entregar.

### Dependencias entre historias

- **US1** (pago con su método): independiente; es la base del resto.
- **US2** (Mercado Pago): depende de US1 (servicio, modelo y rutas de pagos) y del adaptador (T011).
- **US3** (ticket): depende de US1 (pagos `PAGADO`); no necesita Mercado Pago.
- **US4** (panel): independiente de US2 y US3 salvo por los conteos de pagos (US1); puede avanzar en paralelo con US2 y US3.

### Dentro de cada historia

Pruebas (escribirlas y verificar que fallan) → modelos → servicios → controladores y rutas → cliente (modelos, servicios, proveedores) → pantallas → pruebas del cliente.

### Oportunidades de paralelismo

- Fase 1: T002, T003 y T004 en paralelo.
- Fase 2: T008 a T014 en paralelo tras T007 (T010 y T012 tras sus módulos).
- Tras US1, US2, US3 y US4 pueden avanzar en paralelo por personas distintas (archivos distintos).
- Dentro de cada historia, las tareas [P] de pruebas del servidor y del cliente son independientes.

```text
Fundamentos:    T006 → T007 → { T008, T009, T011, T013, T014 } → { T010, T012 }
US1:            T015, T016, T017, T018 (pruebas) → T019 → T020 → T021 → T022 → T023..T030
US2 / US3 / US4 en paralelo tras US1:
                US2: T031..T033 → T034 → T035 → T036 → T037 → T038
                US3: T039..T042 → T043 → T044 → T045 → T046 → T047..T051
                US4: T052, T053 → T054 → T055 → T056 → T057..T061
```

---

## Estrategia de implementación

### MVP primero

1. Completar las Fases 1 y 2 (migración, reglas puras, adaptador del proveedor y plantillas).
2. Completar US1: cobro en efectivo, tarjeta y transferencia, con el bloque de cobro, el listado de pagos y la advertencia al entregar sin cobro.
3. **Detener y validar**: probar de forma independiente con los escenarios 3 a 7, 18 y 19 de `quickstart.md`.
4. Seguir con US3 (ticket) para completar el comprobante del cliente, luego US2 (Mercado Pago) y por último US4 (panel) y la Fase 7 (seeds y validación completa).

### Entrega incremental

Cada historia se cierra con sus pruebas en verde antes de pasar a la siguiente. El sprint se considera completo cuando se cumplen CA-1 a CA-8 de `docs/sprints/sprint-4-pagos-tickets-dashboard.md` y el flujo «orden terminada → consultar total → registrar pago → Mercado Pago cuando corresponda → generar ticket → consultar el panel» se demuestra con recepción y administración.

## Notas

- Las tareas [P] tocan archivos distintos y no dependen de tareas incompletas.
- Cada historia debe poder completarse y probarse de forma independiente salvo las dependencias indicadas.
- Confirmar que las pruebas fallan antes de implementar y hacer un commit pequeño por tarea o grupo lógico (Conventional Commits con la descripción en español).
- No se editan scripts de sprints ya aplicados: todo cambio de esquema va en `004_…`.
- Siempre bloquear la fila de la orden (`FOR UPDATE`) antes de cualquier lectura normal dentro de la transacción de un cobro o de un ticket (lección del Sprint 3 con el nivel REPEATABLE READ).
- Ninguna contraseña ni token en texto plano en código, scripts, pruebas ni documentación; el token de Mercado Pago vive solo en `.env`.
- Prohibido cambiar el estado de un pago fuera de `paymentService` y llamar a Mercado Pago fuera del adaptador.
