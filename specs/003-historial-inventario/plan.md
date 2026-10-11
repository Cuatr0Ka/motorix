# Plan de implementación: Historial, mantenimiento e inventario (Sprint 3)

**Rama**: `003-historial-inventario` | **Fecha**: 2026-10-11 | **Especificación**: [spec.md](./spec.md)

**Entrada**: Especificación de la funcionalidad en `specs/003-historial-inventario/spec.md`

## Resumen

Extender el MVP con el historial por vehículo, el seguimiento de mantenimientos y el control de
inventario. El historial es una **vista calculada** sobre las órdenes Terminadas o Entregadas (sin
copiar datos, RN-10). El mecánico asignado registra el kilometraje del servicio y programa el
próximo mantenimiento; recepción y administración consultan la lista de mantenimientos con su
estado calculado (Normal, Próximo, Vencido). El administrador mantiene el catálogo de refacciones y
registra entradas y ajustes; el mecánico agrega refacciones a la orden y cada uso genera una salida
de inventario ligada a ella. El stock nunca queda negativo y el administrador ve alertas de stock
bajo. Flujo demostrable: finalizar servicio → verlo en historial → programar próximo mantenimiento →
usar refacciones → ver stock actualizado → ver alertas.

Enfoque técnico (detalle en [research.md](./research.md)): se reutilizan la pila y las capas de los
sprints 1 y 2 sin dependencias nuevas. La migración `003` agrega `parts`, `inventory_movements`,
`order_parts` y `maintenance`, y la columna `service_mileage` a `service_orders`. El stock se guarda
en `parts.stock` y solo cambia con una actualización condicionada (`stock >= cantidad`) dentro de la
misma transacción que inserta el movimiento, de modo que la suma de movimientos siempre coincide
con el stock y no hay carreras. Las reglas de estado de mantenimiento y de movimientos viven en
módulos puros y probados (`maintenanceStatus`, `stockRules`).

## Contexto técnico

**Lenguaje/Versión**: JavaScript (ES Modules) sobre Node.js 24 LTS en el backend; Dart con Flutter
3.47.2 en el frontend; SQL para MySQL 8.0 (sin cambios respecto a los sprints anteriores)

**Dependencias principales**: ninguna nueva.
- Backend: `express`, `mysql2`, `jsonwebtoken`, `bcryptjs`, `zod`, `cors`, `helmet`, `dotenv`
- Frontend: `provider`, `http`, `google_fonts`, `data_table_2`
- Pruebas: `jest`, `supertest` (backend); `flutter_test` (frontend)

**Almacenamiento**: MySQL 8.0 local, InnoDB, `utf8mb4`; bases `motorix` y `motorix_test`; usuario
dedicado `motorix_app`. Nueva migración `database/migrations/003_sprint3_maintenance_inventory.sql`
y nuevo seed `database/seeds/003_history_inventory.sql`. Los márgenes de aviso de mantenimiento se
leen de variables de entorno opcionales (`MAINTENANCE_WARN_DAYS`, `MAINTENANCE_WARN_KM`).

**Pruebas**: Jest (unitarias de estado de mantenimiento, reglas de stock y permisos) y Jest +
supertest (integración y contrato contra `motorix_test`, con pruebas de concurrencia de stock);
`flutter test` (proveedores y pantallas)

**Plataforma objetivo**: Aplicación de escritorio (Windows como principal) que consume la API REST
local; interfaz responsiva con prioridad en escritorio

**Tipo de proyecto**: Aplicación web/escritorio con API (frontend + backend + persistencia)

**Metas de rendimiento**: historial legible en menos de 30 s (SC-001); agregar refacción a una orden
en menos de 1 min (SC-002); listados y filtros de hasta 1 000 registros en menos de 2 s (SC-012)

