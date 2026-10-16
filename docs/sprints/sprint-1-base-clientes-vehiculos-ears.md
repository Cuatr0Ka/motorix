<!--
Insumo de especificación para /speckit.specify, redactado con la sintaxis EARS.
Sprint 1 del MVP de Motorix: base del sistema, autenticación, usuarios, clientes y vehículos.
Versión equivalente a sprint-1-base-clientes-vehiculos.md, con los requisitos escritos en EARS.
-->

# Insumo de especificación (EARS) - Sprint 1: Base del sistema, clientes y vehículos

> Referencias obligatorias para el agente:
> - Contexto maestro: `docs/project-context.md`
> - Constitución: `docs/reglas.md` y `.specify/memory/constitution.md`
> - Este documento describe únicamente el alcance del Sprint 1.

## 1. Convención EARS usada en este documento

Cada requisito funcional (`FR-###`) usa una de las plantillas EARS. Las palabras clave se escriben en español y mantienen el orden: estado, disparador, sistema, respuesta.

| Patrón | Plantilla |
|--------|-----------|
| Ubicuo | El `<sistema>` DEBERÁ `<respuesta>`. |
| Dirigido por estado | MIENTRAS `<estado>`, el `<sistema>` DEBERÁ `<respuesta>`. |
| Dirigido por evento | CUANDO `<disparador>`, el `<sistema>` DEBERÁ `<respuesta>`. |
| Comportamiento no deseado | SI `<condición no deseada>`, ENTONCES el `<sistema>` DEBERÁ `<respuesta>`. |
| Característica opcional | DONDE `<característica presente>`, el `<sistema>` DEBERÁ `<respuesta>`. |
| Complejo | MIENTRAS `<estado>`, CUANDO `<disparador>`, el `<sistema>` DEBERÁ `<respuesta>`. |

Reglas de redacción: un solo DEBERÁ por requisito, sujeto siempre explícito, respuesta observable y verificable, y sin describir la implementación (el cómo va en `plan.md`).

Sujetos usados: **el backend**, **el frontend**, **el sistema** (backend y frontend en conjunto) y **la base de datos**.

## 2. Contexto del sprint

Es el primer sprint del MVP. Establece la estructura del repositorio, la conexión con MySQL local, la autenticación con JWT, la autorización por roles y los primeros módulos funcionales: clientes y vehículos. Sin este sprint, los sprints 2, 3 y 4 no pueden construirse.

## 3. Objetivo

Permitir que un usuario autorizado inicie sesión, gestione clientes y registre vehículos asociados a un propietario, con datos persistidos en MySQL local.

## 4. Historias de usuario del sprint

- **US1** - Como usuario del taller (administrador, recepcionista o mecánico), quiero iniciar sesión con mi usuario o correo electrónico y contraseña para acceder a las funciones según mi rol.
- **US2** - Como administrador, quiero gestionar usuarios y roles de acceso para controlar quién puede usar el sistema.
- **US3** - Como recepcionista, quiero registrar y consultar clientes para mantener actualizada la información de los propietarios.
- **US4** - Como recepcionista, quiero editar la información de los clientes para corregir o actualizar sus datos.
- **US5** - Como recepcionista, quiero registrar vehículos para llevar el control de los automóviles atendidos.
- **US6** - Como recepcionista, quiero asociar un vehículo con su propietario para vincular la información correctamente.

## 5. Flujo demostrable al cierre del sprint

    Iniciar sesión
    -> registrar cliente
    -> registrar vehículo
    -> asociarlo con el cliente
    -> consultar la información

## 6. Entidades y tablas que toca este sprint

| Entidad / tabla | Acción en este sprint |
|-----------------|-----------------------|
| `users`         | crear tabla (con `username` único y `email` único), registrar, consultar, autenticar por usuario o correo |
| `clients`       | crear tabla, registrar, consultar, editar |
| `vehicles`      | crear tabla, registrar, consultar, asociar a cliente |

## 7. Requisitos funcionales (EARS)

### 7.1 Autenticación (US1)

