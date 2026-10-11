# Investigación: Historial, mantenimiento e inventario (Sprint 3)

**Fecha**: 2026-10-11

No quedan marcadores `NEEDS CLARIFICATION`. La pila (Node.js + Express ESM, `mysql2`, `zod`, JWT,
Flutter + Provider, Jest + supertest) está fijada por la constitución y los sprints anteriores; este
documento registra las decisiones de diseño propias del Sprint 3.

## D-01. El historial es una vista calculada, no una tabla

- **Decisión**: el historial de un vehículo es una consulta sobre `service_orders` con estado
  `TERMINADO` o `ENTREGADO`, unida a sus servicios, mano de obra, refacciones, mecánico y
  mantenimientos programados desde cada orden. No existe tabla `history`.
- **Justificación**: RN-10 pide derivar el historial sin duplicar información; la orden ya guarda
  todo. Al pasar a Terminado aparece de inmediato (historia 1, escenario 4) sin pasos adicionales.
- **Alternativas**: tabla derivada poblada al terminar la orden (rechazada: duplica datos y puede
  quedar desfasada); vista SQL (rechazada: el equipo no versiona vistas y la consulta con agregados
  es más clara en un modelo del backend).

## D-02. El estado del mantenimiento se calcula, no se almacena

- **Decisión**: `services/maintenanceStatus.js` exporta funciones puras
  (`computeIndicator({ dueDate, dueMileage, currentMileage, today, warnDays, warnKm })`) que devuelven
  `VENCIDO`, `PROXIMO` o `NORMAL`. Es Vencido si `dueDate < today` o `currentMileage >= dueMileage`;
  Próximo si `dueDate - today <= warnDays` o `dueMileage - currentMileage <= warnKm`; en otro caso
  Normal. Solo se evalúan las condiciones que el mantenimiento tiene definidas. Un mantenimiento
  Atendido no tiene indicador.
- **Justificación**: el kilometraje actual del vehículo cambia con cada orden; un estado guardado
  quedaría obsoleto. Función pura → pruebas sin base de datos (CA-8, SC-007).
- **Fecha de referencia**: se compara contra la fecha local del servidor (día calendario); una
  fecha objetivo igual a hoy es Próximo, no Vencido (vence al terminar el día).
- **Filtro y orden en la lista**: el filtro por estado se resuelve en SQL con expresiones
  equivalentes a la función pura para paginar bien; una prueba de integración comprueba que ambas
  coinciden con los datos de ejemplo.
- **Alternativas**: columna `status` actualizada por un trabajo programado (rechazada: añade un proceso
  que no existe en el MVP).

## D-03. Márgenes de aviso configurables por entorno

- **Decisión**: `MAINTENANCE_WARN_DAYS` (30) y `MAINTENANCE_WARN_KM` (1 000) leídos en `config/env.js`
  con esos valores por defecto; son opcionales. Se validan como enteros positivos.
- **Justificación**: aclaración 1 y RN-12 (configurables, sin valores universales). No son secretos y
  evitan una pantalla de configuración que el MVP no pide. El sistema no impone intervalos de
  mantenimiento: la fecha y el kilometraje objetivo los captura quien programa.
- **Alternativas**: tabla `settings` con pantalla (rechazada: fuera de alcance); constantes en el
  código (rechazada: no son configurables).

## D-04. Un solo mantenimiento pendiente por vehículo, garantizado por la base

- **Decisión**: columna generada almacenada `pending_vehicle_id = IF(status = 'PENDIENTE', vehicle_id, NULL)`
  con índice `UNIQUE`. Al programar uno nuevo, el servicio marca como `ATENDIDO` los pendientes
  anteriores del vehículo dentro de la misma transacción.
- **Justificación**: spec FR-006 (el nuevo reemplaza al anterior). Mismo patrón que `open_vehicle_id`
  del Sprint 2: el índice es la última defensa ante dos programaciones simultáneas.
- **Alternativas**: permitir varios pendientes (rechazada: contradice la especificación).

## D-05. Stock como columna y movimientos con cantidad con signo

- **Decisión**: `parts.stock` guarda el stock actual y `inventory_movements.quantity` es un entero
  **con signo** (Entrada > 0, Salida < 0, Ajuste ≠ 0). Invariante: `stock = SUM(quantity)` por
  refacción. Solo `inventoryService` modifica ambos, en una transacción.
- **Justificación**: FR-013 (el stock siempre es la suma de los movimientos) y rendimiento de listados
  y alertas sin agregar miles de filas. Una prueba de integración verifica la invariante tras cada
  escenario (SC-006).
- **Alternativas**: calcular el stock con `SUM` en cada consulta (rechazada: lenta para listados y
  alertas); guardar solo magnitud y tipo (rechazada: el ajuste necesita signo).

## D-06. Stock nunca negativo: cuatro defensas

- **Decisión**: (1) `stockRules` (módulo puro) valida cantidades y calcula la diferencia de un ajuste;
  (2) la actualización es condicionada: `UPDATE parts SET stock = stock + :delta WHERE id = :id AND stock + :delta >= 0`
  y si no afecta filas se responde `INSUFFICIENT_STOCK` con el stock vigente; (3) la fila de la
  refacción se bloquea con `SELECT … FOR UPDATE` dentro de la transacción; (4) la columna es
  `INT UNSIGNED` con `CHECK (stock >= 0)`.
- **Justificación**: RN-8, FR-016, SC-005 y el caso límite de dos mecánicos simultáneos.
- **Bloqueo y orden**: siempre se bloquea primero la orden y después la refacción, para evitar
  interbloqueos.
