# Motorix - Backlog en las 5 fases del PMI, con fechas

> **Proyecto:** Motorix, sistema de gestión para taller mecánico. **Corte:** 2026-11-19.
> **Calendario:** inicio el **1 de septiembre de 2026**, entrega el **30 de noviembre** y holgura del **1 al 5 de diciembre**.
> **Formato:** estilo Jira. Cada fase del PMI es una **épica** con su ventana de fechas y cada entregable es una **historia de usuario** con sus criterios de aceptación.
> **Estado:** ✅ Listo · 🔄 En curso · ⬜ Por hacer.
> **Fechas:** las de octubre y del 1 de noviembre salen del historial real de commits; las de septiembre y las de noviembre posteriores al 19 son planificadas.

**Línea de tiempo**

| Periodo | Fechas | Fase / trabajo | Estado |
|---|---|---|---|
| Septiembre | 1 al 7 sep | PMI-E1 Inicio | ✅ |
| Septiembre y octubre | 8 sep al 9 oct | PMI-E2 Planificación | ✅ |
| Octubre | 10 al 17 oct | PMI-E3 Ejecución: sprints 1 a 4 (MVP) | ✅ |
| Octubre | 17 al 26 oct | PMI-E4 Monitoreo: auditoría del MVP | ✅ |
| Octubre y noviembre | 27 oct al 1 nov | Sprint 5 (especificación, construcción y auditoría) | ✅ |
| Noviembre | 2 al 19 nov | Reporte, backlog y ajuste del alcance (se descarta el Sprint 8) | ✅ |
| Noviembre | 20 al 24 nov | Sprint 6: notificaciones internas | ⬜ |
| Noviembre | 25 al 29 nov | Sprint 7: reportes, configuración, términos y seguridad | ⬜ |
| Noviembre | 30 nov | Auditoría final, cierre y **entrega** | ⬜ |
| Diciembre | 1 al 5 dic | **Holgura** (reserva: no se trabaja en nada, salvo que el tiempo esté muy justo) | ⬜ |

```text
Sep ───────────── Oct ───────────── Nov ──────────── Dic
1      8        10   17   26 1   19  20   25   30 1      5
[Inicio][Planificación][S1-S4][Aud MVP][S5][..][S6][S7][Cierre][Holgura]
```

**Resumen por fase**

| Épica | Fase PMI | Fechas | Historias | Estado |
|---|---|---|---|---|
| PMI-E1 | Inicio | 1 al 7 sep | PMI-1 a PMI-3 | ✅ |
| PMI-E2 | Planificación | 8 sep al 9 oct | PMI-4 a PMI-7 | ✅ |
| PMI-E3 | Ejecución | 10 oct al 29 nov | PMI-8 a PMI-14 | 🔄 |
| PMI-E4 | Monitoreo y control | 17 oct al 30 nov | PMI-15 a PMI-17 | 🔄 |
| PMI-E5 | Cierre | 30 nov | PMI-18 a PMI-20 | ⬜ |

**Roles:** gestor del proyecto (el alumno), docente, administrador, recepcionista y mecánico.

---

## PMI-E1 · Inicio (Initiation) · 1 al 7 sep · ✅

### PMI-1 · Acta de constitución
- **Tipo:** Historia · **Prioridad:** Alta · **Fechas:** 1 al 3 sep · **Estado:** ✅ Hecho
- **Historia:** Como gestor del proyecto, quiero un acta de constitución con el propósito, los objetivos y el alcance inicial para acordar con el docente qué se construye.
- **Criterios de aceptación:**
  - Describe el problema: los talleres mecánicos no concentran clientes, vehículos, servicios e inventario.
  - Fija tres objetivos medibles: centralizar el 100% de la información registrada, registrar el 100% de los servicios en el historial del vehículo y generar recordatorios de mantenimiento por fecha y kilometraje.
  - Define el alcance del MVP y de las funcionalidades posteriores.

### PMI-2 · Registro de interesados
- **Tipo:** Historia · **Prioridad:** Alta · **Fechas:** 4 al 5 sep · **Estado:** ✅ Hecho
- **Historia:** Como gestor del proyecto, quiero un registro de interesados con su interés e influencia para saber a quién sirve cada funcionalidad.
- **Criterios de aceptación:**
  - Incluye administrador, recepcionista, mecánico y cliente, cada uno con su interés y su influencia.
  - El cliente figura como beneficiario externo, no como usuario del sistema.