- **FR-001** (evento): CUANDO un usuario envíe un identificador y una contraseña válidos, el backend DEBERÁ devolver un token JWT válido.
- **FR-002** (ubicuo): El backend DEBERÁ aceptar en un mismo campo de login el nombre de usuario o el correo electrónico, para todos los roles. *(RN-16)*
- **FR-003** (no deseado): SI el identificador o la contraseña no son correctos, ENTONCES el backend DEBERÁ rechazar el login con un mensaje de error en español que no revele cuál de los dos datos falló.
- **FR-004** (ubicuo): El backend DEBERÁ almacenar las contraseñas únicamente como hash bcrypt y verificarlas contra ese hash.
- **FR-005** (no deseado): SI una petición a un endpoint protegido llega sin token o con un token inválido o vencido, ENTONCES el backend DEBERÁ rechazarla como no autenticada.
- **FR-006** (ubicuo): La base de datos DEBERÁ contener las cuentas iniciales `admin`, `recepcion` y `mecanico`, con las contraseñas del estándar del MVP almacenadas con hash bcrypt. *(RN-17)*

### 7.2 Autorización por roles (US2)

- **FR-007** (evento): CUANDO se reciba una petición a un endpoint protegido, el backend DEBERÁ validar en cada petición que el rol del usuario (`ADMIN`, `RECEPTIONIST` o `MECHANIC`) tiene permiso para la operación. *(RN-5, RN-15)*
- **FR-008** (no deseado): SI un usuario autenticado intenta una operación que su rol no permite, ENTONCES el backend DEBERÁ rechazarla como no autorizada, aunque el frontend oculte el control correspondiente. *(RN-15)*
- **FR-009** (estado): MIENTRAS el usuario tenga el rol `ADMIN`, el sistema DEBERÁ permitirle registrar, consultar y modificar usuarios y sus roles.
- **FR-010** (no deseado): SI un usuario sin rol `ADMIN` intenta gestionar usuarios o roles, ENTONCES el backend DEBERÁ rechazar la operación.
- **FR-011** (ubicuo): El sistema DEBERÁ mantener `username` y `email` únicos en `users`.
- **FR-012** (no deseado): SI se intenta registrar o editar un usuario con un `username` o `email` ya existente, ENTONCES el backend DEBERÁ rechazar la operación e indicar qué campo está duplicado.

### 7.3 Contraseñas (US1, US2)

- **FR-013** (evento): CUANDO un usuario autenticado solicite cambiar su contraseña con datos válidos, el backend DEBERÁ guardar la nueva contraseña con hash bcrypt.
- **FR-014** (no deseado): SI la nueva contraseña no cumple la política mínima (8 caracteres, una mayúscula, una minúscula y un número), ENTONCES el backend DEBERÁ rechazar el cambio e indicar qué requisito falta. *(RN-17)*

### 7.4 Clientes (US3, US4)

- **FR-015** (estado): MIENTRAS el usuario tenga permiso sobre clientes, el sistema DEBERÁ permitirle registrar un cliente con sus datos de contacto.
- **FR-016** (evento): CUANDO un usuario autorizado consulte un cliente, el backend DEBERÁ devolver sus datos y la lista de sus vehículos asociados.
- **FR-017** (evento): CUANDO un usuario autorizado consulte el listado de clientes, el backend DEBERÁ devolver los clientes registrados.
- **FR-018** (evento): CUANDO un usuario autorizado envíe datos válidos para editar un cliente, el backend DEBERÁ actualizar el registro y devolver los datos actualizados.
- **FR-019** (no deseado): SI los datos de un cliente son inválidos o están incompletos, ENTONCES el backend DEBERÁ rechazar la operación con un mensaje de error en español que indique los campos incorrectos.
- **FR-020** (no deseado): SI un usuario sin permiso intenta registrar o editar un cliente, ENTONCES el backend DEBERÁ rechazar la operación. *(RN-5)*
- **FR-021** (evento): CUANDO el usuario vaya a guardar cambios sobre un cliente, el frontend DEBERÁ solicitar confirmación antes de enviarlos. *(CA-12, design-system)*

### 7.5 Vehículos y propietario (US5, US6)

