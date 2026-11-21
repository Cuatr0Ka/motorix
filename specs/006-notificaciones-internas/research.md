# Investigación (Fase 0): Notificaciones internas y clientes por avisar (Sprint 6)

**Fecha**: 2026-11-20 | **Especificación**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

La especificación no dejó marcadores abiertos: las decisiones D-01 a D-06 están resueltas en su sección
Aclaraciones. Esta investigación revisó el código existente (`server/` y `client/`) y fija las decisiones de
diseño. Cada una tiene su justificación y las alternativas descartadas.

## Hallazgos del código existente

- **Cálculos ya existentes que se reutilizan** (FR-005):
  - Mantenimientos: `maintenanceService.list({ status, indicator, page, pageSize }, actor)` con el indicador
    `computeIndicator` (`maintenanceStatus.js`) y los márgenes de `getMaintenanceConfig()` (30 días y 1 000 km).
    El panel de control ya lo usa para sus totales.
  - Stock: `partService.alerts()` (`partModel.listAlerts`: activas con `stock <= min_stock`, agotadas primero).
  - Citas y órdenes: `appointments.scheduled_at` (DATETIME), `appointments.status` (PENDIENTE, CONFIRMADA,
    EN_PROCESO, COMPLETADA, CANCELADA) y `service_orders.status` con `order_status_history(order_id, changed_at)`.
- **Autenticación**: `authenticate` consulta al usuario en la base en cada petición, así que un cambio de rol o
  una desactivación rigen de inmediato (caso límite «usuario con el rol cambiado»). `authorize(...roles)` ya
  existe; ninguna ruta nueva necesita otro mecanismo.
- **Cliente Flutter**: el encabezado es el widget `_Header` de `app_shell.dart` (nombre de sección, usuario y
  rol); `docs/design-system.md` (sección 7, «Header») ya prevé notificaciones ahí. El estado se maneja con
  `Provider`; `StockAlertsProvider` consulta al iniciar sesión, al abrir Inventario y tras cada movimiento.
- **Datos del cliente**: `clients.phone` es obligatorio (`VARCHAR(20) NOT NULL`); el caso «cliente sin teléfono»
  del spec solo ocurriría con datos antiguos o vacíos, y se cubre con una indicación en pantalla.
- **Línea base de pruebas**: la última cifra documentada es 1 215 pruebas de backend y 321 de frontend; se mide de
  nuevo en la tarea de línea base antes de tocar código.

## Decisiones

### R-01. Los avisos se calculan al consultar y se componen desde los servicios existentes

- **Decisión**: un servicio nuevo `notificationService` arma la lista llamando a `maintenanceService.list`,
  `partService.alerts` y a dos consultas nuevas de modelo (citas de hoy y órdenes detenidas). No se crea una
  tabla de avisos.
- **Justificación**: FR-003 y FR-005 piden calcular con datos reales y que los números coincidan con el panel, la
  lista de Mantenimientos y las alertas de stock; usar el mismo código lo garantiza.
- **Alternativas descartadas**: tabla de avisos generada por un proceso programado (duplica datos, se desfasa y
  exige un planificador que el proyecto no tiene); recalcular con consultas propias (los números podrían
  diferir del panel).

### R-02. Orden detenida: más de 3 días sin cambio de estado, con regla pura

- **Decisión**: una constante `STALLED_DAYS = 3` y una función pura `isStalledOrder({ status, lastChangeAt,
  today })` en `server/services/noticeRules.js`. La «última fecha de cambio» es el mayor `changed_at` del
  historial de la orden o, si no tiene historial, su `created_at`. Aplica solo a los estados abiertos RECIBIDO,
  DIAGNOSTICO, EN_REPARACION y ESPERANDO_REFACCION. Se compara por días calendario del servidor, igual que los
  mantenimientos.
- **Justificación**: D-01 fijó 3 días y excluye TERMINADO. La regla pura se prueba sin base de datos. El historial
  es la fuente más fiel: `service_orders.updated_at` cambia con cualquier edición (por ejemplo una observación) y
  daría falsos negativos.
- **Alternativas descartadas**: usar `updated_at` (se reinicia con ediciones que no son cambios de estado);
  valor configurable (queda para el Sprint 7).

### R-03. Identidad de un aviso (clave) para la lectura

