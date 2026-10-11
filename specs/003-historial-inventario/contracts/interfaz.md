# Contrato de interfaz: pantallas, navegación y permisos (Sprint 3)

La interfaz sigue `docs/design-system.md` (tema propio de Material 3, tokens, transiciones suaves,
confirmaciones obligatorias) y amplía los contratos de los sprints 1 y 2
(`specs/001-base-clientes-vehiculos/contracts/interfaz.md`,
`specs/002-citas-ordenes-servicio/contracts/interfaz.md`). Ocultar una opción nunca sustituye la
validación del backend.

## Navegación

| Opción | Pantalla | ADMIN | RECEPTIONIST | MECHANIC |
|--------|----------|:-----:|:------------:|:--------:|
| Inicio | Bienvenida con accesos directos y, para ADMIN, aviso de stock bajo | ✔ | ✔ | ✔ |
| Clientes, Vehículos, Citas, Órdenes, Mis órdenes, Usuarios | (sprints 1 y 2) | según rol | según rol | según rol |
| Inventario | Listado de refacciones con alertas, formulario y detalle | ✔ | — | — |
| Mantenimientos | Lista de mantenimientos próximos y vencidos | ✔ | ✔ | — |

El historial vive dentro del **detalle del vehículo** (visible para los tres roles) y las acciones de
refacciones, kilometraje y mantenimiento viven dentro del **detalle de la orden**. El ítem
«Inventario» del menú muestra una insignia con el número de refacciones en alerta (solo ADMIN).

## Pantallas

| Pantalla | Contenido | Acciones | Estados obligatorios |
|----------|-----------|----------|----------------------|
| Inventario (ADMIN) | Banner de alertas («N refacciones con stock bajo, M agotadas») y tabla con código, nombre, unidad, stock, mínimo y chip de estado de stock; búsqueda por código o nombre; filtros de estado de stock y activas/inactivas; paginación | «Nueva refacción»; abrir detalle; atajo «Ver solo alertas» | Vacío, cargando, error, sin resultados; alertas en orden («El inventario está en orden») |
| Formulario de refacción | Código (no editable al editar), nombre, descripción, unidad, stock mínimo y, solo al crear, stock inicial | Guardar, cancelar | Validación por campo; error de código duplicado; salida con cambios |
| Detalle de refacción | Datos, stock, estado de stock y tabla de movimientos (tipo, cantidad con signo, motivo, orden, persona, fecha) | Editar; «Registrar entrada»; «Ajustar inventario» (cantidad contada y motivo); desactivar/reactivar | Cargando, error, vacío de movimientos; refacción inactiva con aviso |
| Mantenimientos (ADMIN, RECEPTIONIST) | Tabla con cliente, teléfono, vehículo (placa), descripción, objetivo (fecha y/o kilometraje) y chip Normal/Próximo/Vencido; filtros de indicador y búsqueda por cliente o placa; por defecto Vencidos primero | Abrir el detalle del vehículo; ADMIN: editar y «Marcar como atendido» (íconos en la fila, el segundo con confirmación) | Vacío («Sin mantenimientos pendientes»), cargando, error, sin resultados |
| Historial en el detalle del vehículo | Sección «Historial de servicios»: línea cronológica de servicios con fecha, folio, kilometraje, problema, diagnóstico, servicios, refacciones y mecánico; mantenimiento vigente destacado | Abrir la orden (según permisos) | Vacío («Este vehículo aún no tiene servicios terminados»), cargando, error |
| Refacciones en el detalle de la orden | Sección «Refacciones utilizadas» con código, nombre y cantidad (la existencia se muestra en el selector al agregar); sección «Kilometraje del servicio» y «Próximo mantenimiento» | Mecánico asignado y ADMIN: agregar (selector con búsqueda y cantidad), corregir cantidad, quitar; registrar kilometraje (orden Terminada); programar o editar mantenimiento | Cargando, error de stock insuficiente (muestra disponible), solo lectura (orden Entregada) |

## Chips (convención de color del sistema de diseño)

| Estado | Color |
|--------|-------|
| Stock Suficiente / Mantenimiento Normal | Verde (correcto) |
| Stock Bajo / Mantenimiento Próximo | Ámbar (advertencia) |
| Stock Agotado / Mantenimiento Vencido | Rojo |
| Mantenimiento Atendido / refacción inactiva | Neutro |

El color nunca es la única señal: cada chip lleva texto («Bajo», «Agotado», «Vencido»…).

## Confirmaciones obligatorias (diálogo con "Confirmar" y "Cancelar")

- Aplicar un ajuste de inventario (muestra stock actual, cantidad contada y diferencia).
- Quitar una refacción de una orden (informa que la cantidad regresa al inventario).
- Desactivar una refacción.
- Marcar un mantenimiento como Atendido.
- Salir de un formulario con cambios sin guardar.

Agregar o corregir refacciones y registrar entradas no piden confirmación, pero muestran un mensaje
de éxito.

## Comportamiento

- El selector de refacciones de la orden muestra solo activas con su existencia; las agotadas
  aparecen deshabilitadas con la leyenda «Agotada».
- Si el servidor responde `INSUFFICIENT_STOCK`, el diálogo conserva lo capturado y muestra «Solo hay N
  disponibles».
- Tras cualquier movimiento de inventario, el cliente de ADMIN vuelve a consultar las alertas.
- Las acciones de edición en el detalle de la orden desaparecen para roles sin permiso y en órdenes
  Entregadas se muestra «Orden entregada: solo lectura».
- Las fechas de mantenimiento se muestran en formato local y el kilometraje con separador de miles.

## Mensajes

Éxito breve mediante *snackbar*; errores en español, sin trazas ni códigos internos visibles. Los
mensajes de reglas de negocio (stock insuficiente, fecha pasada, kilometraje menor) reproducen el
texto del servidor.
