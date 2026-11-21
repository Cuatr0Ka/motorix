# Motorix y la IA: cómo dirijo, reviso y hago crecer un proyecto hecho con agentes

> Borrador en Markdown. Aún no es la presentación: primero se confirma este contenido.
>
> Idea del video: la IA ya genera sin problema el frontend, el backend y la base de datos, pero el software
> no murió. Alguien con criterio técnico tiene que dirigir al agente, revisar lo que produce y responder por
> el resultado. Motorix es mi ejemplo.

---

## 1. Mi inventario (25 pts)

Lo que ya sé (según mis propias respuestas) y la decisión de mi proyecto donde me sirve para dirigir o revisar a la IA.

| Área | Lo que sé | Decisión de Motorix donde me sirve para dirigir o revisar a la IA |
|------|-----------|--------------------------------------------------------------------|
| Bases de datos | SQL (`SELECT`, `JOIN`), normalización y llaves, índices y transacciones. | Reviso que las tablas tengan llaves foráneas y únicas (un pago vigente por orden), que las consultas con `JOIN` usen índices y que el cobro vaya dentro de una transacción. |
| Estructuras de datos | Arreglos y listas, pilas, colas y mapas (hash), árboles y grafos. | Sé que un índice funciona como un árbol: por eso sospecho de una búsqueda lenta y reviso las consultas que genera la IA. |
| Redes | HTTP y códigos de estado, API REST y JSON, TCP/IP, DNS y puertos, HTTPS, tokens y CORS. | Reviso que la API responda con el código correcto, que los permisos se validen en el servidor con el token y que CORS no quede abierto al publicar. |
| Programación e ingeniería de software | Programación orientada a objetos, Git y ramas, requisitos y metodologías ágiles. | Dirijo a la IA con requisitos por sprint (Spec Kit), una rama por funcionalidad y commits pequeños, y reviso que cada requisito esté trazado. |

**Lo que aún me falta:** complejidad (Big O) y pruebas de software. Lo cubro pidiendo a la IA que justifique el costo de las consultas críticas y leyendo las pruebas del proyecto para exigir una por requisito.

---

## 2. Responsabilidad y riesgo (20 pts)

Tres riesgos de mi proyecto, el control que tengo para cada uno y cómo respondo.

### Riesgo 1: cobro duplicado o con un importe incorrecto

- **Control:** índice único `uq_payments_active_order`, bloqueo de la orden en una transacción, el servidor
  calcula el total (no confía en el que manda el cliente) y rechaza un importe distinto. Hay pruebas de
  concurrencia.
- **Cómo respondo:** el pago incorrecto se cancela y se conserva en el historial; se genera uno nuevo con el
  total vigente. Los pagos y tickets emitidos no se editan. No hay reembolsos en el sistema, así que cualquier
  devolución se resuelve fuera de él y se documenta.
- **Lo que me falta:** nadie ha revisado esta lógica a mano, y el sistema no ha manejado cobros reales.

### Riesgo 2: precios o datos de compra visibles para quien no debe verlos

- **Control:** el filtrado por rol se hace en el backend y hay una prueba de fuga de precios
  (`prices.leak.test.js`) que revisa cada consulta que recibe recepción o el mecánico.
- **Cómo respondo:** corrijo el endpoint, agrego la prueba que faltó y reviso las demás consultas que
  comparten la misma función.

### Riesgo 3: vulnerabilidades o secretos expuestos antes de publicar

- **Control actual:** `helmet`, validación con `zod`, bloqueo por intentos fallidos, `.env` ignorado por git y
  `.env.example` sin secretos. Un punto débil que ya identifiqué: CORS está abierto (`cors()` sin
  restricciones) y no hay un límite general de peticiones.
- **Cómo respondo:** antes de publicar, cerrar CORS a los orígenes necesarios y agregar un límite de
  peticiones.
- **Cómo puedo revisar antes si mi sistema es seguro (herramientas por investigar, aún no usadas):**
  - `npm audit` para dependencias vulnerables del backend.
  - Un escáner de secretos como gitleaks, sobre el historial de git.
  - OWASP ZAP para probar la API en ejecución.
  - `flutter analyze` y el análisis estático del cliente.
  - Una revisión de seguridad con la IA (`/security-review`) y, además, una revisión humana de pagos y permisos.

---

## 3. Crecer sin romperse (20 pts)

Qué se rompería primero al pasar de 50 a 5,000 usuarios y qué conocimiento de mi inventario usaría para anticiparlo.

