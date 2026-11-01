# Plan de implementación: Precios de refacciones y cobro completo (Sprint 5)

**Rama**: `005-precios-refacciones-cobro` | **Fecha**: 2026-10-31 | **Especificación**: [spec.md](./spec.md)

**Entrada**: Especificación de la funcionalidad en `specs/005-precios-refacciones-cobro/spec.md`

## Resumen

Las refacciones pasan a tener categoría, marca, precio de compra y precio de venta, y el total de la orden suma
servicios, mano de obra y refacciones. El pago y el ticket nuevos reflejan ese total; los pagos y tickets
emitidos antes del sprint no cambian. El precio de compra solo lo ve la administración y el mecánico no ve
ningún precio.

Enfoque técnico (detalle en [research.md](./research.md)): se reutilizan la pila y las capas de los sprints
anteriores, sin dependencias nuevas. La migración `005` es aditiva: agrega cuatro columnas a `parts` y
`unit_price` a `order_parts`. Esta última es la instantánea del precio; las líneas anteriores quedan en `0` y
no suman, y toda línea nueva guarda un precio mayor a cero. El total sigue calculándose y no se guarda: la
consulta de totales suma también las refacciones. Las reglas nuevas viven en un módulo puro y probado
(`orderTotals`) y en `orderPartService`, que ya bloquea la orden antes de cada cambio, de modo que pago y cambios
de refacciones se serializan. El ticket nuevo lleva `formatVersion: 2` y toma su total del pago registrado; los
anteriores se muestran tal como están. El precio de compra solo existe en las rutas de refacciones del
administrador, y las líneas de la orden se proyectan según el rol.

## Contexto técnico

**Lenguaje/Versión**: JavaScript (ES Modules) sobre Node.js (≥ 20) en el backend; Dart con Flutter en el
frontend; SQL para MySQL 8.0 (sin cambios respecto a los sprints anteriores)

**Dependencias principales**:
- Backend: ninguna nueva (`express`, `mysql2`, `jsonwebtoken`, `bcryptjs`, `zod`, `cors`, `helmet`, `dotenv`).
- Frontend: ninguna nueva (`provider`, `http`, `google_fonts`, `data_table_2`, `printing`, `url_launcher`).
- Pruebas: `jest`, `supertest` (backend); `flutter_test` (frontend).

**Almacenamiento**: MySQL 8.0 local, InnoDB, `utf8mb4`; bases `motorix` y `motorix_test`; usuario dedicado
`motorix_app`. Nueva migración `database/migrations/005_sprint5_part_prices.sql` y nuevo seed
`database/seeds/005_part_prices.sql`. Sin variables de entorno nuevas.

**Pruebas**: Jest (unitarias de `orderTotals`, validadores de precios y contenido del ticket versión 2),
Jest + supertest (integración y contrato contra `motorix_test`, con proveedor de pagos simulado y pruebas de
concurrencia); `flutter test` (modelos, proveedores y pantallas). Línea base: 1003 pruebas de backend y 277 de
frontend del 2026-10-31.

**Plataforma objetivo**: Aplicación de escritorio (Windows como principal) que consume la API REST local;
interfaz responsiva con prioridad en escritorio

**Tipo de proyecto**: Aplicación web/escritorio con API (frontend + backend + persistencia)

**Metas de rendimiento**: sin metas nuevas; el cálculo del total y los listados mantienen los tiempos del
Sprint 4 (la consulta de totales agrega una suma sobre `order_parts`, que ya está indexada por orden)

**Restricciones**: ES Modules obligatorio en el backend; solo el backend accede a la base de datos; permisos
validados en el backend; no se editan scripts de sprints anteriores; importes en centavos enteros y
`DECIMAL(10,2)`; tope de 9 999 999.99 para precios y total; sin datos de tarjeta; seeds idempotentes que no
llaman al proveedor; cumplimiento de `docs/design-system.md`

