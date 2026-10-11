# Plan de implementación: Base del sistema, clientes y vehículos (Sprint 1)

**Rama**: `001-base-clientes-vehiculos` | **Fecha**: 2026-10-10 | **Especificación**: [spec.md](./spec.md)

**Entrada**: Especificación de la funcionalidad en `specs/001-base-clientes-vehiculos/spec.md`

## Resumen

Construir desde cero la base del MVP de Motorix: estructura del repositorio, base de datos MySQL
local con esquema versionado y datos de ejemplo, API REST con autenticación por token y
autorización por rol, y una aplicación de escritorio con los módulos de Inicio, Clientes,
Vehículos y Usuarios. El flujo demostrable es: iniciar sesión → registrar cliente → registrar
vehículo asociado → consultar el cliente con sus vehículos.

Enfoque técnico (detalle en [research.md](./research.md)): backend Node.js con Express en ES
Modules y capas separadas (`services/` concentra la lógica de negocio); acceso a datos con
`mysql2` sin ORM; validación con `zod`; JWT + `bcryptjs`; rol y estado del usuario consultados
en cada petición; frontend Flutter con Material 3, tema propio y Provider.

## Contexto técnico

**Lenguaje/Versión**: JavaScript (ES Modules) sobre Node.js 24 LTS en el backend; Dart con Flutter
3.47.2 en el frontend; SQL para MySQL 8.0

**Dependencias principales**:
- Backend: `express`, `mysql2`, `jsonwebtoken`, `bcryptjs`, `zod`, `cors`, `helmet`, `dotenv`
- Frontend: `provider`, `http`, `google_fonts`, `data_table_2` (compatible con Flutter 3.47)
- Pruebas: `jest`, `supertest` (backend); `flutter_test` (frontend)

**Almacenamiento**: MySQL 8.0 local, InnoDB, `utf8mb4`; bases `motorix` y `motorix_test`; usuario
dedicado `motorix_app`

**Pruebas**: Jest (unitarias) y Jest + supertest (integración y contrato contra `motorix_test`);
`flutter test` (proveedores y widgets)

**Plataforma objetivo**: Aplicación de escritorio (Windows como principal) que consume la API
REST local; interfaz responsiva con prioridad en escritorio

**Tipo de proyecto**: Aplicación web/escritorio con API (frontend + backend + persistencia)

**Metas de rendimiento**: Inicio de sesión hasta la pantalla de Inicio en menos de 10 s (SC-001);
búsqueda en listados de hasta 1 000 registros en menos de 2 s (SC-008)

**Restricciones**: ES Modules obligatorio en el backend; solo el backend accede a la base de
datos; permisos validados en el backend; sin secretos en el repositorio; MySQL local sin Docker;
sin ORM; sin librería complementaria de componentes de UI; cumplimiento de
`docs/design-system.md`

**Escala/Alcance**: 3 roles, 3 tablas de negocio, 4 módulos de pantalla, hasta ~1 000 clientes y
vehículos, usuarios en el orden de decenas

## Verificación de la constitución

*PUERTA: debe pasar antes de la Fase 0. Se vuelve a verificar tras el diseño de la Fase 1.*

| Principio | Evaluación | Cómo se cumple |
|-----------|------------|----------------|
| I. Alcance, MVP y fuente de verdad | PASA | Solo Sprint 1; fuera de alcance excluido (FR-021). Se lee `docs/project-context.md`. Dos discrepancias documentales anotadas en la sección "Actualizaciones de documentación" |
| II. Arquitectura separada | PASA | `client/`, `server/`, `database/`; capas del backend en la raíz de `server/`; la lógica vive en `services/` |
| III. Stack y base local | PASA | Flutter, Node LTS, Express, MySQL local, JWT + bcrypt, ESM con `"type": "module"`, migraciones y seeds en `database/`, variables `DB_*`, usuario `motorix_app`, InnoDB, FK, `utf8mb4`, seeds idempotentes con datos de ejemplo |
| IV. Seguridad | PASA | Contraseñas con hash; `.env` ignorado y `.env.example` sin secretos; permisos validados en el backend; entradas validadas; errores sin trazas |
| V. Reglas de negocio | PASA | Vehículo exige propietario existente; kilometraje no baja sin corrección explícita (cualquier edición de vehículo) |
| VI. API consistente | PASA | JSON uniforme, códigos HTTP apropiados, middlewares de autenticación y autorización, validación de cuerpos, manejo de errores centralizado |
| VII. Pruebas | PASA | Jest + supertest contra `motorix_test`; pruebas de lógica de permisos y negocio; `flutter test` |
| VIII. UX/UI | PASA | Material 3 con `ThemeData` propio y tokens; sin librería adicional; confirmaciones obligatorias; estados vacío, cargando y error |