- **FR-022** (evento): CUANDO un usuario autorizado registre un vehículo con datos válidos y un propietario existente, el backend DEBERÁ crear el vehículo asociado a ese cliente.
- **FR-023** (no deseado): SI se intenta crear un vehículo sin propietario, ENTONCES el backend DEBERÁ rechazar la operación. *(RN-1)*
- **FR-024** (no deseado): SI el propietario indicado no existe, ENTONCES el backend DEBERÁ rechazar la operación con un mensaje de error en español.
- **FR-025** (evento): CUANDO un usuario autorizado consulte un vehículo, el backend DEBERÁ devolver sus datos y los de su propietario.
- **FR-026** (evento): CUANDO un usuario autorizado asocie un vehículo con un cliente, el backend DEBERÁ guardar el vínculo y reflejarlo en la consulta del cliente.
- **FR-027** (no deseado): SI un usuario sin permiso intenta registrar o asociar un vehículo, ENTONCES el backend DEBERÁ rechazar la operación. *(RN-5)*

### 7.6 Persistencia y datos iniciales

- **FR-028** (ubicuo): El sistema DEBERÁ persistir los datos en MySQL local, con motor InnoDB, llaves foráneas y codificación `utf8mb4`.
- **FR-029** (ubicuo): El esquema inicial DEBERÁ estar en `database/migrations/` como scripts SQL numerados e inmutables, y DEBERÁ poder recrearse desde cero.
- **FR-030** (evento): CUANDO se ejecute de nuevo un script de migración o de seeds, el sistema DEBERÁ conservar los datos existentes y no duplicar registros (idempotencia), registrando las migraciones en `schema_migrations`.
- **FR-031** (evento): CUANDO termine la instalación del sistema, la base de datos DEBERÁ contener datos de ejemplo suficientes para que la aplicación muestre información al arrancar.
- **FR-032** (no deseado): SI el frontend necesita datos persistidos, ENTONCES DEBERÁ obtenerlos únicamente a través del backend y nunca conectarse directamente a MySQL.

### 7.7 Estructura, configuración y seguridad del repositorio

- **FR-033** (ubicuo): El backend DEBERÁ usar ES Modules (`import`/`export`), y su `package.json` DEBERÁ declarar `"type": "module"`.
- **FR-034** (ubicuo): El repositorio DEBERÁ incluir un `.env.example` con `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD` y `DB_NAME`, sin valores sensibles.
- **FR-035** (ubicuo): El repositorio DEBERÁ excluir `.env` mediante `.gitignore` y no DEBERÁ contener secretos.
- **FR-036** (ubicuo): Las pruebas de integración DEBERÁN ejecutarse contra la base `motorix_test` y nunca contra la base principal.

### 7.8 Interfaz (aplica a toda pantalla del sprint)

- **FR-037** (ubicuo): El frontend DEBERÁ seguir `docs/design-system.md` en todas sus pantallas (paleta, tipografía, tokens, transiciones suaves y confirmaciones obligatorias).
- **FR-038** (ubicuo): El frontend DEBERÁ mostrar en español todos los textos y mensajes de error al usuario.

## 8. Trazabilidad

| Historia | Requisitos |
|----------|-----------|
| US1 | FR-001 a FR-006, FR-013, FR-014 |
| US2 | FR-007 a FR-012 |
| US3 | FR-015 a FR-017, FR-019 a FR-021 |
| US4 | FR-018 a FR-021 |
| US5 | FR-022 a FR-025, FR-027 |
| US6 | FR-022 a FR-027 |
| Transversales | FR-028 a FR-038 |

| Criterio original | Requisitos que lo cubren |
|-------------------|--------------------------|
| CA-1 | FR-001, FR-004 |
| CA-2 | FR-007, FR-008 |
| CA-3 | FR-015, FR-022, FR-026, FR-028 |
| CA-4 | FR-016 |
| CA-5 | FR-033 |
| CA-6 | FR-029 |
| CA-7 | FR-034 |
| CA-8 | FR-035 |
| CA-9 | FR-002 |
| CA-10 | FR-006 |
| CA-11 | FR-013, FR-014 |
| CA-12 | FR-021, FR-037 |

## 9. Reglas de negocio aplicables

- RN-1: No crear un vehículo sin propietario.
- RN-5: Solo usuarios autorizados pueden modificar registros.
- RN-15: Los permisos deben validarse en backend; ocultar botones en frontend no es seguridad suficiente.
- RN-16: El login acepta usuario o correo electrónico en el mismo campo.
- RN-17: Las contraseñas del estándar del MVP solo aplican a las cuentas iniciales y en entornos locales; al cambiarlas, deben cumplir la política mínima de seguridad.

