# Guía del aseguramiento de la calidad de un sprint

Esta guía la lee un agente (Claude, opencode u otro) que ayuda a una persona a asegurar la calidad de un sprint **antes y durante** su implementación, y a dejar el resultado en un solo documento listo para pasar a Word.

## 0. Contenido de esta carpeta y cómo usarla

Esta carpeta se copia completa dentro de la carpeta `docs/` del proyecto (queda en `docs/aseguramiento-calidad/`). Contiene:

| Archivo | Para qué sirve |
|---|---|
| `guia-aseguramiento-calidad.md` | Este documento: el proceso paso a paso. |
| `plantilla-aseguramiento-calidad.md` | El formato en blanco. Se copia a `docs/aseguramiento-calidad-sprint-N.md` y se llena. |
| `ejemplo-aseguramiento-calidad-sprint-5.md` | Un documento ya terminado (Sprint 5 del proyecto Motorix), como modelo de redacción y nivel de detalle. Todo su contenido (rutas, pruebas, requisitos) pertenece a Motorix: **no lo copies, solo imítalo**. |
| `ejemplo-evidencias/` | Las capturas que usa el ejemplo, para que se vea completo. En tu proyecto las capturas van en `docs/evidencias/sprint-N/`. |

Las rutas que esta guía menciona sin carpeta de origen (`docs/sprints/`, `specs/`, `CLAUDE.md`) son las de un proyecto con Spec Kit; si el tuyo usa otras, adáptalas.

## 1. Qué es y qué no es

- **Control de calidad** (matriz de calidad): se hace *después* de construir, ejecuta pruebas y recoge evidencia. En el proyecto de ejemplo (Motorix) fue la matriz del MVP.
- **Aseguramiento de la calidad** (este documento): se hace *antes y durante* el sprint para que salga bien. Revisa requisitos, planea pruebas, mide una línea base y, al final, incluye un control de calidad final (sección 9 de la plantilla).

El entregable es **un solo archivo Markdown** `docs/aseguramiento-calidad-sprint-N.md`, que al final se convierte a Word.

## 2. Antes de empezar

Confirma con la persona estos datos y no los inventes:

1. Número y nombre del sprint, y su archivo de insumo en `docs/sprints/` (si no existe, se redacta primero con `docs/sprints/_plantilla.md`).
2. Nombre de la rama de trabajo (por ejemplo `005-nombre-corto`) y la rama base.
3. Quién es el responsable y quién aprueba el cierre (en un proyecto escolar puede ser la misma persona; se escribe su nombre y rol).
4. Cuáles son las suites de pruebas y sus comandos (en Motorix: `npm test` en `server/` y `flutter test` en `client/`).
5. Que el proyecto use Spec Kit (`/speckit.specify`, `clarify`, `checklist`, `plan`, `tasks`, `analyze`, `implement`). Si usa otro flujo, adapta los nombres de las puertas de la sección 3 de la plantilla.

Reglas permanentes del proyecto (están en `CLAUDE.md`): responder y escribir en español; identificadores de código en inglés; commits `tipo(alcance): descripción en español, en infinitivo y en minúsculas`; no guardar secretos en el repositorio. Cumple las del proyecto en el que estés.

## 3. Orden de trabajo

Cada paso termina con un commit pequeño que la persona haya pedido. **No hagas commit ni push sin que lo pida.**

