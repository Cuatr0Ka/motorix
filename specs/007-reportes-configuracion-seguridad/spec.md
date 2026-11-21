# Especificación de la funcionalidad: Reportes, configuración, términos y seguridad (Sprint 7)

**Rama de la funcionalidad**: `007-reportes-configuracion-seguridad`

**Creada**: 2026-11-21

**Estado**: Borrador

**Entrada**: Descripción del usuario: "Sprint 7: Reportes, configuración del taller, términos y condiciones y seguridad de la información. Usar como insumo docs/sprints/sprint-7-reportes-configuracion.md"

## Escenarios de usuario y pruebas *(obligatorio)*

### Historia de usuario 1 - Editar los datos del taller (Prioridad: P1)

Como administrador, quiero editar el nombre, la dirección y el teléfono del taller para que el ticket muestre
datos correctos sin tocar el servidor.

**Por qué esta prioridad**: Hoy esos datos solo se cambian con acceso al servidor y reiniciándolo; es la base de la
configuración y desbloquea lo demás.

**Prueba independiente**: El administrador cambia el nombre y el teléfono del taller, genera un ticket nuevo y ve los
datos actualizados; un ticket anterior se ve igual que cuando se emitió.

**Escenarios de aceptación**:

1. **Dado** que soy administrador, **cuando** edito el nombre, la dirección y el teléfono del taller y guardo,
   **entonces** los cambios se guardan y la pantalla los muestra.
2. **Dado** nuevos datos del taller, **cuando** se genera un ticket, **entonces** el ticket nuevo los muestra.
3. **Dado** un ticket emitido antes del cambio, **cuando** lo consulto o lo imprimo, **entonces** conserva los datos
   con los que se emitió.
4. **Dado** un nombre vacío o con más caracteres de los permitidos, **cuando** intento guardar, **entonces** el
   sistema lo rechaza indicando el campo y el motivo.
5. **Dado** una instalación sin datos guardados, **cuando** se genera un ticket, **entonces** se usan los valores
   que ya existían en la configuración del servidor, de modo que el sistema sigue funcionando.
6. **Dado** que soy recepcionista o mecánico, **cuando** intento ver o cambiar la configuración, **entonces** el
   sistema lo rechaza.

---

### Historia de usuario 2 - Ajustar los márgenes de «Próximo» del mantenimiento (Prioridad: P2)

Como administrador, quiero ajustar los márgenes de «Próximo» del mantenimiento (en días y en kilómetros) para
adaptarlos a la operación del taller.

**Por qué esta prioridad**: Mejora una regla que ya funciona con valores fijos; no bloquea al resto del sprint.

**Prueba independiente**: El administrador cambia el margen de 30 a 15 días y verifica que un mantenimiento a 20 días
deja de ser «Próximo» en la lista de Mantenimientos, en el panel de control y en los avisos.

**Escenarios de aceptación**:

1. **Dado** que soy administrador, **cuando** cambio el margen en días o en kilómetros con valores válidos,
   **entonces** se guarda y se usa en adelante.
2. **Dado** un nuevo margen, **cuando** consulto la lista de Mantenimientos, el panel de control o los avisos,
   **entonces** los tres usan el mismo margen y sus números coinciden.
3. **Dado** un valor fuera de los límites válidos (cero, negativo, no numérico o demasiado grande), **cuando** intento
   guardar, **entonces** el sistema lo rechaza indicando el límite.
4. **Dado** una instalación sin márgenes guardados, **cuando** se calcula el indicador, **entonces** se usan 30 días
   y 1 000 km, o los valores de la configuración del servidor si existen.

---

### Historia de usuario 3 - Catálogo de tipos de servicio con intervalos (Prioridad: P1)

Como administrador, quiero mantener un catálogo de tipos de servicio con su intervalo en días y en kilómetros para
que el próximo mantenimiento se proponga sin asumir intervalos universales.

**Por qué esta prioridad**: La regla de negocio 12 pide intervalos configurables; sin catálogo el próximo
mantenimiento se captura a mano en cada orden.

