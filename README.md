# Motorix

Sistema de Gestión para Taller Mecánico. Proyecto académico cuyo MVP se construyó en cuatro
sprints y que ya incluye tres sprints posteriores. Este repositorio contiene el **Sprint 1** (base del
sistema, autenticación, usuarios, clientes y vehículos), el **Sprint 2** (citas y órdenes de servicio),
el **Sprint 3** (historial, mantenimiento e inventario), el **Sprint 4** (pagos, tickets y panel de
control) y, ya posteriores al MVP, el **Sprint 5** (precios de refacciones y cobro completo), el
**Sprint 6** (notificaciones internas y clientes por avisar) y el **Sprint 7** (reportes, configuración
del taller, términos y condiciones y seguridad de la información).

## Estructura

| Carpeta | Contenido |
|---------|-----------|
| `client/` | Aplicación de escritorio en Flutter (Material 3 con tema propio y Provider) |
| `server/` | API REST en Node.js + Express (ES Modules); `server/scripts/` trae la carga de datos de ejemplo |
| `database/` | Migraciones, seeds y scripts de MySQL local (los respaldos locales de `database/respaldos/` no se suben) |
| `docs/` | Contexto del proyecto, reglas, sistema de diseño y sprints |
| `specs/` | Especificaciones de Spec Kit por funcionalidad |

## Requisitos previos

- Windows con PowerShell
- Node.js 20 o superior (probado con 24)
- Flutter 3.47.x con soporte de escritorio Windows (en Windows, activar el *Modo de desarrollador*
  para compilar plugins)
- MySQL Server 8.0 instalado de forma nativa y en ejecución

## Puesta en marcha

```powershell
Copy-Item .env.example .env            # completa DB_PASSWORD y JWT_SECRET
database/scripts/crear-entorno.ps1     # bases motorix y motorix_test + usuario motorix_app
database/scripts/aplicar-migraciones.ps1 -Base motorix
database/scripts/aplicar-migraciones.ps1 -Base motorix_test
database/scripts/aplicar-seeds.ps1 -Base motorix

cd server; npm install; npm run dev
cd client; flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3000/api
```

El cliente también corre en el navegador (`flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api`): los
reportes de Excel se descargan con la descarga del navegador y la pestaña lleva el ícono de Motorix.

### Datos de ejemplo completos (opcional)

Los seeds dejan un conjunto mínimo para probar cada módulo. Para ver las listas y las gráficas llenas, el script
`server/scripts/cargarDatosDemo.js` reemplaza los datos de negocio de la base de desarrollo `motorix` por un conjunto
coherente de octubre a diciembre de 2026 (clientes, vehículos, órdenes, pagos, tickets, inventario, mantenimientos y citas);
conserva usuarios, configuración, tipos de servicio y términos. Sin parámetros solo muestra un resumen; con `--confirmar`
borra y carga. Haz un respaldo antes (`mysqldump`).

```powershell
cd server; node scripts/cargarDatosDemo.js              # solo muestra el resumen
cd server; node scripts/cargarDatosDemo.js --confirmar  # borra y carga
```

La guía de validación de cada sprint está en su carpeta de `specs/` (por ejemplo,
[`specs/001-base-clientes-vehiculos/quickstart.md`](specs/001-base-clientes-vehiculos/quickstart.md) para el Sprint 1 y
[`specs/007-reportes-configuracion-seguridad/quickstart.md`](specs/007-reportes-configuracion-seguridad/quickstart.md) para el Sprint 7).
Los scripts de `database/scripts` aplican las migraciones y los seeds de todos los sprints en orden y son idempotentes.

## Cuentas iniciales (solo entorno local)

| Rol | Usuario | Correo |
|-----|---------|--------|
| Administrador | `admin` | `admin@motorix.local` |
| Recepcionista | `recepcion` | `recepcion@motorix.local` |
| Mecánico | `mecanico` | `mecanico@motorix.local` |
| Mecánico 2 (Sprint 2) | `mecanico2` | `mecanico2@motorix.local` |

Las contraseñas del estándar del MVP están en `docs/project-context.md` y no se guardan en texto
plano en el código ni en los scripts: la base solo contiene su hash bcrypt. Desde el Sprint 7 las contraseñas
nuevas deben tener al menos 10 caracteres con mayúscula, minúscula y número (las ya guardadas siguen valiendo), y en el
primer ingreso cada persona debe aceptar los términos y condiciones.

## Pruebas

```powershell
cd server; npm test        # contra la base motorix_test
cd client; flutter test
```

Estado actual de la suite: 1 534 pruebas del servidor (123 suites) y 449 del cliente.

## Reglas del proyecto

Consulta `.specify/memory/constitution.md` y `docs/reglas.md`. Resumen: ES Modules en el backend,
permisos validados en el backend, sin secretos en el repositorio, interfaz según
`docs/design-system.md`, documentación y mensajes en español.