- **Alternativas**: solo validar en el servicio (rechazada: carrera); permitir negativo con
  advertencia (rechazada por la aclaración del sprint).

## D-07. Uso en órdenes: línea única por refacción y movimientos compensatorios

- **Decisión**: `order_parts` tiene índice único `(order_id, part_id)`. Agregar suma a la línea
  existente; corregir fija la cantidad nueva; quitar elimina la línea. Cada operación inserta un
  movimiento ligado a la orden: Salida por el aumento, Entrada ("Devolución a inventario") por la
  disminución o por quitar la línea. Las operaciones aceptan la orden en cualquier estado hasta
  `TERMINADO`; en `ENTREGADO` responden `ORDER_READ_ONLY`.
- **Justificación**: aclaración 2, FR-014 a FR-018 y RN-6/RN-7. Los movimientos son inmutables, así
  que las correcciones dejan rastro.
- **Alternativas**: una fila por cada uso (rechazada: viola "sin duplicar renglones"); borrar los
  movimientos al quitar (rechazada: los movimientos no se eliminan).

## D-08. Ajuste por conteo

- **Decisión**: el ajuste recibe `countedQuantity` y `reason`; el servicio calcula
  `delta = countedQuantity - stock` bajo bloqueo de fila, rechaza `delta = 0` y guarda el movimiento
  `ADJUSTMENT` con ese delta. La cantidad contada debe ser un entero ≥ 0.
- **Justificación**: aclaración 5. Con el bloqueo, un uso concurrente no falsea el conteo: el delta se
  calcula contra el stock vigente.
- **Alternativas**: capturar la diferencia (rechazada por la aclaración).

## D-09. Kilometraje del servicio en la orden

- **Decisión**: nueva columna `service_orders.service_mileage` (nullable) agregada en la migración 003
  (los scripts anteriores no se editan). Se acepta solo con la orden en `TERMINADO`, ≥ kilometraje de
  entrada y ≤ 2 000 000 (reutiliza `MAX_MILEAGE`); actualiza `vehicles.current_mileage` con
  `GREATEST(COALESCE(current_mileage, 0), :valor)`. Se puede corregir mientras la orden siga en
  Terminado. El historial muestra `service_mileage` si existe y, si no, el de entrada.
- **Justificación**: FR-004 y escenarios de la historia 2.
- **Alternativas**: tabla aparte de lecturas de kilometraje (rechazada: sobredimensionada).

## D-10. Permisos y proyección del catálogo

- **Decisión**: `authorize` por ruta más verificación de pertenencia en servicio (reutilizando
  `loadOrderForActor`: una orden ajena responde 404 al mecánico). El catálogo devuelve a ADMIN la
  vista completa y al MECHANIC una proyección reducida (código, nombre, unidad, existencia) solo de
  refacciones activas. Alertas y movimientos son exclusivos de ADMIN. La lista de mantenimientos es
  de ADMIN y RECEPTIONIST; el mecánico recibe los de un vehículo dentro del historial.
- **Justificación**: aclaraciones 3 y 4; Constitución IV.
- **Marcar Atendido / editar un mantenimiento**: ADMIN y el mecánico de la orden de origen (supuesto,
  coherente con quién lo programa); recepción solo consulta.

## D-11. Alertas de stock

- **Decisión**: una refacción activa está en alerta si `stock <= min_stock`; está Agotada si
  `stock = 0`. Un endpoint `GET /api/parts/alerts` devuelve la lista y el conteo; el cliente lo
  consulta al abrir la sesión de ADMIN, al abrir Inventario y tras cada movimiento (sin canales
  externos ni tiempo real).
- **Justificación**: FR-019 y CA-7; el MVP excluye notificaciones externas.
- **Alternativas**: WebSockets o sondeo periódico (rechazadas: fuera de alcance).

## D-12. Sin precios ni categorías en las refacciones

- **Decisión**: `parts` solo tiene código, nombre, descripción, unidad, stock, stock mínimo y estado
  activo. Precios, marca y categoría se difieren a los sprints de pagos y tickets.
- **Justificación**: suposición de la especificación; evita decidir cálculo de totales antes de tiempo.
- **Alternativas**: incluir `purchasePrice` y `salePrice` del modelo maestro (rechazada: sin uso en
  este sprint).

## D-13. Datos de ejemplo idempotentes y coherentes

- **Decisión**: el seed 003 usa claves naturales: refacciones por `code`; movimientos por
  `(code, reason, type)`; líneas de orden por `(order, part)`; mantenimientos por `(placa, descripción)`;
  órdenes históricas por `(placa, problema reportado)`. Al final recalcula `parts.stock` como la suma
  de movimientos de las refacciones sembradas, lo que es idempotente y mantiene la invariante.
  Incluye órdenes Terminadas y Entregadas de varios vehículos (con servicios y kilometraje de
  servicio), refacciones en estado suficiente, bajo y agotado, y mantenimientos Normal, Próximo,
  Vencido y Atendido calculados relativos a `NOW()` solo al insertar.
- **Justificación**: FR-024 y la restricción de seeds idempotentes.
- **Alternativas**: seeds con ids fijos (rechazada: choca con datos creados por el usuario).

## D-14. Pruebas de concurrencia

- **Decisión**: una prueba de integración lanza varias solicitudes simultáneas contra una refacción
  con stock limitado y comprueba que la suma aceptada nunca supera el stock y que el stock final
  coincide con la suma de movimientos.
- **Justificación**: SC-005 y el caso límite de dos mecánicos.
