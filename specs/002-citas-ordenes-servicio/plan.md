# Plan de implementación: Citas y órdenes de servicio (Sprint 2)

**Rama**: `002-citas-ordenes-servicio` | **Fecha**: 2026-10-10 | **Especificación**: [spec.md](./spec.md)

**Entrada**: Especificación de la funcionalidad en `specs/002-citas-ordenes-servicio/spec.md`

## Resumen

Extender el MVP del Sprint 1 con la gestión de citas y órdenes de servicio. Recepción registra
citas, recibe el vehículo, crea la orden (desde una cita o directa), valida el kilometraje de
entrada y asigna un mecánico; el mecánico consulta únicamente sus órdenes, registra diagnóstico,
servicios, mano de obra, observaciones y recomendaciones, y avanza el estado siguiendo la secuencia
`RECIBIDO → DIAGNOSTICO → EN_REPARACION → TERMINADO → ENTREGADO` (con `ESPERANDO_REFACCION`). La
entrega la registra recepción o administración. El flujo demostrable es: registrar cita → recibir
vehículo → crear orden → asignar mecánico → diagnóstico → servicios → actualizar estado → terminar.

Enfoque técnico (detalle en [research.md](./research.md)): se reutilizan sin cambios la pila y las
capas del Sprint 1 (Express en ES Modules, `mysql2` sin ORM, `zod`, Provider en Flutter). La
migración `002` agrega `appointments`, `service_orders`, `order_services`, `order_labor` y
`order_status_history`. Las reglas que no pueden fallar por concurrencia (una sola orden abierta
por vehículo, una sola cita activa por vehículo y horario, una orden por cita) se refuerzan con
índices únicos en la base. Las transiciones de estado viven en un módulo puro y probado
(`orderTransitions`), y cada cambio es atómico mediante una actualización condicionada al estado
previo.

## Contexto técnico

**Lenguaje/Versión**: JavaScript (ES Modules) sobre Node.js 24 LTS en el backend; Dart con Flutter
3.47.2 en el frontend; SQL para MySQL 8.0 (sin cambios respecto al Sprint 1)

**Dependencias principales**: ninguna nueva.
- Backend: `express`, `mysql2`, `jsonwebtoken`, `bcryptjs`, `zod`, `cors`, `helmet`, `dotenv`
- Frontend: `provider`, `http`, `google_fonts`, `data_table_2`
- Pruebas: `jest`, `supertest` (backend); `flutter_test` (frontend)

**Almacenamiento**: MySQL 8.0 local, InnoDB, `utf8mb4`; bases `motorix` y `motorix_test`; usuario
dedicado `motorix_app`. Nueva migración `database/migrations/002_sprint2_appointments_service_orders.sql`
y nuevo seed `database/seeds/002_appointments_orders.sql`.

**Pruebas**: Jest (unitarias de transiciones, permisos y reglas de kilometraje) y Jest + supertest
(integración y contrato contra `motorix_test`); `flutter test` (proveedores y pantallas)

**Plataforma objetivo**: Aplicación de escritorio (Windows como principal) que consume la API REST
local; interfaz responsiva con prioridad en escritorio

**Tipo de proyecto**: Aplicación web/escritorio con API (frontend + backend + persistencia)

**Metas de rendimiento**: creación de cita en menos de 2 min y de orden en menos de 3 min para
quien la captura (SC-001, SC-002); listados y filtros de hasta 1 000 registros en menos de 2 s
(SC-010); mecánico identifica sus órdenes en menos de 10 s (SC-007)

**Restricciones**: ES Modules obligatorio en el backend; solo el backend accede a la base de datos;
permisos validados en el backend (incluida la pertenencia de la orden al mecánico); no se editan
scripts del Sprint 1; sin librerías nuevas; sin secretos en el repositorio; seeds idempotentes con
datos de ejemplo; cumplimiento de `docs/design-system.md`

**Escala/Alcance**: 3 roles, 5 tablas nuevas, 6 pantallas nuevas (listado, formulario y detalle de
citas; listado, formulario y detalle de órdenes), hasta ~1 000 citas y órdenes

## Verificación de la constitución

*PUERTA: debe pasar antes de la Fase 0. Se vuelve a verificar tras el diseño de la Fase 1.*