**Prueba independiente**: El administrador crea el tipo «Cambio de aceite» con 180 días y 5 000 km, termina una orden
con ese servicio y el sistema propone el próximo mantenimiento con esa fecha y ese kilometraje, que el usuario puede
corregir.

**Escenarios de aceptación**:

1. **Dado** que soy administrador, **cuando** creo un tipo de servicio con nombre y, al menos, un intervalo en días o
   en kilómetros, **entonces** queda en el catálogo y se puede usar.
2. **Dado** un tipo ya usado en órdenes, **cuando** lo edito o lo desactivo, **entonces** se conserva y las órdenes
   anteriores no cambian; un tipo no se borra.
3. **Dado** una orden con un servicio de un tipo con intervalo, **cuando** registro el próximo mantenimiento,
   **entonces** la fecha y el kilometraje se proponen según el intervalo y puedo corregirlos antes de guardar.
4. **Dado** un servicio sin tipo (líneas anteriores al sprint o texto libre), **cuando** registro el próximo
   mantenimiento, **entonces** se captura a mano como hasta ahora.
5. **Dado** un nombre repetido o un intervalo no válido (cero, negativo o no numérico), **cuando** intento guardar,
   **entonces** el sistema lo rechaza indicando el motivo.
6. **Dado** un tipo desactivado, **cuando** agrego un servicio a una orden, **entonces** no se ofrece como opción.

---

### Historia de usuario 4 - Consultar los ingresos por periodo (Prioridad: P2)

Como administrador, quiero consultar los ingresos por periodo para conocer cómo avanza el taller.

**Por qué esta prioridad**: Es el reporte más pedido, pero el panel de control ya muestra una parte de los ingresos.

**Prueba independiente**: El administrador elige un mes y ve el total de ingresos pagados, desglosado por método de
pago y por día, y el total coincide con la suma de los pagos pagados de ese mes.

**Escenarios de aceptación**:

1. **Dado** pagos pagados en un periodo, **cuando** consulto el reporte de ingresos de ese periodo, **entonces** veo
   el total, el desglose por método de pago y por día, y el número de pagos.
2. **Dado** pagos pendientes, rechazados o cancelados, **cuando** consulto el reporte, **entonces** no cuentan como
   ingreso.
3. **Dado** un periodo sin pagos, **cuando** consulto el reporte, **entonces** veo ceros y un mensaje de que no hay
   datos.
4. **Dado** un rango de fechas inválido (fin anterior al inicio) o demasiado amplio, **cuando** consulto, **entonces**
   el sistema lo rechaza indicando el límite.
5. **Dado** que soy recepcionista o mecánico, **cuando** intento consultar el reporte, **entonces** el sistema lo
   rechaza.

---

### Historia de usuario 5 - Servicios frecuentes y productividad por mecánico (Prioridad: P2)

Como administrador, quiero ver los servicios más frecuentes y la productividad por mecánico para tomar decisiones de
operación.

**Por qué esta prioridad**: Orienta la operación, pero depende de que existan datos suficientes del periodo.

**Prueba independiente**: Con órdenes terminadas de dos mecánicos en un mes, el administrador ve los servicios
ordenados por frecuencia y, por mecánico, las órdenes terminadas y el importe de mano de obra.

**Escenarios de aceptación**:

1. **Dado** órdenes con servicios en un periodo, **cuando** consulto los servicios más frecuentes, **entonces** veo
   cada servicio con el número de veces que se realizó, de mayor a menor.
2. **Dado** órdenes terminadas de varios mecánicos, **cuando** consulto la productividad, **entonces** veo, por
   mecánico, las órdenes terminadas y el importe de mano de obra del periodo.
3. **Dado** una orden sin mecánico asignado, **cuando** se calcula la productividad, **entonces** no se atribuye a
   ningún mecánico.
4. **Dado** un periodo sin órdenes, **cuando** consulto los reportes, **entonces** veo el estado vacío.

---

### Historia de usuario 6 - Costo, margen y rotación de las refacciones (Prioridad: P2)

