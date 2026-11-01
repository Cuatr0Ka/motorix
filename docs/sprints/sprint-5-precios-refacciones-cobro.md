<!--
Insumo de especificación para /speckit.specify.
Sprint 5 post-MVP de Motorix: precios de refacciones y cobro completo.
Borrador para revisión: las decisiones de la sección 9 no están resueltas.
-->

# Insumo de especificación - Sprint 5: Precios de refacciones y cobro completo

> Referencias obligatorias para el agente:
> - Contexto maestro: `docs/project-context.md`
> - Constitución: `docs/reglas.md` y `.specify/memory/constitution.md`
> - Propuesta de origen: `docs/sprints/propuesta-sprints-post-mvp.md`
> - Este documento describe únicamente el alcance del Sprint 5.

## 1. Contexto del sprint

Es el primer sprint posterior al MVP y corrige una deuda explícita: el Sprint 3 difirió la categoría, la marca y los precios de las refacciones, y el Sprint 4 los dejó fuera. Hoy el total de una orden es solo servicios más mano de obra; las refacciones se registran con su cantidad pero no suman al cobro. Se apoya en el inventario (Sprint 3) y en los pagos y tickets (Sprint 4), y cambia el cálculo del dinero, que es la zona de mayor riesgo del sistema.

## 2. Objetivo

Que cada refacción tenga categoría, marca, precio de compra y precio de venta, y que el total de la orden, el pago y el ticket incluyan las refacciones utilizadas sin alterar los pagos y tickets ya emitidos.

## 3. Historias de usuario del sprint

- **US1** - Como administrador, quiero registrar la categoría, la marca y los precios de compra y de venta de una refacción para conocer el costo y el precio de cada pieza.
- **US2** - Como recepcionista, quiero que el total de la orden incluya las refacciones utilizadas para cobrar el trabajo completo.
- **US3** - Como recepcionista, quiero que el pago y el ticket reflejen el nuevo total para entregar un comprobante correcto al cliente.
- **US4** - Como administrador, quiero que un cambio de precio no altere órdenes abiertas ni pagos y tickets ya emitidos para conservar la integridad del historial.
- **US5** - Como mecánico, quiero seguir usando las refacciones en una orden sin ver los precios de compra para no exponer información financiera del taller.

## 4. Flujo demostrable al cierre del sprint

    Administrador registra una refacción con categoría, marca, precio de compra y precio de venta
    -> mecánico agrega la refacción a una orden y la orden pasa a Terminada
    -> recepción consulta el total (servicios + mano de obra + refacciones)
    -> registra el pago por ese total
    -> se genera el ticket con las refacciones, su importe y el total
    -> el administrador cambia el precio de la refacción
    -> el pago y el ticket ya emitidos conservan su importe

## 5. Entidades y tablas que toca este sprint

> Basado en las secciones 6.7, 6.8, 6.10 y 14.1 de `project-context.md`.

| Entidad / tabla | Acción en este sprint |
|-----------------|-----------------------|
| `parts` | agregar categoría, marca, precio de compra y precio de venta; editar y consultar |
| `order_parts` | guardar el precio de venta vigente al agregar la refacción (instantánea) |
| `payments` | calcular el importe con el nuevo total; sin cambio de estructura previsto |
| `tickets` | incluir el importe de las refacciones en el contenido nuevo; los tickets existentes no se modifican |
| servicios y mano de obra de la orden | consultar para el total |
| migración `005_...sql` y seeds del sprint | crear |

## 6. Reglas de negocio aplicables

- RN-6: Las refacciones utilizadas deben estar relacionadas con una orden.
- RN-7: El uso de una refacción debe generar o reflejar una salida de inventario.
- RN-8: No permitir stock negativo.
- RN-9: Una orden entregada debe conservarse como historial.
- RN-13: Todo pago debe estar relacionado con una orden.
- RN-14: Los datos sensibles del procesamiento de pagos no deben almacenarse en la aplicación.
- RN-15: Los permisos deben validarse en backend.

## 7. Criterios de aceptación