| Principio | Evaluación | Cómo se cumple |
|-----------|------------|----------------|
| I. Alcance, MVP y fuente de verdad | PASA | Solo Sprint 2, después del Sprint 1; fuera de alcance excluido (FR-028). Se leyeron `docs/project-context.md` y el insumo del sprint. Se añade la tabla auxiliar `order_status_history` por FR-021 (ver "Actualizaciones de documentación") |
| II. Arquitectura separada | PASA | `client/`, `server/`, `database/`; capas en la raíz de `server/`; la lógica (transiciones, kilometraje, asignación, sincronización cita-orden) vive en `services/`, nunca en controladores |
| III. Stack y base local | PASA | Mismo stack; migración numerada nueva sin editar la 001; InnoDB, llaves foráneas, `utf8mb4`; seeds idempotentes con datos suficientes; sin dependencias nuevas |
| IV. Seguridad | PASA | `authenticate` + `authorize` por ruta y verificación de pertenencia de la orden en el servicio; validación `zod`; errores sin trazas; sin secretos (el hash del segundo mecánico es bcrypt) |
| V. Reglas de negocio | PASA | RN-2 (vehículo existente), RN-3 (kilometraje de entrada obligatorio), RN-4 (no baja sin corrección explícita registrada), RN-5 (solo roles autorizados modifican), RN-9 (entregada es historial; sin operación de borrado), RN-15 (permisos en backend) |
| VI. API consistente | PASA | Misma forma `{ data, meta }` / `{ error }`, códigos HTTP y manejo central de errores del Sprint 1; contrato en [contracts/api-rest.md](./contracts/api-rest.md) |
| VII. Pruebas | PASA | Pruebas unitarias de transiciones (CA-8), integración y contrato contra `motorix_test`, `flutter test`; la historia no se da por terminada sin flujo de extremo a extremo |
| VIII. UX/UI | PASA | Material 3 con el tema propio y tokens; sin librería adicional; confirmaciones para cancelar cita, entregar orden y corregir kilometraje; estados vacío, cargando y error; chips de estado con la convención de color |

**Reevaluación tras la Fase 1**: PASA. El diseño no agrega dependencias ni rompe la separación de
capas. No hay violaciones que justificar.

## Estructura del proyecto

### Documentación (esta funcionalidad)

```text
specs/002-citas-ordenes-servicio/
├── plan.md              # Este archivo (salida de /speckit-plan)
├── research.md          # Salida de la Fase 0
├── data-model.md        # Salida de la Fase 1
├── quickstart.md        # Salida de la Fase 1
├── contracts/           # Salida de la Fase 1
│   ├── api-rest.md      # Contrato de la API REST (citas, órdenes, mecánicos)
│   └── interfaz.md      # Contrato de pantallas, navegación y permisos por rol
├── checklists/
│   └── requirements.md
└── tasks.md             # Salida de la Fase 2 (/speckit-tasks; NO lo crea /speckit-plan)
```

### Código fuente (raíz del repositorio)

Solo se listan archivos nuevos o modificados; el resto de la estructura es la del Sprint 1.

```text
database/
├── migrations/
│   └── 002_sprint2_appointments_service_orders.sql   # NUEVO
├── seeds/
│   └── 002_appointments_orders.sql                   # NUEVO (idempotente)
└── README.md                                         # actualizar (nuevas tablas y seed)

server/
├── controllers/            # NUEVOS: appointmentController, orderController, mechanicController
├── models/                 # NUEVOS: appointmentModel, orderModel, orderWorkModel (servicios/mano de obra/historial)
├── routes/                 # NUEVOS: appointmentRoutes, orderRoutes, mechanicRoutes; index.js los monta
├── services/               # NUEVOS: appointmentService, orderService, orderWorkService, orderTransitions (módulo puro)
├── validators/             # NUEVOS: appointmentValidators, orderValidators
├── utils/                  # orderFolio.js (formato y lectura de folio)
└── tests/
    ├── unit/               # orderTransitions, orderPermissions, mileageRule, orderFolio
    ├── integration/        # appointments.flow, orders.create, orders.assign, orders.work, orders.status, orders.mechanicScope, seeds2
    ├── contract/           # appointments.contract, orders.contract, orders.work.contract, mechanics.contract
    └── helpers/            # factories.js y seed.js ampliados (citas, órdenes, segundo mecánico)

client/lib/
├── models/                 # NUEVOS: appointment.dart, service_order.dart, order_work.dart
├── providers/              # NUEVOS: appointments_provider, orders_provider, order_detail_provider; navigation_provider (secciones)
├── screens/                # NUEVAS: appointments_list/form/detail, orders_list/form/detail; home_screen (accesos)
├── services/               # NUEVOS: appointments_service, orders_service
├── widgets/                # NUEVOS: status_chip, mechanic_selector, vehicle_selector; app_shell (íconos de secciones)
└── utils/                  # status_labels.dart (etiquetas y colores por estado)
client/test/                # pruebas de proveedores y pantallas nuevas
```

**Decisión de estructura**: se conserva la separación frontend/backend/persistencia del Sprint 1.
El trabajo de la orden (servicios, mano de obra, historial) se separa del núcleo de la orden en
`orderWorkService` y `orderWorkModel` para mantener los archivos acotados.

## Actualizaciones de documentación

1. `docs/project-context.md` §12 deja abierto si los totales se almacenan o se calculan. Se decide
   **calcularlos** a partir de `order_services` y `order_labor` (research D-11); anotarlo en §12.
2. Registrar en `docs/project-context.md` (Sprint 2) la tabla auxiliar `order_status_history` y
   los registros de corrección de kilometraje, necesarios para FR-021 y FR-009.
3. `database/README.md`: documentar la migración y el seed del Sprint 2.

## Seguimiento de complejidad

No hay violaciones de la constitución que justificar.
