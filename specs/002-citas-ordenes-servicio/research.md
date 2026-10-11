# Investigación: Citas y órdenes de servicio (Sprint 2)

**Fecha**: 2026-10-10

No quedan marcadores `NEEDS CLARIFICATION`. La pila (Node.js + Express ESM, `mysql2`, `zod`, JWT,
Flutter + Provider, Jest + supertest) está fijada por la constitución y el Sprint 1; este documento
registra las decisiones de diseño propias del Sprint 2.

## D-01. Una sola orden abierta por vehículo, garantizada por la base

- **Decisión**: columna generada almacenada `open_vehicle_id = IF(status = 'ENTREGADO', NULL, vehicle_id)`
  con índice `UNIQUE`. MySQL permite varios `NULL` en un índice único, de modo que las órdenes
  entregadas no estorban. El servicio comprueba antes para dar un mensaje claro y traduce el error
  `ER_DUP_ENTRY` a `OPEN_ORDER_EXISTS` (carrera entre dos recepcionistas).
- **Justificación**: aclaración 1 y FR-012. La comprobación en el servicio sola tiene una condición
  de carrera; el índice es la última línea de defensa (mismo criterio que D-08 del Sprint 1).
- **Alternativas**: solo comprobar en el servicio (rechazada: carrera); bloqueo de filas con
  `SELECT … FOR UPDATE` sobre el vehículo (se usa además para el kilometraje, pero no sustituye al
  índice).

## D-02. Una cita activa por vehículo y horario, y una orden por cita

- **Decisión**: `appointments.active_vehicle_id = IF(status IN ('CANCELADA','COMPLETADA'), NULL, vehicle_id)`
  como columna generada, con índice único `(active_vehicle_id, scheduled_at)`. `service_orders.appointment_id`
  lleva índice `UNIQUE` (admite varios `NULL`, para órdenes sin cita).
- **Justificación**: FR-006 (cita duplicada del vehículo en el mismo horario) y entidad "Cita"
  (a lo sumo una orden). Libera el horario al cancelar o completar la cita.
- **Alternativas**: validar solo en el servicio (rechazada: carrera).

## D-03. Modelo de estados de la orden como módulo puro

- **Decisión**: `services/orderTransitions.js` exporta la tabla de transiciones y funciones puras
  (`allowedNext(status)`, `assertTransition(from, to)`, `canActorTransition({ role, userId, order, to })`).
  Sin acceso a la base ni a Express.
- **Transiciones**: `RECIBIDO→DIAGNOSTICO`, `DIAGNOSTICO→EN_REPARACION`, `EN_REPARACION→TERMINADO`,
  `TERMINADO→ENTREGADO`, `DIAGNOSTICO→ESPERANDO_REFACCION`, `EN_REPARACION→ESPERANDO_REFACCION`,
  `ESPERANDO_REFACCION→EN_REPARACION`. Cualquier otra se rechaza (`INVALID_TRANSITION` con la lista
  de permitidas).
- **Justificación**: CA-5 y CA-8; la lógica más sensible del sprint se prueba sin base de datos.
- **Alternativas**: validar dentro del servicio con condicionales (rechazada: difícil de probar y
  de mantener).

## D-04. Cambio de estado atómico y concurrencia

- **Decisión**: dentro de una transacción, `UPDATE service_orders SET status = ? WHERE id = ? AND status = ?`
  (estado leído). Si `affectedRows = 0`, otra persona cambió la orden: se responde `409 STATE_CONFLICT`
  con el estado vigente. En la misma transacción se inserta el registro de `order_status_history` y,
  si aplica, se sincroniza la cita. El cliente reintenta tras ver el estado actual.
- **Justificación**: aclaración 5 (solo prospera el primer cambio) sin bloqueos largos.
- **Alternativas**: `SELECT … FOR UPDATE` (válida pero más acoplada); columna de versión
  (rechazada: innecesaria con la comparación del estado).

## D-05. Autorización de dos niveles

