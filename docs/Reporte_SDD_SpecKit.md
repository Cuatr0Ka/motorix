# Reporte individual: SDD con Spec Kit

**Entrega:** lunes 19 de octubre de 2026, antes de las 14:00 h

> Leyenda: ✅ ya tiene contenido · 🟡 falta completar o verificar · ❌ pendiente

## Datos de la entrega

| Campo | Mi respuesta |
|---|---|
| Alumno | José Adrián Mendoza Hernández |
| Equipo y proyecto | Motorix: Sistema de Gestión para Taller Mecánico. Jorge Francisco Domínguez Ramírez (Product Architect), José Adrián Mendoza Hernández (Agile Enabler), Raúl Francisco Amador, Edward Negrete Bustos, Ignacio Joaquín Trejo y Carlos Castro Rafael (Product Builder) |
| Repositorio | https://github.com/Cuatr0Ka/motorix |
| Rama | `004-pagos-tickets-dashboard` |
| Herramienta de IA | Claude Code (Anthropic) con Spec Kit (integración claude) |

**Commits de la rama (ID corto):**

| Commit | Fecha | Contenido |
|---|---|---|
| `32ee589` | 10-oct | Constitution y base del sistema, clientes, vehículos, citas y órdenes de servicio (sprints 1 y 2) |
| `a7c440a` | 11-oct | Historial, mantenimiento e inventario de refacciones (sprint 3) |
| `be83ef9` | 11-oct | Pagos, tickets de servicio y panel de control (sprint 4) |
| `735e5be` | 11-oct | Alineación del contrato y del modelo de datos con lo implementado |
| `0e4709f` | 11-oct | Renovación de la interfaz y rediseño del panel con gráficas |
| `fbf7cbd` | 12-oct | Logo de la aplicación |
| `db7bf6c` | 14-oct | Propuesta de sprints posteriores al MVP |
| `979966e` | 15-oct | Insumo del sprint 1 con requisitos en EARS |

---

## Apartado 0 — Índice de evidencias (5 pts) 🟡

Rama única `004-pagos-tickets-dashboard`, sin squash ni force-push: el historial muestra el orden real. Los enlaces con hash apuntan a la versión exacta del archivo en ese commit (`https://github.com/Cuatr0Ka/motorix/blob/<hash>/<ruta>`).

| Apartado | Evidencia | Commit |
|---|---|---|
| 1. Contexto y constitution | `.specify/memory/constitution.md` | `32ee589` |
| 2. Spec sprint 1 | `specs/001-base-clientes-vehiculos/spec.md` | `32ee589` |
| 2. Spec sprint 2 | `specs/002-citas-ordenes-servicio/spec.md` | `32ee589` |
| 2. Spec sprint 3 | `specs/003-historial-inventario/spec.md` | `a7c440a` |
| 2. Spec sprint 4 | `specs/004-pagos-tickets-dashboard/spec.md` | `be83ef9` |
| 2. Spec sprint 1 (con EARS) | `specs/001-base-clientes-vehiculos/spec.md` (FR-008 y FR-012 en EARS) | `0a387c4` |
| 2. Calidad de los specs | `specs/00X-*/checklists/requirements.md` | `32ee589`, `a7c440a`, `be83ef9` |
| 3. Plan técnico | `specs/00X-*/plan.md`, `research.md`, `contracts/` | `32ee589`, `a7c440a`, `be83ef9`; ajuste del S4 en `735e5be` |
| 4. Modelo de datos | `specs/00X-*/data-model.md` | `32ee589`, `a7c440a`, `be83ef9`, `735e5be` |
| 4. Migraciones reales | `database/migrations/001`–`004` | `32ee589` (001, 002), `a7c440a` (003), `be83ef9` (004) |
| 5. Tareas | `specs/00X-*/tasks.md` | `32ee589`, `a7c440a`, `be83ef9` |
| 5 y 6. Trazabilidad y pruebas | `docs/evidencias/trazabilidad.md` y salidas de pruebas | 🟡 commit nuevo |
| 6. Implementación | Historial de commits de `32ee589` a `be83ef9`, más `0e4709f` y `fbf7cbd` | ver apartado 6 |
| 6. Capturas y salida de pruebas | 🟡 `docs/evidencias/` | 🟡 commit nuevo |
| 7. EARS | `docs/sprints/sprint-1-base-clientes-vehiculos-ears.md` y sección «Criterios de aceptación en EARS» del spec | `979966e` y `0a387c4` |

