# Guía de validación: Reportes, configuración, términos y seguridad (Sprint 7)

Escenarios para comprobar de extremo a extremo que el sprint funciona. Los detalles del esquema están en
[data-model.md](./data-model.md), los de la API en [contracts/api-rest.md](./contracts/api-rest.md) y los de la interfaz en
[contracts/interfaz.md](./contracts/interfaz.md).

## Requisitos previos

- MySQL 8 local con las bases `motorix` y `motorix_test` y el usuario `motorix_app` (ver `database/README.md`).
- `server/.env` configurado (sin secretos en el repositorio). El sprint no usa servicios externos ni dependencias nuevas.
- Dependencias instaladas en `server/` (`npm install`) y en `client/` (`flutter pub get`).

## 1. Preparar la base

```powershell
database\scripts\aplicar-migraciones.ps1 -Base motorix
database\scripts\aplicar-seeds.ps1 -Base motorix
```

Resultado esperado: se aplica la migración `007` y el seed `007`. Volver a ejecutar ambos no duplica ni falla. Para la base de
pruebas, repetir con `-Base motorix_test`. Todos los usuarios existentes quedan sin aceptar los términos `1.0`.

## 2. Línea base y regresión

```powershell
cd server; npm test
cd ..\client; flutter test
```

Resultado esperado: pasan las pruebas de los sprints 1 a 6 (la última cifra documentada es 1 349 de backend y 373 de
frontend, que se mide de nuevo antes de empezar) más las pruebas nuevas. Las que cambien por declaración de la
especificación (contraseña de 10 caracteres, aceptación de términos y configuración) se registran en el documento de
aseguramiento.

## 3. Pruebas del sprint

```powershell
cd server; npm test -- tests/unit/serviceIntervals tests/unit/reportRules tests/unit/csv tests/unit/passwordPolicy tests/integration/settings tests/integration/serviceTypes tests/integration/terms tests/integration/audit tests/integration/session tests/integration/reports tests/integration/dataExposure tests/integration/injection tests/integration/seed.settings tests/contract/settings tests/contract/serviceTypes tests/contract/reports tests/contract/terms tests/contract/audit
cd ..\client; flutter test test/settings_test.dart test/service_types_test.dart test/reports_test.dart test/terms_test.dart test/audit_log_test.dart test/inactivity_test.dart
```

Resultado esperado: todas aprobadas. Los nombres exactos de los archivos son los de `tasks.md`.

## 4. Recorrido manual (flujo demostrable)

Con la API y el cliente levantados y los datos de ejemplo cargados:

1. Inicia sesión como administrador. **Esperado**: aparece la pantalla de términos; aceptarlos lleva al inicio. Al volver a
   iniciar sesión no se piden de nuevo.
2. Abre **Configuración → Taller**, cambia el nombre y el teléfono y guarda. Genera un ticket de una orden cobrada.
   **Esperado**: el ticket nuevo muestra los datos nuevos y un ticket anterior se ve igual que antes.
3. En **Configuración → Mantenimiento** cambia el margen de 30 a 15 días. **Esperado**: la lista de Mantenimientos, el panel
   de control y los avisos usan el nuevo margen y sus números coinciden.
4. En **Configuración → Tipos de servicio** crea «Cambio de aceite» (180 días y 5 000 km). Como mecánico, agrega a una orden
   un servicio de ese tipo, termínala y programa el próximo mantenimiento con **Usar el intervalo del servicio**.
   **Esperado**: se rellenan la fecha y el kilometraje y se pueden corregir. Genera el ticket: muestra «Próximo servicio».
5. Abre **Reportes**, elige **Este mes** y recorre las tres pestañas. **Esperado**: los ingresos coinciden con los pagos
   pagados del mes; los servicios y mecánicos tienen datos; las refacciones sin precio de compra muestran «Sin costo».
6. Pulsa **Exportar CSV** en cada pestaña y abre el archivo en una hoja de cálculo. **Esperado**: coincide con la pantalla,
   las tildes se ven bien y los importes tienen dos decimales.
7. Cambia el rol de un usuario y el precio de una refacción, y abre **Bitácora**. **Esperado**: ambas acciones aparecen con
   quién, cuándo y qué; el filtro por acción las separa; no hay forma de editar ni borrar.
8. Intenta crear un usuario con la contraseña `Corta1Aa`. **Esperado**: se rechaza por tener menos de 10 caracteres.
9. Como recepcionista o mecánico, intenta abrir Reportes, Configuración y Bitácora. **Esperado**: no aparecen en el menú y
   la API responde 403.
10. Deja la sesión sin actividad. **Esperado**: a los 28 minutos aparece el aviso con cuenta regresiva y a los 30 se cierra la
    sesión (para ver el efecto sin esperar, la prueba `inactivity_test.dart` lo simula con tiempo controlado).

## 5. Comprobaciones con la API

```powershell
# Sustituye $token por el de la sesión de prueba (después de aceptar los términos)
curl -H "Authorization: Bearer $token" http://localhost:3000/api/terms/current
curl -H "Authorization: Bearer $token" "http://localhost:3000/api/reports/income?from=2026-11-01&to=2026-11-30"
curl -H "Authorization: Bearer $token" "http://localhost:3000/api/reports/income?from=2026-11-01&to=2026-11-30&format=csv"
curl -H "Authorization: Bearer $token" "http://localhost:3000/api/audit-log?action=PART_PRICE_CHANGED"
```

Resultados esperados:

- Las respuestas cumplen [contracts/api-rest.md](./contracts/api-rest.md).
- Con el token del mecánico, `/api/reports/*`, `/api/settings`, `/api/audit-log` y `/api/terms/acceptances` responden 403.
- Con un usuario que no aceptó los términos, cualquier ruta (salvo `/terms/current`, `/terms/accept` y `/auth/me`) responde
  `403 TERMS_NOT_ACCEPTED`.
- Un rango de más de 366 días o con `to` anterior a `from` responde `400 VALIDATION_ERROR`.

## 6. Rendimiento

Con el generador de datos de la prueba de rendimiento (1 000 pagos y 1 000 órdenes con sus servicios y refacciones), cada
reporte responde en menos de 3 segundos (SC-006).

## 7. Cierre del sprint

- `docs/project-context.md`, `docs/design-system.md` y `.env.example` actualizados.
- Documento de aseguramiento de la calidad del sprint con la línea base, la regresión y la matriz final.
- Verificar que no hay dependencias nuevas en `server/package.json` ni en `client/pubspec.yaml` (la exportación es CSV).