### PMI-3 · Concepción arquitectónica
- **Tipo:** Historia · **Prioridad:** Alta · **Fechas:** 6 al 7 sep · **Estado:** ✅ Hecho
- **Historia:** Como gestor del proyecto, quiero definir el stack y el uso de IA generativa para estructurar el desarrollo desde el inicio.
- **Criterios de aceptación:**
  - Cliente en Flutter, API en Node.js con Express, base de datos MySQL, autenticación con JWT y cobro con Mercado Pago en modo de pruebas.
  - Desarrollo con Claude Code y Spec Kit.

---

## PMI-E2 · Planificación (Planning) · 8 sep al 9 oct · ✅

### PMI-4 · Especificación del sistema
- **Tipo:** Historia · **Prioridad:** Alta · **Fechas:** 8 sep al 9 oct (sprints 1 a 4); cada sprint posterior se especifica al iniciar · **Estado:** ✅ Hecho (sprints 1 a 5); ⬜ sprints 6 y 7 al iniciar cada uno
- **Historia:** Como gestor del proyecto, quiero especificar cada sprint antes de construirlo para que la IA implemente lo pedido y no lo que inventó.
- **Criterios de aceptación:**
  - Cada sprint tiene su especificación, su plan, su modelo de datos y su lista de tareas.
  - Las dudas se aclaran antes de planear.
  - Los sprints 6 y 7 se especifican antes de construirse.

### PMI-5 · Alcance y Product Backlog
- **Tipo:** Historia · **Prioridad:** Alta · **Fechas:** 8 sep al 9 oct; actualizado el 19 nov · **Estado:** ✅ Hecho
- **Historia:** Como gestor del proyecto, quiero un enunciado de alcance y un backlog de épicas e historias para controlar qué entra y qué no.
- **Criterios de aceptación:**
  - El backlog tiene 10 épicas y 44 historias de usuario (27 hechas y 17 pendientes) con criterios de aceptación.
  - **Entra:** usuarios y roles, clientes, vehículos, citas, órdenes, historial, mantenimiento, inventario, precios de refacciones, pagos, Mercado Pago de pruebas, tickets, panel, notificaciones internas y reportes.
  - **Queda fuera:** chatbot de WhatsApp y mensajería al cliente, portal del cliente, facturación electrónica, fotos del vehículo, hosting y puesta en producción.

### PMI-6 · Presupuesto integral
- **Tipo:** Historia · **Prioridad:** Media · **Fechas:** 1 al 9 oct · **Estado:** ✅ Hecho
- **Historia:** Como gestor del proyecto, quiero un presupuesto con mano de obra, IA, alojamiento y reserva de riesgos para justificar el costo del proyecto.
- **Criterios de aceptación:**
  - La reserva de riesgos es el 15% del subtotal.
  - El alojamiento cuesta $0.00 porque el sistema corre en local.

| Categoría | Cálculo | Subtotal (MXN) |
|---|---|---|
| Mano de obra (gestión) | 18 h × $150 | $2,700.00 |
| Mano de obra (pruebas) | 6 h × $150 | $900.00 |
| Herramientas de IA (Claude Pro) | 2 meses × 20 USD (≈ $370 al mes) | $740.00 |
| Alojamiento | Local, sin contratar | $0.00 |
| **Subtotal** | | **$4,340.00** |
| Reserva de riesgos | $4,340.00 × 15% | $651.00 |
| **Costo total** | | **$4,991.00** |

### PMI-7 · Plan de gestión de riesgos
- **Tipo:** Historia · **Prioridad:** Alta · **Fechas:** 1 al 9 oct · **Estado:** ✅ Hecho
- **Historia:** Como gestor del proyecto, quiero identificar los riesgos con su probabilidad, impacto y respuesta para actuar antes de que afecten la entrega.
- **Criterios de aceptación:**
  - Cada riesgo tiene probabilidad (A, M o B), impacto, respuesta, plazo y estado.
  - Cubre los riesgos base: recursos, operación, desempeño, claridad, alcance, costo y tiempo.

| No. | Riesgo | Prob. | Impacto | Respuesta | Plazo | Estado |
|---|---|---|---|---|---|---|
| 1 | Escasez de recursos: depende de la cuota de Claude Pro | M | El avance se detiene a mitad de un sprint | Sprints cortos y commits pequeños | Continuo | Vigilado |
| 2 | Contratiempos operativos: internet e incompatibilidades de versiones | M | No se puede avanzar ni demostrar | Fijar versiones y documentar el entorno | Antes de cada sprint | Mitigado |
| 3 | Bajo desempeño del código generado por IA | M | Consultas lentas y errores de dinero o de stock | Pruebas automáticas y prueba de rendimiento | Cada sprint | Mitigado |
| 4 | Falta de claridad en lo que se pide a la IA | A | Se implementa algo distinto de lo pedido | Aclarar decisiones antes de programar | Antes de programar | Mitigado |
| 5 | Corrupción del alcance | A | El MVP no se termina de demostrar y el costo crece | Backlog cerrado y descartes por escrito | Continuo | Controlado |
| 6 | Costos y tiempo sin registro de horas | M | Se subestima el costo y no hay reserva | Reserva del 15% y registro de horas | Desde el Sprint 6 (20 nov) | Abierto |
| 7 | Cierre del 30 de noviembre con los sprints 6 y 7 sin construir | M | La auditoría final queda vacía | Construir primero el Sprint 6 y dividir el 7 si falta tiempo | Antes del 30 nov | Abierto |