- [ ] CA-1: Una refacción puede registrarse y editarse con categoría, marca, precio de compra y precio de venta, y los datos persisten en MySQL local.
- [ ] CA-2: Los precios rechazan valores negativos, no numéricos y con más de dos decimales; se definen los límites máximos.
- [ ] CA-3: Al agregar una refacción a una orden se guarda su precio de venta vigente; un cambio posterior de precio no modifica esa línea.
- [ ] CA-4: El total de la orden es servicios más mano de obra más refacciones (cantidad por precio guardado), calculado en centavos enteros.
- [ ] CA-5: El pago nuevo se registra por el total con refacciones; el importe enviado que no coincida se sigue rechazando.
- [ ] CA-6: Los pagos y tickets generados antes del sprint conservan su importe y su contenido sin cambios, y siguen consultándose y mostrándose correctamente.
- [ ] CA-7: El ticket nuevo incluye cantidad, precio unitario e importe de cada refacción, y el subtotal y el total las suman.
- [ ] CA-8: Se mantienen las reglas del Sprint 4: un solo pago vigente por orden, también con solicitudes simultáneas, y ningún dato de tarjeta almacenado.
- [ ] CA-9: Mercado Pago recibe el importe con refacciones; un pago pendiente cuyo importe ya no coincide con el total se detecta y se resuelve según la decisión de la sección 9.
- [ ] CA-10: El precio de compra solo es visible para el administrador; el mecánico y recepción no lo reciben en la API, validado en backend.
- [ ] CA-11: El panel de control y los listados de órdenes y pagos no se rompen con el nuevo total.
- [ ] CA-12: Los seeds incluyen refacciones con precios y una orden cobrable con refacciones, y son idempotentes.
- [ ] CA-13: Existen y pasan pruebas de cálculo del total, instantáneas, redondeo, permisos por rol, concurrencia del pago y compatibilidad con tickets anteriores.
- [ ] CA-14: `docs/project-context.md`, `docs/design-system.md` y los comentarios que dicen que las refacciones no suman importe se actualizan en el mismo sprint.

## 8. Fuera de alcance de este sprint

- Costeo, margen de ganancia, utilidad y reportes financieros (Sprint 7).
- Impuestos y facturación electrónica.
- Descuentos, promociones y pagos parciales o a plazos.
- Reembolsos dentro del sistema.
- Catálogo de proveedores y órdenes de compra.
- Notificaciones, reportes, configuración del taller y WhatsApp (Sprints 6 a 9).
- Fotos del vehículo y puesta en producción (Sprint 10).

## 9. Decisiones pendientes que deben resolverse en /speckit.clarify

- Refacciones existentes y líneas ya registradas sin precio: ¿se les asigna 0, se les exige capturar el precio, o se bloquea agregarlas a una orden hasta que lo tengan?
- Orden con solo refacciones: hoy `NOTHING_TO_CHARGE` la rechaza. ¿Pasa a ser cobrable?
- Órdenes abiertas al desplegar: ¿qué precio toman sus refacciones ya agregadas, el vigente al migrar o 0?
- Pago de Mercado Pago pendiente cuando cambia el total: ¿se cancela y se genera uno nuevo, se actualiza el importe o se marca como desfasado?
- Si el administrador corrige el precio de una línea de una orden abierta, ¿se permite y con qué motivo o permiso?
- Categoría: ¿lista cerrada administrable o texto libre? Marca: ¿texto libre?
- Precio de venta menor al de compra: ¿se permite, se advierte o se rechaza?
- Redondeo del importe de una línea (cantidad por precio) y límites máximos de precio y de total.
- Cómo se muestran los tickets anteriores, que no traen precio de refacciones, junto a los nuevos.
- Visibilidad del precio de venta para el mecánico: ¿lo ve o solo ve nombre, código, unidad y existencia?

## 10. Restricciones técnicas heredadas

- Backend en ES Modules, nunca CommonJS.
- Solo el backend accede a MySQL; el frontend nunca se conecta directo.
- Permisos validados en backend, no solo en UI.
- Sin secretos en el repositorio.
- Idioma: español en chat, docs, comentarios y pruebas.
- MySQL local, InnoDB, llaves foráneas, `utf8mb4`.
- Login acepta usuario o correo electrónico en el mismo campo.
- Toda pantalla del frontend sigue `docs/design-system.md`.
- Pruebas de integración contra `motorix_test`, nunca contra la base principal.
- Los seeds del sprint DEBEN incluir datos de ejemplo suficientes para que la aplicación muestre información al arrancar. La base no puede quedar vacía tras la instalación.
- Los seeds DEBEN ser idempotentes: si se corren de nuevo, no duplican registros.
- Los importes se calculan en centavos enteros y se guardan como `DECIMAL(10,2)`, igual que en el Sprint 4.
- Las migraciones son aditivas y numeradas (`005_...sql`); no modifican las migraciones anteriores.
