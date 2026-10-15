# Propuesta de sprints posteriores al MVP

> **Estado:** borrador para revisión. No es un insumo de `/speckit.specify` todavía.
> **Base:** `docs/project-context.md` (alcance, sección 7 "Funcionalidad fuera del MVP actual" y sección 27 "Decisiones pendientes").
> **Fecha:** 2026-10-12

## Cómo leer este documento

Cada sprint está marcado según su origen:

- **Deuda:** viene del contexto maestro (algo que el MVP dejó explícitamente pendiente).
- **Propuesta:** idea nueva, no está en el contexto maestro.
- **Por verificar:** se afirmó sin revisar el código; hay que confirmarlo antes de redactar el sprint.

## Descartado

- **Portal del cliente:** contradice el contexto. El cliente es un beneficiario externo y solo recibe información y recordatorios, no es un usuario autenticado.
- **Facturación electrónica:** no aparece en el contexto maestro.

## Sprint 5: Precios de refacciones y cobro completo *(deuda)*

- Categoría, marca, precio de compra y precio de venta en `parts`.
- El total de la orden suma las refacciones. El pago y el ticket reflejan el nuevo total.
- Los pagos y tickets ya generados conservan su importe, porque son instantáneas.
- Motivo: el Sprint 3 difirió estos campos a los sprints de pagos y tickets, y el Sprint 4 los dejó fuera. Hoy el total de cobro es solo servicios más mano de obra.

## Sprint 6: Notificaciones internas *(deuda, por verificar)*

- Centro de notificaciones en el header: mantenimientos próximos y vencidos, citas del día, stock bajo y órdenes detenidas.
- Se calculan con datos reales, sin duplicarlos. Solo se guarda el estado "leída".
- Referencia: sección 6.12 del contexto maestro.
- **Por verificar:** puede que el dashboard o el header ya cubran parte de esto.

## Sprint 7: Reportes y configuración *(propuesta, por verificar)*

- Reportes para el administrador: ingresos por periodo, servicios frecuentes, productividad por mecánico y rotación de inventario, con exportación.
- Configuración del taller: datos para el ticket y márgenes de "Próximo" en mantenimiento.
- Catálogo de tipos de servicio con intervalos configurables, para no asumir intervalos universales (regla de negocio 12).
- **Por verificar:** puede que los datos del taller ya sean configurables.

## Sprint 8: Comunicación con el cliente, preparación del chatbot *(propuesta)*

- Cola de mensajes salientes: ticket, recordatorio de mantenimiento, recordatorio de cita y vehículo listo.
- Plantillas, registro de envíos (pendiente, enviado, fallido), consentimiento y preferencia de contacto.
- Adaptador aislado con un proveedor de pruebas, para no atar el dominio a WhatsApp.
- Es el más especulativo. Podría fusionarse con el Sprint 9.

## Sprint 9: Integración con WhatsApp *(deuda)*

- Conexión del adaptador con la API de WhatsApp Business o un proveedor equivalente.
- Respuesta inicial automática y reenvío a recepción cuando haga falta una persona.
- Si hay tiempo, consultas simples de estado de orden o de próximo mantenimiento.
- Se trata como servicio externo, tal como lo establece la sección 7 del contexto maestro.

## Sprint 10 (opcional): Evidencias y puesta en producción *(deuda)*

- Fotos del vehículo a la entrada, que resuelve la decisión abierta de almacenamiento de evidencias.
- Hosting, respaldos de la base y HTTPS, que resuelve la decisión abierta de hosting.
- Revisión de seguridad.
- Referencia: sección 27 del contexto maestro.

## Orden recomendado

```text
5 → 6 → 7 → 8 → 9 → 10
```

- El 5 va primero porque corrige el cálculo del cobro.
- El 8 antecede al 9 para separar la lógica de mensajes del proveedor.
- El 6 y el 7 se pueden intercambiar.
- El 10 se puede adelantar si necesitan demostrar el sistema fuera de local.

## Preguntas abiertas

1. ¿Los precios de refacciones deben entrar ya (Sprint 5), o el taller cobra solo servicios y mano de obra por ahora?
2. ¿Qué canal se usará primero para avisar al cliente: WhatsApp, correo o SMS? Define el Sprint 8.
3. ¿Se incluye el Sprint 10 o el proyecto académico termina antes?
4. ¿Se fusionan los sprints 8 y 9?

## Pendientes de verificación en el código

- Qué hay ya implementado en notificaciones (header y dashboard).
- Si los datos del taller en el ticket son configurables o están fijos.
- Si existe algún módulo de reportes o de configuración.
- Apartados "fuera de alcance" de los sprints 1 a 3 y archivos en `specs/`, por si registran pendientes.
