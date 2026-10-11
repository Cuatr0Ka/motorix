# Guía de inicio rápido y validación: Sprint 2

Guía para comprobar de extremo a extremo que la funcionalidad cumple la [especificación](./spec.md).
El esquema está en [data-model.md](./data-model.md) y la API en
[contracts/api-rest.md](./contracts/api-rest.md). El entorno base (MySQL, `.env`, Node.js y Flutter) es
el del Sprint 1: ver `specs/001-base-clientes-vehiculos/quickstart.md`.

## Requisitos previos

- Sprint 1 instalado y funcionando (usuarios, clientes y vehículos de ejemplo).
- MySQL 8.0 local en ejecución y `.env` configurado.

## 1. Aplicar la base de datos del Sprint 2

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
cd server; npm test        # incluye transiciones de estado, permisos e integración (motorix_test)
cd client; flutter test
```

## 4. Escenarios de validación manual

Cuentas de ejemplo: `recepcion`, `mecanico`, `mecanico2` y `admin` (contraseñas del estándar del MVP
en `docs/project-context.md`, solo para entornos locales).

| # | Escenario | Resultado esperado | Referencia |
|---|-----------|--------------------|------------|
| 1 | Al abrir la aplicación con la base recién sembrada, revisar Citas y Órdenes | Aparecen citas y órdenes de ejemplo en todos los estados, sin capturar nada | FR-026, SC-009 |
| 2 | Como `recepcion`, registrar una cita para un cliente y uno de sus vehículos | Queda Pendiente y aparece en el listado | US1 |
| 3 | Registrar una cita con fecha pasada, con un vehículo ajeno al cliente o en un horario ya ocupado | Se rechaza con un mensaje claro | FR-006 |
| 4 | Confirmar la cita, modificar su hora y cancelarla (con confirmación) | Los cambios se ven; la cancelada ya no se edita | FR-002, FR-004, FR-005 |
| 5 | Desde una cita Pendiente, «Recibir vehículo y crear orden» con kilometraje y mecánico | Se crea la orden `RECIBIDO` con folio; la cita pasa a En proceso; el kilometraje del vehículo se actualiza | US2, FR-010, FR-011 |
| 6 | Crear una orden con un kilometraje menor al actual del vehículo | Se rechaza; solo se acepta con corrección explícita y motivo | CA-6, FR-009 |
| 7 | Crear otra orden para un vehículo que ya tiene una abierta | Se rechaza | FR-012 |
| 8 | Crear una orden directa (sin cita) y asignarla a `mecanico`; reasignarla a `mecanico2` | La orden pasa de una lista a otra | US3 |
| 9 | Iniciar sesión como `mecanico` | Solo ve sus órdenes no entregadas; abrir una ajena por la API responde 404 | CA-3, SC-005 |
| 10 | Como `mecanico`, registrar diagnóstico, dos servicios, mano de obra y una recomendación | Se guardan; los totales se recalculan | US5, CA-4 |
| 11 | Avanzar la orden RECIBIDO → DIAGNÓSTICO → EN REPARACIÓN; usar Esperando refacción y reanudar | Cada paso queda en el historial | US6, CA-5 |
| 12 | Intentar saltar a Terminado desde Recibido, o intentar Entregado como mecánico | Se rechaza e indica los estados permitidos o el permiso | FR-019, FR-020 |
| 13 | Pasar la orden a Terminado | La cita de origen pasa a Completada | FR-011 |
| 14 | Como `recepcion`, entregar la orden (con confirmación) | Queda Entregada y de solo lectura; no hay forma de eliminarla | FR-017, SC-008 |
| 15 | Abrir la misma orden en dos sesiones y cambiar su estado en ambas | La segunda recibe el estado vigente (`STATE_CONFLICT`) | Aclaración 5 |
| 16 | Como `recepcion`, llamar a la API para cambiar el estado a Diagnóstico | `403 FORBIDDEN` | CA-7 |
| 17 | Ejecutar de nuevo `aplicar-seeds.ps1` | No se duplican citas ni órdenes | SC-009 |

## 5. Criterios de aceptación del sprint

Cada criterio CA-1 a CA-8 de `docs/sprints/sprint-2-citas-ordenes.md` debe poder demostrarse con los
escenarios anteriores o con las pruebas automatizadas (CA-8: pruebas unitarias de la tabla de
transiciones en `server/tests/unit/`), sin secretos en el repositorio.

## 6. Resultado de la validación

Validado el 2026-10-10 con MySQL 8.0.46 local, Node.js 24 y Flutter 3.47.2.

### Pruebas automatizadas

- **Backend**: 470 pruebas en 35 suites (`npm test`, contra `motorix_test`): unitarias (transiciones de estado,
  matriz de permisos por rol y pertenencia, regla de kilometraje, folio), integración y contrato de citas,
  órdenes, asignación, trabajo, estados y alcance del mecánico, seeds del Sprint 2 y rendimiento con 1 000
  citas y 1 000 órdenes (todas las consultas por debajo de 2 s).
- **Cliente**: 150 pruebas (`flutter test`, sin `test/widget_test.dart`, que es la plantilla de `flutter create`
  y no compila) y `flutter analyze lib` sin avisos.

### Recorrido de extremo a extremo (API real + MySQL local)

Se levantó `server.js` contra `motorix_test` sembrada con los seeds 001 y 002 y se recorrieron los escenarios
del apartado 4 por HTTP con las cuentas de ejemplo: **37 de 37 comprobaciones correctas**.

| # | Escenario | Resultado |
|---|-----------|-----------|
| 1 | Datos de ejemplo al primer arranque | ✔ citas en los 5 estados y órdenes en los 6 estados |
| 2 | Registrar una cita | ✔ queda Pendiente |
| 3 | Fecha pasada, vehículo ajeno, horario ocupado | ✔ rechazados con 422, 422 y 409 |
| 4 | Confirmar, modificar y cancelar | ✔; la cancelada ya no se edita (409); el mecánico no ve citas (403) |
| 5 | Crear la orden desde la cita | ✔ RECIBIDO con folio; cita En proceso; kilometraje del vehículo actualizado |
| 6 | Kilometraje menor o ausente | ✔ rechazado (422 `MILEAGE_DECREASE` / 400) |
| 7 | Segunda orden abierta | ✔ rechazada (409 `OPEN_ORDER_EXISTS`) |
| 8 | Orden directa, asignar y reasignar | ✔ la orden cambia de lista entre `mecanico` y `mecanico2` |
| 9 | Alcance del mecánico | ✔ solo ve las suyas y no entregadas; una ajena responde 404 |
| 10 | Diagnóstico, servicios, mano de obra y recomendaciones | ✔ totales recalculados; recepción no puede registrar (403) |
| 11 | Avance con Esperando refacción | ✔ |
| 12 | Salto de estado y entrega por el mecánico | ✔ 422 con las permitidas; 403 |
| 13 | Terminar | ✔ la cita de origen queda Completada |
| 14 | Entrega y solo lectura | ✔ 409 `ORDER_READ_ONLY`; sin `DELETE` (404); historial de 7 registros |
| 15 | Cambios simultáneos de estado | ✔ solo uno prospera |
| 16 | Rol sin permiso | ✔ 403 |
| 17 | Repetir el seed | ✔ 3 ejecuciones seguidas: 5 citas, 7 órdenes, 9 servicios, 5 de mano de obra y 24 cambios de estado sin duplicados |

La interfaz gráfica se verificó con pruebas de widgets (`flutter test`); no se realizó un recorrido manual de las
pantallas en una ventana de escritorio real.

### Criterios de aceptación del sprint

| Criterio | Evidencia |
|----------|-----------|
| CA-1 citas de extremo a extremo | `appointments.flow.test.js`, `appointments.contract.test.js`, escenarios 2 a 4 |
| CA-2 orden asociada a cliente y vehículo en MySQL local | `orders.create.test.js`, escenario 5 |
| CA-3 el mecánico solo ve sus órdenes | `orders.mechanicScope.test.js`, escenario 9 |
| CA-4 diagnóstico, servicios y recomendaciones | `orders.work.test.js`, escenario 10 |
| CA-5 secuencia de estados | `orderTransitions.test.js` (36 pares), `orders.status.test.js`, escenarios 11 a 14 |
| CA-6 kilometraje de entrada | `mileageRule.test.js`, `orders.create.test.js`, escenario 6 |
| CA-7 permisos por rol en el backend | `orderPermissions.test.js` y pruebas de contrato 401/403/404, escenarios 12 y 16 |
| CA-8 pruebas de transiciones | `server/tests/unit/orderTransitions.test.js` y `orderPermissions.test.js` |

### Incidencias encontradas y resueltas durante la validación

- `database/scripts/comun.ps1` enviaba el SQL a `mysql` en ASCII bajo Windows PowerShell 5.1 (tildes y eñes se
  guardaban como `?`), lo que impedía repetir el seed 001. Ahora fuerza UTF-8 al enviar el SQL.
- MySQL no admite `ON UPDATE CASCADE` en la llave foránea de una columna base de una columna generada
  almacenada: las FK de `vehicle_id` en `appointments` y `service_orders` usan `ON UPDATE RESTRICT`.