Como administrador, quiero ver el costo, el precio y el margen de las refacciones usadas y la rotación del
inventario para controlar la rentabilidad.

**Por qué esta prioridad**: Aprovecha los precios del Sprint 5; es el reporte más delicado porque maneja el precio de
compra.

**Prueba independiente**: Con refacciones usadas en órdenes del periodo, el administrador ve por refacción las
unidades usadas, el costo, el precio de venta y el margen, y la rotación del inventario.

**Escenarios de aceptación**:

1. **Dado** refacciones usadas en un periodo, **cuando** consulto el reporte, **entonces** veo por refacción las
   unidades, el costo, el precio de venta, el margen en importe y en porcentaje.
2. **Dado** una refacción sin precio de compra o líneas anteriores al Sprint 5 con precio cero, **cuando** se calcula
   el margen, **entonces** esas líneas se señalan como «Sin costo» y no distorsionan el total del margen.
3. **Dado** el periodo, **cuando** consulto la rotación, **entonces** veo las salidas del periodo sobre la existencia
   promedio de cada refacción.
4. **Dado** que soy recepcionista o mecánico, **cuando** intento consultar el reporte, **entonces** el sistema lo
   rechaza y nunca recibo un precio de compra.

---

### Historia de usuario 7 - Exportar los reportes (Prioridad: P2)

Como administrador, quiero exportar cada reporte para compartirlo o archivarlo.

**Por qué esta prioridad**: Cierra el flujo de reportes, pero es opcional si el tiempo se acorta.

**Prueba independiente**: El administrador exporta el reporte de ingresos del mes y el archivo contiene los mismos
datos y filtros que la pantalla.

**Escenarios de aceptación**:

1. **Dado** un reporte en pantalla, **cuando** lo exporto, **entonces** obtengo un archivo con los mismos datos, el
   mismo periodo y los mismos filtros que veo.
2. **Dado** los importes del reporte, **cuando** los exporto, **entonces** coinciden con la pantalla al centavo.
3. **Dado** un reporte vacío, **cuando** lo exporto, **entonces** el archivo trae los encabezados y ninguna fila de
   datos.
4. **Dado** un periodo inválido, **cuando** intento exportar, **entonces** el sistema lo rechaza igual que en pantalla.

---

### Historia de usuario 8 - Próximo servicio en el ticket (Prioridad: P1)

Como cliente, quiero que mi ticket indique cuándo toca mi próximo servicio para recordarlo sin que nadie me escriba.

**Por qué esta prioridad**: Es la forma en que el cliente se entera de su próximo servicio, ya que el sistema no envía
mensajes.

**Prueba independiente**: Con una orden de un tipo de servicio con intervalo y su próximo mantenimiento registrado, el
ticket nuevo muestra la línea «Próximo servicio» con la fecha y el kilometraje; sin próximo mantenimiento, no la
muestra.

**Escenarios de aceptación**:

1. **Dado** una orden con su próximo mantenimiento registrado (fecha, kilometraje o ambos), **cuando** se genera el
   ticket, **entonces** incluye la línea «Próximo servicio» con esos datos.
2. **Dado** una orden sin próximo mantenimiento, **cuando** se genera el ticket, **entonces** la línea no aparece.
3. **Dado** un ticket emitido antes del sprint, **cuando** lo consulto o lo imprimo, **entonces** se ve y se imprime
   igual que cuando se emitió, sin la línea nueva.
4. **Dado** que el próximo mantenimiento se corrige después de emitir el ticket, **cuando** consulto ese ticket,
   **entonces** conserva lo que decía al emitirse.

---

### Historia de usuario 9 - Aceptar los términos y condiciones al ingresar (Prioridad: P1)

Como usuario del taller, quiero leer y aceptar los términos y condiciones y el aviso de privacidad al ingresar al
sistema para conocer las reglas de uso y cómo se protege la información de los clientes.

**Por qué esta prioridad**: El sistema maneja datos personales de clientes; el uso responsable debe quedar aceptado
antes de operar.