---

## PMI-E3 · Ejecución (Execution) · 10 oct al 29 nov · 🔄

> Cada historia es un sprint y enlaza las historias del backlog del producto (`MOT-n`).

### PMI-8 · Sprint 1: base, clientes y vehículos
- **Tipo:** Historia · **Prioridad:** Alta · **Fechas:** 10 al 11 oct · **Estado:** ✅ Hecho · **Producto:** MOT-1 a MOT-6
- **Historia:** Como recepcionista, quiero iniciar sesión y registrar clientes y vehículos para empezar a atender en el taller.
- **Criterios de aceptación:**
  - Inicio de sesión por rol, gestión de usuarios, clientes y vehículos con su propietario.

### PMI-9 · Sprint 2: citas y órdenes de servicio
- **Tipo:** Historia · **Prioridad:** Alta · **Fechas:** 10 al 11 oct · **Estado:** ✅ Hecho · **Producto:** MOT-7 a MOT-12
- **Historia:** Como recepcionista, quiero registrar citas y crear órdenes de servicio asignadas a un mecánico para organizar el trabajo.
- **Criterios de aceptación:**
  - Citas, órdenes, asignación a mecánico, diagnóstico, servicios y cambios de estado.

### PMI-10 · Sprint 3: historial e inventario
- **Tipo:** Historia · **Prioridad:** Alta · **Fechas:** 11 oct · **Estado:** ✅ Hecho · **Producto:** MOT-13 a MOT-18
- **Historia:** Como mecánico, quiero consultar el historial del vehículo y descontar refacciones del inventario para dar seguimiento al mantenimiento.
- **Criterios de aceptación:**
  - Historial por vehículo, kilometraje, próximo mantenimiento, inventario y alertas de stock bajo.

### PMI-11 · Sprint 4: pagos, tickets y panel
- **Tipo:** Historia · **Prioridad:** Alta · **Fechas:** 11 al 17 oct · **Estado:** ✅ Hecho · **Producto:** MOT-19 a MOT-22
- **Historia:** Como recepcionista, quiero cobrar la orden y entregar un ticket para cerrar el servicio.
- **Criterios de aceptación:**
  - Pago por método, Mercado Pago de pruebas, ticket imprimible y panel de control del administrador.

### PMI-12 · Sprint 5: precios de refacciones y cobro
- **Tipo:** Historia · **Prioridad:** Alta · **Fechas:** 27 oct al 1 nov · **Estado:** ✅ Hecho · **Producto:** MOT-27 a MOT-31
- **Historia:** Como administrador, quiero registrar precios de refacciones y cobrarlos dentro del total para que el ticket sea correcto.
- **Criterios de aceptación:**
  - Categoría, marca y precios; total de la orden con refacciones; pagos y tickets viejos sin cambios; precios reservados por rol.

### PMI-13 · Sprint 6: notificaciones internas
- **Tipo:** Historia · **Prioridad:** Alta · **Fechas:** 20 al 24 nov · **Estado:** ⬜ Por hacer · **Producto:** MOT-32 a MOT-38
- **Historia:** Como recepcionista, quiero ver avisos y una lista de clientes por avisar para contactarlos a tiempo.
- **Criterios de aceptación:**
  - Centro de notificaciones, avisos por rol, marca de leído y lista de clientes por avisar.

### PMI-14 · Sprint 7: reportes, configuración, términos y seguridad
- **Tipo:** Historia · **Prioridad:** Alta · **Fechas:** 25 al 29 nov · **Estado:** ⬜ Por hacer · **Producto:** MOT-39 a MOT-48
- **Historia:** Como administrador, quiero reportes, configuración del taller, términos y condiciones y protección de la información para tomar decisiones, mantener los datos del ticket y operar con seguridad.
- **Criterios de aceptación:**
  - Datos del taller, márgenes de mantenimiento, catálogo de servicios, reportes con exportación y "Próximo servicio" en el ticket.
  - Términos y condiciones con aceptación al ingresar, bitácora de acciones sensibles, política de contraseñas y cierre de sesión por inactividad.
  - Si el tiempo no alcanza, se divide: configuración, catálogo, términos y seguridad primero; reportes después.