**Restricciones**: ES Modules obligatorio en el backend; solo el backend accede a la base de datos;
permisos validados en el backend (incluida la pertenencia de la orden al mecánico); no se editan
scripts de sprints anteriores (los cambios a `service_orders` van en la migración 003); sin
librerías nuevas; sin secretos en el repositorio; stock negativo prohibido; seeds idempotentes con
datos de ejemplo; cumplimiento de `docs/design-system.md`

**Escala/Alcance**: 3 roles, 4 tablas nuevas y 1 columna nueva, 5 pantallas nuevas (inventario con
alertas, formulario y detalle de refacción, mantenimientos, y secciones nuevas en el detalle del
vehículo y de la orden), hasta ~1 000 refacciones, movimientos y mantenimientos

## Verificación de la constitución

*PUERTA: debe pasar antes de la Fase 0. Se vuelve a verificar tras el diseño de la Fase 1.*

| Principio | Evaluación | Cómo se cumple |
|-----------|------------|----------------|
| I. Alcance, MVP y fuente de verdad | PASA | Solo Sprint 3, después de los sprints 1 y 2; fuera de alcance excluido (FR-026). Se leyeron `docs/project-context.md` y el insumo del sprint. Los campos de `parts` y `maintenance` se ajustan a la especificación (ver "Actualizaciones de documentación") |
| II. Arquitectura separada | PASA | `client/`, `server/`, `database/`; capas en la raíz de `server/`; la lógica (stock, movimientos, estado de mantenimiento) vive en `services/`, nunca en controladores |
| III. Stack y base local | PASA | Mismo stack; migración numerada nueva sin editar las anteriores; InnoDB, llaves foráneas, `utf8mb4`; seeds idempotentes con datos suficientes; sin dependencias nuevas |
| IV. Seguridad | PASA | `authenticate` + `authorize` por ruta y verificación de pertenencia de la orden en el servicio; proyección reducida del catálogo para el mecánico; validación `zod`; errores sin trazas; sin secretos |
| V. Reglas de negocio | PASA | RN-6 (refacción siempre ligada a una orden), RN-7 (cada uso genera salida en la misma transacción), RN-8 (stock negativo imposible, también por la base), RN-10 (historial derivado), RN-11 (fecha, kilometraje o ambos), RN-12 (márgenes configurables) |
| VI. API consistente | PASA | Misma forma `{ data, meta }` / `{ error }`, códigos HTTP y manejo central de errores; contrato en [contracts/api-rest.md](./contracts/api-rest.md) |
| VII. Pruebas | PASA | Pruebas unitarias de estado de mantenimiento y reglas de stock (CA-8), integración y contrato contra `motorix_test` incluyendo concurrencia, `flutter test`; flujo de extremo a extremo en el quickstart |
| VIII. UX/UI | PASA | Material 3 con el tema propio y tokens; sin librería adicional; confirmaciones para ajustes, quitar refacciones, desactivar y marcar Atendido; estados vacío, cargando y error; chips de estado con la convención de color |

**Reevaluación tras la Fase 1**: PASA. El diseño no agrega dependencias ni rompe la separación de
capas. No hay violaciones que justificar.

## Estructura del proyecto

### Documentación (esta funcionalidad)

```text
specs/003-historial-inventario/
├── plan.md              # Este archivo (salida de /speckit-plan)
├── research.md          # Salida de la Fase 0
├── data-model.md        # Salida de la Fase 1
├── quickstart.md        # Salida de la Fase 1
├── contracts/           # Salida de la Fase 1
│   ├── api-rest.md      # Contrato de la API REST (historial, mantenimientos, refacciones)
│   └── interfaz.md      # Contrato de pantallas, navegación y permisos por rol
├── checklists/
│   └── requirements.md
└── tasks.md             # Salida de la Fase 2 (/speckit-tasks; NO lo crea /speckit-plan)
```

### Código fuente (raíz del repositorio)

Solo se listan archivos nuevos o modificados; el resto de la estructura es la de los sprints 1 y 2.