- **Decisión**: cada aviso tiene una clave de texto estable: `TIPO:id` o `TIPO:id:variante`.

  | Tipo | Clave | Por qué esa forma |
  |------|-------|-------------------|
  | Mantenimiento próximo | `MAINT_UPCOMING:{maintenanceId}` | Al pasar a vencido cambia de tipo, así que es un aviso nuevo (FR-007) |
  | Mantenimiento vencido | `MAINT_OVERDUE:{maintenanceId}` | Ídem |
  | Cita del día | `APPT_TODAY:{appointmentId}` | Una cita genera un solo aviso |
  | Stock bajo | `STOCK_LOW:{partId}` | Al agotarse pasa a `STOCK_OUT`, aviso nuevo |
  | Stock agotado | `STOCK_OUT:{partId}` | Ídem |
  | Orden detenida | `STALLED:{orderId}:{lastHistoryId}` | Si la orden cambia de estado y vuelve a detenerse, la clave cambia y reaparece sin leer |

- **Justificación**: D-05 (tipo y objeto) y el escenario 5 de la historia 6 (de próximo a vencido). El último
  `lastHistoryId` (0 si no hay historial) evita que una lectura vieja oculte una detención nueva de la misma
  orden.
- **Alternativas descartadas**: clave solo por objeto (no reaparece al empeorar); clave con la fecha (cambia cada
  día y reaparecería sin motivo).

### R-04. Lectura por usuario en `notification_reads`

- **Decisión**: tabla `notification_reads (user_id, notice_key, read_at)` con llave primaria compuesta
  `(user_id, notice_key)`. Marcar como leído es `INSERT IGNORE`, así que repetirlo o hacerlo en paralelo deja una
  sola fila y no falla (FR-021). El servidor solo registra las claves que correspondan a avisos vigentes del
  usuario; las demás se ignoran sin error (caso «el aviso desapareció mientras se leía»). Las lecturas no se
  borran al desaparecer el aviso; no afectan a nadie y la tabla crece muy poco (una fila por aviso leído).
- **Justificación**: FR-006 y FR-007; es el único estado que se guarda (FR-003).
- **Alternativas descartadas**: guardar la lectura en el navegador del cliente (no persiste entre equipos ni es
  por usuario); borrar lecturas con un proceso periódico (agrega un planificador por muy poco beneficio).

### R-05. Visibilidad por rol en el servicio, no en la interfaz

- **Decisión**: `notificationService.list(actor)` decide qué tipos arma según `actor.role`: ADMIN todos; RECEPTIONIST
  mantenimientos, citas y órdenes detenidas; MECHANIC solo órdenes detenidas con `mechanic_id = actor.id`. Las
  consultas de stock ni se ejecutan para recepción y mecánico. El mecánico no recibe nombre de cliente ni teléfono.
- **Justificación**: FR-004 y la regla de que los permisos se validan en el servidor. Ejecutar solo lo permitido
  también evita trabajo innecesario.
- **Alternativas descartadas**: devolver todo y filtrar en Flutter (rompe la seguridad); una ruta por rol
  (duplica el contrato).

### R-06. Un solo endpoint de consulta y actualización cada 60 segundos

- **Decisión**: `GET /api/notifications` devuelve el total de no leídos y la lista agrupada por tipo. El cliente la
  consulta al iniciar sesión, al cambiar de sección y con un `Timer.periodic` de 60 segundos mientras la sesión
  esté abierta; el temporizador se cancela al cerrar sesión o al destruir el proveedor.
- **Justificación**: D-03. Un endpoint único es suficiente; el cálculo es barato (R-09) y no hace falta un
  `summary` aparte. El intervalo de 60 segundos cumple SC-009.
- **Alternativas descartadas**: WebSocket o eventos del servidor (fuera de alcance por el spec); un endpoint
  `summary` aparte (dos rutas para casi el mismo cálculo).

### R-07. Lista de clientes por avisar: hechos y claves

- **Decisión**: la lista se calcula con cuatro motivos. Cada aviso al cliente guarda el motivo y el identificador
  del hecho:

  | Motivo | Hecho (`fact_id`) | Condición |
  |--------|-------------------|-----------|
  | `ORDER_READY` | `service_orders.id` | Estado TERMINADO |
  | `APPT_TOMORROW` | `appointments.id` | Fecha de mañana y estado PENDIENTE o CONFIRMADA |
  | `MAINT_UPCOMING` | `maintenance.id` | Pendiente con indicador PROXIMO |
  | `MAINT_OVERDUE` | `maintenance.id` | Pendiente con indicador VENCIDO |

  La tabla `client_notices` tiene `UNIQUE (reason, fact_id)`: un mismo hecho solo se avisa una vez (FR-016), y un
  hecho nuevo (otra orden u otra cita) es otra fila (FR-017). Un cliente con dos motivos aparece dos veces, una
  por motivo (caso límite). Que un mantenimiento pase de próximo a vencido es otro motivo y, por tanto, otro
  aviso.
- **Justificación**: la unicidad en la base garantiza «un solo registro» aunque dos recepcionistas marquen a la vez
  (FR-021).
