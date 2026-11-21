# Base de datos de Motorix

MySQL 8.0 local (instalación nativa, sin Docker), motor InnoDB y codificación `utf8mb4`. Cada
integrante del equipo usa su propia instancia. El backend es el único que accede a la base.

## Contenido

| Carpeta / archivo | Propósito |
|-------------------|-----------|
| `migrations/` | Scripts SQL numerados e inmutables que definen el esquema (`001` Sprint 1: usuarios, clientes y vehículos; `002` Sprint 2: citas, órdenes de servicio, servicios, mano de obra e historial de estados; `003` Sprint 3: refacciones, movimientos de inventario, refacciones por orden, mantenimientos y kilometraje del servicio; `004` Sprint 4: pagos y tickets; `005` Sprint 5: categoría, marca y precios de las refacciones y precio de venta guardado en cada línea de refacción de la orden; `006` Sprint 6: lectura de avisos por usuario y avisos registrados a clientes; `007` Sprint 7: configuración del taller, tipos de servicio, términos y condiciones con su versión 1.0, bitácora de acciones sensibles, tipo opcional en los servicios de la orden y última actividad de cada usuario) |
| `seeds/` | Datos iniciales idempotentes (`001`: cuentas, clientes y vehículos de ejemplo; `002`: segundo mecánico `mecanico2`, citas y órdenes de ejemplo en todos los estados; `003`: refacciones con movimientos, órdenes históricas para el historial, refacciones usadas y mantenimientos Normal, Próximo, Vencido y Atendido; `004`: pagos en los cuatro estados y métodos y tickets de órdenes cobradas; `005`: precios de refacciones, una orden Terminada cobrable con refacciones y un pago de Mercado Pago desfasado) |
| `scripts/` | Scripts de PowerShell para crear, migrar, sembrar y reiniciar la base |
| `data/` | Directorio de datos local opcional; está en `.gitignore` y NO se versiona |

## Primer uso

1. Instala y arranca MySQL Server 8.0, y copia `.env.example` a `.env`.
2. Crea el entorno (pide la contraseña de `root` solo para este paso y la que tendrá `motorix_app`):

   ```powershell
   database/scripts/crear-entorno.ps1
   ```

3. Escribe en `.env` la contraseña elegida para `motorix_app` en `DB_PASSWORD`.
4. Aplica el esquema y los datos de ejemplo:

   ```powershell
   database/scripts/aplicar-migraciones.ps1 -Base motorix
   database/scripts/aplicar-migraciones.ps1 -Base motorix_test
   database/scripts/aplicar-seeds.ps1 -Base motorix
   ```

## Operaciones habituales

| Necesidad | Comando |
|-----------|---------|
| Aplicar migraciones nuevas | `database/scripts/aplicar-migraciones.ps1 -Base motorix` |
| Repetir los seeds (no duplica nada) | `database/scripts/aplicar-seeds.ps1 -Base motorix` |
| Recrear la base desde cero (elimina todas las tablas) | `database/scripts/reiniciar-local.ps1 -Base motorix` |

## Reglas

- La aplicación usa el usuario dedicado `motorix_app`, NUNCA `root`.
- Los cambios de esquema se agregan como **nuevos** scripts numerados (`003_...`); no se editan los
  scripts de sprints ya aplicados. Cada versión aplicada queda en `schema_migrations`.
- Las pruebas de integración usan solo `motorix_test`.
- Los seeds no contienen contraseñas en texto plano: las cuentas iniciales llevan únicamente el
  hash bcrypt. Las contraseñas del estándar del MVP están en `docs/project-context.md` y solo son
  válidas en entornos locales.
- La conexión se configura únicamente con las variables de entorno `DB_HOST`, `DB_PORT`,
  `DB_USER`, `DB_PASSWORD` y `DB_NAME`.

## Reversa manual de la migración 005

El DDL de MySQL no es transaccional, así que la reversa se hace a mano, sobre una copia de la base:

1. Respaldar la base.
2. Quitar order_parts.unit_price y las columnas category, brand, purchase_price y sale_price de parts con ALTER TABLE … DROP COLUMN (antes, sus restricciones chk_order_parts_unit_price, chk_parts_purchase_price y chk_parts_sale_price).
3. Borrar el registro 005_sprint5_part_prices de schema_migrations.

Los pagos y tickets emitidos no se modifican con la migración ni con su reversa.

## Reversa manual de la migración 006

La migración 006 solo crea dos tablas nuevas, así que su reversa es sencilla y no toca datos existentes:

1. Respaldar la base.
2. Borrar las tablas con DROP TABLE client_notices y DROP TABLE notification_reads (ninguna otra tabla depende de ellas).
3. Borrar el registro 006_sprint6_notices de schema_migrations.

Los avisos (mantenimientos, citas, stock y órdenes detenidas) no se guardan, por lo que no hay nada más que revertir.

## Reversa manual de la migración 007

La migración 007 crea cinco tablas y agrega dos columnas nulas; no cambia ninguna fila existente. Para revertirla, sobre una copia de la base:

1. Respaldar la base.
2. Quitar la llave foránea y la columna de los servicios con ALTER TABLE order_services DROP FOREIGN KEY fk_order_services_type, DROP KEY idx_order_services_type, DROP COLUMN service_type_id.
3. Quitar la columna de actividad con ALTER TABLE users DROP COLUMN last_activity_at.
4. Borrar las tablas en este orden: DROP TABLE terms_acceptances, terms_versions, audit_log, service_types y settings.
5. Borrar el registro 007_sprint7_settings_terms_audit de schema_migrations.

Se pierden la configuración guardada, los tipos de servicio, las aceptaciones de términos y la bitácora.
