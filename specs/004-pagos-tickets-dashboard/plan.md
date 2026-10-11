# Plan de implementación: Pagos, tickets y panel de control (Sprint 4)

**Rama**: `004-pagos-tickets-dashboard` | **Fecha**: 2026-10-11 | **Especificación**: [spec.md](./spec.md)

**Entrada**: Especificación de la funcionalidad en `specs/004-pagos-tickets-dashboard/spec.md`

## Resumen

Cerrar el ciclo de atención y el MVP. La recepción cobra una orden Terminada o Entregada por su total
(servicios más mano de obra) en efectivo, tarjeta (terminal externa), transferencia o Mercado Pago en modo
de pruebas; genera un ticket único por orden cobrada, que se visualiza e imprime; y la administración
consulta un panel con indicadores reales de órdenes, citas, mantenimientos, inventario y cobros.

Enfoque técnico (detalle en [research.md](./research.md)): se reutilizan la pila y las capas de los sprints
anteriores. La migración `004` agrega `payments` y `tickets`. Las reglas que no pueden fallar por
concurrencia se refuerzan en la base: un solo pago vigente por orden (columna generada con índice único),
un solo ticket por orden (índice único) y restricciones que impiden pagos inmediatos sin estado Pagado.
La lógica de estados de pago y de contenido del ticket vive en módulos puros y probados (`paymentRules`,
`ticketContent`). Mercado Pago se aísla en un adaptador (`integrations/mercadoPago.js`) que usa el `fetch`
de Node.js sin SDK, con credenciales solo por variables de entorno y sustituible en pruebas. El ticket
guarda una instantánea de su contenido. El panel calcula cada indicador reutilizando los mismos modelos y
criterios de los listados, sin tablas de estadísticas. En el cliente se agregan dos dependencias pequeñas y
justificadas: `printing` (impresión en escritorio) y `url_launcher` (abrir el enlace de cobro).

## Contexto técnico

**Lenguaje/Versión**: JavaScript (ES Modules) sobre Node.js 24 LTS en el backend; Dart con Flutter
3.47.2 en el frontend; SQL para MySQL 8.0 (sin cambios respecto a los sprints anteriores)

**Dependencias principales**:
- Backend: ninguna nueva (`express`, `mysql2`, `jsonwebtoken`, `bcryptjs`, `zod`, `cors`, `helmet`, `dotenv`;
  Mercado Pago se consume con el `fetch` incluido en Node.js).
- Frontend: **dos nuevas** — `printing` (con su dependencia `pdf`, para abrir el diálogo de impresión del
  sistema con el ticket) y `url_launcher` (para abrir el enlace de cobro en el navegador). Justificación en
  research D-09. Se mantienen `provider`, `http`, `google_fonts` y `data_table_2`.
- Pruebas: `jest`, `supertest` (backend); `flutter_test` (frontend)

**Almacenamiento**: MySQL 8.0 local, InnoDB, `utf8mb4`; bases `motorix` y `motorix_test`; usuario
dedicado `motorix_app`. Nueva migración `database/migrations/004_sprint4_payments_tickets.sql` y nuevo seed
`database/seeds/004_payments_tickets.sql`. Variables de entorno nuevas (todas opcionales, sin valores
secretos en el repositorio): `MERCADOPAGO_ACCESS_TOKEN`, `MERCADOPAGO_API_URL`, `SHOP_NAME`, `SHOP_ADDRESS`,
`SHOP_PHONE`.

**Pruebas**: Jest (unitarias de reglas de pago, adaptador de Mercado Pago con `fetch` simulado y contenido
del ticket) y Jest + supertest (integración y contrato contra `motorix_test`, con un proveedor de pagos
simulado y pruebas de concurrencia); `flutter test` (proveedores y pantallas)

**Plataforma objetivo**: Aplicación de escritorio (Windows como principal) que consume la API REST local;
interfaz responsiva con prioridad en escritorio

**Tipo de proyecto**: Aplicación web/escritorio con API (frontend + backend + persistencia)

**Metas de rendimiento**: pago en efectivo registrado en menos de 1 min y ticket en menos de 1 min
(SC-001, SC-003); listados y panel con hasta 1 000 registros en menos de 2 s (SC-012)