**Escala/Alcance**: 3 roles, 0 tablas nuevas, 5 columnas nuevas, 2 migraciones de datos implícitas (valores por
omisión), cambios en 4 pantallas (formulario y listado del inventario, refacciones de la orden, cobro y ticket),
hasta ~1 000 órdenes

## Verificación de la constitución

*PUERTA: debe pasar antes de la Fase 0. Se vuelve a verificar tras el diseño de la Fase 1.*

| Principio | Evaluación | Cómo se cumple |
|-----------|------------|----------------|
| I. Alcance, MVP y fuente de verdad | REQUIERE ENMIENDA ANTES DE IMPLEMENTAR | El principio fija los sprints 1 a 4 y exige aprobación para agregar alcance. Este sprint es posterior al MVP: la implementación no empieza hasta que el director y el equipo aprueben la enmienda de la constitución (tarea T002, hallazgo H-01 del aseguramiento); la documentación y el diseño pueden avanzar. Se leyó `docs/project-context.md` (secciones 6.7, 6.8, 6.10 y 13) y el insumo del sprint. Se actualizará la documentación para que código y planeación no se contradigan (FR-018) |
| II. Arquitectura separada | PASA | `client/`, `server/`, `database/`; la lógica vive en `services/` y en el módulo puro `orderTotals`; la integración con Mercado Pago no cambia |
| III. Stack y base local | PASA | Mismo stack; migración numerada nueva y aditiva; InnoDB, llaves foráneas, `utf8mb4`; seeds idempotentes con datos suficientes. Sin dependencias nuevas |
| IV. Seguridad | PASA | Rutas con `authenticate` + `authorize`; validación `zod`; el precio de compra solo se selecciona en las rutas de refacciones del administrador; las líneas de la orden se proyectan por rol en el servicio; ningún dato de tarjeta |
| V. Reglas de negocio | PASA | RN-6 y RN-7 (refacciones ligadas a la orden con su salida de inventario), RN-8 (sin stock negativo), RN-9 (orden entregada = historial), RN-13 (pago ligado a la orden), RN-15 (permisos en el backend) |
| VI. API consistente | PASA | Misma forma `{ data, meta }` / `{ error }`, códigos HTTP y manejo central; contrato en [contracts/api-rest.md](./contracts/api-rest.md) |
| VII. Pruebas | PASA | Pruebas unitarias del total y de los precios, integración y contrato contra `motorix_test`, concurrencia (pago contra cambios de refacciones, precio contra alta de línea), regresión de los sprints 1 a 4 y `flutter test`; flujo de extremo a extremo en [quickstart.md](./quickstart.md) |
| VIII. UX/UI | PASA | Material 3 con el tema propio y tokens; confirmación al guardar un precio de venta menor al de compra y al cancelar un pago desfasado; estados vacío, cargando y error; chip «Sin precio de venta» con la convención de color ámbar |

**Reevaluación tras la Fase 1**: REQUIERE ENMIENDA ANTES DE IMPLEMENTAR (misma puerta del principio I, T002). El diseño no agrega
dependencias, tablas ni capas nuevas.

## Estructura del proyecto

### Documentación (esta funcionalidad)

```text
specs/005-precios-refacciones-cobro/
├── spec.md              # Especificación (/speckit-specify y /speckit-clarify)
├── plan.md              # Este archivo (/speckit-plan)
├── research.md          # Fase 0: decisiones y alternativas
├── data-model.md        # Fase 1: columnas, reglas y estados
├── quickstart.md        # Fase 1: guía de validación de extremo a extremo
├── contracts/
│   ├── api-rest.md      # Cambios del contrato de la API
│   └── interfaz.md      # Cambios de las pantallas
├── checklists/
│   ├── requirements.md  # Calidad de la especificación
│   └── cobro.md         # Calidad de los requisitos de dinero (puerta G-04)
└── tasks.md             # Fase 2 (/speckit-tasks, aún no se crea)
```

### Código fuente (raíz del repositorio)

