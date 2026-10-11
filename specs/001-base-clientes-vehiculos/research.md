# Investigación: Base del sistema, clientes y vehículos (Sprint 1)

**Fecha**: 2026-10-10

No quedan marcadores `NEEDS CLARIFICATION` en el contexto técnico. Las decisiones de base (Flutter +
Provider, `mysql2`, migraciones SQL numeradas, Jest + supertest, MySQL nativo, ES Modules) ya
estaban fijadas por la constitución y `docs/project-context.md`. Este documento registra las
decisiones de diseño tomadas para el sprint.

## D-01. Sistema de módulos y ejecución de pruebas

- **Decisión**: ES Modules en todo el backend (`"type": "module"`). Jest se ejecuta con
  `node --experimental-vm-modules node_modules/jest/bin/jest.js`.
- **Justificación**: la constitución prohíbe CommonJS; Jest soporta ESM solo con esa bandera.
- **Alternativas**: Vitest (rechazada: la constitución fija Jest); transpilar a CommonJS (rechazada).

## D-02. Acceso a datos

- **Decisión**: `mysql2/promise` con un pool (`config/db.js`), consultas parametrizadas en
  `models/`; sin ORM ni query builder.
- **Justificación**: decisión ya tomada; las consultas parametrizadas evitan inyección SQL; el
  esquema es pequeño.
- **Alternativas**: Sequelize/Prisma/Knex (rechazadas por decisión del equipo).

## D-03. Migraciones y seeds

- **Decisión**: scripts SQL numerados e inmutables en `database/migrations/`; los scripts de
  PowerShell usan el cliente `mysql` y registran cada versión en `schema_migrations`
  (idempotente). Los seeds usan `INSERT ... ON DUPLICATE KEY UPDATE` o `INSERT IGNORE` sobre claves
  únicas (usuario, correo, placa), de modo que repetirlos no duplica nada. Los mismos scripts
  aceptan el nombre de la base (`motorix` o `motorix_test`).
- **Justificación**: cumple la constitución (recrear desde cero, scripts numerados, idempotencia).
- **Alternativas**: herramienta de migraciones de terceros (rechazada: dependencia innecesaria).

## D-04. Contraseñas de las cuentas iniciales en los seeds

- **Decisión**: el seed SQL inserta únicamente el hash bcrypt (costo 10) de las contraseñas del
  estándar del MVP, generado una vez con `bcryptjs`. Ninguna contraseña en texto plano aparece en
  el código ni en los scripts.
- **Justificación**: CA-10 y la constitución (Principio IV); mantiene el seed 100 % SQL e idempotente.
- **Alternativas**: script Node que hashee al sembrar (rechazada: obligaría a escribir las
  contraseñas en texto plano en código).

## D-05. Autenticación y sesión

- **Decisión**: `POST /api/auth/login` recibe `identifier` y `password`. Si `identifier` contiene
  `@` se busca por correo; si no, por nombre de usuario. Se emite un JWT (HS256) de 8 horas cuyo
  payload solo lleva el id de usuario. En **cada** petición protegida el middleware
  `authenticate` consulta el usuario en la base y comprueba que siga activo; `authorize` usa el rol
  vigente de la base, no el del token. Cerrar sesión descarta el token en el cliente.
- **Justificación**: FR-002, FR-004 y la aclaración sobre efecto inmediato; el costo de una consulta
  por petición es despreciable a esta escala.
- **Alternativas**: rol dentro del token (rechazada: no permite efecto inmediato); lista de
  revocación (rechazada: complejidad innecesaria).

## D-06. Hash de contraseñas

- **Decisión**: `bcryptjs`, costo 10.
- **Justificación**: JavaScript puro, evita compilar módulos nativos en Windows.
- **Alternativas**: `bcrypt` nativo (rechazada por fricción de instalación); `argon2` (la
  constitución fija bcrypt).

## D-07. Validación y errores

- **Decisión**: esquemas `zod` en `validators/` aplicados por un middleware `validate`; mensajes
  en español. Errores de negocio mediante `AppError` (código estable, estado HTTP y mensaje);
  un `errorHandler` central responde `{ "error": { "code", "message", "details?" } }` y nunca
  devuelve trazas ni mensajes del motor de base de datos.
- **Justificación**: Principios IV y VI; FR-015.
- **Alternativas**: `joi`, `express-validator` (equivalentes; `zod` ya elegido).

## D-08. Normalización y unicidad

- **Decisión**: usuario, correo y placa se recortan; la placa se guarda en mayúsculas; el correo en
  minúsculas; un correo vacío se guarda como `NULL`. La unicidad se garantiza con índices
  `UNIQUE` y el intercolado por defecto de MySQL 8 (`utf8mb4_0900_ai_ci`), que no distingue
  mayúsculas ni acentos, cubriendo el caso límite de usuarios que difieren solo en mayúsculas. El
  servicio traduce el error de clave duplicada a `409` con el campo afectado.
- **Justificación**: casos límite de la especificación; la base es la última línea de defensa
  contra carreras de concurrencia.
