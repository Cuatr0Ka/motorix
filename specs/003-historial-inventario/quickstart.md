# Guía de inicio rápido y validación: Sprint 3

Guía para comprobar de extremo a extremo que la funcionalidad cumple la [especificación](./spec.md).
El esquema está en [data-model.md](./data-model.md) y la API en
[contracts/api-rest.md](./contracts/api-rest.md). El entorno base (MySQL, `.env`, Node.js y Flutter) es
el del Sprint 1: ver `specs/001-base-clientes-vehiculos/quickstart.md`.

## Requisitos previos

- Sprints 1 y 2 instalados y funcionando (usuarios, clientes, vehículos, citas y órdenes de ejemplo).
- MySQL 8.0 local en ejecución y `.env` configurado. Opcional: `MAINTENANCE_WARN_DAYS` y
  `MAINTENANCE_WARN_KM` (por defecto 30 y 1 000).

## 1. Aplicar la base de datos del Sprint 3

```powershell
database/scripts/aplicar-migraciones.ps1 -Base motorix
database/scripts/aplicar-migraciones.ps1 -Base motorix_test
database/scripts/aplicar-seeds.ps1 -Base motorix
```

Repetir `aplicar-seeds.ps1` no duplica registros. Para recrear todo desde cero:
`database/scripts/reiniciar-local.ps1 -Base motorix`.

## 2. Ejecutar

```powershell
cd server;  npm install;  npm run dev                       # API en http://localhost:3000
cd client;  flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3000/api
```

## 3. Pruebas automatizadas

```powershell
cd server; npm test        # incluye estado de mantenimiento, reglas de stock, concurrencia e integración (motorix_test)
cd client; flutter test
```

## 4. Escenarios de validación manual

Cuentas de ejemplo: `recepcion`, `mecanico`, `mecanico2` y `admin` (contraseñas del estándar del MVP
en `docs/project-context.md`, solo para entornos locales).

| # | Escenario | Resultado esperado | Referencia |
|---|-----------|--------------------|------------|
| 1 | Con la base recién sembrada, abrir Inventario como `admin` | Hay refacciones suficientes, bajas y agotadas, y el banner de alertas muestra el conteo | FR-024, SC-010, SC-011 |
| 2 | Abrir el detalle de un vehículo con servicios terminados | El historial muestra las órdenes en orden cronológico con kilometraje, servicios y refacciones | US1, CA-1 |
| 3 | Abrir el detalle de un vehículo sin servicios terminados | Estado vacío claro | US1 |
| 4 | Como `mecanico`, terminar una orden asignada, registrar su kilometraje de servicio | Aparece en el historial; el kilometraje del vehículo se actualiza | US2 |
| 5 | Registrar un kilometraje de servicio menor al de entrada | Se rechaza con un mensaje claro | US2 |
| 6 | Programar el próximo mantenimiento (fecha y/o kilometraje) desde esa orden | Queda vigente; el anterior del vehículo pasa a Atendido | US2, CA-2 |
| 7 | Intentar programarlo sin fecha ni kilometraje, con fecha pasada o kilometraje ≤ actual | Se rechaza | FR-005 |
| 8 | Como `recepcion`, abrir Mantenimientos | Se ven Normal, Próximo y Vencido con cliente y teléfono; los Vencidos primero | US3, CA-3 |
| 9 | Como `mecanico`, abrir la lista de mantenimientos por la API | `403 FORBIDDEN` | SC-008 |
| 10 | Como `admin`, registrar una refacción con stock inicial y mínimo | Aparece en el inventario con su movimiento de entrada | US4, CA-4 |
| 11 | Registrar un código duplicado | Se rechaza (`PART_CODE_TAKEN`) | US4 |
| 12 | Registrar una entrada de mercancía y un ajuste por conteo | El stock sube y queda en la cantidad contada; el detalle muestra ambos movimientos | US4 |
| 13 | Como `mecanico`, agregar 2 unidades de una refacción a una orden asignada | La orden las muestra, el stock baja 2 y hay un movimiento de salida ligado a la orden | US5, CA-5 |
| 14 | Agregar más unidades de las disponibles | Se rechaza con «Solo hay N disponibles»; nada cambia | US5, CA-6 |
| 15 | Corregir a una cantidad menor y luego quitar la refacción | Las unidades regresan al inventario con movimientos de entrada ligados a la orden | US5 |
| 16 | Orden entregada: intentar agregar o quitar refacciones | Se rechaza (`ORDER_READ_ONLY`) | FR-018 |
| 17 | Como `mecanico2`, modificar refacciones de una orden de `mecanico` | `404` | SC-008 |
| 18 | Como `recepcion`, llamar a la API de refacciones | `403 FORBIDDEN` | SC-008 |
| 19 | Dejar una refacción en o por debajo de su mínimo con una salida | Aparece en las alertas del `admin`; una entrada la quita | US6, CA-7 |
| 20 | Como `mecanico`, abrir el catálogo | Solo ve código, nombre, unidad y existencia | FR-011 |
| 21 | Dos solicitudes simultáneas que juntas superan el stock | Solo prospera la que cabe; el stock nunca queda negativo | SC-005 |
| 22 | Ejecutar de nuevo `aplicar-seeds.ps1` | No se duplican refacciones, movimientos, líneas ni mantenimientos | SC-011 |

## 5. Criterios de aceptación del sprint

Cada criterio CA-1 a CA-8 de `docs/sprints/sprint-3-historial-inventario.md` debe poder demostrarse con
los escenarios anteriores o con las pruebas automatizadas (CA-8: pruebas unitarias de
`maintenanceStatus` y `stockRules` en `server/tests/unit/`), sin secretos en el repositorio.