**Restricciones**: ES Modules obligatorio en el backend; solo el backend accede a la base de datos y al
proveedor de pagos; permisos validados en el backend; no se editan scripts de sprints anteriores; sin datos
de tarjeta ni credenciales en la base, el repositorio, las respuestas ni los registros; sin precios de
refacciones; sin archivos PDF; seeds idempotentes que no llaman al proveedor; cumplimiento de
`docs/design-system.md`

**Escala/Alcance**: 3 roles, 2 tablas nuevas, 5 pantallas nuevas (panel, pagos, tickets, ticket y sección
de cobro en el detalle de la orden), hasta ~1 000 pagos, tickets y órdenes

## Verificación de la constitución

*PUERTA: debe pasar antes de la Fase 0. Se vuelve a verificar tras el diseño de la Fase 1.*

| Principio | Evaluación | Cómo se cumple |
|-----------|------------|----------------|
| I. Alcance, MVP y fuente de verdad | PASA | Solo Sprint 4, después de los sprints 1 a 3; fuera de alcance excluido (FR-028). Se leyeron `docs/project-context.md` y el insumo del sprint. Los campos de `Payment` y `Ticket` se ajustan a la especificación (ver "Actualizaciones de documentación") |
| II. Arquitectura separada | PASA | `client/`, `server/`, `database/`; capas en la raíz de `server/`; la lógica vive en `services/`; la integración con Mercado Pago está aislada en `integrations/` (reglas del proyecto: «lógica de integración aislada del dominio») |
| III. Stack y base local | PASA CON JUSTIFICACIÓN | Mismo stack y migración numerada nueva; InnoDB, llaves foráneas, `utf8mb4`; seeds idempotentes con datos suficientes. Backend sin dependencias nuevas. Frontend: `printing` y `url_launcher` son dependencias nuevas, justificadas en research D-09 (la constitución exige justificar toda dependencia nueva) |
| IV. Seguridad | PASA | `authenticate` + `authorize` por ruta; validación `zod`; el token de Mercado Pago solo en variables de entorno y nunca en respuestas ni registros; ningún dato de tarjeta se solicita ni se guarda (RN-14); errores del proveedor traducidos a mensajes genéricos |
| V. Reglas de negocio | PASA | RN-9 (orden entregada = historial; pagos y ticket no se borran), RN-13 (pago siempre ligado a una orden, con llave foránea), RN-14 (sin datos sensibles), RN-15 (permisos en backend) |
| VI. API consistente | PASA | Misma forma `{ data, meta }` / `{ error }`, códigos HTTP y manejo central de errores; contrato en [contracts/api-rest.md](./contracts/api-rest.md) |
| VII. Pruebas | PASA | Pruebas unitarias de reglas de pago y de contenido del ticket (CA-8), integración y contrato contra `motorix_test`, adaptador de Mercado Pago con `fetch` simulado, concurrencia y `flutter test`; flujo de extremo a extremo en el quickstart |
| VIII. UX/UI | PASA | Material 3 con el tema propio y tokens; confirmaciones para registrar y cancelar pagos, generar el ticket y entregar sin cobro; estados vacío, cargando y error; chips de estado con la convención de color. `fl_chart` no se necesita: los indicadores son tarjetas numéricas |

**Reevaluación tras la Fase 1**: PASA. El diseño solo suma las dos dependencias de cliente justificadas y no
rompe la separación de capas. No hay violaciones que justificar más allá de D-09.

## Estructura del proyecto

### Documentación (esta funcionalidad)

```text
specs/004-pagos-tickets-dashboard/
├── plan.md              # Este archivo (salida de /speckit-plan)
├── research.md          # Salida de la Fase 0
├── data-model.md        # Salida de la Fase 1
├── quickstart.md        # Salida de la Fase 1
├── contracts/           # Salida de la Fase 1
│   ├── api-rest.md      # Contrato de la API REST (pagos, tickets, panel)
│   └── interfaz.md      # Contrato de pantallas, navegación y permisos por rol
├── checklists/
│   └── requirements.md
└── tasks.md             # Salida de la Fase 2 (/speckit-tasks; NO lo crea /speckit-plan)
```

### Código fuente (raíz del repositorio)

