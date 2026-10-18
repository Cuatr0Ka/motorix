# Especificación de la funcionalidad: Base del sistema, clientes y vehículos (Sprint 1)

**Rama de la funcionalidad**: `001-base-clientes-vehiculos`

**Creada**: 2026-10-10

**Estado**: Borrador

**Entrada**: Descripción del usuario: "Usa la descripción de docs/sprints/sprint-1-base-clientes-vehiculos.md"

## Aclaraciones

### Sesión 2026-10-10

- Q: ¿Qué debe hacer el sistema cuando un cliente nuevo repite el teléfono o el correo de otro? → A: El correo es único (si se captura) y se rechaza el repetido; el teléfono puede repetirse, pero se muestra una advertencia de posible duplicado.
- Q: ¿Qué opciones muestra el menú lateral a cada rol y cuál es la pantalla inicial? → A: Menú con Inicio, Clientes y Vehículos para todos los roles, y Usuarios solo para ADMIN; la pantalla inicial es una pantalla de Inicio de bienvenida con accesos directos, previa al listado de Clientes.
- Q: ¿Qué librería complementaria de componentes de interfaz se usará? → A: Ninguna; solo el tema propio del sistema de diseño y las librerías de apoyo ya permitidas en `docs/design-system.md`.
- Q: ¿Qué set de íconos usará la interfaz? → A: El set de íconos estándar de la plataforma de interfaz, sin dependencia adicional.
- Q: ¿Desde cuándo se aplica la desactivación o el cambio de rol de un usuario con sesión iniciada? → A: De inmediato; en cada solicitud se valida que el usuario siga activo y con su rol actual.

## Escenarios de usuario y pruebas *(obligatorio)*

### Historia de usuario 1 - Iniciar sesión según mi rol (Prioridad: P1)

Como usuario del taller (administrador, recepcionista o mecánico), quiero iniciar sesión con mi
usuario o correo electrónico y mi contraseña para acceder únicamente a las funciones que
corresponden a mi rol.

**Por qué esta prioridad**: Sin acceso autenticado no se puede usar ninguna otra función; es la
base de todo el sistema y de los sprints posteriores.

**Prueba independiente**: Se prueba iniciando sesión con cada una de las tres cuentas iniciales,
tanto con el usuario como con el correo, y verificando que cada una ve solo lo permitido a su rol.

**Escenarios de aceptación**:

1. **Dado** una cuenta activa con usuario `recepcion`, **cuando** escribo ese usuario y su
   contraseña correcta en el campo de acceso, **entonces** entro al sistema con la sesión de mi rol.
2. **Dado** la misma cuenta, **cuando** escribo su correo electrónico en el mismo campo con la
   contraseña correcta, **entonces** entro igualmente al sistema.
3. **Dado** una contraseña incorrecta o una cuenta inexistente, **cuando** intento iniciar sesión,
   **entonces** veo un mensaje de error genérico que no revela cuál de los dos datos falló.
4. **Dado** una cuenta desactivada, **cuando** intento iniciar sesión, **entonces** el acceso se
   rechaza con un mensaje claro.
5. **Dado** que ya inicié sesión, **cuando** intento una acción que mi rol no permite, **entonces**
   el sistema la rechaza aunque la solicitud se haga sin pasar por la interfaz.
6. **Dado** que mi sesión expiró o no existe, **cuando** intento acceder a una función protegida,
   **entonces** se me solicita iniciar sesión de nuevo.

---

### Historia de usuario 2 - Gestionar usuarios y roles (Prioridad: P2)

Como administrador, quiero gestionar usuarios y roles de acceso para controlar quién puede usar el
sistema.

**Por qué esta prioridad**: Permite administrar el acceso, pero el sistema ya es demostrable con
las cuentas iniciales; por eso va después de clientes y vehículos en valor de negocio directo.

**Prueba independiente**: Se prueba, con la cuenta de administrador, creando un usuario con un rol,
consultándolo, cambiando su rol y desactivándolo, y comprobando que otro rol no puede hacerlo.

**Escenarios de aceptación**:

1. **Dado** que soy administrador, **cuando** registro un usuario con nombre de usuario, correo,
   rol y contraseña inicial válida, **entonces** el usuario queda creado y puede iniciar sesión.
2. **Dado** un nombre de usuario o correo que ya existe, **cuando** intento registrarlo, **entonces**
   el sistema lo rechaza indicando el campo duplicado.
