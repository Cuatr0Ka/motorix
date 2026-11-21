# Investigación (Fase 0): Reportes, configuración, términos y seguridad (Sprint 7)

**Fecha**: 2026-11-21 | **Especificación**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

La especificación no tiene marcadores abiertos: las decisiones D-01 a D-12 están resueltas en su sección Aclaraciones.
Esta investigación revisó el código existente (`server/` y `client/`) y fija las decisiones de diseño con su
justificación y las alternativas descartadas.

## Hallazgos del código existente

- **Configuración**: `getShopConfig()` y `getMaintenanceConfig()` (`server/config/env.js`) son **síncronas** y leen
  `.env`. Se usan en `ticketService.js` (datos del taller), `maintenancePresenter.js`, `maintenanceService.js` y
  `clientNoticeService.js` (márgenes). `presentMaintenance` se llama también desde `orderService.js` y
  `vehicleHistoryService.js`.
- **Ticket**: `buildTicketContent` ya guarda en `tickets.content` una instantánea JSON del taller, el cliente, el
  vehículo y los importes (`formatVersion: 2`), así que **los datos del taller de un ticket emitido ya no cambian**
  aunque cambie la configuración.
- **Contraseñas**: `server/utils/passwordPolicy.js` exige hoy 8 caracteres con mayúscula, minúscula y número; la usan
  `userService.assertPasswordPolicy` (alta y edición) y `authService.changePassword`. El cliente repite la regla en
  `client/lib/utils/password_policy.dart`.
- **Sesión**: `authenticate` consulta al usuario en la base en **cada** petición (confirma que sigue activo y toma su
  rol vigente); el token dura 8 horas (`getJwtConfig`). No existe ninguna noción de inactividad. El cliente guarda el
  token solo en memoria (`SessionProvider`) y no tiene endpoint de cierre de sesión.
- **Bloqueo por intentos fallidos**: `userModel.registerFailedAttempt` y `authService.login` (5 fallos, 15 minutos).
- **Servicios de la orden**: `order_services` (`description`, `amount`) y `order_labor`; las líneas de servicio son
  texto libre y no tienen tipo. El próximo mantenimiento se programa con `POST /api/orders/:id/maintenance`.
- **Datos de los reportes**: `payments` (`amount`, `method`, `status`, `paid_at`), `order_services`, `order_labor`,
  `order_parts` (`quantity`, `unit_price` desde el Sprint 5), `parts` (`purchase_price`, `sale_price`, `stock`),
  `inventory_movements` (`type`, `quantity`, `created_at`) y `order_status_history` (fecha en que una orden quedó
  Terminada).
- **Cambios de precios, usuarios y pagos**: `partService.update(id, fields)`, `userService.create/update` y
  `paymentService.cancel(id)` **no reciben quién actúa**; hay que pasarles el actor para la bitácora.
- **Cliente Flutter**: no hay dependencia para guardar archivos, pero ya están `url_launcher` y `dart:io`. El
  `FakeApi` de pruebas devuelve 404 a toda ruta desconocida.
- **Línea base de pruebas**: 1 349 de backend (97 suites) y 373 de frontend del 2026-11-20; se mide de nuevo en la
  primera tarea.

## Decisiones

### R-01. Configuración en una tabla clave-valor leída bajo demanda

- **Decisión**: tabla `settings (setting_key, setting_value, updated_by, updated_at)` y un `settingsService` con
  funciones **asíncronas** `getShop()` y `getMaintenanceMargins()` que leen la base en cada llamada. El valor guardado
  gana; si no hay, se usa el de `.env`; si tampoco, el predeterminado (FR-003). Los consumidores obtienen los márgenes
  **una vez por petición** y se los pasan a `presentMaintenance` (que deja de leer `.env` y recibe `margins` como
  parámetro).
- **Justificación**: una lectura por consulta es barata y evita estados desfasados entre procesos y entre pruebas
  (que reinician la base). El cambio es mecánico: 5 puntos de llamada.
- **Alternativas descartadas**: caché en memoria con invalidación (riesgo de datos viejos tras reiniciar la base en
  pruebas y de complejidad); una tabla con columnas fijas (obliga a una migración por cada ajuste nuevo).