## Estado del Sprint 1

Implementado: inicio de sesión (usuario o correo) con roles, gestión de usuarios, clientes y vehículos
con asociación a su propietario, cambio de contraseña y datos de ejemplo. Validado con 215 pruebas del
backend y 86 del cliente; el detalle y la trazabilidad de los criterios de aceptación están en la sección 6
de [`quickstart.md`](specs/001-base-clientes-vehiculos/quickstart.md).

Para recrear la base local desde cero: `database/scripts/reiniciar-local.ps1 -Base motorix`.

## Estado del Sprint 2

Implementado: citas (registrar, consultar, modificar, confirmar y cancelar), órdenes de servicio creadas
desde una cita o de forma directa, con kilometraje de entrada validado y una sola orden abierta por
vehículo; asignación de mecánico; vista «Mis órdenes» del mecánico; diagnóstico, servicios, mano de obra,
observaciones y recomendaciones; y cambio de estado con la secuencia
`RECIBIDO → DIAGNOSTICO → EN_REPARACION → TERMINADO → ENTREGADO` (más `ESPERANDO_REFACCION`), con historial.
La entrega la registran recepción o administración; las órdenes entregadas son de solo lectura y no se
eliminan. Los seeds incluyen un segundo mecánico, citas en los cinco estados y órdenes en los seis.

Validado con 470 pruebas del backend (incluidas las de la lógica de transiciones de estado) y 150 del
cliente, y con un recorrido de extremo a extremo contra la API real y MySQL local; el detalle está en la
sección 6 de [`quickstart.md`](specs/002-citas-ordenes-servicio/quickstart.md).

Menú por rol: recepción y administración ven Citas y Órdenes; el mecánico ve Mis órdenes. Los permisos se
validan siempre en el backend.

## Estado del Sprint 3

Implementado: historial de servicios por vehículo (calculado a partir de las órdenes Terminadas o Entregadas),
kilometraje del servicio, programación del próximo mantenimiento por fecha, kilometraje o ambos con indicador
Normal, Próximo o Vencido (margen de aviso configurable; desde el Sprint 7 se edita en Configuración y `MAINTENANCE_WARN_DAYS` y `MAINTENANCE_WARN_KM` quedan como valor de respaldo),
catálogo de refacciones con entradas y ajustes por conteo, refacciones utilizadas en las órdenes (cada uso genera
su salida de inventario y el stock nunca queda negativo) y alertas de stock bajo para la administración. Los seeds
incluyen refacciones suficientes, bajas y agotadas, historial en varios vehículos y mantenimientos en todos los
estados.

Validado con 752 pruebas del backend (incluidas las de la lógica de inventario y mantenimiento y las de
concurrencia de stock) y 206 del cliente, y con un recorrido de extremo a extremo contra la API real y MySQL
local; el detalle está en la sección 6 de [`quickstart.md`](specs/003-historial-inventario/quickstart.md).

Menú por rol: la administración ve además Mantenimientos e Inventario; recepción ve Mantenimientos; el mecánico
consulta el historial en el detalle del vehículo, registra el kilometraje, el mantenimiento y las refacciones en
sus órdenes. Los permisos se validan siempre en el backend.

## Estado del Sprint 4

Implementado: cobro de las órdenes Terminadas o Entregadas con efectivo, tarjeta (solo folio de terminal),
transferencia o Mercado Pago, con un único pago vigente por orden y verificación de que el importe coincide con el
total de la orden; cancelación de cobros pendientes; entrega de la orden con cobro o sin cobro; tickets de servicio
(folio `TK-######`, instantánea del cobro, impresión o guardado en PDF) y panel de control con indicadores y
actividad reciente solo para administración. Los seeds incluyen pagos en los cuatro estados y métodos, y tickets.

Mercado Pago es opcional y funciona solo en entorno de pruebas: el token se define únicamente en `.env`
(`MERCADOPAGO_ACCESS_TOKEN`) y nunca se guarda en el repositorio. Sin token, los demás métodos siguen funcionando y
el cobro con Mercado Pago responde que el servicio no está configurado. Los datos del taller del ticket se
configuraban con `SHOP_NAME`, `SHOP_ADDRESS` y `SHOP_PHONE`; desde el Sprint 7 se editan en Configuración y esas variables
quedan como valor de respaldo.

Validado con 1001 pruebas del backend (lógica de pagos, adaptador de Mercado Pago simulado, concurrencia, permisos,
seguridad, contratos, seeds y rendimiento con 1 000 pagos y tickets) y 265 del cliente.

Menú por rol: la administración ve Panel de control, Cobros y Tickets; recepción ve Cobros y Tickets; el mecánico no
accede a cobros. Los permisos se validan siempre en el backend.