**Prueba independiente**: Un usuario que inicia sesión por primera vez ve los términos, los acepta y entra; en el
siguiente ingreso no se los vuelve a pedir; si el administrador publica una versión nueva, se los pide de nuevo.

**Escenarios de aceptación**:

1. **Dado** un usuario que no ha aceptado la versión vigente, **cuando** inicia sesión, **entonces** ve los términos y
   el aviso de privacidad antes de usar el sistema.
2. **Dado** la pantalla de aceptación, **cuando** el usuario los rechaza, **entonces** se cierra su sesión y no
   accede.
3. **Dado** la pantalla de aceptación, **cuando** el usuario los acepta, **entonces** queda registrada la versión, la
   fecha y el usuario, y entra al sistema.
4. **Dado** un usuario que ya aceptó la versión vigente, **cuando** inicia sesión, **entonces** no se le vuelven a
   pedir.
5. **Dado** una versión nueva publicada, **cuando** un usuario inicia sesión o sigue con su sesión abierta, **entonces**
   debe aceptarla antes de seguir operando.
6. **Dado** un usuario sin aceptación vigente, **cuando** intenta usar la API directamente, **entonces** el servidor
   rechaza sus operaciones, salvo ver los términos, aceptarlos y cerrar sesión.
7. **Dado** que soy administrador, **cuando** consulto los términos, **entonces** veo la versión vigente y quién y
   cuándo aceptó cada versión.

---

### Historia de usuario 10 - Proteger la información del sistema (Prioridad: P1)

Como administrador, quiero que la información del sistema esté protegida (bitácora de acciones sensibles, política de
contraseñas, cierre de sesión por inactividad y respuestas sin datos reservados) para detectar usos indebidos y
proteger los datos del taller y de sus clientes.

**Por qué esta prioridad**: El sistema guarda datos personales y precios de compra; sin trazabilidad ni controles
básicos un uso indebido pasa inadvertido.

**Prueba independiente**: El administrador cambia el rol de un usuario y un precio, y ve ambas acciones en la
bitácora con quién, cuándo y qué; una contraseña débil se rechaza; tras la inactividad la sesión se cierra.

**Escenarios de aceptación**:

1. **Dado** una acción sensible (inicio de sesión fallido, bloqueo, alta, baja o cambio de rol de un usuario, cambio
   de configuración o de precios, o pago cancelado), **cuando** ocurre, **entonces** queda registrada con quién la
   hizo, cuándo y sobre qué.
2. **Dado** que soy administrador, **cuando** consulto la bitácora, **entonces** puedo filtrar por fecha, usuario y
   acción, y recorrerla por páginas.
3. **Dado** cualquier usuario, **cuando** intenta editar o borrar un registro de la bitácora, **entonces** no existe
   forma de hacerlo desde la aplicación.
4. **Dado** un registro de la bitácora, **cuando** se consulta, **entonces** nunca contiene contraseñas, hashes,
   tokens ni datos de tarjeta.
5. **Dado** una contraseña que no cumple la política, **cuando** se crea o se cambia una cuenta, **entonces** el
   sistema la rechaza con un mensaje claro de lo que falta.
6. **Dado** una sesión sin actividad durante el periodo de inactividad, **cuando** pasa ese tiempo, **entonces** la
   sesión se cierra y se pide iniciar sesión de nuevo.
7. **Dado** cualquier respuesta de la API de usuarios, refacciones, órdenes, pagos y tickets, **cuando** la recibe un
   rol, **entonces** no incluye el hash de contraseña, el token ni los precios reservados a ese rol.
8. **Dado** un texto de búsqueda con caracteres de inyección, **cuando** se envía a un campo de búsqueda, **entonces**
   se trata como texto y no altera la consulta ni devuelve datos de más.
9. **Dado** que soy recepcionista o mecánico, **cuando** intento consultar la bitácora, **entonces** el sistema lo
   rechaza.

---

### Casos límite

- **Cambio de configuración simultáneo**: si dos administradores guardan la configuración casi al mismo tiempo, gana
  el último cambio y ambos quedan en la bitácora; ningún dato queda a medias.