---

## Apartado 1 — Contexto y constitution (10 pts) ✅

### Qué problema resuelve
Un taller pequeño suele llevar clientes, citas, órdenes, refacciones y cobros en cuadernos u hojas de cálculo. 🟡 (confirmar contra `docs/project-context.md` y afinar con los dolores reales: órdenes sin cobrar, refacciones que se agotan sin aviso, mantenimientos que se olvidan). Motorix junta todo en una sola aplicación.

### Proyecto
Motorix es el Sistema de Gestión para Taller Mecánico, un proyecto académico de Ingeniería en Sistemas Computacionales. Centraliza en una aplicación de escritorio (con API y MySQL local) lo que el taller llevaba a mano: clientes, vehículos, citas, órdenes de servicio, refacciones y cobros. Lo usa el personal del taller con tres roles: administrador, recepcionista y mecánico. El MVP se construye en 4 sprints: (1) base, clientes y vehículos; (2) citas y órdenes de servicio; (3) historial, mantenimiento e inventario; (4) pagos, tickets y panel de control.

### Principios de la constitution (v1.0.0, 8 principios)

| # | Principio | Qué dice | Por qué lo elegimos |
|---|---|---|---|
| I | Alcance y MVP (**no negociable**) | Se lee `docs/project-context.md` antes de cada sprint, sin funciones fuera de alcance y con los sprints en orden | Con poco tiempo el riesgo es querer hacerlo todo; obliga a tener algo funcional de punta a punta antes de sumar funciones |
| II | Arquitectura por capas (**no negociable**) | `client/`, `server/` y `database/` separados; la lógica de negocio vive en `services/`; Mercado Pago aislado en un adaptador | Cada capa se prueba y cambia sin romper las demás |
| III | Stack acotado | Flutter, Node.js con Express (ES Modules), MySQL local con scripts SQL numerados, JWT + bcrypt, usuario dedicado (nunca root) | Son tecnologías que el equipo conoce; los scripts numerados permiten recrear la base desde cero |
| IV | Seguridad (**no negociable**) | Contraseñas con hash, secretos en `.env`, permisos validados en el backend, sin datos de tarjeta | El sistema maneja datos de clientes y pagos |
| V | Reglas de negocio (**no negociable**) | Sin vehículo sin propietario ni orden sin vehículo; kilometraje de entrada; stock nunca negativo; orden entregada se conserva; todo pago pertenece a una orden | Protegen la consistencia del inventario, el historial y los cobros |
| VI | API consistente | JSON uniforme, códigos HTTP correctos, errores centralizados | Una API predecible facilita la integración con el frontend |
| VII | Pruebas | Jest y supertest contra `motorix_test`, y `flutter test` | Las reglas de estados e inventario fallan en silencio sin pruebas; la base separada evita borrar datos reales |
| VIII | Interfaz sencilla (**no negociable**) | `docs/design-system.md`, Material 3, confirmación en acciones destructivas | El personal del taller no es técnico: una pantalla clara importa más que una vistosa |

### Decisiones y gobernanza
- Resueltas en el Sprint 1: Flutter con Provider (se descartó React), `mysql2` directo sin ORM, MySQL local sin Docker, migraciones SQL numeradas e inmutables, ramas `NNN-nombre` y Conventional Commits en español.
- Enmiendas aprobadas por el equipo, coordinadas por el director del proyecto, con SemVer. Redactada el 2026-10-01; última enmienda el 2026-10-10.
- Pendiente: la ratificación formal aparece como `TODO(RATIFICATION_DATE)` en el archivo.