```text
database/
├── migrations/005_sprint5_part_prices.sql        # nuevo: columnas de parts y order_parts.unit_price
└── seeds/005_part_prices.sql                      # nuevo: precios, líneas con precio y casos de compatibilidad

server/
├── models/
│   ├── partModel.js            # columnas nuevas, búsqueda por categoría y marca, proyección con precios
│   ├── orderPartModel.js       # unit_price, importe de la línea y bandera de línea anterior
│   └── orderWorkModel.js       # totals(): suma de refacciones
├── services/
│   ├── orderTotals.js          # nuevo: importe de línea, tope del total (módulo puro)
│   ├── partService.js          # alta/edición con precios y confirmación bajo el costo
│   ├── orderPartService.js     # precio de la línea, bloqueo con pago Pagado, tope, línea anterior
│   ├── orderService.js         # proyección de líneas y totales por rol
│   ├── paymentService.js       # desglose, diferencia y aviso de desfase
│   ├── paymentRules.js         # mensaje de «nada que cobrar»
│   ├── ticketContent.js        # formato versión 2 con refacciones y subtotales
│   └── ticketService.js        # total del ticket = importe del pago
├── validators/
│   └── partValidators.js       # categoría, marca, precios y confirmBelowCost
└── tests/
    ├── unit/                   # orderTotals, partPrices, ticketContent v2
    ├── integration/            # partes con precios, líneas con precio, cobro con refacciones,
    │                           # orden pagada, aprobación tardía, ticket v2, fuga de precio, seeds
    └── contract/               # parts, orderParts, billing y tickets actualizados

client/
├── lib/
│   ├── models/                 # part.dart, order_work.dart, payment.dart, ticket.dart
│   ├── screens/                # part_form_screen, inventory_screen, part_detail_screen
│   ├── widgets/                # order_parts_section, ticket_view y el bloque de cobro
│   └── utils/ticket_printer.dart
└── test/                       # inventory_screens, order_parts, order_billing, ticket_screens, ticket_printer

docs/
├── project-context.md          # secciones 6.7, 6.10, 12 (Part) y 14.1
└── design-system.md            # corrección de los indicadores del panel y nuevos elementos
```

**Decisión de estructura**: se conserva la estructura de los sprints anteriores. No se crean tablas ni capas
nuevas; el único archivo nuevo de lógica es el módulo puro `server/services/orderTotals.js`.

## Cobertura de riesgos

| Riesgo | Cómo lo cubre el diseño | Prueba |
|--------|-------------------------|--------|
| R-01 un cambio de precio altera lo emitido | `order_parts.unit_price` como instantánea; el ticket guarda su contenido | integración: cambiar el precio y comparar orden, pago y ticket |
| R-02 pagos y tickets anteriores se alteran | migración aditiva con `unit_price = 0`; el ticket anterior no se toca | integración con los datos del seed 004 antes y después |
| R-03 se rompe el pago único vigente | no se toca el índice único; el total solo cambia de valor | las pruebas de concurrencia del Sprint 4 siguen pasando |
| R-04 pago pendiente de Mercado Pago desfasado | `amountOutdated` más aviso en el intento de cobro | integración con proveedor simulado |
| R-05 el precio de compra llega a otros roles | solo existe en las rutas de refacciones del administrador | prueba que recorre todas las rutas con cada rol y busca las claves de precio |
| R-06 redondeo | cantidad entera por precio de dos decimales, en centavos | unitarias de `orderTotals` |
| R-07 orden con solo refacciones | `assertOrderPayable` solo exige total mayor a cero | integración |
| R-08 documentación desfasada | tareas de documentación del sprint (FR-018) | revisión en el cierre |
| R-09 panel y listados | el panel sale de pagos; los listados no muestran el total | regresión del Sprint 4 |

## Seguimiento de complejidad

| Violación | Por qué se necesita | Alternativa más simple descartada porque |
|-----------|--------------------|------------------------------------------|
| Principio I: sprint posterior al MVP | Corrige una deuda declarada del MVP (el cobro no incluye refacciones) | Posponerlo deja un cobro incompleto; se resuelve con la enmienda de la constitución (H-01), que es una puerta previa a la implementación (T002) |
