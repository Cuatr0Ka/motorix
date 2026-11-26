# Despliegue de Motorix en Render y TiDB Cloud

Documento de lo que se hizo para publicar Motorix de forma gratuita (25 de noviembre de 2026).

**Enlace del sistema publicado: <https://motorix-58i3.onrender.com>**

## Resumen

Motorix quedó publicado con una sola dirección. Un único servicio web de Render (plan gratuito) ejecuta la API de Node/Express y sirve también la web de Flutter. La base de datos es MySQL compatible en TiDB Cloud (plan Starter, gratuito y sin tarjeta). Quien use el sistema solo necesita el enlace.

```
Personas → https://motorix-58i3.onrender.com
              ├─ Web de Flutter (archivos de server/public)
              └─ API Express (/api)  →  TiDB Cloud (MySQL compatible, TLS)
```

| Pieza | Proveedor y plan | Costo |
|---|---|---|
| API y web | Render, servicio web Free (Node, región Ohio) | $0 |
| Base de datos | TiDB Cloud Starter, MySQL Compatible, TiDB v8.5.3, región N. Virginia | $0 |

## Por qué esta opción

- **Oracle Cloud (máquina virtual gratuita):** se descartó por el trabajo de administrar el servidor (instalar Node y MySQL, HTTPS, respaldos y firewall).
- **Supabase:** es PostgreSQL y la API usa `mysql2` directo, sin ORM. Habría que reescribir unas 166 consultas, las 7 migraciones y las pruebas.
- **Web y API separadas:** se descartó para tener un solo enlace y evitar problemas de CORS.

## Qué se cambió en el código

Todo está en la rama principal (`004-pagos-tickets-dashboard`), integrado con pull requests:

| PR | Cambio |
|---|---|
| #2 | Sprints 5 a 7 al día con la rama principal y límite de intentos de inicio de sesión por IP |
| #3 | El límite de intentos se reescribió sin dependencias nuevas (la regla FR-032 y la constitución exigen justificar cada dependencia) |
| #4 | Compatibilidad con TiDB: `DB_SSL`, migraciones 005 y 007 divididas y bloqueo de lecturas de refacciones |
| #5 | Servir la web desde la API, `TRUST_PROXY`, `CORS_ORIGIN`, URL de API relativa en el cliente, web compilada en `server/public` y script de contraseñas |

### Compatibilidad con TiDB

Al probar contra TiDB aparecieron tres diferencias con MySQL:

1. **Migración 005:** un `ALTER TABLE` agregaba varias columnas y usaba `AFTER` sobre una columna recién agregada en la misma sentencia. TiDB no lo admite. Se dividió en un `ALTER TABLE` por cambio.
2. **Migración 007:** un `ALTER TABLE` agregaba una columna y, en la misma sentencia, un índice y una llave foránea que la usaban. Se dividió igual. Ambas migraciones se editaron aunque la regla del proyecto dice que no se editan las aplicadas: fue una excepción autorizada, está anotada en cada archivo y el esquema resultante es idéntico. Las bases ya migradas no se vuelven a tocar.
3. **Refacciones simultáneas:** con aislamiento por instantánea, cuatro solicitudes a la vez sobre la misma orden devolvían error 500. Las lecturas de la línea de refacción dentro de las transacciones ahora usan `FOR UPDATE`. En MySQL el resultado no cambia.

Las columnas generadas con índices únicos (una sola orden abierta por vehículo) sí funcionan en TiDB.

## Configuración de Render

| Campo | Valor |
|---|---|
| Repositorio y rama | `Cuatr0Ka/motorix`, rama `004-pagos-tickets-dashboard` |
| Directorio raíz | `server` |
| Comando de build | `npm ci` |
| Comando de inicio | `node server.js` |
| Instancia | Free ($0 al mes). Ojo: el formulario propone por defecto una de $7 |

**Variables de entorno** (solo los nombres; los valores secretos viven únicamente en el panel de Render y en `.env.tidb`, que git ignora):

| Variable | Para qué sirve |
|---|---|
| `DB_HOST`, `DB_PORT`, `DB_NAME` | Dirección, puerto (4000) y nombre de la base (`motorix`) en TiDB |
| `DB_USER`, `DB_PASSWORD` | Credenciales de TiDB (secretas) |
| `DB_SSL=true` | Conexión con TLS, que TiDB exige |
| `SERVE_WEB=true` | La API sirve la web de `server/public` |
| `TRUST_PROXY=1` | Ver la IP real del cliente detrás del proxy de Render, para que el límite de intentos de login no bloquee a todos juntos |
| `JWT_SECRET` | Secreto de las sesiones, generado de forma aleatoria por Render |