3. **Dado** que soy administrador, **cuando** cambio el rol de un usuario o lo desactivo,
   **entonces** el cambio se aplica de inmediato, incluso si esa persona ya tenía una sesión
   iniciada: su siguiente solicitud se valida con el estado y el rol vigentes.
4. **Dado** que soy recepcionista o mecánico, **cuando** intento ver o modificar usuarios,
   **entonces** el sistema lo rechaza.
5. **Dado** cualquier usuario con sesión iniciada, **cuando** cambio mi contraseña, **entonces** el
   sistema exige que cumpla la política mínima (8 caracteres, con mayúscula, minúscula y número) y
   rechaza las que no la cumplan.

---

### Historia de usuario 3 - Registrar y consultar clientes (Prioridad: P1)

Como recepcionista, quiero registrar y consultar clientes para mantener actualizada la información
de los propietarios.

**Por qué esta prioridad**: Todo vehículo necesita un propietario; los clientes son el primer dato
de negocio del sistema.

**Prueba independiente**: Se prueba registrando un cliente, buscándolo en el listado y abriendo su
detalle, con la sesión de recepcionista.

**Escenarios de aceptación**:

1. **Dado** que soy recepcionista, **cuando** registro un cliente con los datos obligatorios,
   **entonces** aparece en el listado de clientes.
2. **Dado** datos obligatorios faltantes o con formato inválido, **cuando** intento guardar,
   **entonces** el sistema indica qué campos corregir y no guarda nada.
3. **Dado** que hay varios clientes registrados, **cuando** busco por nombre o teléfono,
   **entonces** veo solo los que coinciden.
4. **Dado** un cliente con vehículos asociados, **cuando** abro su detalle, **entonces** veo sus
   datos y la lista de sus vehículos.
5. **Dado** que soy mecánico, **cuando** consulto clientes, **entonces** puedo verlos pero no
   crearlos ni modificarlos.

---

### Historia de usuario 4 - Editar clientes (Prioridad: P2)

Como recepcionista, quiero editar la información de los clientes para corregir o actualizar sus
datos.

**Por qué esta prioridad**: Es una corrección de datos ya registrados; depende de que existan
clientes (Historia 3).

**Prueba independiente**: Se prueba modificando el teléfono de un cliente existente y comprobando
que el nuevo valor se ve en el listado y en el detalle.

**Escenarios de aceptación**:

1. **Dado** un cliente existente, **cuando** cambio sus datos y confirmo, **entonces** los cambios
   se guardan y se muestran de inmediato.
2. **Dado** una edición con datos inválidos, **cuando** intento guardar, **entonces** se rechaza y
   los datos anteriores se conservan.
3. **Dado** que soy mecánico, **cuando** intento editar un cliente, **entonces** el sistema lo
   rechaza.

---

### Historia de usuario 5 - Registrar vehículos (Prioridad: P1)

Como recepcionista, quiero registrar vehículos para llevar el control de los automóviles atendidos.

**Por qué esta prioridad**: El vehículo es el eje de las órdenes de servicio de los sprints
siguientes.

**Prueba independiente**: Se prueba registrando un vehículo con sus datos y verificando que se
puede consultar en el listado de vehículos.

**Escenarios de aceptación**:

1. **Dado** que soy recepcionista, **cuando** registro un vehículo con placa, marca, modelo y año,
   **entonces** queda guardado y aparece en el listado.
2. **Dado** una placa que ya pertenece a otro vehículo, **cuando** intento registrarlo, **entonces**
   el sistema lo rechaza indicando el duplicado.
3. **Dado** datos inválidos (por ejemplo, un año imposible), **cuando** intento guardar, **entonces**
   se rechaza con mensajes claros.
4. **Dado** que soy mecánico, **cuando** consulto vehículos, **entonces** puedo verlos pero no
   crearlos ni modificarlos.

---

### Historia de usuario 6 - Asociar un vehículo con su propietario (Prioridad: P1)

Como recepcionista, quiero asociar un vehículo con su propietario para vincular la información
correctamente.

**Por qué esta prioridad**: Es una regla de negocio obligatoria: no puede existir un vehículo sin
propietario.

**Prueba independiente**: Se prueba intentando registrar un vehículo sin cliente (debe fallar) y
luego con un cliente existente (debe funcionar), y viendo el vehículo en el detalle del cliente.