- **Alternativas descartadas**: unicidad por cliente (ocultaría hechos nuevos); guardar un contador de intentos o
  una nota (D-02 los descartó).

### R-08. Marcar como avisado: idempotente y verificado

- **Decisión**: `POST /api/client-notices` con `{ reason, factId }`. El servicio comprueba que el hecho cumple hoy
  la condición del motivo; si no, responde 409 `NOTICE_NOT_APPLICABLE`. Si ya estaba avisado (carrera entre dos
  usuarios), responde 200 con el registro existente. Si lo crea, responde 201. En ningún caso se envía un mensaje
  al cliente (FR-019): no existe integración alguna.
- **Justificación**: evita registrar avisos de hechos inexistentes y cumple la concurrencia sin error visible.
- **Alternativas descartadas**: confiar en lo que mande el cliente sin verificar (permitiría avisos falsos);
  responder 409 al duplicado (el spec pide que no haya error visible).

### R-09. Rendimiento

- **Decisión**: cada tipo de aviso se resuelve con una consulta acotada y con índices que ya existen
  (`idx_maintenance_due`, `idx_appointments_scheduled`, `idx_orders_status`,
  `idx_order_history_order (order_id, changed_at)`). La lista devuelve como máximo 50 avisos por tipo y, aparte,
  el total real de cada tipo, para que el contador sea exacto. Las órdenes detenidas se calculan con una consulta
  que une cada orden abierta con su último cambio de estado. Se verifica con una prueba de 1 000 órdenes, 1 000
  citas y 1 000 mantenimientos (SC-007, menos de 2 segundos).
- **Justificación**: FR-023. No se necesitan índices nuevos en tablas existentes; la migración solo crea las dos
  tablas nuevas.
- **Alternativas descartadas**: caché en memoria del servidor (complica la coherencia con el panel y no hace falta
  a esta escala).

### R-10. Interfaz: campana en el encabezado y sección nueva

- **Decisión**: la campana se agrega al `_Header` existente, a la izquierda del usuario, con una insignia con el
  total ("99+" si pasa de 99). Al pulsarla se abre un panel anclado (sin dependencias nuevas) con los avisos
  agrupados por tipo, un indicador por tipo (ámbar para próximo y orden detenida, rojo para vencido y stock
  agotado, según la convención de colores del sistema de diseño) y los estados de carga, vacío y error. «Clientes
  por avisar» es una sección nueva del menú para administración y recepción, con una tabla y el botón «Avisado»
  con confirmación.
- **Justificación**: FR-001, FR-010, principio VIII. Reutiliza `PanelCard`, `AppDataTable`, `state_views`,
  `ConfirmDialog` y los tokens existentes.
- **Alternativas descartadas**: pantalla completa de notificaciones (más pasos para algo que debe verse de un
  vistazo); una librería de insignias (el principio VIII limita las dependencias y no hace falta).

### R-11. Compatibilidad con la insignia de Inventario y el aviso de inicio

- **Decisión**: `StockAlertsProvider` y su banner no se modifican. El centro de notificaciones consulta el servidor
  y el stock sale de la misma función `partService.alerts()`, así que ambos no se contradicen. Tras un movimiento
  de inventario, además de refrescar las alertas de stock se refresca el centro.
- **Justificación**: FR-009.
- **Alternativas descartadas**: reemplazar `StockAlertsProvider` (riesgo de regresión sin beneficio).

### R-12. Datos de ejemplo

- **Decisión**: el seed `006_notices.sql` agrega, con fechas relativas a `CURDATE()` y sin duplicar filas al
  repetirse, al menos: un mantenimiento próximo, uno vencido, una cita de hoy, una cita de mañana, una refacción
  con stock bajo y otra agotada (las que ya existan en los seeds anteriores se reutilizan), una orden abierta con
  más de 3 días sin cambio, una orden Terminada sin entregar y un aviso al cliente ya registrado. No llama a
  ningún servicio externo.
- **Justificación**: FR-022 y la regla de que la aplicación muestre información al arrancar.

### R-13. Documentación y pruebas

- **Decisión**: actualizar `docs/project-context.md` (sección 6.12) y `docs/design-system.md` (header y una
  sección nueva de notificaciones). Pruebas: unitarias de `noticeRules`, integración y contrato contra
  `motorix_test` (permisos por rol, lectura por usuario, claves, concurrencia, rendimiento) y `flutter test`
  (modelos, proveedor con temporizador simulado, campana y sección). Se agrega un documento de aseguramiento de
  la calidad del sprint, como en el Sprint 5.
- **Justificación**: FR-024, FR-025, SC-008 y principio VII.