### Evidencia
`.specify/memory/constitution.md` (entró en `32ee589`; no ha cambiado después). Remite a `docs/project-context.md` y `docs/design-system.md`.

---

## Apartado 2 — Spec (15 pts) ✅

Un spec por sprint, en español y sin tecnología. Cada uno trae historias con prioridad, escenarios Dado / Cuando / Entonces, casos límite, requisitos (FR), criterios de éxito (SC), suposiciones y entidades clave.

| Sprint | Carpeta | Historias | Requisitos | Criterios de éxito |
|---|---|---|---|---|
| 1 | `specs/001-base-clientes-vehiculos` | 6 | 22 | 9 |
| 2 | `specs/002-citas-ordenes-servicio` | 6 | 28 | 10 |
| 3 | `specs/003-historial-inventario` | 6 | 27 | 12 |
| 4 | `specs/004-pagos-tickets-dashboard` | 4 | 29 | 12 |

### Ejemplo (Sprint 4)
- **Historia 1:** «Como recepcionista, quiero registrar el pago de una orden eligiendo cómo se cobró (efectivo, tarjeta o transferencia) para cerrar el ciclo del servicio y dejar constancia del cobro.»
- **Criterio:** «Dado una orden con un pago Pagado, cuando intento registrar otro pago, entonces el sistema lo rechaza porque la orden ya está cobrada.»
- **Criterio:** «Dado un importe distinto del total vigente, cuando intento registrar el pago, entonces el sistema lo rechaza con un mensaje que indica el total a cobrar.»
- **SC-001:** el pago de una orden se registra en menos de 1 minuto. **SC-005:** cero órdenes con dos pagos vigentes, verificado con pruebas con solicitudes simultáneas.

### Ambigüedades resueltas (`/speckit.clarify`, 5 preguntas por spec, 20 en total)
- **Sprint 1:** correo único y teléfono repetible con advertencia; la desactivación o el cambio de rol aplican de inmediato.
- **Sprint 2:** un vehículo no puede tener más de una orden abierta (FR-012); si dos personas cambian el estado a la vez, solo prospera el primero.
- **Sprint 3:** «Próximo» mantenimiento = 30 días o 1 000 km, lo que ocurra primero, configurable.
- **Sprint 4:** el total es servicios más mano de obra (las refacciones no suman); se puede entregar sin cobrar, con advertencia y confirmación.

### Versiones del spec (sprint 1)

| Versión | Qué cambió | Commit |
|---|---|---|
| Inicial (tras `/speckit.specify` y `/speckit.clarify`) | Requisitos con «DEBE», escenarios Dado / Cuando / Entonces, 5 aclaraciones incorporadas | `32ee589` |
| Con criterios EARS | FR-008 (a–d) y FR-012 (a–c) reescritos en EARS y sección «Criterios de aceptación en EARS» | `0a387c4` |

El insumo `docs/sprints/sprint-1-base-clientes-vehiculos-ears.md` (`979966e`) es la base para esa segunda versión.

### Calidad y límites
Cada sprint tiene `checklists/requirements.md`. Cada spec declara lo que queda fuera (por ejemplo FR-021 del Sprint 1 y FR-028 del Sprint 4).

**Pendientes:** los cuatro specs siguen en «Estado: Borrador». Los requisitos usan «DEBE» y los escenarios Dado / Cuando / Entonces; la versión EARS vive solo en `docs/sprints/sprint-1-base-clientes-vehiculos-ears.md`.

### Evidencia
`specs/00X-*/spec.md` y `checklists/requirements.md`. Commits `32ee589` (001 y 002), `a7c440a` (003), `be83ef9` (004). Entradas: `docs/sprints/sprint-1` a `sprint-4`.

---

## Apartado 3 — Plan técnico (15 pts) ✅