**Escenarios de aceptación**:

1. **Dado** un cliente existente, **cuando** registro un vehículo y lo asocio a ese cliente,
   **entonces** el vehículo aparece en el detalle del cliente y su propietario se muestra en el
   detalle del vehículo.
2. **Dado** que no selecciono propietario o selecciono uno inexistente, **cuando** intento guardar
   el vehículo, **entonces** el sistema lo rechaza.
3. **Dado** un vehículo ya registrado, **cuando** cambio su propietario a otro cliente existente y
   confirmo, **entonces** el vehículo deja de aparecer en el cliente anterior y aparece en el nuevo.

---

### Casos límite

- Intentar iniciar sesión con campos vacíos o con espacios en blanco al inicio o al final.
- Registrar dos usuarios cuyo usuario o correo difieren solo en mayúsculas y minúsculas.
- Desactivar o cambiar de rol al único administrador activo, que dejaría el sistema sin quien lo
  administre.
- Cambiar una contraseña por una que no cumple la política, o por la misma contraseña actual.
- Registrar un cliente con un correo ya existente (se rechaza) o con un teléfono ya existente (se
  advierte de un posible duplicado y se permite continuar tras confirmar).
- Consultar un cliente que no existe o un vehículo que no existe.
- Cambiar el propietario de un vehículo a un cliente inexistente.
- Intentar eliminar un cliente que ya tiene vehículos asociados.
- Reejecutar la carga de datos de ejemplo: no debe duplicar registros.
- Usar una sesión cuyo rol fue cambiado o cuya cuenta fue desactivada después de iniciar sesión:
  la siguiente solicitud se rechaza o se evalúa con el rol nuevo, sin esperar a que expire.

## Requisitos *(obligatorio)*

### Requisitos funcionales

- **FR-001**: El sistema DEBE permitir iniciar sesión con un único campo que acepta usuario o
  correo electrónico, más una contraseña, para todos los roles.
- **FR-002**: El sistema DEBE emitir, tras un inicio de sesión exitoso, una credencial de sesión
  con vigencia limitada y rechazar el acceso a funciones protegidas cuando falte, sea inválida o
  haya expirado.
- **FR-003**: El sistema DEBE almacenar las contraseñas únicamente de forma cifrada irreversible;
  nunca en texto plano ni visibles en respuestas, registros o la interfaz.
- **FR-004**: El sistema DEBE manejar tres roles: administrador (ADMIN), recepcionista
  (RECEPTIONIST) y mecánico (MECHANIC), y validar el permiso del rol en cada operación protegida
  del lado del servidor, con independencia de lo que muestre la interfaz.
- **FR-005**: El sistema DEBE incluir tres cuentas iniciales (`admin`, `recepcion`, `mecanico`)
  con las contraseñas del estándar del MVP, disponibles solo para entornos locales.
- **FR-006**: Los administradores DEBEN poder registrar, consultar, cambiar el rol y activar o
  desactivar usuarios; el nombre de usuario y el correo DEBEN ser únicos. La desactivación y el
  cambio de rol DEBEN surtir efecto de inmediato, validando en cada solicitud que el usuario siga
  activo y con su rol vigente.
- **FR-007**: Todo usuario con sesión iniciada DEBE poder cambiar su contraseña; el sistema DEBE
  validar la política mínima (8 caracteres, al menos una mayúscula, una minúscula y un número)
  tanto en cambios como en altas de usuarios.
- **FR-008**: Inicio de sesión rechazado, bloqueo y reinicio del contador (EARS):
  - **FR-008a** (no deseado): SI la cuenta está desactivada, ENTONCES el backend DEBERÁ rechazar
    el inicio de sesión con un mensaje claro.
  - **FR-008b** (no deseado): SI el usuario o la contraseña son incorrectos, ENTONCES el backend
    DEBERÁ rechazar el inicio de sesión con un mensaje en español que no indique cuál de los dos
    datos falló.
  - **FR-008c** (evento): CUANDO una cuenta acumule 5 intentos fallidos consecutivos, el backend
    DEBERÁ bloquearla durante 15 minutos e informarlo con un mensaje claro.
  - **FR-008d** (evento): CUANDO una cuenta inicie sesión correctamente, el backend DEBERÁ
    reiniciar a cero su contador de intentos fallidos.
