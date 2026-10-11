# Contrato de interfaz: pantallas, navegación y permisos (Sprint 2)

La interfaz sigue `docs/design-system.md` (tema propio de Material 3, tokens, transiciones suaves,
confirmaciones obligatorias) y amplía el contrato del Sprint 1
(`specs/001-base-clientes-vehiculos/contracts/interfaz.md`). Ocultar una opción nunca sustituye la
validación del backend.

## Navegación

| Opción | Pantalla | ADMIN | RECEPTIONIST | MECHANIC |
|--------|----------|:-----:|:------------:|:--------:|
| Inicio | Bienvenida con accesos directos | ✔ | ✔ | ✔ |
| Clientes | (Sprint 1) | ✔ | ✔ | ✔ (consulta) |
| Vehículos | (Sprint 1) | ✔ | ✔ | ✔ (consulta) |
| Citas | Listado, formulario y detalle de citas | ✔ | ✔ | — |
| Órdenes | Listado, formulario y detalle de todas las órdenes | ✔ | ✔ | — |
| Mis órdenes | Listado y detalle de las órdenes asignadas | — | — | ✔ |
| Usuarios | (Sprint 1) | ✔ | — | — |

La pantalla de Inicio añade accesos directos a Citas y Órdenes (o a Mis órdenes para el mecánico).
Los íconos son los estándar de Material.

## Pantallas

| Pantalla | Contenido | Acciones | Estados obligatorios |
|----------|-----------|----------|----------------------|
| Listado de citas | Tabla con fecha y hora, cliente, vehículo (placa), motivo y chip de estado; búsqueda por cliente o placa; filtros de estado y rango de fechas; paginación | Ver detalle; "Nueva cita"; confirmar y cancelar desde la fila o el detalle | Vacío, cargando, error, sin resultados |
| Formulario de cita | Cliente (selector con búsqueda), vehículo (solo los del cliente elegido), fecha y hora, motivo, observaciones | Guardar, cancelar | Validación por campo; error de horario ocupado o fecha pasada; salida con cambios |
| Detalle de cita | Datos de la cita, cliente, vehículo y orden asociada (enlace) | Editar y Confirmar (si Pendiente o Confirmada), "Recibir vehículo y crear orden", Cancelar cita | Cargando, error |
| Listado de órdenes | Tabla con folio, fecha, cliente, vehículo, mecánico y chip de estado; búsqueda por folio, cliente o placa; filtros de estado y mecánico; paginación | Ver detalle; "Nueva orden" | Vacío, cargando, error, sin resultados |
| Formulario de orden | Vehículo (selector con búsqueda; con cliente derivado) o cita de origen, kilometraje de entrada, problema reportado, mecánico opcional | Guardar, cancelar; opción de corrección de kilometraje | Validación por campo; error de orden abierta existente; error de kilometraje menor con diálogo de corrección |
| Detalle de orden | Encabezado con folio, cliente, vehículo, kilometraje de entrada, mecánico y chip de estado; secciones: Diagnóstico, Servicios realizados, Mano de obra, Observaciones y recomendaciones, Totales, Historial de estados | Según rol: asignar o reasignar mecánico (recepción y administración); editar el trabajo y cambiar de estado (mecánico asignado y administración); entregar (recepción y administración) | Cargando, error, solo lectura (orden entregada), conflicto de estado |
| Mis órdenes | Mismo listado de órdenes, restringido a las asignadas; por defecto sin entregadas; filtro de estado | Abrir detalle | Vacío («No tienes órdenes asignadas»), cargando, error |

## Chips de estado (convención de color del sistema de diseño)

| Estado | Color |
|--------|-------|
| Cita Pendiente / Orden Recibido | Neutro |
| Cita Confirmada / Orden Diagnóstico, En reparación | Primario (en curso) |
| Orden Esperando refacción | Ámbar (advertencia) |
| Cita Completada / Orden Terminado, Entregado | Verde (completado) |
| Cita En proceso | Primario (en curso) |
| Cita Cancelada | Rojo |

## Confirmaciones obligatorias (diálogo con "Confirmar" y "Cancelar")

- Cancelar una cita (con motivo opcional).
- Registrar la entrega de una orden (paso a Entregado).
- Corregir el kilometraje de entrada a un valor menor (exige capturar el motivo).
- Quitar un servicio o una línea de mano de obra.
- Salir de un formulario con cambios sin guardar.

El avance de estado hasta Terminado no pide confirmación, pero sí muestra un mensaje de éxito.

## Comportamiento del detalle de la orden

- Los botones de transición se generan a partir de `allowedTransitions` que devuelve el servidor;
  no se duplica la matriz de estados en el cliente.
- Si el servidor responde `STATE_CONFLICT`, la pantalla recarga la orden y muestra el estado
  vigente con un mensaje.
- Una orden entregada oculta todas las acciones de edición y muestra «Orden entregada: solo lectura».
- Una orden sin mecánico muestra «Sin asignar» y, para recepción y administración, el selector de
  asignación; las acciones de avance quedan deshabilitadas con la explicación correspondiente.

## Mensajes

Éxito breve mediante *snackbar*; errores en español, sin trazas ni códigos internos visibles. Los
mensajes de reglas de negocio (kilometraje, horario ocupado, orden abierta, transición inválida)
reproducen el texto del servidor.
