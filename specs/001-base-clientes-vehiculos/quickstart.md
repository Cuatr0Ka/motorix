# Guía de inicio rápido y validación: Sprint 1

Guía para levantar el entorno local y comprobar de extremo a extremo que la funcionalidad cumple la
[especificación](./spec.md). Los detalles de esquema están en [data-model.md](./data-model.md) y los de la
API en [contracts/api-rest.md](./contracts/api-rest.md).

## Requisitos previos

- Windows con PowerShell, Node.js 24 LTS, Flutter 3.47.x con soporte de escritorio Windows y
  MySQL Server 8.0 instalado de forma nativa (no Docker) y en ejecución.
- Acceso a MySQL con un usuario administrador para el primer paso (`root` solo para crear el entorno;
  la aplicación nunca lo usa).
- En Windows, activar el **Modo de desarrollador** (`start ms-settings:developers`): Flutter lo exige
  para compilar aplicaciones con plugins (soporte de enlaces simbólicos).

## 1. Configuración

```powershell
Copy-Item .env.example .env        # completa DB_PASSWORD y JWT_SECRET (no se versiona)
database/scripts/crear-entorno.ps1 # crea las bases motorix y motorix_test y el usuario motorix_app
database/scripts/aplicar-migraciones.ps1 -Base motorix
database/scripts/aplicar-migraciones.ps1 -Base motorix_test
database/scripts/aplicar-seeds.ps1 -Base motorix
```

Variables esperadas en `.env`: `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`,
`DB_NAME_TEST`, `JWT_SECRET`, `PORT`. Repetir `aplicar-seeds.ps1` no duplica registros. Para recrear la
base desde cero: `database/scripts/reiniciar-local.ps1 -Base motorix` (pide confirmación; `-Forzar` la omite).

## 2. Ejecutar

```powershell
cd server;  npm install;  npm run dev                       # API en http://localhost:3000
cd client;  flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3000/api
```

## 3. Pruebas automatizadas

```powershell
cd server; npm test        # unitarias, integración y contrato (contra motorix_test)
cd client; flutter test
```

## 4. Escenarios de validación manual

| # | Escenario | Resultado esperado | Referencia |
|---|-----------|--------------------|------------|
| 1 | Iniciar sesión con `recepcion` y con `recepcion@motorix.local` (contraseña del estándar del MVP) | Entra a Inicio con ambas formas | FR-001, US1 |
| 2 | Iniciar sesión con contraseña incorrecta | Mensaje genérico; tras 5 fallos, bloqueo temporal | FR-008 |
| 3 | Como recepcionista, registrar un cliente | Aparece en el listado | US3 |
| 4 | Registrar un cliente con el teléfono de otro | Diálogo de posible duplicado; permite continuar tras confirmar | Aclaración 1 |
| 5 | Registrar un cliente con un correo existente | Se rechaza | FR-009 |
| 6 | Editar el teléfono de un cliente | El cambio se ve en listado y detalle | US4 |
| 7 | Registrar un vehículo sin propietario | Se rechaza | FR-012 |
| 8 | Registrar un vehículo con propietario y consultar el detalle del cliente | El vehículo aparece en el cliente | US5, US6 |
| 9 | Registrar una placa repetida | Se rechaza | US5 |
| 10 | Cambiar el propietario de un vehículo | Pide confirmación; el vehículo cambia de cliente | FR-013 |
| 11 | Iniciar sesión como `mecanico` | Ve Clientes y Vehículos sin botones de alta o edición; una llamada directa a la API es rechazada con 403 | FR-014, SC-002 |
| 12 | Como `admin`, crear un usuario, cambiar su rol y desactivarlo | Se aplica de inmediato, incluso con su sesión abierta | US2, FR-006 |
| 13 | Intentar desactivar al único administrador | Se rechaza | FR-017 |
| 14 | Cambiar la contraseña por una débil / válida | Rechazada con mensaje / aceptada | FR-007 |
| 15 | Cerrar sesión | Pide confirmación y vuelve al inicio de sesión | FR-016 |
| 16 | Revisar la base: tabla `users` | Contraseñas solo como hash bcrypt | SC-005 |
| 17 | Ejecutar `reiniciar-local.ps1` en un equipo limpio | Esquema y datos de ejemplo recreados en menos de 10 minutos | SC-006, SC-007 |