1. **Las búsquedas.** Los listados buscan con `LIKE '%texto%'`. Con un comodín al principio, MySQL no puede
   usar los índices de nombre o teléfono y recorre toda la tabla. Con 50 usuarios no se nota; con miles de
   clientes, vehículos y refacciones, sí. Además, la migración del Sprint 5 no agregó índices para buscar por
   categoría o marca.
   - *Qué haría:* revisar los planes con `EXPLAIN`, buscar por prefijo cuando sea posible o usar un índice de
     texto completo.
2. **La paginación con `OFFSET`.** Las páginas profundas se vuelven cada vez más lentas.
   - *Qué haría:* paginación por cursor en los listados que más crezcan (pagos, tickets, movimientos de
     inventario).
3. **El pool de 10 conexiones y los bloqueos del cobro.** Cada cobro bloquea una orden dentro de una
   transacción. Con muchos usuarios a la vez, las peticiones esperarían una conexión.
   - *Qué haría:* medir con una prueba de carga, ajustar el pool y mantener las transacciones cortas. Ya
     existe una prueba de rendimiento con 1,000 pagos y tickets, pero no con usuarios simultáneos.
4. **La confirmación de Mercado Pago.** Se hace por consulta manual, sin avisos automáticos del proveedor.
   Con más cobros, la recepción tendría que consultar cada uno.
   - *Qué haría:* agregar el aviso automático (webhook) con verificación de firma.
5. **El panel de control.** Calcula sus indicadores con datos reales en cada consulta.
   - *Qué haría:* medirlo antes de asumir que escala; si es lento, guardar resultados por un tiempo corto.

> Lo que no sé todavía: cuánto tardan hoy estas consultas con miles de registros. El primer paso sería
> medirlas, no adivinar.

---

## 4. Recursos con criterio (15 pts)

| Tipo de herramienta | Tareas que resuelvo bien con ella en Motorix |
|---------------------|-----------------------------------------------|
| Gratuita (DeepSeek) | Pruebas simples, el `README`, traducir y revisar textos de la interfaz, datos de ejemplo (seeds), formato y comentarios. |
| Más capaz (Claude Code) | Revisar el diseño completo, la concurrencia de pagos y stock, el modelo de datos, los permisos por rol y una revisión de seguridad. Esos errores salen caros. |

**Cómo cuido mi cuota:**
- Tareas pequeñas, con la especificación del sprint como contexto, en lugar de pedir "revisa todo el
  proyecto".
- Dividir el trabajo con `tasks.md` y pedir una tarea a la vez.
- No volver a leer lo que ya está en los documentos del proyecto; apoyarme en `docs/project-context.md` y
  en la constitución.
- Dejar los cambios grandes y delicados a Claude Code, y lo repetitivo a DeepSeek.

Coincide con el video: para trabajo real conviene un modelo frontera, y para aprender o tareas simples sirve
uno gratuito.

---

## 5. Mi siguiente paso (20 pts)

**Área elegida: MCP (Model Context Protocol).**

**Con mis palabras:** un MCP es un servidor pequeño que le da a un agente de IA una lista de acciones o
consultas permitidas. En lugar de dejar que el agente entre libremente a mi base de datos o a mi API, yo
decido qué puede pedir y qué no. Es como darle una ventanilla con tres servicios en vez de la llave de todo
el taller.

**Cómo podría aplicarlo en Motorix (más allá de un CRUD):** un servidor MCP de solo lectura que permita a un
agente responder preguntas del taller, por ejemplo "¿qué refacciones están bajas de existencia?" o "¿qué
órdenes siguen abiertas?", reutilizando la API que ya existe y sus reglas de permisos.

**Práctica que propongo:**
1. Crear un servidor MCP con dos o tres consultas de solo lectura: alertas de stock bajo, órdenes abiertas
   y estado de una orden.
2. Conectarlo a la API con una cuenta de rol limitado, no con la de administración.
3. Probarlo con el agente y comprobar que no devuelve datos que ese rol no debe ver.

**Permisos que le daría y por qué (se documentan al implementarlo):**

| Permiso | Decisión | Motivo |
|---------|----------|--------|
| Leer alertas de stock y estado de órdenes | Sí | Es información operativa que la recepción ya consulta. |
| Ver el precio de compra | No | Regla del Sprint 5: solo la administración lo ve. |
| Crear, editar o cancelar pagos | No | Una acción sobre dinero necesita una persona. |
| Ver credenciales o el token de Mercado Pago | No | Los secretos nunca salen de `.env`. |
| Escribir en la base de datos | No | El agente solo lee; los cambios pasan por la API y sus validaciones. |

