# Contrato de interfaz: pantallas, navegación y permisos (Sprint 1)

La interfaz sigue `docs/design-system.md` (tema propio de Material 3, tokens, transiciones
suaves, confirmaciones obligatorias). Este contrato fija qué pantallas existen, quién las ve y qué
estados y confirmaciones requieren. Ocultar una opción nunca sustituye la validación del backend.

## Navegación

Menú lateral colapsable (`NavigationRail`), solo con módulos del sprint y del rol:

| Opción | Pantalla | ADMIN | RECEPTIONIST | MECHANIC |
|--------|----------|:-----:|:------------:|:--------:|
| Inicio | Pantalla de bienvenida | ✔ | ✔ | ✔ |
| Clientes | Listado y detalle de clientes | ✔ | ✔ | ✔ (solo consulta) |
| Vehículos | Listado y detalle de vehículos | ✔ | ✔ | ✔ (solo consulta) |
| Usuarios | Gestión de usuarios | ✔ | — | — |
| Cerrar sesión | Diálogo de confirmación | ✔ | ✔ | ✔ |

La pantalla inicial tras iniciar sesión es **Inicio**. El encabezado muestra el título de la
sección, el nombre y el rol de la persona; el buscador y las notificaciones del sistema de diseño
no se incluyen en este sprint (sin contenido que mostrar).

## Pantallas

| Pantalla | Contenido | Acciones | Estados obligatorios |
|----------|-----------|----------|----------------------|
| Inicio de sesión | Campo "Usuario o correo", contraseña, botón "Iniciar sesión" | Iniciar sesión | Cargando, error genérico, cuenta bloqueada |
| Inicio | Nombre y rol; accesos directos a las secciones permitidas (sin indicadores) | Navegar | — |
| Cambiar contraseña | Contraseña actual, nueva, confirmación; reglas visibles | Guardar | Error de política, éxito |
| Listado de clientes | Tabla con nombre, teléfono, correo, nº de vehículos; búsqueda por nombre o teléfono; paginación | Ver detalle; "Nuevo cliente" y editar (ADMIN, RECEPTIONIST) | Vacío, cargando, error, sin resultados |
| Formulario de cliente | Nombre, teléfono, correo, dirección | Guardar, cancelar | Validación por campo; diálogo de teléfono duplicado; salida con cambios |
| Detalle de cliente | Datos del cliente y tabla de sus vehículos | Editar; "Registrar vehículo" con el propietario preseleccionado | Vacío (sin vehículos), cargando, error |
| Listado de vehículos | Tabla con placa, marca, modelo, año, propietario; búsqueda; paginación | Ver detalle; "Nuevo vehículo" y editar (ADMIN, RECEPTIONIST) | Vacío, cargando, error, sin resultados |
| Formulario de vehículo | Propietario (selector con búsqueda, obligatorio), marca, modelo, año, placa, VIN, color, kilometraje | Guardar, cancelar; cambio de propietario | Validación por campo; diálogo de cambio de propietario; corrección de kilometraje |
| Detalle de vehículo | Datos del vehículo y su propietario (enlace al cliente) | Editar | Cargando, error |
| Usuarios (ADMIN) | Tabla con usuario, nombre, correo, rol, estado | "Nuevo usuario", cambiar rol, activar/desactivar | Vacío, cargando, error, conflicto de último administrador |

## Confirmaciones obligatorias (diálogo con "Confirmar" y "Cancelar")

- Cerrar sesión.
- Desactivar un usuario (y reactivarlo no requiere confirmación).
- Cambiar el propietario de un vehículo.
- Guardar un cliente con un teléfono ya registrado (muestra las coincidencias).
- Corregir un kilometraje a un valor menor.
- Salir de un formulario con cambios sin guardar.

## Mensajes

Éxito breve mediante *snackbar*; errores en español, sin trazas ni códigos internos visibles. El
mensaje de credenciales inválidas es genérico.