- **Tipo de servicio sin intervalo en días ni en kilómetros**: se rechaza; debe tener al menos uno.
- **Tipo de servicio desactivado y en uso**: las órdenes y los mantenimientos ya creados lo conservan.
- **Periodo de reportes muy amplio**: se limita (por ejemplo, a un año) y el reporte indica el límite; con muchos
  datos, el reporte pagina o resume y responde en un tiempo razonable.
- **Zona horaria del corte**: el día, la semana y el mes se cortan con la fecha local del servidor, igual que el
  panel de control.
- **Pagos cancelados después de emitir un ticket**: el reporte de ingresos solo cuenta pagos pagados al momento de
  consultar; un ticket emitido no cambia.
- **Refacción sin precio de compra**: el margen se muestra como «Sin costo» y no se suma al margen total.
- **Versión de términos publicada mientras alguien trabaja**: la persona debe aceptar antes de su siguiente
  operación; lo que ya envió se completa.
- **Usuarios ya existentes**: deben aceptar los términos en su siguiente inicio de sesión.
- **Contraseñas ya guardadas que no cumplen la política**: siguen funcionando hasta que se cambien; la política solo
  se aplica al crear o cambiar la contraseña.
- **Inactividad y trabajo sin guardar**: antes de cerrar la sesión se avisa para no perder un formulario a medias.
- **Intento de acceso a la bitácora o a los reportes sin ser administrador**: el servidor responde 403 aunque la
  solicitud no venga de la interfaz.
- **Datos anteriores al sprint**: las órdenes, pagos, tickets y mantenimientos existentes se leen igual y no se
  modifican.

## Requisitos *(obligatorio)*

### Requisitos funcionales

**Configuración y catálogo**

- **FR-001**: El administrador DEBE poder ver y editar desde la aplicación el nombre, la dirección y el teléfono del
  taller, con longitudes máximas y mensajes de error por campo.
- **FR-002**: Los datos del taller guardados DEBEN usarse en los tickets nuevos; los tickets ya emitidos NO DEBEN
  cambiar.
- **FR-003**: Si no hay un valor guardado, el sistema DEBE usar el valor de la configuración del servidor o, si
  tampoco existe, el predeterminado (30 días y 1 000 km en los márgenes), para que una instalación existente siga
  funcionando.
- **FR-004**: El administrador DEBE poder editar los márgenes de «Próximo» en días y en kilómetros con límites
  válidos; la lista de Mantenimientos, el panel de control y los avisos DEBEN usar el mismo margen.
- **FR-005**: El administrador DEBE poder crear, editar y desactivar tipos de servicio con nombre único y al menos un
  intervalo (días, kilómetros o ambos); un tipo NO DEBE borrarse y los tipos en uso se conservan.
- **FR-006**: Un servicio de una orden DEBE poder enlazarse opcionalmente a un tipo de servicio; los servicios
  existentes sin tipo siguen funcionando.
- **FR-007**: Al registrar el próximo mantenimiento de una orden con un tipo de servicio con intervalo, el sistema
  DEBE proponer la fecha y el kilometraje y permitir corregirlos.
- **FR-008**: Configuración, catálogo de tipos de servicio y reportes DEBEN ser exclusivos del administrador,
  validado en el servidor (los demás roles reciben 403).

**Reportes**

- **FR-009**: El sistema DEBE ofrecer un reporte de ingresos por periodo: total de pagos pagados, desglose por método
  de pago y por día, y número de pagos.
- **FR-010**: El sistema DEBE ofrecer un reporte de servicios más frecuentes y de productividad por mecánico (órdenes
  terminadas e importe de mano de obra) del periodo.
- **FR-011**: El sistema DEBE ofrecer un reporte de refacciones usadas con unidades, costo, precio de venta y margen
  (importe y porcentaje), y la rotación del inventario del periodo; el precio de compra DEBE verlo solo el
  administrador.
- **FR-012**: Los reportes DEBEN filtrarse por rango de fechas (día, semana, mes o rango libre), con un máximo de un
  año por consulta y mensajes claros ante rangos inválidos.