- **FR-009**: Recepcionistas y administradores DEBEN poder registrar, consultar y editar clientes
  con datos de contacto (nombre completo, teléfono, correo electrónico y dirección opcional). El
  correo, si se captura, DEBE ser único entre clientes; un teléfono ya registrado en otro cliente
  DEBE generar una advertencia de posible duplicado, sin impedir el guardado tras confirmar.
- **FR-010**: El sistema DEBE ofrecer un listado de clientes con búsqueda por nombre o teléfono y
  un detalle de cliente que muestre sus datos y sus vehículos asociados.
- **FR-011**: Recepcionistas y administradores DEBEN poder registrar, consultar y editar
  vehículos con placa, marca, modelo, año, color opcional y kilometraje actual opcional; la placa
  DEBE ser única.
- **FR-012**: Propietario obligatorio del vehículo (EARS):
  - **FR-012a** (no deseado): SI se intenta registrar un vehículo sin propietario, ENTONCES el
    backend DEBERÁ rechazar la operación.
  - **FR-012b** (no deseado): SI el propietario indicado no existe, ENTONCES el backend DEBERÁ
    rechazar la operación con un mensaje de error en español.
  - **FR-012c** (evento): CUANDO un usuario autorizado registre un vehículo con datos válidos y
    un propietario existente, el backend DEBERÁ crear el vehículo asociado a ese cliente.
- **FR-013**: El sistema DEBE permitir cambiar el propietario de un vehículo hacia otro cliente
  existente, solicitando confirmación previa.
- **FR-014**: Los mecánicos DEBEN poder consultar clientes y vehículos, sin poder crearlos ni
  modificarlos.
- **FR-015**: El sistema DEBE validar en el servidor todos los datos recibidos (formato, longitud,
  obligatoriedad, duplicados) y devolver mensajes claros en español sin exponer detalles internos.
- **FR-016**: El sistema DEBE pedir confirmación antes de cualquier acción destructiva o de
  cambio sensible (por ejemplo, desactivar un usuario o cambiar el propietario de un vehículo) y
  mostrar mensajes de éxito o error tras cada acción.
- **FR-017**: El sistema DEBE impedir que quede el sistema sin al menos un administrador activo.
- **FR-018**: El sistema DEBE conservar la información de forma persistente entre sesiones y
  reinicios, y permitir recrear el esquema de datos completo desde cero.
- **FR-019**: El sistema DEBE incluir datos de ejemplo (usuarios, clientes y vehículos asociados)
  suficientes para mostrar información al primer arranque, y su carga DEBE ser repetible sin
  duplicar registros.
- **FR-020**: Toda pantalla DEBE seguir el sistema de diseño del proyecto (`docs/design-system.md`)
  y mostrar solo las opciones que el rol del usuario puede usar. El menú lateral DEBE ofrecer
  Inicio, Clientes y Vehículos a todos los roles, y Usuarios únicamente al administrador.
- **FR-022**: Al iniciar sesión, el sistema DEBE mostrar una pantalla de Inicio de bienvenida con
  el nombre y rol de la persona y accesos directos a las secciones que su rol puede usar (sin
  indicadores ni estadísticas, que quedan fuera del alcance).
- **FR-021**: El sistema DEBE mantener fuera del alcance de este sprint: citas, órdenes de
  servicio, inventario, pagos, tickets, panel de indicadores, chatbot, recuperación de contraseña,
  registro público de usuarios y modo oscuro.

### Criterios de aceptación en EARS

Los requisitos FR-008 y FR-012 están redactados con la sintaxis EARS (Easy Approach to
Requirements Syntax): un solo DEBERÁ por requisito, sujeto explícito (backend o frontend) y
respuesta observable. El resto de los requisitos conserva la redacción con "DEBE" y se migrará
a EARS en una revisión posterior; la versión completa en EARS está en
`docs/sprints/sprint-1-base-clientes-vehiculos-ears.md`.