```text
database/
├── migrations/
│   └── 003_sprint3_maintenance_inventory.sql   # NUEVO
├── seeds/
│   └── 003_history_inventory.sql               # NUEVO (idempotente)
└── README.md                                   # actualizar (nuevas tablas y seed)

server/
├── config/env.js           # MODIFICADO: lectura de márgenes de aviso de mantenimiento
├── controllers/            # NUEVOS: partController, inventoryController, maintenanceController,
│                           #         orderPartController, vehicleHistoryController
├── models/                 # NUEVOS: partModel, inventoryMovementModel, orderPartModel, maintenanceModel
│                           # MODIFICADO: orderModel (service_mileage), vehicleModel (historial)
├── routes/                 # NUEVAS: partRoutes, maintenanceRoutes; orderRoutes y vehicleRoutes ampliadas;
│                           #         index.js las monta
├── services/               # NUEVOS: partService, inventoryService, orderPartService, maintenanceService,
│                           #         vehicleHistoryService, maintenanceStatus (puro), stockRules (puro)
├── validators/             # NUEVOS: partValidators, maintenanceValidators; orderValidators ampliado
└── tests/
    ├── unit/               # maintenanceStatus, stockRules, inventoryPermissions
    ├── integration/        # history, serviceMileage, maintenance.flow, parts.flow, inventory.movements,
    │                       # orderParts.flow, orderParts.concurrency, stockAlerts, seeds.sprint3
    ├── contract/           # parts.contract, inventory.contract, orderParts.contract,
    │                       # maintenance.contract, history.contract
    └── helpers/            # factories.js y seed.js ampliados (refacciones, mantenimientos)

client/lib/
├── models/                 # NUEVOS: part.dart, inventory_movement.dart, maintenance.dart, history_entry.dart
├── providers/              # NUEVOS: parts_provider, part_detail_provider, maintenance_provider,
│                           #         stock_alerts_provider, vehicle_history_provider;
│                           # MODIFICADOS: navigation_provider (secciones), order_detail_provider (refacciones)
├── screens/                # NUEVAS: inventory_screen, part_form_screen, part_detail_screen,
│                           #         maintenance_list_screen; MODIFICADAS: vehicle_detail_screen
│                           #         (historial), order_detail_screen (refacciones, kilometraje, mantenimiento),
│                           #         home_screen (alerta de stock)
├── services/               # NUEVOS: parts_service, maintenance_service; vehicles_service y
│                           # orders_service ampliados
├── widgets/                # NUEVOS: stock_chip, maintenance_chip, part_selector,
│                           #         vehicle_history_section, order_parts_section; app_shell (secciones)
└── utils/                  # status_labels.dart ampliado (estados de stock y mantenimiento)
client/test/                # pruebas de proveedores y pantallas nuevas
```

**Decisión de estructura**: se conserva la separación frontend/backend/persistencia. El inventario
se separa del uso en órdenes: `inventoryService` es el único que modifica el stock y registra
movimientos; `orderPartService` solo orquesta la línea de la orden y delega en él, de modo que
ninguna otra ruta puede alterar el stock por fuera.

## Actualizaciones de documentación

1. `docs/project-context.md` (entidades `Part`, `InventoryMovement` y `Maintenance`): el sprint usa
   los campos de la especificación (código, nombre, descripción, unidad, stock, stock mínimo, activo;
   movimiento con cantidad con signo, motivo, orden y persona; mantenimiento con descripción, fecha
   y kilometraje objetivo, orden de origen y estado). Se descartan por ahora categoría, marca y
   precios (D-12 de research). Anotarlo.
2. Registrar la tabla `order_parts` y la columna `service_orders.service_mileage` en la sección de
   tablas del Sprint 3.
3. `database/README.md`: documentar la migración y el seed del Sprint 3.
4. `.env.example`: documentar `MAINTENANCE_WARN_DAYS` y `MAINTENANCE_WARN_KM` (opcionales).

## Seguimiento de complejidad

No hay violaciones de la constitución que justificar.
