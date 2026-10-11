# Motorix · aplicación de escritorio

Aplicación Flutter (Material 3 con tema propio, Provider para el estado) que consume la API REST de
`server/`. Nunca se conecta directamente a la base de datos. Prioridad: escritorio Windows.

## Módulos

| Módulo | Quién lo ve | Sprint |
|--------|-------------|--------|
| Inicio | Todos los roles (bienvenida y accesos directos) | 1 |
| Clientes y Vehículos | Todos los roles (solo consulta para el mecánico) | 1 |
| Usuarios | Administrador | 1 |
| Citas | Administrador y recepcionista | 2 |
| Órdenes | Administrador y recepcionista | 2 |
| Mis órdenes | Mecánico (solo las asignadas a su cuenta) | 2 |

En el detalle de una orden, los botones se generan con las transiciones que devuelve el servidor
(`allowedTransitions`), ya filtradas por rol y pertenencia; la matriz de estados no se duplica en el cliente.
Ocultar una opción nunca sustituye la validación del backend.

## Estructura de `lib/`

| Carpeta | Contenido |
|---------|-----------|
| `models/` | Modelos de datos que devuelve la API |
| `services/` | Cliente HTTP y servicios por recurso (`api_client.dart`, `orders_service.dart`, …) |
| `providers/` | Estado con Provider (sesión, navegación, listados, detalle de orden) |
| `screens/` | Pantallas (listados, formularios y detalles) |
| `widgets/` | Componentes reutilizables (tabla, selectores, chips de estado, diálogos) |
| `utils/` | Tema (`app_theme.dart`), tokens del sistema de diseño, etiquetas de estado y formatos |

Toda pantalla sigue `docs/design-system.md`: colores, espaciados y radios salen de `utils/tokens.dart`,
nunca se escriben valores sueltos, y cada pantalla maneja los estados vacío, cargando y error.

## Ejecutar y probar

```powershell
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3000/api
flutter analyze lib
flutter test            # pruebas de proveedores y pantallas con una API simulada
```

Antes de ejecutar, levanta la API (`cd server; npm run dev`) y aplica las migraciones y los seeds de
`database/` (consulta el `README.md` de la raíz). Las cuentas de ejemplo y sus contraseñas están en
`docs/project-context.md` (solo entorno local).