1. **Preparar el insumo del sprint.** Redáctalo con la plantilla de `docs/sprints/` y **verifica contra el código real** lo que afirma (modelos, rutas, totales). Lo que contradiga al código se anota como hallazgo. Lista las decisiones abiertas (D-01, D-02…).
2. **Crear el documento.** Copia la plantilla a `docs/aseguramiento-calidad-sprint-N.md`, cambia `Sprint N`, `<Proyecto>` y las rutas, y llena las secciones 0, 1 y 2.
3. **Línea base de regresión (antes de tocar código).** Ejecuta las suites completas, anota suites y pruebas aprobadas, el commit y la fecha. Pide a la persona las **capturas de la terminal** (`captura-linea-base-backend.png`, `captura-linea-base-frontend.png`) y enlázalas en la sección 8.
4. **Puertas G-01 a G-08.** A medida que avanzas por las etapas de Spec Kit, llena la fila de cada puerta (sección 3) con estado y una evidencia corta (ruta del documento, conteos). Una puerta solo se marca *Aprobado* si su criterio se cumplió; si se cumplió con una salvedad, *Aprobado con observación* y la salvedad va en la evidencia.
5. **Aclaraciones.** Las decisiones abiertas se resuelven con la persona (preguntas cerradas con opciones y una recomendación). Anota la resolución en la especificación y resume en la sección 4. No asumas respuestas.
6. **Lista de calidad (`checklist`).** Revisa todos los puntos; cada uno se resuelve cambiando la especificación. Lo que cambie el contrato queda como hallazgo (sección 7).
7. **Plan, tareas y análisis.** Verifica que el plan cumpla la constitución, que la migración sea aditiva si hay base de datos y que las **pruebas vayan antes del código** en cada historia. Repite `analyze` hasta no tener hallazgos críticos, altos ni medios. Cada requisito debe tener tarea y cada tarea un requisito.
8. **Constitución.** Si el sprint contradice un principio (por ejemplo, el alcance del MVP), se necesita una **enmienda aprobada por quien tenga la autoridad** antes de implementar. Se registra como hallazgo H-01 y como criterio de entrada.
9. **Riesgos y trazabilidad.** Llena la sección 5 (riesgos con prueba que los cubre) y la 6 (cada criterio de aceptación enlazado a requisito, tarea, prueba y resultado). Es la última etapa antes de implementar; después se actualizan los resultados.
10. **Implementar por historias**, parando en cada punto de control. Después de cada fase ejecuta las pruebas y actualiza el documento (hallazgos, trazabilidad).
11. **Regresión de cierre.** Ejecuta de nuevo las suites. Ninguna prueba anterior debe pasar de verde a rojo. Si una prueba anterior debe cambiar por una modificación declarada en la especificación, se actualiza y se registra como hallazgo; nunca se borra ni se debilita sin registro.
12. **Control de calidad final (sección 9 y anexo).** Elige 5 requisitos, prioriza los que más pueden fallar (instantáneas de datos, permisos por rol, concurrencia, compatibilidad con datos antiguos, redondeo). Por cada uno escribe los tres bloques del anexo: Requisito, Prueba y Resultado.
13. **Recorrido de escenarios contra la API real** (si el sprint tiene `quickstart.md`): ejecútalo contra la API y la base de datos reales, preferiblemente en una base de pruebas para no gastar los datos de demostración, y anota el resultado de cada escenario.
14. **Recorrido manual en la aplicación (lo hace la persona).** Pídele las capturas y los tiempos; ver sección 5 de esta guía.
15. **Cierre.** Completa la sección 10 solo con datos verdaderos y pide la aprobación explícita de quien aprueba. Marca las tareas finales y haz el commit.
16. **Pasar a Word** (sección 7 de esta guía) y, solo si la persona lo pide, publicar.

## 4. Cómo llenar cada sección

- **0. Datos:** hechos, no deseos. La fecha de cierre y el estado general se llenan al final.
- **1. Alcance:** dos listas cortas tomadas del insumo.
- **2. Criterios:** son casillas. `[x]` solo si de verdad se cumplió; el texto va en pasado cuando el documento se cierra.
- **3. Puertas:** una fila por etapa; estado + evidencia de una frase y enlace a la ruta.
- **4. Decisiones:** un párrafo que remita a la especificación, o una tabla si son pocas.
- **5. Riesgos:** cada riesgo con impacto, mitigación y **la prueba concreta que lo cubre**. Estados: Mitigado, Aceptado o Abierto. No dejes celdas vacías al cierre.
- **6. Trazabilidad:** una fila por criterio de aceptación. Resultado: Aprobado, Aprobado con observación o Fallido. La evidencia nombra archivos de prueba reales.
- **7. Hallazgos:** todo lo encontrado, con severidad (crítica, alta, media, baja), origen, estado y resolución. Los ajustes menores de pruebas pueden fusionarse en una fila (`H-03 a H-07`) para no alargar el documento.
- **8. Regresión:** comando, conteos antes/después, diferencia, commit y fecha, y las cuatro capturas.
- **9. Matriz final:** cinco filas con el formato de la matriz de calidad del MVP: Requisito (con archivo y FR), Criterio de aceptación observable, Prueba ejecutada (archivo y número de casos), Resultado y Evidencia con enlaces al anexo.
- **10. Cierre:** criterios de salida cumplidos (N de 5), defectos abiertos, observaciones (incluye los tiempos medidos), quién aprueba y la fecha.
- **Anexo:** por cada RF-0x, los tres bloques con el mismo identificador (`E-01 Requisito`, `E-01 Prueba`, `E-01 Resultado`). El requisito se cita **literal** desde `spec.md` con número de línea. La prueba indica archivo y líneas, qué comprueba y un fragmento corto real. El resultado trae el comando, la salida real y la captura.

Mantén el documento **corto**: si algo ya está completo en la especificación (por ejemplo, el texto de las decisiones), enlázalo en lugar de copiarlo.

## 5. Evidencia: qué debes pedir a la persona y qué debes verificar

Hay cosas que solo la persona puede hacer. Prepárale una **tabla de capturas** con: nombre de archivo, qué debe verse, con qué usuario y qué datos usar. Los nombres van en minúsculas y con guiones, en `docs/evidencias/sprint-N/`.

Capturas típicas: regresión del backend y del frontend; una por cada RF de la sección 9 (la pantalla que demuestra el comportamiento); y las de línea base.

**Verifica cada captura antes de enlazarla:** ábrela, confirma que muestra lo que dice la tabla y compara las sumas de verificación (`sha256sum`) para detectar copias idénticas con nombres distintos. En el Sprint 5, dos capturas resultaron ser la misma imagen y hubo que repetir una. Si una captura no demuestra lo que dice el documento, pide otra o redacta el texto con lo que sí demuestra.