### Arquitectura y stack
- Aplicación de escritorio en tres capas: `client/` (Flutter 3.47, Dart, Material 3, Provider), `server/` (Node.js 24 LTS, Express, ES Modules) y `database/` (MySQL 8.0, InnoDB, utf8mb4).
- Backend en `config/`, `controllers/`, `models/`, `routes/`, `services/`, `middlewares/`, `validators/`, `utils/`. La lógica vive en `services/` y el acceso a datos en `models/` con `mysql2`.
- Dependencias: backend con `express`, `mysql2`, `jsonwebtoken`, `bcryptjs`, `zod`, `cors`, `helmet`, `dotenv`; frontend con `provider`, `http`, `google_fonts`, `data_table_2` y (Sprint 4) `fl_chart`, `printing`, `url_launcher`; pruebas con Jest, supertest y `flutter_test`.
- Mercado Pago queda aislado en `server/integrations/mercadoPago.js` y solo lo usa `paymentService`.

### Decisiones y alternativas descartadas (`research.md`)

| Decisión | Se descartó |
|---|---|
| S1 D-01: ES Modules con Jest | Vitest (la constitution fija Jest); transpilar a CommonJS |
| S1 D-02: `mysql2` directo | Sequelize, Prisma, Knex |
| S1 D-05: el rol se consulta en cada petición | Guardarlo en el token (no permite efecto inmediato) |
| S1 D-06: `bcryptjs` | `bcrypt` nativo (fricción de instalación), argon2 |
| S4 D-01: el total a cobrar se calcula, no se guarda | Guardarlo en la orden (se desfasa); bloquear la edición de órdenes cobradas |
| S4 D-02: un pago vigente por orden garantizado por la base (columna generada única) | Comprobarlo solo en el servicio (condición de carrera) |
| S4 D-04: Mercado Pago con `fetch` sin SDK, en un adaptador | SDK oficial |

### Coherencia con constitution y spec
Cada `plan.md` trae la tabla «Verificación de la constitución» (8 principios, antes de la investigación y tras el diseño). Las metas medibles salen del spec (p. ej. búsqueda en 1 000 registros en menos de 2 s, SC-008 del Sprint 1). Cada sprint genera `quickstart.md` y `contracts/` (`api-rest.md`, `interfaz.md`).

### Evidencia
`specs/00X-*/plan.md`, `research.md`, `contracts/`. Commits `32ee589`, `a7c440a`, `be83ef9`, `735e5be`.

---

## Apartado 4 — Base de datos (15 pts) ✅

### Modelo
MySQL 8.0, InnoDB, utf8mb4. 14 tablas de negocio en 4 migraciones, más `schema_migrations`. Cada sprint tiene `data-model.md` con tablas, columnas, restricciones, índices, transiciones de estado, diagrama y datos de ejemplo.

Relaciones: un cliente tiene varios vehículos; una cita y una orden pertenecen a un vehículo; una orden tiene servicios, mano de obra, refacciones, historial de estados, pagos y a lo sumo un ticket; las refacciones generan movimientos de inventario; un vehículo tiene mantenimientos.

### Entidades y requisitos

| Tabla(s) | Requisitos |
|---|---|
| `users` | FR-001, FR-004, FR-006 (spec 001) |
| `clients`, `vehicles` | FR-009 a FR-012 (spec 001) |
| `appointments` | FR-001 a FR-006 (spec 002) |
| `service_orders`, `order_status_history` | FR-007 a FR-012, FR-017, FR-019, FR-021 (spec 002) |
| `order_services`, `order_labor` | FR-016 (spec 002) |
| `parts`, `inventory_movements`, `order_parts` | FR-010 a FR-017 (spec 003) |
| `maintenance` | FR-005 a FR-009 (spec 003) |
| `payments` | FR-002 a FR-007 (spec 004) |
| `tickets` | FR-012 a FR-014 (spec 004) |

