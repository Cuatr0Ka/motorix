# Motorix

Sistema de Gestión para Taller Mecánico. Proyecto académico cuyo MVP se construye en cuatro
sprints. Este repositorio contiene el **Sprint 1** (base del sistema, autenticación, usuarios,
clientes y vehículos), el **Sprint 2** (citas y órdenes de servicio), el **Sprint 3** (historial,
mantenimiento e inventario) y el **Sprint 4** (pagos, tickets y panel de control).

## Estructura

| Carpeta | Contenido |
|---------|-----------|
| `client/` | Aplicación de escritorio en Flutter (Material 3 con tema propio y Provider) |
| `server/` | API REST en Node.js + Express (ES Modules) |
| `database/` | Migraciones, seeds y scripts de MySQL local |
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

La guía completa de validación está en
[`specs/001-base-clientes-vehiculos/quickstart.md`](specs/001-base-clientes-vehiculos/quickstart.md) (Sprint 1) y en
[`specs/002-citas-ordenes-servicio/quickstart.md`](specs/002-citas-ordenes-servicio/quickstart.md) (Sprint 2) y
[`specs/003-historial-inventario/quickstart.md`](specs/003-historial-inventario/quickstart.md) (Sprint 3).
Los scripts de `database/scripts` aplican las migraciones y los seeds de los tres sprints en orden y son idempotentes.

## Cuentas iniciales (solo entorno local)

| Rol | Usuario | Correo |
|-----|---------|--------|
| Administrador | `admin` | `admin@motorix.local` |
| Recepcionista | `recepcion` | `recepcion@motorix.local` |
| Mecánico | `mecanico` | `mecanico@motorix.local` |
| Mecánico 2 (Sprint 2) | `mecanico2` | `mecanico2@motorix.local` |

Las contraseñas del estándar del MVP están en `docs/project-context.md` y no se guardan en texto
plano en el código ni en los scripts: la base solo contiene su hash bcrypt.

## Pruebas

```powershell
cd server; npm test        # contra la base motorix_test
cd client; flutter test
```

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
Normal, Próximo o Vencido (margen de aviso configurable con `MAINTENANCE_WARN_DAYS` y `MAINTENANCE_WARN_KM`),
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
configuran con `SHOP_NAME`, `SHOP_ADDRESS` y `SHOP_PHONE`.

Validado con 1001 pruebas del backend (lógica de pagos, adaptador de Mercado Pago simulado, concurrencia, permisos,
seguridad, contratos, seeds y rendimiento con 1 000 pagos y tickets) y 265 del cliente.

Menú por rol: la administración ve Panel de control, Cobros y Tickets; recepción ve Cobros y Tickets; el mecánico no
accede a cobros. Los permisos se validan siempre en el backend.