**Tiempos de uso** (criterios de éxito medibles con cronómetro): explica a la persona qué mide cada uno (de qué pantalla a cuál), dale los datos de ejemplo, el usuario y los pasos. **Nunca registres estimaciones como mediciones**; si ella no los mide, escríbelo como observación. Una estimación tuya puede acompañar la explicación, pero no entra como evidencia.

Los datos de demostración se gastan al hacer el recorrido manual (por ejemplo, una orden ya cobrada no se puede cobrar otra vez). Avisa antes y ofrece restaurar o crear datos nuevos.

## 6. Reglas de calidad del propio documento

- Todo lo que afirmes debe poder comprobarse en el repositorio: rutas, conteos, comandos y números de línea reales. Si no pudiste ejecutar algo, dilo; no lo marques como aprobado.
- No dejes `Pendiente`, `Captura pendiente`, `<...>` ni textos de plantilla («se llena…», «al terminar se pasa a Word») en la versión final. Cuando algo siga pendiente de verdad, el documento no está cerrado.
- No cierres con un estado más favorable que la evidencia: si hay una salvedad, usa *Aprobado con observación* y descríbela.
- Revisa que reporte, análisis y matriz no se contradigan (conteos, fechas, nombres de archivo).
- La aprobación final y la firma son de la persona responsable, no tuyas.

## 7. Pasar a Word

Cuando el Markdown esté completo y revisado por la persona:

1. Si el proyecto ya tiene un `.docx` de referencia (por ejemplo, una matriz de calidad anterior), úsalo como modelo de formato; si no, usa este, que es el del proyecto de ejemplo: **hoja Carta horizontal, márgenes de 0.5", Arial 10 pt** (Consolas para código), título en negrita y mayúsculas con una línea de subtítulo (proyecto, sprint, rama, alumno, fecha), **tablas con bordes grises y encabezado en negrita con fondo gris**, y número de página en el pie.
2. Genera el `.docx` con una librería (por ejemplo `docx` de npm o `pandoc`/LibreOffice si están instalados). Convierte: encabezados, tablas, citas, bloques de código, casillas `[x]` como ☑ y `[ ]` como ☐, imágenes (ancho máximo ≈ 640 px) y los enlaces internos `[texto](#ancla)` como hipervínculos a marcadores de los encabezados.
3. **Hipervínculos externos:** los nombres de archivo y carpeta en tipo código pueden enlazarse a su versión en el repositorio remoto (`.../blob/<rama>/<ruta>`), y los pies de las capturas a la imagen. Enlaza **solo** archivos que estén versionados y subidos; un enlace a un archivo no subido da error 404. Haz esto después de que la persona haya subido la rama.
4. Comprueba el resultado: 9 tablas, el número de imágenes esperado, página horizontal, sin restos de `**` ni acentos graves. Si puedes renderizarlo (LibreOffice), mira las páginas; si no, dilo y pide a la persona que lo abra en Word.
5. Guárdalo junto al Markdown: `docs/aseguramiento-calidad-sprint-N.docx`. Ten en cuenta que `.gitignore` puede excluir los `.docx`; no lo fuerces con `-f`: avísale a la persona.

## 8. Errores que ya ocurrieron (evítalos)

- **Comillas inversas (backticks) en PowerShell** rompen textos y corrompieron un archivo. Para editar documentos y código usa la herramienta de edición de archivos, no cadenas de shell.
- **Documentos largos por `heredoc` o `node -e`** fallan con «unexpected EOF». Escribe un script auxiliar en el directorio temporal y ejecútalo.
- **Reemplazos con `$'` o `$&`** en `String.replace` alteran el texto; usa una función de reemplazo.
- **Archivos con CRLF:** una expresión con `$` y bandera `m` no coincide por el `\r`. Normaliza o acepta `\r?$`.
- **Scripts que reescriben tablas Markdown** pueden dejar basura al inicio del archivo. Después de cada modificación masiva, revisa la primera línea y el `git diff`.
- **`expect(valor, mensaje)` en Jest** no admite dos argumentos; acumula las violaciones y compara una sola vez.
- **Capturas idénticas** con nombres distintos (ver sección 5).
- **Cambiar un contrato** rompe pruebas anteriores: regístralo como hallazgo con la lista de pruebas ajustadas y la razón.

## 9. Lista final antes de entregar

- [ ] Documento sin `<...>`, sin `Pendiente`, sin `Captura pendiente` y sin textos de plantilla.
- [ ] Las puertas G-01 a G-08, los riesgos y la trazabilidad están completos y con evidencia real.
- [ ] Las suites completas pasan; los conteos del documento coinciden con las capturas.
- [ ] Cada captura enlazada existe, se abrió y demuestra lo que dice.
- [ ] Los tiempos de uso son mediciones de la persona.
- [ ] La sección 10 está firmada por quien aprueba, con fecha.
- [ ] Commit hecho (solo si la persona lo pidió) y `.docx` generado y revisado.
- [ ] Push o pull request **solo** con confirmación explícita.