---

## PMI-E4 · Monitoreo y control (Monitoring & Controlling) · 17 oct al 30 nov · 🔄

### PMI-15 · Auditoría de calidad del MVP
- **Tipo:** Historia · **Prioridad:** Alta · **Fechas:** 17 al 26 oct · **Estado:** ✅ Hecho
- **Historia:** Como gestor del proyecto, quiero auditar los sprints 1 a 4 para demostrar que cumplen sus requisitos.
- **Criterios de aceptación:**
  - Cada requisito tiene su criterio verificable, su prueba, su resultado, su prioridad y sus observaciones.
  - Todos los requisitos auditados quedan aprobados.

### PMI-16 · Auditoría de calidad de la fase 2 (avance al 20 de noviembre)
- **Tipo:** Historia · **Prioridad:** Alta · **Fechas:** 27 oct al 1 nov · **Estado:** ✅ Hecho
- **Historia:** Como gestor del proyecto, quiero auditar el Sprint 5 con los mismos rubros para comprobar que lo nuevo no rompió lo anterior.
- **Criterios de aceptación:**
  - Se audita el cobro con refacciones, la conservación de pagos y tickets viejos y la reserva de precios.
  - Los riesgos del sprint quedan mitigados.

### PMI-17 · Auditoría de calidad de la fase 3 (cierre, 30 de noviembre)
- **Tipo:** Historia · **Prioridad:** Alta · **Fechas:** 24 al 30 nov (sprint 6 el 24 y sprint 7 el 29 o 30) · **Estado:** ⬜ Por hacer
- **Historia:** Como gestor del proyecto, quiero auditar los sprints 6 y 7 para cerrar el semestre con las últimas integraciones verificadas.
- **Criterios de aceptación:**
  - Cada criterio de MOT-32 a MOT-48 queda con prueba y resultado.
  - Los defectos se registran con su prioridad.

---

## PMI-E5 · Cierre (Closing) · 30 nov · ⬜

### PMI-18 · Entrega final del software
- **Tipo:** Historia · **Prioridad:** Alta · **Fechas:** 30 nov · **Estado:** ⬜ Por hacer
- **Historia:** Como gestor del proyecto, quiero entregar el sistema con todas las fases concluidas para que el docente lo evalúe.
- **Criterios de aceptación:**
  - El sistema funciona en local con todos los sprints entregados.
  - Queda por confirmar con el docente que una demostración local cumple "sistema desplegado".

### PMI-19 · Viabilidad y deuda técnica
- **Tipo:** Historia · **Prioridad:** Media · **Fechas:** 30 nov · **Estado:** ⬜ Por hacer
- **Historia:** Como gestor del proyecto, quiero un dictamen de viabilidad y de deuda técnica para decir si el sistema está listo para producción.
- **Criterios de aceptación:**
  - La deuda lista: sin despliegue, HTTPS ni respaldos; Mercado Pago solo de pruebas; sin fotos del vehículo; sin mensajería al cliente; sin revisión de seguridad formal.
  - El dictamen final se escribe después de la auditoría de la fase 3.

### PMI-20 · Lecciones aprendidas
- **Tipo:** Historia · **Prioridad:** Media · **Fechas:** 30 nov · **Estado:** 🔄 Borrador
- **Historia:** Como gestor del proyecto, quiero reflexionar sobre el ciclo completo para dejar documentado qué funcionó y qué mejorar.
- **Criterios de aceptación:**
  - Registra aciertos y mejoras de la gestión con IA, del alcance, de la calidad y de los costos.
  - El alumno confirma el texto antes del 30 de noviembre.

| Qué funcionó | Qué mejorar |
|---|---|
| Aclarar antes de programar redujo el retrabajo | Llevar un registro de horas y costos desde el principio |
| Fijar reglas del proyecto mantuvo el estilo y el idioma | Controlar antes el alcance |
| Las pruebas detectaron errores de la IA | Fijar las versiones de dependencias desde el inicio |
| Descartar a tiempo protegió el cierre | Mantener alineados el backlog y la documentación |

---

**Holgura · 1 al 5 de diciembre (no es parte de las 5 fases ni del cierre)**

> La holgura es una reserva de tiempo aparte; el Cierre termina el 30 de noviembre.

- **Regla:** en la holgura no se hace nada. Es una reserva y no forma parte del plan de trabajo.
- **Excepción:** solo si el tiempo está muy justo el 30 de noviembre, se usa para terminar lo que falte del Sprint 7 y para corregir los defectos críticos de la auditoría final.
- **Nunca:** funciones nuevas fuera del backlog.