- **FR-013**: Los importes DEBEN calcularse en centavos enteros y coincidir con los pagos y las órdenes que los
  originan; la suma de las partes DEBE ser igual al total mostrado.
- **FR-014**: Cada reporte DEBE poder exportarse a un archivo con los mismos datos, periodo y filtros que la
  pantalla, en [NEEDS CLARIFICATION: ¿en qué formato se exportan los reportes? Opciones: (A) CSV; (B) Excel; (C) PDF;
  (D) más de uno].
- **FR-015**: Los reportes DEBEN responder en un tiempo razonable con muchos datos, limitando el periodo o paginando
  los listados largos.

**Ticket**

- **FR-016**: El ticket nuevo DEBE incluir la línea «Próximo servicio» (fecha, kilometraje o ambos) cuando la orden
  tiene su próximo mantenimiento registrado, y NO DEBE mostrarla cuando no lo tiene.
- **FR-017**: Los tickets emitidos antes del sprint o antes de un cambio de configuración DEBEN conservar su
  contenido tal como se emitieron.

**Términos y condiciones**

- **FR-018**: Todo usuario autenticado DEBE aceptar la versión vigente de los términos y condiciones y del aviso de
  privacidad antes de usar el sistema; si los rechaza, la sesión se cierra.
- **FR-019**: La aceptación DEBE guardar usuario, versión y fecha; no se vuelve a pedir mientras la versión no cambie
  y se pide de nuevo cuando se publica una versión nueva.
- **FR-020**: Los términos DEBEN cubrir el uso permitido del sistema, la confidencialidad de los datos de clientes y
  vehículos, la responsabilidad de las cuentas personales y el aviso de privacidad. El administrador DEBE poder
  consultar la versión vigente y las aceptaciones. [NEEDS CLARIFICATION: ¿cómo se publican los términos y quién los
  redacta? Opciones: (A) texto fijo entregado con el sistema y versionado por el equipo; (B) el administrador los
  edita y publica versiones desde la aplicación].
- **FR-021**: La aceptación DEBE validarse en el servidor: sin aceptación vigente, la API DEBE rechazar las
  operaciones del usuario, salvo consultar los términos, aceptarlos y cerrar sesión.
- **FR-022**: Los usuarios existentes DEBEN aceptar los términos en su siguiente inicio de sesión.

**Seguridad de la información**

- **FR-023**: El sistema DEBE registrar en una bitácora, como mínimo: inicios de sesión fallidos y bloqueos, altas,
  bajas y cambios de rol de usuarios, cambios de configuración y de precios, y pagos cancelados, con quién, cuándo y
  sobre qué.
- **FR-024**: El administrador DEBE poder consultar la bitácora con filtros por fecha, usuario y acción y paginada;
  nadie DEBE poder editar ni borrar sus registros desde la aplicación, y los registros se conservan.
- **FR-025**: La bitácora NO DEBE guardar contraseñas, hashes, tokens ni datos de tarjeta.
- **FR-026**: La política de contraseñas DEBE aplicarse al crear y al cambiar la contraseña, con un mensaje claro;
  las contraseñas siguen guardándose solo con hash. [NEEDS CLARIFICATION: ¿qué exige la política de contraseñas y
  tras cuánto tiempo de inactividad se cierra la sesión? Propuesta: mínimo 10 caracteres con mayúscula, minúscula y
  número; cierre a los 30 minutos sin actividad con aviso previo; ¿se acepta o se ajusta?].
- **FR-027**: La sesión DEBE cerrarse tras el periodo de inactividad y pedir iniciar sesión de nuevo; la expiración
  del token se mantiene validada en el servidor.
- **FR-028**: Ninguna respuesta de la API DEBE incluir el hash de contraseña, el token ni los precios reservados al
  rol; DEBEN existir pruebas por cada endpoint de usuarios, refacciones, órdenes, pagos y tickets.