| Requisito | Patrón | Escenario relacionado | Dato medible | Prueba |
|-----------|--------|-----------------------|--------------|--------|
| FR-008a | No deseado | Historia 1, escenario 4 | Cuenta desactivada rechazada en el 100 % de los intentos | Backend (Jest + supertest) |
| FR-008b | No deseado | Historia 1, escenario 3 | El mensaje no incluye cuál dato falló | Backend (Jest + supertest) |
| FR-008c | Evento | Casos límite de sesión | 5 intentos fallidos y 15 minutos de bloqueo | Backend (Jest + supertest) |
| FR-008d | Evento | Historia 1, escenarios 1 y 2 | Contador en 0 tras un acceso correcto | Backend (Jest + supertest) |
| FR-012a | No deseado | Historia 6, escenario 2 | Cero vehículos sin propietario creados (SC-009) | Backend (Jest + supertest) |
| FR-012b | No deseado | Historia 6, escenario 2 | Propietario inexistente rechazado en el 100 % de los intentos | Backend (Jest + supertest) |
| FR-012c | Evento | Historia 6, escenario 1 | Vehículo visible en el detalle del cliente | Backend (Jest + supertest) |

### Entidades clave *(incluir si la funcionalidad involucra datos)*

- **Usuario**: Persona con acceso al sistema. Tiene nombre de usuario único, correo único, rol
  (administrador, recepcionista o mecánico), estado activo o inactivo y contraseña cifrada.
- **Cliente**: Propietario de uno o más vehículos. Tiene nombre completo, teléfono, correo
  electrónico (único si se captura) y dirección opcional. Se relaciona con cero o más vehículos.
- **Vehículo**: Automóvil atendido en el taller. Tiene placa única, marca, modelo, año, color y
  kilometraje actual opcionales. Pertenece obligatoriamente a un cliente.

## Criterios de éxito *(obligatorio)*

### Resultados medibles

- **SC-001**: Un usuario con cuenta válida inicia sesión y llega a su pantalla de Inicio en menos
  de 10 segundos.
- **SC-002**: El 100 % de las operaciones protegidas rechaza a los roles no autorizados, aun
  cuando la solicitud no provenga de la interfaz.
- **SC-003**: Una recepcionista completa el flujo "iniciar sesión → registrar cliente → registrar
  vehículo asociado → consultar el cliente con su vehículo" en menos de 5 minutos, sin ayuda.
- **SC-004**: El 90 % de las personas de prueba registra un cliente y un vehículo correctos en el
  primer intento, sin necesidad de capacitación.
- **SC-005**: Ninguna contraseña aparece en texto legible en la base de datos, en registros ni en
  respuestas del sistema.
- **SC-006**: Tras una instalación nueva, el sistema muestra clientes y vehículos de ejemplo sin
  capturar nada a mano, y repetir la carga de ejemplo no genera duplicados.
- **SC-007**: El esquema completo se recrea desde cero, en un equipo limpio, en menos de 10
  minutos siguiendo la documentación.
- **SC-008**: Los listados de clientes y vehículos, con hasta 1 000 registros, muestran
  resultados de búsqueda en menos de 2 segundos.
- **SC-009**: Cero intentos de crear un vehículo sin propietario tienen éxito.

## Suposiciones

- Los usuarios son personal interno del taller; no existe registro público ni acceso de clientes.
- Matriz de permisos asumida: ADMIN puede todo, incluida la gestión de usuarios; RECEPTIONIST
  crea y edita clientes y vehículos; MECHANIC solo consulta clientes y vehículos.
- Los usuarios se desactivan, no se eliminan, para conservar la trazabilidad.
- Los clientes y vehículos no se eliminan en este sprint; la baja queda para un sprint posterior.
- Datos obligatorios del cliente: nombre completo y teléfono; el correo y la dirección son
  opcionales, y el correo, si se captura, debe tener formato válido.
- La contraseña del estándar del MVP aplica solo a las cuentas iniciales y a entornos locales;
  cualquier contraseña nueva debe cumplir la política mínima (FR-007).
- La vigencia de la sesión es de una jornada laboral estándar (por ejemplo, 8 horas).
- La aplicación es de uso en escritorio como prioridad, en español y en un solo idioma.
- Las decisiones de tecnología ya están fijadas por la constitución del proyecto
  (`.specify/memory/constitution.md`) y se tratarán en la fase de planeación, no aquí.
- No se usa librería complementaria de componentes de interfaz; solo las de apoyo ya permitidas
  por el sistema de diseño.
- El set de íconos es el estándar de la plataforma de interfaz, sin dependencia adicional.
- Dependencias: `docs/project-context.md` (alcance), `docs/design-system.md` (interfaz) y
  `docs/reglas.md` (reglas del proyecto).