- **Decisión**: `authorize(...)` por ruta controla el rol. La pertenencia (mecánico asignado) se
  verifica en el servicio con la orden cargada. Una orden ajena responde `404 NOT_FOUND` al
  mecánico, igual que si no existiera, para no revelar datos (CA-3). Las operaciones de trabajo y
  estado permiten al ADMIN sobre cualquier orden.
- **Justificación**: FR-014, FR-020, FR-022, Principio IV. El rol vigente viene de `authenticate`
  (consulta por petición del Sprint 1).
- **Alternativas**: filtrar solo en el listado (rechazada: permitiría leer por identificador).

## D-06. Lista de mecánicos asignables

- **Decisión**: `GET /api/mechanics` (ADMIN, RECEPTIONIST) devuelve solo `{ id, name, username }` de
  usuarios activos con rol `MECHANIC`. No se abre `/api/users` (exclusivo del administrador).
- **Justificación**: recepción necesita elegir mecánico sin acceso a la gestión de usuarios.
- **Alternativas**: abrir `/users` en lectura a recepción (rechazada: expone correo y estados).

## D-07. Kilometraje de entrada y corrección explícita

- **Decisión**: en el alta de la orden, dentro de una transacción con `SELECT … FOR UPDATE` sobre el
  vehículo: si `vehicles.current_mileage` no es nulo y el kilometraje de entrada es menor, se
  responde `422 MILEAGE_DECREASE` salvo que lleguen `mileageCorrection: true` y
  `mileageCorrectionReason` (mínimo 5 caracteres). La corrección se guarda en la orden
  (`mileage_correction`, `mileage_correction_reason`). Después se actualiza `vehicles.current_mileage`.
  Si el vehículo no tiene valor, se acepta cualquier entero entre 0 y 2 000 000.
- **Justificación**: RN-3, RN-4, FR-009, FR-010; reutiliza el código `MILEAGE_DECREASE` del Sprint 1.
- **Alternativas**: reutilizar `mileageCorrection` solo como booleano (rechazada: la corrección debe
  quedar registrada con motivo).

## D-08. Folio legible

- **Decisión**: el folio se deriva del identificador: `OS-` + id con ceros a la izquierda (6
  dígitos), por ejemplo `OS-000012`. No se guarda columna; se calcula al leer y la búsqueda por
  folio acepta `OS-12`, `os-000012` o `12`.
- **Justificación**: único y estable sin una secuencia aparte ni una columna extra que pueda
  desincronizarse; una columna generada no puede depender de `AUTO_INCREMENT`.
- **Alternativas**: columna `folio` rellenada tras insertar (rechazada: dos pasos y riesgo de nulos).

## D-09. Sincronización de citas con órdenes

- **Decisión**: al crear una orden desde una cita Pendiente o Confirmada, la cita pasa a
  `EN_PROCESO` en la misma transacción; cuando la orden llega a `TERMINADO`, la cita pasa a
  `COMPLETADA`. No se permite crear una orden desde una cita en otro estado
  (`APPOINTMENT_NOT_AVAILABLE`).
- **Justificación**: FR-011; mantiene un solo origen de verdad del avance.
- **Alternativas**: sincronizar con una tarea diferida (rechazada: inconsistencias transitorias).

## D-10. Zonas horarias y fechas de las citas

- **Decisión**: `scheduled_at` es `DATETIME` en la hora local del servidor (un solo taller, una sola
  zona horaria). La API recibe y devuelve ISO 8601; el servicio compara con la hora actual para
  rechazar fechas pasadas con un margen de 1 minuto por desfase de reloj.
- **Justificación**: coherente con `created_at` del Sprint 1 y con un uso local; evita conversiones
  innecesarias.
- **Alternativas**: `TIMESTAMP`/UTC (rechazada: sin beneficio para un taller de una sola sede).

## D-11. Importes y totales

- **Decisión**: importes en `DECIMAL(10,2)`, no negativos, máximo 9 999 999.99. Los totales
  (servicios, mano de obra y total) se **calculan** al leer la orden con `SUM`; no se guardan.
  La API devuelve los importes como cadenas decimales (`"1250.00"`) para no perder precisión, y el
  cliente los formatea.
- **Justificación**: `docs/project-context.md` §12 deja la decisión a este sprint; calcular evita
  inconsistencias al editar o quitar líneas (FR-016).
