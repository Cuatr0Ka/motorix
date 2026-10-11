# Base de datos de Motorix

MySQL 8.0 local (instalación nativa, sin Docker), motor InnoDB y codificación `utf8mb4`. Cada
integrante del equipo usa su propia instancia. El backend es el único que accede a la base.

## Contenido

| Carpeta / archivo | Propósito |
|-------------------|-----------|
| `migrations/` | Scripts SQL numerados e inmutables que definen el esquema (`001` Sprint 1: usuarios, clientes y vehículos; `002` Sprint 2: citas, órdenes de servicio, servicios, mano de obra e historial de estados) |
| `seeds/` | Datos iniciales idempotentes (`001`: cuentas, clientes y vehículos de ejemplo; `002`: segundo mecánico `mecanico2`, citas y órdenes de ejemplo en todos los estados) |
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
| Recrear la base desde cero | `database/scripts/reiniciar-local.ps1 -Base motorix` |

## Reglas

- La aplicación usa el usuario dedicado `motorix_app`, NUNCA `root`.
- Los cambios de esquema se agregan como **nuevos** scripts numerados (`002_...`); no se editan los
  scripts de sprints ya aplicados. Cada versión aplicada queda en `schema_migrations`.
- Las pruebas de integración usan solo `motorix_test`.
- Los seeds no contienen contraseñas en texto plano: las cuentas iniciales llevan únicamente el
  hash bcrypt. Las contraseñas del estándar del MVP están en `docs/project-context.md` y solo son
  válidas en entornos locales.
- La conexión se configura únicamente con las variables de entorno `DB_HOST`, `DB_PORT`,
  `DB_USER`, `DB_PASSWORD` y `DB_NAME`.