## Estado del Sprint 5

Primer sprint posterior al MVP (habilitado por la enmienda 1.1.0 de la constitución): precios de refacciones y cobro
completo. Implementado: categoría, marca y precios de compra y de venta de cada refacción (con aviso y confirmación
si se vende bajo el costo); cada línea de refacción de una orden guarda el precio de venta vigente al agregarla, y
el total de la orden suma servicios, mano de obra y refacciones (tope de 9 999 999.99); el pago se registra por ese
total, Mercado Pago recibe ese importe, un pago pendiente cuyo importe ya no coincide se señala como desfasado y se
cancela con confirmación, y una aprobación tardía muestra la diferencia por cobrar; el ticket nuevo usa el formato
versión 2 (precio e importe por refacción y tres subtotales) y los anteriores se muestran como se emitieron; una orden
con un pago Pagado no admite cambios de refacciones. El precio de compra solo lo ve la administración y el mecánico
no ve ningún precio de refacciones. Los seeds agregan precios, una orden Terminada cobrable con refacciones y un pago
pendiente desfasado, sin tocar pagos ni tickets anteriores. Las líneas de refacción anteriores al sprint quedan con
precio 0 y no suman al total.

Validado con 1215 pruebas del backend y 321 del cliente, y con un recorrido de los 10 escenarios del
[`quickstart.md`](specs/005-precios-refacciones-cobro/quickstart.md) contra la API real y MySQL local. El registro
de calidad del sprint (puertas, riesgos, trazabilidad, hallazgos y evidencias) está en
[`docs/aseguramiento-calidad-sprint-5.md`](docs/aseguramiento-calidad-sprint-5.md).

## Estado del Sprint 6

Notificaciones internas y clientes por avisar. Implementado: una campana en el encabezado con el total de avisos no
leídos y un panel agrupado por tipo (mantenimientos vencidos, stock agotado, órdenes detenidas, citas de hoy,
mantenimientos próximos y stock bajo), con lectura por usuario; el contador se actualiza al iniciar sesión, al navegar y
cada 60 segundos. Una orden detenida es una orden abierta con más de 3 días sin cambio de estado. El mecánico solo ve los
avisos de las órdenes que tiene asignadas. La pantalla **Clientes por avisar** lista a quién avisar (vehículo listo, cita de
mañana, mantenimiento próximo o vencido) y la recepción marca «Avisado»; el sistema no envía mensajes. Los avisos se
calculan al consultar con datos reales y solo se guarda quién los leyó y a quién ya se avisó.

Validado con 1 349 pruebas del servidor y 373 del cliente al cierre del sprint. El registro de calidad está en
[`docs/aseguramiento-calidad-sprint-6.md`](docs/aseguramiento-calidad-sprint-6.md).

## Estado del Sprint 7

Reportes, configuración del taller, términos y condiciones y seguridad de la información. Implementado:

- **Configuración** (solo administración): datos del taller y márgenes de «Próximo» editables desde la aplicación (valor
  guardado, luego `.env`, luego el predeterminado), y un catálogo de **tipos de servicio** con intervalo en días y kilómetros
  que propone el próximo mantenimiento. El ticket nuevo usa el formato versión 3 y muestra «Próximo servicio» cuando la
  orden lo tiene; los tickets anteriores no cambian.
- **Reportes** (solo administración): ingresos por periodo, servicios más frecuentes, productividad por mecánico, costo y
  margen de refacciones (con «Sin costo» cuando falta el precio de compra) y rotación del inventario, en centavos enteros y
  con periodos de hasta un año. Cada reporte se **exporta a Excel** (.xlsx) con el logo y los colores de Motorix; es la
  única dependencia nueva del sprint (`exceljs`, en el servidor).
- **Términos y condiciones:** pantalla de aceptación al ingresar, validada en el servidor (`403 TERMS_NOT_ACCEPTED`);
  al publicar una versión nueva todos deben aceptarla. El administrador consulta quién aceptó.
- **Seguridad:** bitácora de solo lectura de acciones sensibles (sin contraseñas, hashes, tokens ni tarjetas), contraseñas
  de 10 caracteres, cierre de sesión a los 30 minutos de inactividad con aviso a los 28, y pruebas de no exposición de datos
  y de inyección.

Menú del administrador: se suman Reportes, Configuración, Términos y Bitácora. Los permisos se validan siempre en el
backend.

Validado con 1 534 pruebas del servidor (123 suites) y 449 del cliente, con las 94 tareas del sprint completas. El registro
de calidad (puertas, riesgos, trazabilidad de los 26 criterios, hallazgos y regresión) está en
[`docs/aseguramiento-calidad-sprint-7.md`](docs/aseguramiento-calidad-sprint-7.md).