## 10. Criterios de éxito verificables

Cada criterio debe poder comprobarse con una prueba (Jest + supertest en backend, `flutter test` en frontend).

- **SC-001**: Un usuario con credenciales válidas obtiene un JWT y accede a un endpoint protegido (FR-001, FR-005).
- **SC-002**: Para cada endpoint protegido existe una prueba por rol que confirma el permiso o el rechazo (FR-007, FR-008).
- **SC-003**: El flujo completo "login, registrar cliente, registrar vehículo, asociar, consultar" funciona contra MySQL local (FR-015, FR-022, FR-026, FR-016).
- **SC-004**: Un vehículo sin propietario es rechazado en el 100 % de los intentos (FR-023).
- **SC-005**: Ejecutar migraciones y seeds dos veces seguidas no produce duplicados ni errores (FR-030).
- **SC-006**: Una búsqueda en el repositorio no encuentra secretos y `.env` está ignorado (FR-035).

## 11. Casos límite a especificar

- Login con identificador en distinta capitalización o con espacios al inicio o al final. [NEEDS CLARIFICATION: ¿se normaliza el identificador?]
- Duración y renovación del token JWT. [NEEDS CLARIFICATION: tiempo de vida del token]
- Datos obligatorios y formato del cliente (teléfono, correo) y del vehículo (placa, VIN, año). [NEEDS CLARIFICATION: campos y validaciones]
- Reasignar un vehículo a otro cliente: ¿se permite en este sprint? [NEEDS CLARIFICATION]
- Desactivar un usuario frente a eliminarlo. [NEEDS CLARIFICATION]
- Qué operaciones sobre clientes y vehículos puede hacer el rol `MECHANIC` (¿solo consulta?). [NEEDS CLARIFICATION]

## 12. Fuera de alcance de este sprint

- Citas.
- Órdenes de servicio.
- Inventario y refacciones.
- Pagos y Mercado Pago.
- Tickets.
- Dashboard.
- Chatbot de WhatsApp.
- Recuperación de contraseña (incluida la recuperación por correo).
- Registro público de usuarios.
- Modo oscuro.

## 13. Decisiones

Ya resueltas para el MVP; NO deben reabrirse sin aprobación del equipo:

- **Frontend**: Flutter + Dart con Material Design 3 y Provider para estado. Sistema de diseño en `docs/design-system.md`.
- **Acceso a datos desde Node.js**: driver `mysql2` directo, sin ORM ni query builder. Debe ser compatible con ES Modules.
- **MySQL local**: instalación nativa, no Docker, con usuario dedicado `motorix_app`.
- **Herramienta de migraciones**: scripts SQL numerados e inmutables en `database/migrations/`, ejecutados por scripts idempotentes con registro en `schema_migrations`.
- **Pruebas**: Jest + supertest en backend (unitarias, de integración y de contrato contra `motorix_test`); `flutter test` en frontend.

Se resuelven en `/speckit.clarify` para este sprint:

- Librería complementaria de componentes de UI en Flutter (o ninguna).
- Set de iconos definitivo.
- Estructura exacta del sidebar y pantallas iniciales del Sprint 1.
- Los puntos marcados con `[NEEDS CLARIFICATION]` en la sección 11.

## 14. Restricciones técnicas heredadas

- Backend en ES Modules, nunca CommonJS.
- Solo el backend accede a MySQL; el frontend nunca se conecta directo.
- Permisos validados en backend, no solo en UI.
- Sin secretos en el repositorio.
- Idioma: español en chat, docs, comentarios y pruebas.
- MySQL local, InnoDB, llaves foráneas, `utf8mb4`.
- Login acepta usuario o correo electrónico en el mismo campo.
- Toda pantalla del frontend sigue `docs/design-system.md`.
- Pruebas de integración contra `motorix_test`, nunca contra la base principal.
- Los seeds del sprint DEBEN incluir datos de ejemplo suficientes para que la aplicación muestre información al arrancar. La base no puede quedar vacía tras la instalación.
- Los seeds DEBEN ser idempotentes: si se corren de nuevo, no duplican registros.