Solo se listan archivos nuevos o modificados; el resto de la estructura es la de los sprints anteriores.

```text
database/
├── migrations/
│   └── 004_sprint4_payments_tickets.sql        # NUEVO
├── seeds/
│   └── 004_payments_tickets.sql                # NUEVO (idempotente, sin llamar al proveedor)
└── README.md                                   # actualizar (nuevas tablas y seed)

server/
├── config/env.js           # MODIFICADO: getMercadoPagoConfig() y getShopConfig()
├── integrations/           # NUEVO: mercadoPago.js (adaptador aislado; sustituible en pruebas)
├── controllers/            # NUEVOS: paymentController, ticketController, dashboardController
├── models/                 # NUEVOS: paymentModel, ticketModel, dashboardModel
├── routes/                 # NUEVAS: paymentRoutes, ticketRoutes, dashboardRoutes;
│                           # orderRoutes ampliado (pagos y ticket de una orden); index.js las monta
├── services/               # NUEVOS: paymentService, ticketService, dashboardService,
│                           #         paymentRules (puro), ticketContent (puro)
│                           # MODIFICADO: orderService (resumen de cobro en el detalle)
├── validators/             # NUEVOS: paymentValidators, ticketValidators
└── tests/
    ├── unit/               # paymentRules, mercadoPagoAdapter, ticketContent, paymentPermissions
    ├── integration/        # payments.flow, payments.mercadoPago, payments.concurrency, tickets.flow,
    │                       # dashboard, seeds.sprint4, performance (ampliado)
    ├── contract/           # payments.contract, tickets.contract, dashboard.contract
    └── helpers/            # factories.js ampliado (pagos, tickets) y proveedor de pagos simulado

client/
├── pubspec.yaml            # MODIFICADO: printing, url_launcher
└── lib/
    ├── models/             # NUEVOS: payment.dart, ticket.dart, dashboard.dart
    ├── providers/          # NUEVOS: payments_provider, tickets_provider, dashboard_provider;
    │                       # MODIFICADOS: navigation_provider (secciones), order_detail_provider (cobro)
    ├── screens/            # NUEVAS: dashboard_screen, payments_list_screen, tickets_list_screen,
    │                       #         ticket_screen; MODIFICADA: order_detail_screen (cobro y entrega sin cobro)
    ├── services/           # NUEVOS: payments_service, tickets_service, dashboard_service
    ├── widgets/            # NUEVOS: order_billing_section, payment_chip, ticket_view, indicator_card
    └── utils/              # NUEVO: ticket_printer.dart; MODIFICADO: status_labels.dart
client/test/                # pruebas de proveedores y pantallas nuevas
```

**Decisión de estructura**: el cobro (`paymentService`) es el único que cambia el estado de los pagos y el
único que habla con el adaptador de Mercado Pago; `ticketService` solo lee pagos y órdenes. El panel
(`dashboardService`) no tiene modelo propio de datos: compone consultas de los modelos existentes.

## Actualizaciones de documentación

1. `docs/project-context.md` (entidades `Payment` y `Ticket`): usar los campos de la especificación
   (`order_id`, importe, método, estado, referencias externas, enlace de cobro, instantánea del ticket) y
   registrar que el total se calcula como servicios más mano de obra, que las refacciones no suman importe,
   que el ticket no genera archivo PDF y que el panel es exclusivo de administración.
2. `.env.example`: documentar `MERCADOPAGO_ACCESS_TOKEN` (vacío), `MERCADOPAGO_API_URL`, `SHOP_NAME`,
   `SHOP_ADDRESS` y `SHOP_PHONE`.
3. `database/README.md`: documentar la migración y el seed del Sprint 4.
4. `.specify/memory/constitution.md` o `docs/project-context.md` §27: registrar como decisión del Sprint 4
   el uso de `printing` y `url_launcher` en el cliente.

## Seguimiento de complejidad

| Elemento | Por qué se necesita | Alternativa más simple descartada |
|----------|---------------------|-----------------------------------|
| Dependencias `printing` y `url_launcher` (cliente) | Flutter de escritorio no trae impresión ni apertura de enlaces en el navegador; CA-5 exige imprimir | Mostrar solo el enlace/ticket en pantalla sin imprimir (no cumple CA-5) |