### R-02. Los datos del taller de un ticket ya emitido no cambian por la instantánea existente

- **Decisión**: `ticketService.generate` toma el taller de `settingsService.getShop()` y lo guarda en `content`, como
  hoy. No se agrega ninguna tabla ni columna para esto.
- **Justificación**: FR-002 y FR-017 ya se cumplen por diseño; solo cambia la fuente de los datos.
- **Alternativas descartadas**: guardar el taller en una columna aparte del ticket (duplica la instantánea).

### R-03. Catálogo de tipos de servicio y enlace opcional a las líneas

- **Decisión**: tabla `service_types` (`name` único, `interval_days`, `interval_km`, `active`) con la restricción de
  que al menos uno de los dos intervalos sea mayor a cero, y columna nueva `order_services.service_type_id`
  (nullable, llave foránea con `ON DELETE RESTRICT`). Un tipo no se borra (solo se desactiva); las líneas anteriores
  quedan con `NULL`.
- **Justificación**: D-09 y FR-005/FR-006. La migración es aditiva (una tabla y una columna con valor nulo por
  omisión).
- **Alternativas descartadas**: enlazar por texto (frágil); obligar el tipo en cada línea (rompe órdenes existentes).

### R-04. Propuesta del próximo mantenimiento calculada en el servidor

- **Decisión**: `GET /api/orders/:id/maintenance/suggestion` devuelve `{ dueDate, dueMileage, basedOn }`. Toma los
  tipos de servicio con intervalo de las líneas de la orden y propone **el intervalo más corto** de cada eje: la
  fecha es la fecha de hoy más los días y el kilometraje es el del servicio (o el actual del vehículo) más los
  kilómetros. Sin tipos con intervalo, responde `204`. La interfaz solo rellena el formulario existente; la
  persona corrige antes de guardar y la validación de `POST .../maintenance` no cambia.
- **Justificación**: FR-007; la regla vive en un módulo puro y probado (`serviceIntervals`).
- **Alternativas descartadas**: guardar la propuesta (se desactualiza); calcularla en Flutter (la regla de negocio
  debe estar en `services/`).

### R-05. «Próximo servicio» en el ticket: formato versión 3

- **Decisión**: `buildTicketContent` agrega `nextService: { dueDate, dueMileage, description }` y sube a
  `formatVersion: 3` **solo cuando** la orden tiene un mantenimiento pendiente propio (el que se programó desde esa
  orden); si no lo tiene, no agrega el campo. Los tickets anteriores (versión 1 y 2) no se tocan y se muestran como
  se emitieron. La vista y la impresión del cliente leen el campo cuando existe.
- **Justificación**: FR-016 y FR-017; sigue el patrón del Sprint 5 (`formatVersion` 2).
- **Alternativas descartadas**: recalcular el próximo servicio al consultar el ticket (cambiaría un ticket emitido).

### R-06. Reportes: agregados en SQL, importes en centavos y rango validado

- **Decisión**: cinco consultas de lectura (`income`, `services`, `productivity`, `parts`, `rotation`) en
  `reportModel.js` con agregados en SQL y `SUM(ROUND(amount * 100))` para operar en **centavos enteros**; el servicio
  las presenta como cadenas con dos decimales. Un módulo puro `reportRules` valida el rango (`from` y `to` en
  `AAAA-MM-DD`, `to >= from`, máximo 366 días) y calcula los extremos del día con la fecha local del servidor.
  - **Ingresos**: pagos `PAGADO` con `paid_at` en el rango, por método y por día.
  - **Servicios y productividad**: órdenes cuya fecha de «Terminada» (último `order_status_history` a `TERMINADO`)
    cae en el rango; servicios por frecuencia (por tipo si lo tienen, por descripción si no) y, por mecánico,
    órdenes terminadas e importe de mano de obra; las órdenes sin mecánico no se atribuyen a nadie.
  - **Refacciones**: líneas de esas órdenes; costo con el precio de compra **actual** de la refacción (el precio de
    compra no se guarda por línea), precio con `unit_price` de la línea; sin costo (nulo o cero) se señala «Sin
    costo» y no entra en el margen total.
  - **Rotación**: salidas (`OUT`) del rango sobre la existencia promedio, con la existencia al inicio y al final
    reconstruida desde los movimientos; promedio cero devuelve rotación nula.