- **FR-029**: Las consultas DEBEN usar parámetros y las entradas DEBEN validarse en el servidor; una prueba
  automática DEBE comprobar intentos de inyección en los campos de búsqueda.

**Datos, documentación y compatibilidad**

- **FR-030**: Los datos de ejemplo del sprint DEBEN incluir la configuración inicial, tipos de servicio, una
  versión de términos y datos suficientes para que los reportes muestren información, y DEBEN poder cargarse varias
  veces sin duplicarse.
- **FR-031**: La documentación del proyecto (sección de configuración y reportes del contexto maestro, y el sistema de
  diseño) DEBE actualizarse en este sprint, y `.env.example` DEBE indicar qué pasa a la aplicación y qué queda como
  valor de respaldo.
- **FR-032**: El sprint NO DEBE alterar los datos existentes de clientes, vehículos, citas, órdenes, mantenimientos,
  pagos ni tickets, ni los contratos de los sprints anteriores salvo lo declarado aquí.

### Entidades clave *(incluir si la funcionalidad involucra datos)*

- **Configuración del taller**: pares de nombre y valor con los datos del taller y los márgenes de mantenimiento.
- **Tipo de servicio**: nombre único, intervalo en días y en kilómetros (al menos uno) y estado activo; se enlaza
  opcionalmente a los servicios de una orden.
- **Reporte**: consulta calculada sobre pagos, órdenes, servicios, refacciones y movimientos de inventario para un
  periodo; no se guarda.
- **Versión de términos**: texto de los términos y del aviso de privacidad con su número de versión y fecha de
  publicación.
- **Aceptación de términos**: constancia de que un usuario aceptó una versión, con la fecha.
- **Registro de bitácora**: acción sensible con quién, cuándo, sobre qué y un resumen sin datos reservados.
- **Ticket**: comprobante que conserva su contenido tal como se emitió; el ticket nuevo agrega «Próximo servicio».
- **Usuario y contraseña**: la contraseña sigue guardándose solo con hash y ahora debe cumplir la política.

## Criterios de éxito *(obligatorio)*

### Resultados medibles

- **SC-001** (FR-001, FR-002): El administrador cambia los datos del taller y ve el cambio en un ticket nuevo en menos
  de 2 minutos, y el 100 % de los tickets anteriores conserva sus datos.
- **SC-002** (FR-005, FR-007): Con un tipo de servicio configurado, el próximo mantenimiento de una orden se propone
  con la fecha y el kilometraje correctos en el 100 % de los casos de prueba.
- **SC-003** (FR-009 a FR-013): En el 100 % de los casos de prueba los importes de cada reporte coinciden al centavo
  con los pagos y las órdenes que los originan.
- **SC-004** (FR-014): El archivo exportado de cada reporte coincide con la pantalla (mismos datos, periodo y filtros)
  en el 100 % de los casos de prueba.
- **SC-005** (FR-008, FR-021, FR-024): En el 100 % de las pruebas por rol, recepción y mecánico reciben rechazo en
  configuración, catálogo, reportes y bitácora, y un usuario sin aceptación vigente es rechazado por el servidor.
- **SC-006** (FR-015): Con 1 000 pagos, 1 000 órdenes y sus refacciones, cada reporte responde en menos de 3 segundos.
- **SC-007** (FR-023, FR-025): El 100 % de las acciones sensibles de las pruebas queda en la bitácora y ningún
  registro contiene contraseñas, hashes, tokens ni datos de tarjeta.
- **SC-008** (FR-026, FR-027): El 100 % de las contraseñas que no cumplen la política se rechaza con un mensaje
  claro, y la sesión se cierra al pasar el periodo de inactividad en el 100 % de los casos de prueba.
- **SC-009** (FR-028, FR-029): En ninguna respuesta de los endpoints revisados aparece el hash de contraseña, el
  token ni un precio reservado al rol, y los intentos de inyección de las pruebas no alteran ninguna consulta.
- **SC-010** (FR-018, FR-019): Un usuario nuevo acepta los términos y entra al sistema en menos de 1 minuto, y no se
  le vuelven a pedir hasta que se publique una versión nueva.
