# Trazabilidad: requisito → tarea → commit → prueba

Evidencia del apartado 6 del reporte (`docs/Reporte_SDD_SpecKit.md`). Rama `004-pagos-tickets-dashboard`.

## Resultado de las pruebas (ejecutadas el 2026-10-17)

| Capa | Comando | Resultado | Salida completa |
|---|---|---|---|
| Backend | `npm test` en `server/` (Jest + supertest, base `motorix_test`) | 67 suites y 1 003 pruebas aprobadas, 0 fallas (60 s) | `docs/evidencias/pruebas-backend-jest.txt` |
| Frontend | `flutter test` en `client/` | 277 pruebas aprobadas, 0 fallas | `docs/evidencias/pruebas-frontend-flutter.txt` |

## Commits ↔ tareas

| Commit | Sprint | Tareas marcadas `[X]` en `tasks.md` | Qué implementa |
|---|---|---|---|
| `32ee589` | 1 | 108 (`specs/001-.../tasks.md`) | Constitution, base del sistema, autenticación, usuarios, clientes y vehículos |
| `32ee589` | 2 | 88 (`specs/002-.../tasks.md`) | Citas y órdenes de servicio |
| `a7c440a` | 3 | 77 (`specs/003-.../tasks.md`) | Historial, mantenimiento e inventario de refacciones |
| `be83ef9` | 4 | 70 (`specs/004-.../tasks.md`) | Pagos, tickets y panel de control |
| `735e5be` | 4 | — | Alineación del contrato y del modelo de datos con lo implementado |
| `0e4709f` | 4 | — | Renovación de la interfaz y rediseño del panel con gráficas |
| `fbf7cbd` | 4 | — | Logo de la aplicación |

Total: 343 tareas terminadas, ninguna pendiente. Los sprints 1 y 2 entraron juntos en `32ee589`, y cada sprint lleva su `tasks.md` en el mismo commit que su código.

## Requisito → prueba (sprint 1: requisitos reescritos en EARS)

| Requisito | Prueba que lo verifica | Resultado |
|---|---|---|
| FR-008a: cuenta desactivada rechazada | `server/tests/integration/auth.flow.test.js` → `test_rechaza_una_cuenta_desactivada_con_el_mismo_mensaje_generico` | Sí |
| FR-008b: mensaje que no revela cuál dato falló | `auth.flow.test.js` → `test_contrasena_incorrecta_y_cuenta_inexistente_dan_el_mismo_mensaje_generico` | Sí |
| FR-008c: bloqueo tras 5 fallos y 15 minutos | `auth.flow.test.js` → `test_bloquea_la_cuenta_tras_5_fallos_consecutivos_aun_con_la_contrasena_correcta` y `test_el_bloqueo_vence_pasados_15_minutos` | Sí |
| FR-008d: contador a cero tras acceso correcto | `auth.flow.test.js` → `test_un_acceso_correcto_reinicia_el_contador_de_fallos` | Sí |
| FR-012a: vehículo sin propietario rechazado | `server/tests/integration/vehicles.flow.test.js` → `test_rechaza_un_vehiculo_sin_propietario` | Sí |
| FR-012b: propietario inexistente rechazado | `server/tests/integration/vehicles.owner.test.js` → `test_rechaza_un_propietario_inexistente_con_422_y_conserva_al_actual` | Sí |
| FR-012c: vehículo creado asociado al cliente | `server/tests/contract/vehicles.contract.test.js` → `test_crea_un_vehiculo_y_devuelve_201_con_el_propietario` | Sí |

## Criterios de éxito (sprint 4)

| Criterio | Prueba | Resultado |
|---|---|---|
| Historia 1: segundo pago vigente rechazado | `server/tests/integration/payments.flow.test.js` → `test_no_admite_un_segundo_pago_vigente` | Sí |
| Historia 1: importe distinto del total rechazado con el total a cobrar | `payments.flow.test.js` → `test_rechaza_un_importe_distinto_e_informa_el_total` | Sí |
| SC-005: cero órdenes con dos pagos vigentes, con solicitudes simultáneas | `server/tests/integration/payments.concurrency.test.js` → `test_cinco_cobros_simultaneos_con_metodos_distintos_dejan_un_solo_pago` | Sí |
| Sin datos de tarjeta en la base | `payments.flow.test.js` → `test_la_tabla_de_pagos_no_tiene_columnas_de_tarjeta` | Sí |
| SC-001: pago en menos de 1 minuto | Medición de uso con una persona; no hay prueba automática | 🟡 por medir |

## Lo que no se verificó
- SC-001 del sprint 4 y otros criterios de tiempo de uso (SC-003 y SC-004 del sprint 1) dependen de pruebas con personas, no de pruebas automáticas.
- No se ejecutó `/speckit.analyze`.
- Las capturas de pantalla de la aplicación funcionando están pendientes en `docs/evidencias/`.
