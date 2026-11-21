# Guía de validación: Notificaciones internas y clientes por avisar (Sprint 6)

Escenarios para comprobar de extremo a extremo que el sprint funciona. Los detalles del esquema están en
[data-model.md](./data-model.md), los de la API en [contracts/api-rest.md](./contracts/api-rest.md) y los de la
interfaz en [contracts/interfaz.md](./contracts/interfaz.md).

## Requisitos previos

- MySQL 8 local con las bases `motorix` y `motorix_test` y el usuario `motorix_app` (ver `database/README.md`).
- `server/.env` configurado (sin secretos en el repositorio). El sprint no usa servicios externos.
- Dependencias instaladas en `server/` (`npm install`) y en `client/` (`flutter pub get`).

## 1. Preparar la base

```powershell
database\scripts\aplicar-migraciones.ps1 -Base motorix
database\scripts\aplicar-seeds.ps1 -Base motorix
```

Resultado esperado: se aplica la migración `006` y el seed `006`. Volver a ejecutar ambos no duplica ni falla.
Para la base de pruebas, repetir con `-Base motorix_test`.

## 2. Línea base y regresión

```powershell
cd server; npm test
cd ..\client; flutter test
```

Resultado esperado: pasan las pruebas de los sprints 1 a 5 (la última cifra documentada es 1 215 de backend y
321 de frontend, que se mide de nuevo antes de empezar) más las pruebas nuevas. Las que cambien por declaración
de la especificación se registran en el documento de aseguramiento.

## 3. Pruebas del sprint

```powershell
cd server; npm test -- tests/unit/noticeRules.test.js tests/unit/noticeValidators.test.js tests/integration/notifications tests/integration/clientNotices tests/integration/seed.notices.test.js tests/contract/notifications tests/contract/clientNotices
cd ..\client; flutter test test/notice_models_test.dart test/notifications_test.dart test/client_notices_test.dart
```

Resultado esperado: todas aprobadas. Los nombres de los archivos son los de `tasks.md` (T006, T008, T014 a T016, T024 a T025, T029 a T031, T036 a T039, T046 a T047, T051 a T052, T056 a T057 y T061 a T062); la prueba de rendimiento se ejecuta aparte (sección 6).

## 4. Recorrido manual (flujo demostrable)

Con la API y el cliente levantados y los datos de ejemplo cargados:

1. Inicia sesión como administrador. **Esperado**: la campana del encabezado muestra el total de avisos no leídos
   (hay al menos un caso de cada tipo).
2. Abre el panel. **Esperado**: aparecen, agrupados, mantenimientos vencidos, stock agotado, órdenes detenidas,
   citas de hoy, mantenimientos próximos y stock bajo.
3. Pulsa el aviso de stock. **Esperado**: llegas a Inventario, el aviso queda leído y el contador baja en uno.
4. Cierra sesión y vuelve a entrar. **Esperado**: el aviso sigue leído.
5. Inicia sesión como recepcionista. **Esperado**: ves mantenimientos, citas y órdenes detenidas; **no** ves avisos
   de stock. Tu lectura del paso 3 no cuenta aquí (la lectura es por usuario).
6. Inicia sesión como mecánico. **Esperado**: solo ves avisos de órdenes detenidas que tengas asignadas, sin
   nombre de cliente.
7. Como recepcionista abre **Clientes por avisar**. **Esperado**: ves a los clientes con teléfono, vehículo y
   motivo (vehículo listo, cita de mañana, mantenimiento próximo o vencido).
8. Pulsa **Avisado** en la orden terminada y confirma. **Esperado**: la fila sale de la lista y no reaparece al
   actualizar.
9. Como mecánico intenta abrir la lista, con la interfaz o con la API. **Esperado**: no aparece en el menú y la
   API responde 403.
10. Espera 60 segundos con el panel cerrado después de cambiar de estado una orden detenida (desde otro usuario).
    **Esperado**: el aviso desaparece de la campana sin recargar.

## 5. Comprobaciones con la API

```powershell
# Sustituye $token por el de la sesión de prueba
curl -H "Authorization: Bearer $token" http://localhost:3000/api/notifications
curl -X POST -H "Authorization: Bearer $token" -H "Content-Type: application/json" `
  -d '{"keys":["STOCK_LOW:1"]}' http://localhost:3000/api/notifications/read
curl -H "Authorization: Bearer $token" http://localhost:3000/api/client-notices
```

Resultados esperados:

- La respuesta cumple [contracts/api-rest.md](./contracts/api-rest.md).
- Con el token del mecánico, `/api/notifications` solo trae `STALLED` de sus órdenes y `/api/client-notices`
  responde 403.
- Repetir el `POST /api/notifications/read` con la misma clave responde 200 y no duplica filas.
- Un `POST /api/client-notices` repetido responde 200 la segunda vez, no un error.

## 6. Rendimiento

Con el generador de datos de la prueba de rendimiento (1 000 órdenes, 1 000 citas y 1 000 mantenimientos), la
consulta `GET /api/notifications` responde en menos de 2 segundos (SC-007).

## 7. Cierre del sprint

- `docs/project-context.md` (sección 6.12) y `docs/design-system.md` actualizados.
- Documento de aseguramiento de la calidad del sprint con la línea base, la regresión y la matriz final.
- Verificar que el sistema no envía ningún mensaje al cliente: no existe ninguna integración de mensajería
  (SC-006).