`CORS_ORIGIN` no se configuró: al ser la misma dirección para la web y la API, no hace falta. Sin ese valor, CORS queda abierto.

## Base de datos en TiDB

- Se crearon las bases `motorix` y `motorix_test`, se aplicaron las 7 migraciones y los 7 seeds.
- Se cargaron los datos de ejemplo con `server/scripts/cargarDatosDemo.js`: 12 clientes, 16 vehículos, 37 órdenes, 30 pagos, 14 refacciones y 20 mantenimientos. Los pagos de noviembre suman $29,215.00, igual que en MySQL local.
- El acceso de red está abierto a todas las IP (regla `Allow_all_public_connections`, que TiDB trae por defecto), porque Render no tiene IP fija en el plan gratuito. Para entrar siguen haciendo falta el usuario y la contraseña, y la conexión va cifrada.

## Cómo publicar cambios

Cada merge o push a `004-pagos-tickets-dashboard` vuelve a desplegar en Render por sí solo.

Si cambia el cliente (Flutter), hay que recompilar la web y volver a copiarla. Debe hacerse desde **PowerShell**, no desde Git Bash, porque este convierte `/api` en una ruta de Windows:

```powershell
cd client
flutter build web --release --web-resources-cdn --dart-define=API_BASE_URL=/api
Remove-Item ..\server\public -Recurse -Force -ErrorAction SilentlyContinue
robocopy build\web ..\server\public /E /XD canvaskit
```

Después se hace commit de `server/public` (pesa unos 6 MB; la carpeta `canvaskit` se excluye porque el navegador la baja del CDN de Flutter).

## Límites y cuidados del plan gratuito

- **Render se duerme** tras 15 minutos sin visitas. La primera visita después tarda alrededor de 50 segundos. Se decidió no agregar ningún aviso propio: se espera que Render muestre el suyo, cosa que no se verificó.
- **Horas compartidas:** Render da 750 horas al mes para todo el espacio de trabajo, incluidos los servicios `duopost` y `api-products`.
- **Cuota de TiDB:** 50 millones de Request Units y 5 GiB de almacenamiento al mes. Si se agota, la base rechaza conexiones nuevas hasta el mes siguiente, sin cobro (no hay tarjeta ni límite de gasto). El panel de TiDB mostraba 0 de uso aun después de las pruebas, así que no se pudo medir cuánta cuota se gastó.
- **No correr la suite de pruebas contra TiDB:** consume cuota y tarda mucho por la latencia (25 pruebas tardaron 8 minutos). Para pruebas se usa el MySQL local.
- **Respaldo:** el MySQL local conserva todo. Si TiDB o Render fallaran el día de una presentación, se puede mostrar la aplicación corriendo en la computadora.

## Decisiones y riesgos aceptados

- **Contraseñas de prueba sin cambiar:** por ser un proyecto escolar, las cuentas conservan las contraseñas del estándar del MVP, que están en `docs/project-context.md`. Cualquiera que las conozca puede entrar como administrador. Para cambiarlas existe `server/scripts/restablecerContrasena.js`.
- **Acceso a TiDB abierto a todas las IP**, como se explicó arriba.
- **`.env.tidb`:** guarda las credenciales de TiDB en la carpeta del proyecto. Git lo ignora, pero conviene borrarlo si la carpeta se comparte.

## Qué se verificó y qué no

**Verificado:**
- Las 7 migraciones aplican en una base vacía de TiDB.
- En TiDB pasan `orders.create`, `payments.concurrency` y la prueba corregida de refacciones simultáneas.
- Suites completas en MySQL local antes de publicar: 1 546 pruebas del servidor y 451 del cliente.
- En producción: la API responde, la web carga, las rutas protegidas piden sesión y el inicio de sesión funciona con la base de TiDB.

**No verificado:**
- El resto de las pruebas de concurrencia en TiDB (`tickets`, `clientNotices`) ni la suite completa.
- La descarga de Excel, el ticket impreso y el cierre por inactividad en la versión publicada.
- Que Render muestre un aviso propio al despertar.