---

## Los tres puntos

### 1. Qué estoy haciendo, qué hace la IA y cómo se implementó en el proyecto

En mi proyecto Motorix, un sistema de gestión para taller mecánico, hago lo que el video describe como el
cambio de rol del programador: dejo de escribir cada línea y paso a administrar a un agente, de la misma forma
que antes se delegaba a personas. Yo defino el alcance, las reglas del proyecto y los sprints, y apruebo las
decisiones importantes. La IA, que es Claude Code (un modelo frontera, como el que el video recomienda para
trabajo real), se encarga de ejecutar: genera el frontend en Flutter, el backend en Node con Express y la base
de datos en MySQL, justo la parte que el video dice que el vibe coding ya cubre bien. Para no trabajar a
ciegas usé Spec Kit, que ordena el trabajo en especificar, planear, generar tareas e implementar. Además,
cada sprint tiene pruebas automáticas, decisiones registradas y documentos de aseguramiento de la calidad.
Esto se parece a lo que el video menciona para los estudiantes: los procesos de siempre, como las pruebas,
siguen vigentes, solo que ahora se aplican con un agente en lugar de una persona.

### 2. Qué todavía no se ha hecho

Medido contra el video, lo que falta es lo que va más allá de una aplicación básica. Primero, que una persona
con criterio técnico revise a fondo el código que generó la IA, porque el video insiste en que en algún punto
hace falta un profesional que lo verifique. Segundo, probar el sistema con usuarios reales, ya que el video
recuerda que un proyecto nunca termina y siempre llegan errores y cambios; Motorix solo se ha probado en
entorno local. Tercero, el despliegue y el escalado: no hay hosting ni nube, y no se ha probado con mucha
carga de datos. Cuarto, las integraciones más difíciles, pues Mercado Pago funciona solo en modo de pruebas.
Quinto, las tecnologías nuevas que menciona el video, como MCP, protocolos entre agentes y bases de datos
vectoriales, que el proyecto no usa. Por último, quedan pendientes los sprints 6 al 10, que solo están
propuestos, y la ratificación formal de la constitución del proyecto por parte del equipo.

### 3. Qué me preocuparía

Lo que más me preocuparía es lo que el video llama ir a ciegas: que el código funcione y pase las pruebas,
pero que nadie del equipo lo entienda lo suficiente como para corregirlo o mantenerlo. Relacionado con eso
está la responsabilidad, porque si la IA comete un error en pagos o en permisos, quien responde es el equipo,
no la herramienta ni la empresa que la hizo. También me preocupa que Motorix sea, en esencia, el tipo de
aplicación básica que el video dice que hoy cualquiera puede generar con IA; su valor está en la
organización, la trazabilidad y la calidad con que se construyó, más que en su complejidad técnica. Si el
sistema creciera, aparecerían problemas de consultas lentas, costos de base de datos y migraciones, que es
justo donde el video dice que el vibe coding se queda corto. Finalmente, me preocupa depender de un modelo de
paga para seguir el mismo flujo de trabajo, y dejarme llevar por el miedo a quedarme fuera (el FOMO) en lugar
de aprender con calma lo que realmente necesito.

---

## Conclusión: qué se aprendió

Con este ejercicio aprendí que la IA puede construir una aplicación completa, pero eso no me quita la
responsabilidad: la IA escribe, yo dirijo y reviso. Lo que hizo útil a Motorix no fue el código generado,
sino el trabajo humano alrededor: definir el alcance, escribir reglas claras, exigir pruebas y decidir qué
se puede y qué no se puede automatizar.

También aprendí que mis conocimientos de base de datos, estructuras de datos, redes y seguridad siguen
siendo lo que me permite detectar un riesgo a tiempo, como un cobro duplicado, una búsqueda que no escala o
una consulta que deja ver un precio que no debería verse. Sin ese criterio, habría aceptado el código sin
saber qué revisar.

Por último, me quedó claro que terminar la aplicación no es terminar el proyecto: faltan la revisión humana,
el uso con usuarios reales, el despliegue y el crecimiento. Mi siguiente paso es aprender una tecnología nueva
(un servidor MCP) con un permiso mínimo y documentado, sin caer en el FOMO, para ir más allá de un CRUD.