- **Alternativas**: columnas de total almacenadas (rechazada: riesgo de desincronización).

## D-12. Historial de cambios de estado

- **Decisión**: tabla `order_status_history` (orden, estado anterior, nuevo, usuario, fecha). La
  creación de la orden registra la entrada inicial (sin estado anterior).
- **Justificación**: FR-021. Es una tabla auxiliar dentro del alcance del sprint (trazabilidad del
  estado), no una función nueva.
- **Alternativas**: solo guardar la fecha del último cambio (rechazada: no cumple FR-021).

## D-13. Listados, búsqueda y orden

- **Decisión**: mismas convenciones del Sprint 1 (`page`, `pageSize`, `search`, `likePattern`,
  `limitOffset`). Citas: orden por fecha ascendente; filtros `status`, `from`, `to`; búsqueda por
  nombre del cliente o placa. Órdenes: orden por id descendente; filtros `status`, `mechanicId`;
  búsqueda por folio, cliente o placa. Índices en `appointments(scheduled_at)`, `appointments(status)`,
  `service_orders(status)` y `service_orders(mechanic_id, status)`.
- **Justificación**: SC-010 (menos de 2 s con 1 000 registros) y coherencia de la API.
- **Alternativas**: búsqueda de texto completo (rechazada: sobredimensionada).

## D-14. Listado por defecto del mecánico

- **Decisión**: para el rol `MECHANIC`, `GET /api/orders` fuerza `mechanicId` al del solicitante e
  ignora el que envíe; si no se indica `status`, excluye `ENTREGADO`. Con `status=ENTREGADO` las
  muestra.
- **Justificación**: aclaración 3 y CA-3.
- **Alternativas**: dos endpoints (rechazada: duplica rutas y pruebas).

## D-15. Seeds idempotentes con fechas

- **Decisión**: `database/seeds/002_appointments_orders.sql` inserta con `INSERT … SELECT … WHERE NOT EXISTS`,
  usando claves naturales independientes de la fecha: citas por (placa del vehículo, motivo) y
  órdenes por (placa, problema reportado). Las fechas se calculan relativas a `NOW()` solo al
  insertar, de modo que repetir el seed no vuelve a insertar y no desplaza lo ya sembrado. Se agrega
  un segundo mecánico (`mecanico2`) con hash bcrypt de la contraseña del estándar del MVP,
  `INSERT IGNORE` por usuario/correo. Se siembra al menos una orden por estado del flujo (cada una
  en un vehículo distinto, por la regla de una orden abierta) y dos entregadas.
- **Justificación**: FR-026, SC-009; constitución, Principio III.
- **Alternativas**: fechas fijas (rechazada: quedarían en el pasado y las citas no se verían como
  próximas).

## D-16. Pruebas de la lógica de transiciones y permisos

- **Decisión**: pruebas unitarias exhaustivas de `orderTransitions` (matriz de las 6 × 6 transiciones
  entre estados, y permisos por rol y pertenencia); pruebas de integración del flujo completo con
  los tres roles; pruebas de contrato por endpoint (forma de la respuesta, validación, 401 y 403).
- **Justificación**: CA-8, SC-004, SC-005 y Principio VII.
- **Alternativas**: pruebas solo de integración (rechazada: más lentas y menos exhaustivas).

## D-17. Navegación y pantallas del cliente

- **Decisión**: se amplía `AppSection` con `appointments` («Citas»), `orders` («Órdenes») y
  `myOrders` («Mis órdenes»). `sectionsFor(role)`: ADMIN y RECEPTIONIST ven Inicio, Clientes,
  Vehículos, Citas y Órdenes (+ Usuarios el ADMIN); MECHANIC ve Inicio, Clientes, Vehículos y Mis
  órdenes. Los chips de estado usan la convención de color del sistema de diseño (verde completado,
  ámbar espera/advertencia, neutro en curso, rojo cancelado).
- **Justificación**: FR-027 y constitución, Principio VIII.
- **Alternativas**: una sola sección «Órdenes» para todos (rechazada: el mecánico necesita un
  acceso explícito a las suyas, SC-007).