- **Justificación**: FR-009 a FR-013, D-05 a D-08. Los agregados en SQL con los índices existentes (`idx_payments_status`,
  `idx_order_history_order`, `idx_order_parts_order`) cumplen el SC-006 sin tablas de estadísticas (RN-10).
- **Alternativas descartadas**: tablas de resumen precalculadas (duplican datos y se desfasan); calcular en Node con
  todas las filas (lento con 1 000 órdenes).

### R-07. Exportación CSV por el mismo endpoint, sin dependencias

- **Decisión**: cada reporte acepta `?format=csv` y responde `text/csv; charset=utf-8` con `Content-Disposition`
  (`reporte-ingresos-2026-11-01_2026-11-30.csv`). Un módulo puro `csv.js` arma el texto: marca de orden de bytes
  UTF-8, separador coma, comillas dobles escapadas, saltos `\r\n`, importes con punto y dos decimales y fechas
  `AAAA-MM-DD`. Una celda de texto que empieza con `=`, `+`, `-` o `@` se antepone con una comilla simple para evitar
  la ejecución de fórmulas al abrirla en una hoja de cálculo.
- **Justificación**: D-01; el contenido sale de la **misma función** que la pantalla, así que coincide al centavo
  (SC-004). La protección contra fórmulas es una medida de seguridad de la información (FR-029).
- **Alternativas descartadas**: Excel o PDF (librerías nuevas, prohibidas sin justificar por la constitución).

### R-08. Guardar el CSV en el cliente sin dependencias nuevas

- **Decisión**: el cliente descarga el CSV con `ApiClient` y lo escribe con `dart:io` en la carpeta de descargas del
  usuario (`USERPROFILE\Downloads` en Windows; `HOME/Downloads` en otros), con el nombre que indica el servidor. Muestra
  el mensaje «Archivo guardado en [ruta]» con el botón **Abrir carpeta**, que usa `url_launcher`. Si la carpeta no
  existe o no se puede escribir, muestra el error y no pierde el reporte.
- **Justificación**: la app es de escritorio y no hay selector de archivos en las dependencias permitidas.
- **Alternativas descartadas**: `file_picker` o `path_provider` (dependencias nuevas).

### R-09. Términos y condiciones: texto fijo versionado y aceptación por usuario

- **Decisión**: tablas `terms_versions` (`version`, `title`, `body`, `published_at`) y `terms_acceptances`
  (`user_id`, `terms_version_id`, `accepted_at`, única por usuario y versión). La migración 007 inserta la versión
  `1.0` con el texto (uso permitido, confidencialidad de los datos de clientes y vehículos, responsabilidad de las
  cuentas personales y aviso de privacidad); una versión nueva se agrega en una migración posterior. La vigente es la
  de mayor `published_at`. Endpoints: `GET /api/terms/current`, `POST /api/terms/accept` y
  `GET /api/terms/acceptances` (solo ADMIN).
- **Justificación**: D-02 y FR-018 a FR-022. Sin editor en la aplicación no hay pantalla de edición ni validaciones de
  texto largo.
- **Alternativas descartadas**: editor en la aplicación (más pantallas y pruebas); guardar el texto en un archivo del
  cliente (el servidor no podría registrar qué versión se aceptó).

### R-10. Aceptación validada en el servidor dentro de `authenticate`

- **Decisión**: `authenticate` ya consulta al usuario en cada petición; ahí mismo se comprueba que haya una
  aceptación de la versión vigente (una consulta indexada). Sin aceptación, responde `403 TERMS_NOT_ACCEPTED` (con la
  versión vigente en `details`), **salvo** `GET /api/terms/current`, `POST /api/terms/accept` y `GET /api/auth/me`.
  Cerrar sesión no necesita ruta (el token vive en memoria del cliente). El cliente, al iniciar sesión, pide
  `/terms/current` y, si `accepted` es falso, muestra la pantalla de aceptación; si recibe `TERMS_NOT_ACCEPTED` en
  medio de una sesión (versión nueva), la vuelve a mostrar.