### Restricciones relevantes
- Todas las llaves foráneas son `ON DELETE RESTRICT`.
- `payments`: columna generada `active_order_id` con índice UNIQUE (un solo pago vigente por orden); `CHECK (amount > 0)`; solo Mercado Pago puede estar Pendiente, Rechazado o Cancelado; sin número de tarjeta, vencimiento ni código de seguridad.
- `tickets`: `UNIQUE` en `order_id` e instantánea del contenido.

### Evidencia
`specs/00X-*/data-model.md`; `database/migrations/001_sprint1_users_clients_vehicles.sql`, `002_sprint2_appointments_service_orders.sql`, `003_sprint3_maintenance_inventory.sql`, `004_sprint4_payments_tickets.sql`; `database/seeds/` y `database/README.md`. Commits `32ee589`, `a7c440a`, `be83ef9`, `735e5be`.

---

## Apartado 5 — Tareas (10 pts) ✅

- Cada sprint tiene `tasks.md` con tareas numeradas (T001…), pequeñas y con archivo exacto. Fases: Preparación, Fundamentos (bloqueante), una por historia según prioridad y Pulido final.
- Marcadores `[P]` (paralelizable) y `[US1]`… (historia). Las pruebas van antes de la implementación.
- Tareas terminadas: 108 + 88 + 77 + 70 = **343**, ninguna pendiente.
- Cada `tasks.md` cierra con «Dependencias y orden de ejecución» (en el Sprint 1: la Fase 2 bloquea todo; US1 va primero; US6 depende de US5 y US3; US4 de US3).
- **Limitación:** la trazabilidad es por historia, no por requisito (casi ninguna tarea cita un FR).
- **Análisis:** no se conservó evidencia de haber ejecutado `/speckit.analyze`. La consistencia se revisó con la tabla de verificación de la constitución y los checklists de calidad.

**Evidencia:** `specs/00X-*/tasks.md` con casillas `[X]`. Commits `32ee589`, `a7c440a`, `be83ef9`.

---

## Apartado 6 — Implementación y verificación (20 pts) 🟡

> Qué commits implementan qué tareas, cómo se comprobó contra los criterios del spec y qué no cumple todavía. El detalle requisito → tarea → commit → prueba está en `docs/evidencias/trazabilidad.md`; la salida de las pruebas en `docs/evidencias/pruebas-backend-jest.txt` y `docs/evidencias/pruebas-frontend-flutter.txt`.

### 6.1 Commits ↔ tareas

| Commit | Sprint | Tareas terminadas | Qué implementa |
|---|---|---|---|
| `32ee589` | 1 | 108 (`specs/001-.../tasks.md`) | Constitution, base, autenticación, usuarios, clientes y vehículos |
| `32ee589` | 2 | 88 (`specs/002-.../tasks.md`) | Citas y órdenes de servicio |
| `a7c440a` | 3 | 77 (`specs/003-.../tasks.md`) | Historial, mantenimiento e inventario de refacciones |
| `be83ef9` | 4 | 70 (`specs/004-.../tasks.md`) | Pagos, tickets y panel de control |
| `735e5be` | 4 | — | Alineación del contrato y del modelo de datos con lo implementado |
| `0e4709f` | 4 | — | Renovación de la interfaz y rediseño del panel con gráficas |
| `fbf7cbd` | 4 | — | Logo de la aplicación |

Total: 343 tareas, ninguna pendiente. Los sprints 1 y 2 entraron juntos en un solo commit; cada sprint lleva su `tasks.md` en el mismo commit que su código.

### 6.2 Demostración con capturas
Una captura por criterio, con el ID de la historia y del criterio. Sprint(s) elegido(s) para la demo: 🟡 (sugerido: sprint 4 y sprint 1).

| Criterio | Captura |
|---|---|
| 🟡 Panel con 4 indicadores y gráfica (US del S4, SC) | `docs/evidencias/…png` |
| 🟡 Pago rechazado en una orden ya cobrada (S4, US1) | |
| 🟡 Bloqueo de cuenta tras 5 intentos fallidos (S1, FR-008) | |
| 🟡 Vehículo sin propietario rechazado (S1, FR-012) | |