- **SC-011** (FR-032): Toda prueba de los sprints 1 a 6 sigue pasando al cierre, salvo las que deban actualizarse por
  cambios declarados en esta especificación (contraseñas, aceptación de términos y configuración), y cada
  actualización se registra en el documento de aseguramiento.

## Suposiciones

- Este sprint es posterior al MVP. La constitución (principio I, enmienda 1.1.0) lo permite con su insumo, la
  aprobación registrada del responsable del proyecto y el flujo de Spec Kit; la aprobación del Sprint 7 se registra
  como puerta antes de la implementación, igual que en el Sprint 6.
- El insumo es `docs/sprints/sprint-7-reportes-configuracion.md`. El sprint es amplio: si el tiempo no alcanza,
  se entregan primero configuración, catálogo, ticket, términos y seguridad, y después los reportes y su
  exportación.
- Los reportes son exclusivos del administrador; no hay una versión reducida para la recepción.
- Los periodos de los reportes son día, semana, mes o rango libre, con corte por la fecha local del servidor y un
  máximo de un año por consulta.
- La productividad por mecánico se mide con las órdenes terminadas y el importe de mano de obra del periodo.
- La rotación del inventario es las salidas del periodo sobre la existencia promedio de cada refacción.
- El margen de una refacción sin precio de compra (o con líneas anteriores al Sprint 5 con precio cero) se muestra
  como «Sin costo» y no entra en el margen total.
- El ticket ya conserva su contenido tal como se emitió; por eso los datos del taller de un ticket emitido no
  cambian aunque la configuración cambie.
- El tipo de servicio se enlaza de forma opcional a las líneas de servicio de una orden; las líneas existentes sin
  tipo no se modifican.
- La bitácora se conserva sin borrarse, se pagina y no se exporta; las acciones registradas son las del FR-023.
- Los usuarios existentes aceptan los términos en su siguiente inicio de sesión, y la política de contraseñas solo se
  aplica al crear o cambiar la contraseña.
- Quedan fuera: cifrado de la base en disco, respaldos, HTTPS y despliegue (se descartó el antiguo Sprint 8),
  autenticación de dos pasos, recuperación de contraseña por correo, gráficas avanzadas, impuestos y facturación
  electrónica, envío automático de reportes y mensajes al cliente. El texto de los términos es una plantilla que el
  taller debe revisar; este documento no ofrece asesoría legal.
- Se reutilizan la autenticación, los roles, los precios de las refacciones, el ticket con su instantánea y los
  cálculos de mantenimiento de los sprints anteriores; el servidor sigue siendo el único que accede a la base de
  datos.

## Decisiones pendientes para /speckit.clarify

Vienen de la sección 9 del insumo. Las tres con marcador están en los requisitos; las demás tienen una opción por
omisión en las suposiciones y se confirman en `/speckit.clarify`:

- **D-01** (FR-014): formato de exportación de los reportes.
- **D-02** (FR-020): cómo se publican los términos y quién los redacta.
- **D-03** (FR-026): política de contraseñas y tiempo de inactividad.
- **D-04**: prioridad si el sprint no alcanza (por omisión, configuración, términos y seguridad primero).
- **D-05**: periodos de los reportes y corte por la fecha local del servidor (por omisión, día, semana, mes y rango
  libre, máximo un año).
- **D-06**: productividad por mecánico (por omisión, órdenes terminadas e importe de mano de obra).
- **D-07**: rotación del inventario (por omisión, salidas sobre existencia promedio).
- **D-08**: margen sin precio de compra (por omisión, «Sin costo» fuera del total).
- **D-09**: enlace del tipo de servicio con las líneas de servicio (por omisión, opcional).
- **D-10**: reportes para la recepción (por omisión, no).
- **D-11**: bitácora (por omisión, acciones del FR-023, sin borrar, paginada, sin exportar).
- **D-12**: usuarios existentes y contraseñas sembradas (por omisión, aceptan en su siguiente ingreso; la política
  solo aplica al crear o cambiar).