- **Justificación**: FR-021 («no solo la pantalla»); el punto único evita olvidar una ruta.
- **Alternativas descartadas**: un middleware aparte por router (se podría omitir en una ruta nueva); validar solo en
  el cliente.

### R-11. Bitácora de auditoría de solo inserción

- **Decisión**: tabla `audit_log` (`actor_user_id` nullable, `action`, `entity_type`, `entity_id`, `summary`,
  `created_at`) y un `auditService.record({ actor, action, entityType, entityId, summary })` que se llama **después**
  de cada acción sensible y no interrumpe la operación si falla (se avisa en el registro de errores del servidor).
  Acciones: `LOGIN_FAILED`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGED`, `USER_CREATED`, `USER_DEACTIVATED`,
  `USER_ACTIVATED`, `USER_ROLE_CHANGED`, `SETTINGS_CHANGED`, `SERVICE_TYPE_CHANGED`, `PART_PRICE_CHANGED`,
  `PAYMENT_CANCELLED` y `TERMS_ACCEPTED`. El `summary` se arma con datos permitidos (nombre de usuario, rol anterior
  y nuevo, nombre de la refacción, precio anterior y nuevo, folio de la orden), **nunca** contraseñas, hashes, tokens
  ni datos de tarjeta, y en un inicio de sesión fallido **no** se guarda el texto que se tecleó (podría ser una
  contraseña escrita en el campo de usuario): solo el usuario si existe. No hay rutas de edición ni de borrado. Se
  consulta con `GET /api/audit-log` (ADMIN), filtros `from`, `to`, `userId` y `action`, paginada.
- **Justificación**: FR-023 a FR-025 y SC-007. Una prueba revisa que ninguna fila contenga cadenas reservadas.
- **Alternativas descartadas**: registrar dentro de la misma transacción de cada acción (acopla todos los servicios y
  una falla de la bitácora cancelaría una operación válida); un trigger de base de datos (oculta la lógica).

### R-12. Política de contraseñas de 10 caracteres

- **Decisión**: `PASSWORD_MIN_LENGTH` pasa de 8 a 10 en `passwordPolicy.js` y en `password_policy.dart`; el resto de la
  regla (mayúscula, minúscula y número) no cambia. Se aplica donde ya se aplicaba (alta de usuario, edición con
  contraseña y cambio de contraseña propia). Las contraseñas ya guardadas siguen valiendo y las cuentas sembradas no
  se obligan a cambiarla (D-12). Las pruebas que usaban contraseñas de 8 o 9 caracteres se actualizan y se registran
  en el aseguramiento (SC-011).
- **Justificación**: FR-026; es un cambio de una constante con sus pruebas.
- **Alternativas descartadas**: obligar el cambio al siguiente ingreso (fuera del alcance y rompe cuentas sembradas).

### R-13. Cierre por inactividad validado en el servidor y con aviso en el cliente

- **Decisión**: columna nueva `users.last_activity_at` (nullable). `authenticate` rechaza con `401 SESSION_INACTIVE` si
  la última actividad fue hace más de 30 minutos y, si no, la actualiza **como máximo una vez por minuto**
  (`UPDATE ... WHERE last_activity_at IS NULL OR last_activity_at < NOW() - INTERVAL 60 SECOND`). El inicio de sesión
  la fija en ese momento. `NULL` se trata como activa (sesiones anteriores a la migración). El cliente agrega un
  `InactivityGuard` alrededor del `AppShell`: observa punteros y teclado, avisa a los 28 minutos con un diálogo y
  cuenta regresiva («Seguir conectado»), cierra la sesión a los 30 y, mientras la persona trabaja, consulta
  `GET /api/auth/me` como máximo cada 5 minutos para que el servidor vea la actividad de la interfaz.
- **Justificación**: FR-027 y CA-23 («validada en backend»). Con solo el temporizador del cliente, cerrar la ventana de
  otra forma o usar la API directamente evadiría el control.
- **Alternativas descartadas**: solo temporizador en Flutter (no es seguridad); tokens de vida corta con
  renovación (más piezas y rompe el esquema actual).

### R-14. No exposición de datos y entradas hostiles probadas

- **Decisión**: dos pruebas transversales: (1) un recorrido por los endpoints de usuarios, refacciones, órdenes, pagos,
  tickets, configuración, reportes y bitácora con los tres roles que busca en todo el JSON las claves
  `password`, `passwordHash`, `password_hash`, `token` y el precio de compra donde no corresponde; (2) un recorrido por
  los campos de búsqueda de clientes, vehículos, citas, órdenes, refacciones, usuarios, mantenimientos y pagos con
  cargas de inyección (`' OR '1'='1`, `%`, `_`, `\`, `--`, `; DROP TABLE`) que comprueba que no hay errores 500, que
  no se devuelven filas de más y que las tablas siguen intactas.
- **Justificación**: FR-028 y FR-029; hoy el código usa consultas parametrizadas y `likePattern`, y la prueba lo deja
  garantizado.
- **Alternativas descartadas**: confiar en la revisión manual.

### R-15. Interfaz: cuatro secciones nuevas para el administrador y dos pantallas transversales

- **Decisión**: secciones del menú solo para ADMIN: **Configuración** (datos del taller, márgenes y catálogo de tipos de
  servicio, en pestañas), **Reportes** (ingresos, servicios y productividad, refacciones y rotación, con selector de
  periodo y botón **Exportar CSV**), **Bitácora** y **Términos** (versión vigente y aceptaciones). La pantalla de
  aceptación de términos aparece tras iniciar sesión (y cuando el servidor lo exige); el formulario de servicio de la
  orden suma un selector opcional de tipo; el formulario de próximo mantenimiento suma «Usar el intervalo del
  servicio»; el ticket muestra «Próximo servicio». Todo sigue `docs/design-system.md`, sin dependencias nuevas
  (`fl_chart` ya existe para las barras del reporte de ingresos).
- **Justificación**: FR-001 a FR-020; reutiliza `PageHeader`, `AppDataTable`, `ConfirmDialog`, `state_views` y los tokens.
- **Alternativas descartadas**: una sola pantalla con todo (demasiado larga); gráficas nuevas (fuera de alcance).

### R-16. Compatibilidad: cuentas existentes, pruebas y datos de ejemplo

- **Decisión**: (1) la migración 007 deja a **todos** los usuarios existentes sin aceptación, así que deben aceptar en su
  siguiente ingreso (D-12); (2) los ayudantes de pruebas (`createUser`, `createUserWithToken`) registran la aceptación
  de la versión vigente para que las pruebas anteriores no reciban `403`, y `resetDatabase` borra las aceptaciones y
  la bitácora pero **conserva** `terms_versions` y la versión 1.0; (3) las pruebas de seeds que inician sesión con
  cuentas sembradas aceptan los términos primero; (4) el `FakeApi` del cliente responde `/terms/current` con
  `accepted: true`. Todo cambio de pruebas se registra en el aseguramiento (SC-011). El seed 007 agrega la
  configuración inicial y los tipos de servicio; no toca órdenes, pagos ni tickets existentes.
- **Justificación**: FR-030 y FR-032; sin esto, el 100 % de las pruebas con sesión fallaría por un cambio de contrato
  declarado.
- **Alternativas descartadas**: desactivar la aceptación en el entorno de pruebas (la prueba ya no cubriría la regla).

### R-17. Documentación y orden de entrega

- **Decisión**: actualizar `docs/project-context.md` (nuevas secciones de configuración, reportes, términos y
  seguridad, y las entidades) y `docs/design-system.md` (secciones nuevas), y `.env.example` indicando que
  `SHOP_*` y `MAINTENANCE_WARN_*` quedan como valor de respaldo. Orden de las tareas (D-04): fundamentos, configuración
  y catálogo, ticket, términos, seguridad y, al final, reportes y exportación.
- **Justificación**: FR-031 y D-04.