### 6.3 Verificación contra los criterios

| Criterio (spec) | ¿Cumple? | Evidencia |
|---|---|---|
| FR-008a a FR-008d (S1): rechazo de cuenta desactivada, mensaje genérico, bloqueo tras 5 fallos y 15 min, contador a cero | Sí | `server/tests/integration/auth.flow.test.js` |
| FR-012a a FR-012c (S1): propietario obligatorio y existente | Sí | `vehicles.flow.test.js`, `vehicles.owner.test.js` y `vehicles.contract.test.js` |
| Historia 1 (S4): segundo pago vigente e importe distinto rechazados | Sí | `server/tests/integration/payments.flow.test.js` |
| SC-005 (S4): cero órdenes con dos pagos vigentes con solicitudes simultáneas | Sí | `server/tests/integration/payments.concurrency.test.js` |
| SC-001 (S4): pago en menos de 1 minuto | Parcial | Sin medición con una persona; solo hay pruebas automáticas del flujo |
| SC-003 y SC-004 (S1): tiempos y primer intento de personas de prueba | Parcial | Sin sesión de usabilidad registrada |

### 6.4 Resultado de las pruebas (ejecutadas el 2026-10-17)
- **Backend** (`npm test`, Jest + supertest contra `motorix_test`): 67 suites y 1 003 pruebas aprobadas, 0 fallas.
- **Frontend** (`flutter test`): 277 pruebas aprobadas, 0 fallas.
- Salidas completas en `docs/evidencias/`.

### 6.5 Análisis de consistencia
🟡 Ejecutar `/speckit.analyze` y guardar el resultado en `docs/evidencias/`; así el apartado 5 deja de depender de la tabla de verificación de la constitución.

### 6.6 Lo que todavía no cumple
- Los cuatro specs siguen en «Borrador».
- EARS aplicado solo a FR-008 y FR-012 del spec del sprint 1 (`0a387c4`); el resto de los requisitos y los otros tres specs siguen con «DEBE».
- SC-001 del sprint 4 y SC-003 y SC-004 del sprint 1 no tienen medición con personas.
- Faltan las capturas de la aplicación (sección 6.2).

---

## Apartado 7 — EARS y reflexión (10 pts + hasta 5 extra) ✅

### Qué es EARS
Easy Approach to Requirements Syntax: plantillas fijas para que cada requisito diga una sola cosa y se pueda probar (condición, sistema, DEBERÁ, respuesta observable). Cinco patrones: ubicuo, por evento (CUANDO), por estado (MIENTRAS), comportamiento no deseado (SI… ENTONCES) y opcional (DONDE); se pueden combinar. Su ventaja: obliga a decir quién responde y qué se puede medir, y de cada requisito sale una prueba.

### Requisito 1: inicio de sesión (spec 001, FR-008)
**Antes:** «El sistema DEBE rechazar el inicio de sesión de cuentas desactivadas y mostrar, ante credenciales inválidas, un mensaje que no revele cuál dato falló. Tras 5 intentos fallidos consecutivos, el sistema DEBE bloquear la cuenta durante 15 minutos e informarlo con un mensaje claro; un acceso correcto reinicia el contador.»
*Problema:* junta cuatro comportamientos, mezcla sujetos y no aclara cuándo ocurre cada uno.

**Después (EARS):**
- a) SI la cuenta está desactivada, ENTONCES el backend DEBERÁ rechazar el inicio de sesión. *(no deseado)*
- b) SI el usuario o la contraseña son incorrectos, ENTONCES el backend DEBERÁ rechazar el inicio de sesión con un mensaje en español que no indique cuál dato falló. *(no deseado)*
- c) CUANDO una cuenta acumule 5 intentos fallidos consecutivos, el backend DEBERÁ bloquearla durante 15 minutos e informarlo con un mensaje claro. *(evento; medible: 5 intentos, 15 minutos)*
- d) CUANDO una cuenta inicie sesión correctamente, el backend DEBERÁ reiniciar su contador de intentos fallidos a cero. *(evento)*