- **Alternativas**: comprobar duplicados solo en el servicio (rechazada: condición de carrera).

## D-09. Bloqueo por intentos fallidos

- **Decisión**: tras 5 intentos fallidos consecutivos se bloquea la cuenta 15 minutos
  (`failed_login_attempts`, `locked_until`); un acceso correcto reinicia el contador. La respuesta
  sigue siendo genérica (`401`) para no revelar si la cuenta existe; el bloqueo responde `423` con
  mensaje claro.
- **Justificación**: decisión ya registrada en `docs/project-context.md` §27; mitiga adivinación de
  contraseñas con costo mínimo.
- **Nota**: no figura en `spec.md`; debe añadirse como requisito (ver plan.md, "Actualizaciones de
  documentación").
- **Alternativas**: `express-rate-limit` por IP (rechazada: no protege una cuenta concreta ni
  añade valor en red local).

## D-10. Regla de teléfono duplicado

- **Decisión**: al crear o editar un cliente, si el teléfono ya existe en otro cliente, la API
  responde `409` con código `PHONE_DUPLICATE` y la lista de coincidencias. El cliente reenvía la
  petición con `confirmDuplicatePhone: true` tras la confirmación de la persona. El correo
  duplicado responde `409` con `EMAIL_DUPLICATE` sin posibilidad de confirmar.
- **Justificación**: aclaración 1; mantiene la regla en el backend (Principio IV).
- **Alternativas**: solo advertir en la interfaz (rechazada: la regla debe vivir en el backend).

## D-11. Kilometraje

- **Decisión**: en la edición de un vehículo, un `currentMileage` menor al registrado se rechaza
  (`422`, `MILEAGE_DECREASE`) salvo que se envíe `mileageCorrection: true`.
- **Justificación**: Principio V de la constitución (regla 4 del contexto). Es una regla vigente
  desde el primer momento en que existe el dato.
- **Alternativas**: diferir al Sprint 2 (rechazada: dejaría una regla constitucional sin cubrir).

## D-12. Último administrador

- **Decisión**: el servicio de usuarios rechaza (`409`, `LAST_ADMIN`) desactivar o cambiar de rol
  al único administrador activo. La comprobación y el cambio ocurren en una transacción con
  bloqueo de filas.
- **Justificación**: FR-017.
- **Alternativas**: solo validar en la interfaz (rechazada).

## D-13. Frontend

- **Decisión**: Flutter para escritorio Windows (compatible con web), Material 3 con `ThemeData`
  propio en `client/lib/utils/app_theme.dart` y tokens centralizados; estado con Provider
  (`SessionProvider`, `SidebarProvider`, `ClientsProvider`, `VehiclesProvider`, `UsersProvider`);
  cliente HTTP con `http`; `data_table_2` (versión compatible con Flutter 3.47, a verificar al
  instalar) para tablas; `google_fonts` para IBM Plex Sans. La URL de la API se pasa con
  `--dart-define=API_BASE_URL`.
- **Justificación**: constitución y sistema de diseño; cero librerías de UI adicionales (aclaración 3).
- **Alternativas**: `dio` (rechazada: `http` basta); `shadcn_ui` (rechazada por decisión del equipo).

## D-14. Almacenamiento del token en el cliente

- **Decisión**: el token vive solo en memoria (en `SessionProvider`); al cerrar la aplicación se
  vuelve a iniciar sesión.
- **Justificación**: evita guardar credenciales en disco y una dependencia extra; aceptable para
  el MVP de uso local.
- **Alternativas**: `flutter_secure_storage` (puede añadirse más adelante si el equipo lo pide).

## D-15. Íconos

- **Decisión**: set estándar de Material (`Icons.*`), sin dependencia adicional.
- **Justificación**: aclaración 4 y restricción de un único set.
- **Alternativas**: `lucide_icons_flutter`, `phosphor_flutter` (rechazadas por la aclaración).

## D-16. Pruebas

- **Decisión**: la suite de integración y contrato levanta la aplicación (`app.js`) sin escuchar un
  puerto, usa `motorix_test` (nunca `motorix`), aplica migraciones antes de ejecutarse y vacía las
  tablas entre pruebas. Un guardia aborta si `DB_NAME` no termina en `_test`. En Flutter se prueban
  proveedores con un cliente HTTP simulado y los widgets críticos (inicio de sesión, formularios,
  diálogos de confirmación, visibilidad del menú por rol).
- **Justificación**: Principio VII.
- **Alternativas**: base en memoria o SQLite (rechazadas: no reproducen el comportamiento de MySQL).

## D-17. Paginación y búsqueda

- **Decisión**: listados con `page` y `pageSize` (20 por defecto, máximo 100) y búsqueda `search`
  mediante `LIKE` sobre nombre y teléfono (clientes) y placa, marca, modelo y propietario
  (vehículos), con índices sobre los campos de búsqueda.
- **Justificación**: SC-008 con holgura para ~1 000 registros.
- **Alternativas**: `FULLTEXT` (rechazada: innecesaria a esta escala).