## 6. Resultado de la validación

Validado el 2026-10-11 con MySQL 8.0 local, Node.js 24 y Flutter 3.47.2.

### Pruebas automatizadas

- **Backend**: 752 pruebas en 52 suites (`npm test`, contra `motorix_test`): unitarias (estado de mantenimiento,
  reglas de stock y regla del kilometraje del servicio), integración y contrato de historial, kilometraje del
  servicio, mantenimientos (programar, editar, atender y lista con indicador calculado), catálogo, movimientos de
  inventario, refacciones por orden, alertas de stock, **concurrencia de stock** (varias solicitudes simultáneas
  sobre la misma refacción), seeds del Sprint 3 y rendimiento con 1 000 refacciones, movimientos, mantenimientos y
  servicios de un mismo vehículo (todas las consultas por debajo de 2 s; la más lenta tardó 59 ms).
- **Cliente**: 206 pruebas (`flutter test`) y `flutter analyze lib` sin avisos.

### Recorrido de extremo a extremo (API real + MySQL local)

Se levantó `server.js` contra `motorix_test` recreada con `reiniciar-local.ps1` (migraciones 001 a 003 y seeds 001 a
003) y se recorrieron los escenarios del apartado 4 por HTTP con las cuentas de ejemplo: **22 de 22 comprobaciones
correctas**.

| # | Escenario | Resultado |
|---|-----------|-----------|
| 1 | Datos de ejemplo al primer arranque | ✔ refacciones suficientes, bajas y agotadas; 5 alertas (2 agotadas) |
| 2 | Historial de un vehículo con servicios | ✔ órdenes terminadas en orden cronológico |
| 3 | Vehículo sin servicios terminados | ✔ historial vacío |
| 4 | Kilometraje del servicio | ✔ se guarda y sube el kilometraje actual del vehículo |
| 5 | Kilometraje de servicio menor al de entrada | ✔ 422 `SERVICE_MILEAGE_TOO_LOW` |
| 6 | Programar el próximo mantenimiento | ✔ el nuevo reemplaza al anterior, que queda Atendido |
| 7 | Sin objetivo, fecha pasada o kilometraje ≤ actual | ✔ rechazados con 422 |
| 8 | Lista de mantenimientos como recepción | ✔ Normal, Próximo y Vencido con cliente y teléfono; Vencidos primero |
| 9 | Lista de mantenimientos como mecánico | ✔ 403 |
| 10 | Registrar una refacción con stock inicial | ✔ 201 con su movimiento de entrada |
| 11 | Código duplicado | ✔ 409 `PART_CODE_TAKEN` |
| 12 | Entrada y ajuste por conteo | ✔ el stock queda en 8 y el ajuste guarda −2 |
| 13 | Agregar a una orden | ✔ el stock baja y hay una salida ligada a la orden |
| 14 | Cantidad mayor al stock | ✔ 409 `INSUFFICIENT_STOCK` sin cambios |
| 15 | Corregir a la baja y quitar | ✔ las unidades regresan al inventario |
| 16 | Orden entregada | ✔ 409 `ORDER_READ_ONLY` |
| 17 | Mecánico no asignado | ✔ 404 |
| 18 | Recepción en el catálogo | ✔ 403 |
| 19 | Alertas tras usar y tras una entrada | ✔ la refacción aparece y luego deja de aparecer |
| 20 | Catálogo del mecánico | ✔ solo código, nombre, unidad y existencia (activas) |
| 21 | Solicitudes simultáneas | ✔ solo caben las que hay en existencia; stock final 0, nunca negativo |
| 22 | Repetir el seed | ✔ 3 ejecuciones seguidas sin cambiar ningún conteo y con el stock coherente con los movimientos |

La interfaz gráfica se verificó con pruebas de widgets (`flutter test`); no se realizó un recorrido manual de las
pantallas en una ventana de escritorio real.

### Criterios de aceptación del sprint

| Criterio | Evidencia |
|----------|-----------|
| CA-1 historial cronológico de órdenes terminadas | `history.test.js`, `history.contract.test.js`, escenarios 2 y 3 |
| CA-2 próximo mantenimiento por fecha y/o kilometraje | `maintenance.flow.test.js`, `serviceMileage.test.js`, escenarios 4 a 7 |
| CA-3 mantenimientos próximos y vencidos correctos | `maintenanceStatus.test.js`, `maintenance.list.test.js` (incluye la equivalencia entre el filtro SQL y la función pura), escenario 8 |
| CA-4 refacciones y stock contra MySQL local | `parts.flow.test.js`, `inventory.movements.test.js`, escenarios 10 a 12 |
| CA-5 agregar a una orden genera la salida | `orderParts.flow.test.js`, escenario 13 |
| CA-6 el sistema impide el stock negativo | `stockRules.test.js`, `orderParts.concurrency.test.js`, restricciones de la base, escenarios 14 y 21 |
| CA-7 alertas de stock bajo en la interfaz | `stockAlerts.test.js`, `stock_alerts_test.dart`, escenario 19 |
| CA-8 pruebas de inventario y mantenimiento existen y pasan | `maintenanceStatus.test.js`, `stockRules.test.js` y las suites de integración y contrato |

### Corrección durante la validación

`database/scripts/reiniciar-local.ps1` solo eliminaba las tablas del Sprint 1 y fallaba al recrear la base desde cero
(`Table 'appointments' already exists`). Ahora elimina todas las tablas de la base, de modo que recrear el esquema
completo vuelve a funcionar y seguirá funcionando con las tablas de los sprints siguientes.