**Reevaluación tras la Fase 1**: PASA. El diseño no introduce dependencias fuera de lo permitido ni
rompe la separación de capas. No hay violaciones que justificar.

## Estructura del proyecto

### Documentación (esta funcionalidad)

```text
specs/001-base-clientes-vehiculos/
├── plan.md              # Este archivo (salida de /speckit-plan)
├── research.md          # Salida de la Fase 0
├── data-model.md        # Salida de la Fase 1
├── quickstart.md        # Salida de la Fase 1
├── contracts/           # Salida de la Fase 1
│   ├── api-rest.md      # Contrato de la API REST
│   └── interfaz.md      # Contrato de pantallas, navegación y permisos por rol
├── checklists/
│   └── requirements.md
└── tasks.md             # Salida de la Fase 2 (/speckit-tasks; NO lo crea /speckit-plan)
```

### Código fuente (raíz del repositorio)

```text
database/
├── migrations/
│   └── 001_sprint1_users_clients_vehicles.sql
├── seeds/
│   └── 001_initial_data.sql
├── scripts/
│   ├── crear-entorno.ps1          # crea bases y usuario motorix_app
│   ├── aplicar-migraciones.ps1    # idempotente, registra en schema_migrations
│   ├── aplicar-seeds.ps1          # idempotente
│   └── reiniciar-local.ps1        # recrea la base desde cero
└── README.md

server/
├── package.json                   # "type": "module"
├── app.js                         # construye la aplicación Express (sin escuchar)
├── server.js                      # arranque y puerto
├── config/                        # env.js, db.js
├── controllers/                   # auth, users, clients, vehicles
├── models/                        # acceso a datos con mysql2
├── routes/
├── services/                      # lógica de negocio
├── middlewares/                   # authenticate, authorize, validate, errorHandler
├── validators/                    # esquemas zod
├── utils/                         # AppError, respuestas, normalizadores
└── tests/
    ├── unit/
    ├── integration/
    └── contract/

client/
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── models/
│   ├── screens/                   # login, inicio, clientes, vehículos, usuarios
│   ├── widgets/                   # layout con sidebar, diálogos, tablas, estados
│   ├── services/                  # cliente HTTP de la API
│   ├── providers/                 # sesión, sidebar, listados
│   └── utils/                     # app_theme.dart, tokens
└── test/

docs/                              # ya existe
.env.example
.gitignore
README.md
```

**Decisión de estructura**: aplicación con frontend y backend separados más una carpeta de
persistencia, tal como exige el Principio II. El backend no usa carpeta `src/` intermedia
(decisión ya registrada en la constitución).

## Actualizaciones de documentación

Discrepancias detectadas entre documentos que deben corregirse junto con la implementación
(Principio I: mantener `docs/project-context.md` alineado):

1. `docs/project-context.md` §27 anota `lucide_icons_flutter` como set de íconos "pendiente de
   confirmación"; la aclaración de esta funcionalidad fijó el set estándar de Material. Actualizar
   §27 y la fila de íconos de `docs/design-system.md` (§3 y §12).
2. `docs/project-context.md` §11 muestra `server/src/`; la constitución fija capas directamente en
   `server/`. Alinear §11.
3. `docs/project-context.md` §27 define un bloqueo de cuenta tras 5 intentos fallidos durante
   15 minutos que no aparece en la especificación. El plan lo contempla (ver research.md, D-09);
   conviene añadirlo como requisito en `spec.md` (por ejemplo, una extensión de FR-008) antes de
   generar tareas.

## Seguimiento de complejidad

No hay violaciones de la constitución que justificar.