### Requisito 2: propietario del vehículo (spec 001, FR-012)
**Antes:** «Todo vehículo DEBE estar asociado a un cliente existente como propietario; el sistema DEBE rechazar vehículos sin propietario o con propietario inexistente.»
*Problema:* no dice quién rechaza ni qué ve el usuario, y junta dos errores distintos.

**Después (EARS):**
- a) SI se intenta registrar un vehículo sin propietario, ENTONCES el backend DEBERÁ rechazar la operación. *(no deseado)*
- b) SI el propietario indicado no existe, ENTONCES el backend DEBERÁ rechazar la operación con un mensaje de error en español. *(no deseado)*
- c) CUANDO un usuario autorizado registre un vehículo con datos válidos y un propietario existente, el backend DEBERÁ crear el vehículo asociado a ese cliente. *(evento)*

El requisito 2 coincide con FR-022 a FR-024 de `docs/sprints/sprint-1-base-clientes-vehiculos-ears.md`. El requisito 1 se redactó para este reporte y aún no está en ese archivo.

### Dónde y cuándo se aplicará
- **Dónde:** en «Requisitos funcionales» y en los escenarios de `specs/001-base-clientes-vehiculos/spec.md`, empezando por FR-008 y FR-012. Los escenarios Dado / Cuando / Entonces se conservan y se complementan con EARS.
- **Cuándo:** hecho el 17 de octubre de 2026 en el commit `0a387c4` (commit nuevo, sin reescribir el historial), para FR-008 y FR-012. El resto de los requisitos del spec sigue con «DEBE». Después, el Sprint 5 de `docs/sprints/propuesta-sprints-post-mvp.md` se redactará con EARS desde `/speckit.specify`.

### Reflexión
- **Qué cambié del spec:** los requisitos eran «El sistema DEBE…» y juntaban varias reglas (p. ej. FR-008). Al pasarlos a EARS los separé por evento o error, indiqué si responde backend o frontend y dejé datos medibles. Las aclaraciones de `/speckit.clarify` cerraron ambigüedades antes de planear (bloqueo de cuentas, cuentas desactivadas).
- **Trabajar con IA:** acelera specs, planes y tareas, pero solo funciona bien con contexto claro; sin constitution ni documento de alcance inventa o se adelanta. Lo importante es revisar lo generado contra el spec. El orden spec → plan → tareas → implementación evita retrabajo.
- **Limitación honesta:** el `spec.md` del sprint 1 tiene en EARS solo FR-008 y FR-012 (commit `0a387c4`); los demás requisitos siguen con «DEBE» y su versión completa en EARS está en el insumo `docs/sprints/sprint-1-base-clientes-vehiculos-ears.md`.

### Bono EARS
Commit `979966e` (15-oct-2026): «docs(sprints): agregar insumo del sprint 1 con requisitos en ears». Agrega `docs/sprints/sprint-1-base-clientes-vehiculos-ears.md` con 30 requisitos (FR-001 a FR-030) en EARS. Ya está en `origin/004-pagos-tickets-dashboard`.

---

## Pendientes para cerrar

1. **Apartado 6** completo: commits ↔ tareas, capturas, verificación criterio por criterio, pruebas ejecutadas.
2. ✅ `docs/evidencias/trazabilidad.md` y salidas de pruebas creadas; falta hacer commit y tomar las capturas (6.2).
3. Ejecutar `/speckit.analyze` y guardar el resultado.
4. ✅ EARS en FR-008 y FR-012 del sprint 1 (`0a387c4`). Opcional: extender EARS al resto de los requisitos del spec.
5. Afinar el problema que resuelve Motorix (apartado 1) con `docs/project-context.md`.
6. Con los commits nuevos, completar el índice y comprobar que los enlaces con hash abran.
7. Decidir formato de entrega: este `.md` en la rama, o PDF/documento.