## 5. Criterios de aceptación del sprint

Cada criterio CA-1 a CA-12 de `docs/sprints/sprint-1-base-clientes-vehiculos.md` debe poder
demostrarse con los escenarios anteriores o con las pruebas automatizadas, sin secretos en el
repositorio (`.env` ignorado y `.env.example` sin valores sensibles).

## 6. Resultado de la validación (2026-10-10)

Validado contra una instancia local de MySQL 8.0.46 y la API real. Las pruebas automatizadas
pasaron completas: **backend 215 pruebas** (unitarias, integración y contrato contra `motorix_test`) y
**cliente 86 pruebas** (`flutter test`), con `flutter analyze` sin avisos.

### Escenarios de la sección 4

Los escenarios 1 a 14 se recorrieron por HTTP contra la API real con datos de ejemplo (21 comprobaciones,
todas correctas) y, en la parte de interfaz, con pruebas de widgets sobre una API simulada. Además:

| # | Estado | Cómo se comprobó |
|---|--------|------------------|
| 15 | Correcto | Prueba de widgets: pide confirmación; "Cancelar" conserva la sesión y "Confirmar" vuelve al acceso |
| 16 | Correcto | `passwords.test.js`: las 3 cuentas guardan solo hash bcrypt (costo 10) y ninguna respuesta expone hashes ni contraseñas |
| 17 | Correcto | `reiniciar-local.ps1 -Base motorix -Forzar`: esquema y datos en **0,4 s** (3 usuarios, 8 clientes, 12 vehículos, 1 migración) |

### Trazabilidad de los criterios de aceptación

| Criterio | Evidencia |
|----------|-----------|
| CA-1 JWT válido y contraseñas con bcrypt | `auth.contract`, `auth.flow`, `passwords.test` |
| CA-2 Roles validados en el backend en cada endpoint | 403 por rol en cada contrato (`*.contract.test.js`), `authorize.test`, `users.flow` (efecto inmediato) |
| CA-3 Cliente, vehículo y asociación de extremo a extremo con MySQL local | Escenarios 3, 8 y 10 por HTTP; `clients.flow`, `vehicles.flow`, `vehicles.owner` |
| CA-4 Consultar cliente devuelve sus vehículos | `clients.contract` (`GET /:id`), escenario 8 |
| CA-5 ES Modules y `"type": "module"` | `esm.test.js` |
| CA-6 Esquema en `database/migrations/` recreable desde cero | Escenario 17 |
| CA-7 `.env.example` con variables `DB_*` sin valores sensibles | Revisión manual (T104) |
| CA-8 Sin secretos en el repositorio y `.env` ignorado | Búsqueda de secretos (T104); `.gitignore` ignora `.env` y `.env.*` |
| CA-9 Login por usuario o correo, todos los roles | `passwords.test` (3 roles × 2 formas), `auth.flow` |
| CA-10 Cuentas iniciales con hash bcrypt | `seeds.test`, `passwords.test` (los hashes coinciden con las contraseñas documentadas) |
| CA-11 Cambio de contraseña con política mínima | `users.contract`, `users.flow`, `users_screens_test` |
| CA-12 Pantallas según `docs/design-system.md` | Revisión de tokens (T105) y pruebas de ventana angosta/expandida; ver pendientes |

### Pendientes y límites de esta validación

- **No se ejecutó `database/scripts/crear-entorno.ps1`**: pide la contraseña de `root` por consola. Solo se
  validó su sintaxis; las bases de la validación se crearon con SQL equivalente en una instancia temporal.
  Ejecútalo una vez en tu equipo (`! database/scripts/crear-entorno.ps1`).
- **La aplicación no se abrió como programa de escritorio**: `flutter build windows` se detuvo porque el
  *Modo de desarrollador* de Windows está desactivado. El cliente se validó con `flutter analyze` y
  pruebas de widgets (incluidas ventanas de 760, 1000 y 1400 px), pero falta una **revisión visual** de
  CA-12 en una ventana real.
- La pantalla "Cambiar contraseña" no avisa al salir con campos escritos (es una sección del menú, no un
  formulario apilado); el resto de formularios sí confirma la salida con cambios sin guardar.
