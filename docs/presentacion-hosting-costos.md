# Motorix: alojamiento, costo del MVP y riesgos

Borrador para pasar a Canva. Las cifras de precios son de noviembre de 2026 y vienen de páginas de terceros; conviene confirmarlas en la página oficial de cada proveedor antes de presentar. Tipo de cambio de referencia: 18.5 MXN por USD (27 de octubre de 2026).

## Estructura de la presentación

| Diapositiva | Contenido |
|---|---|
| 1 | Portada: Motorix, sistema de gestión para taller mecánico |
| 2 | Qué se va a alojar: API Node/Express y MySQL 8 (el cliente Flutter es de escritorio y no se aloja) |
| 3 | Tabla de cotizaciones de alojamiento |
| 4 | Plan A, B y C con su justificación |
| 5 | Costo del MVP en dos escenarios (sin hosting, como está hoy, y con el hosting del Plan A): tiempo, IA y alojamiento |
| 6 | Reserva de contingencia con la matriz de riesgos |
| 7 | Tabla de riesgos: cómo aplican y qué pasa si no se atienden |
| 8 | Conclusión |

## 1. Qué se necesita alojar

- **API:** Node.js 20 o superior con Express (ES Modules).
- **Base de datos:** MySQL 8 con InnoDB y `utf8mb4`. El proyecto usa `mysql2` directo, sin ORM, así que cambiar de MySQL a otro motor implicaría reescribir las consultas.
- **Cliente:** aplicación de escritorio en Flutter; solo necesita la URL de la API.
- **Carga esperada:** un taller, con pocos usuarios a la vez (administración, recepción y mecánicos).

## 2. Cotizaciones de alojamiento

| Proveedor | Qué incluye | USD/mes | MXN/mes (aprox.) | Observación |
|---|---|---|---|---|
| Hostinger VPS KVM 1 | 1 vCPU, 4 GB RAM, 50 GB NVMe; Node y MySQL en el mismo servidor | 6.49 (promoción a 24 meses) | 120 | Renueva en 11.99 USD (≈220 MXN). La administración del servidor corre por cuenta propia. |
| DigitalOcean | Droplet de 1 GB (6 USD) más MySQL administrado (15 USD) | 21 | 390 | Respaldos y escalado incluidos en la base administrada. |
| AWS Lightsail | Instancia (5 USD) más MySQL administrado (15 USD) | 20 | 370 | Tiene ruta de crecimiento hacia AWS. |
| Railway (plan Hobby) | 5 USD con 5 USD de consumo incluido | 5 a 10 | 90 a 185 | Se cobra por uso; falta confirmar la oferta de MySQL. |
| Render | Servicio web Starter de 7 USD | 7 | 130 | Descartado: solo ofrece PostgreSQL, no MySQL. |
| Aiven (Developer) | MySQL administrado | 5 | 90 | Cerró su MySQL gratuito para cuentas nuevas; es solo base de datos. |
| Azure para Estudiantes | 100 USD de crédito por 12 meses | 0 mientras dure el crédito | 0 | MySQL B1ms de 12 a 30 USD al mes: el crédito alcanza de 3 a 8 meses. |

Puntos por verificar: dos fuentes no coinciden en el precio del Droplet de DigitalOcean (4 o 6 USD) ni en el plan gratuito de Railway.

## 3. Plan A, B y C

### Plan A: Hostinger VPS KVM 1

- **Por qué hoy:** es la opción más barata que da recursos suficientes. Los 4 GB de RAM alcanzan para la API y MySQL en el mismo servidor, y el código no cambia.
- **Costo:** ≈120 MXN al mes con la promoción; ≈1,440 MXN el primer año.
- **Qué hay que asumir:** respaldos, actualizaciones y seguridad del servidor los hace el equipo.

### Plan B: DigitalOcean con MySQL administrado

- **Por qué para el crecimiento natural:** cuando el taller tenga datos reales o lleguen más talleres, la base de datos se separa del servidor de la API y ya trae respaldos automáticos y escalado.
- **Costo:** ≈390 MXN al mes.
- **Cuándo pasar a este plan:** al tener usuarios reales, o cuando perder datos deje de ser aceptable.

### Plan C: AWS Lightsail

- **Por qué como respaldo y camino de largo plazo:** permite crecer hacia AWS (base de datos RDS, balanceo de carga) si Motorix se vuelve un producto con varios clientes, y sirve de alternativa si falla otro proveedor.
- **Costo:** ≈370 MXN al mes.

### Por qué no las demás

- **Render:** no ofrece MySQL; migrar a PostgreSQL obligaría a reescribir consultas.
- **Aiven:** es solo base de datos y ya no tiene plan MySQL gratuito para cuentas nuevas.
- **Azure para Estudiantes:** el crédito caduca a los 12 meses y se agota antes con MySQL; sirve para una demostración, no como hogar permanente.
- **Railway:** el cobro por uso es difícil de predecir en un presupuesto fijo.

## 4. Costo del MVP

### Supuestos

- Horas: 3 días completos de trabajo = 24 horas (8 horas por día).
- Tarifa: 96 MXN por hora, a partir del sueldo promedio de un desarrollador junior en México según Indeed (15,336 MXN al mes entre 160 horas).
- IA: Claude Pro, 20 USD al mes (≈370 MXN), por 1 mes de proyecto.
- Reparto de horas: 18 de planeación y gestión (H_p) y 6 de depuración (H_d). Es una estimación.
- Alojamiento: se calculan dos escenarios.
  - **Escenario 1, sin hosting (como está hoy):** todo corre en local, 0 MXN.
  - **Escenario 2, con hosting del Plan A (Hostinger KVM 1):** ≈120 MXN por 1 mes de servicio (6.49 USD con la promoción).

### Paso 1. Costo base nominal

| Concepto | Cálculo | Escenario 1: sin hosting (MXN) | Escenario 2: con hosting (MXN) |
|---|---|---|---|
| Horas de planeación y gestión (H_p) | 18 h × 96 | 1,728 | 1,728 |
| Horas de depuración (H_d) | 6 h × 96 | 576 | 576 |
| Claude Pro | 1 mes × 20 USD | 370 | 370 |
| Alojamiento | Hostinger KVM 1, 1 mes | 0 | 120 |
| **Costo base** | | **2,674** | **2,794** |

### Paso 2. Matriz de riesgos

Impacto y probabilidad van de 1 a 5. La exposición es impacto × probabilidad ÷ 25.

| Riesgo | Impacto | Probabilidad | Exposición |
|---|---|---|---|
| 1. Escasez de recursos | 4 | 4 | 0.64 |
| 2. Contratiempos operativos | 3 | 3 | 0.36 |
| 3. Bajo desempeño | 3 | 2 | 0.24 |
| 4. Falta de claridad | 3 | 2 | 0.24 |
| 5. Corrupción del alcance | 4 | 3 | 0.48 |
| 6. Costos y tiempo | 4 | 3 | 0.48 |
| **Factor de riesgo (F_r), promedio** | | | **0.41 (41 %)** |

### Paso 3. Presupuesto final

| Concepto | Escenario 1: sin hosting (MXN) | Escenario 2: con hosting (MXN) |
|---|---|---|
| Costo base | 2,674 | 2,794 |
| Reserva de contingencia (costo base × 41 %) | 1,096 | 1,146 |
| **Presupuesto final del MVP** | **≈ 3,770** | **≈ 3,940** |

La diferencia entre los dos escenarios es de ≈170 MXN: 120 del hosting y 50 de reserva adicional sobre ese gasto. Se usa el mismo factor de riesgo (41 %) en ambos para que sean comparables.

Nota sobre el pago del hosting: la promoción de 6.49 USD al mes exige contratar 24 meses por adelantado (≈156 USD, ≈2,880 MXN en un solo pago). El escenario 2 prorratea el costo por mes para compararlo con el escenario 1.

### Proyección del alojamiento (Plan A)

| Periodo | MXN |
|---|---|
| Por mes, con la promoción | ≈ 120 |
| Primer año | ≈ 1,440 |
| Por mes, tras la renovación | ≈ 220 |

## 5. Riesgos del proyecto

| Riesgo | Cómo aplica en mi proyecto | Qué pasa si no lo atiendo |
|---|---|---|
| **1. Escasez de recursos** | Todo el desarrollo depende del límite de uso de Claude Pro. No hay hosting y la base es local. | Me quedo sin cuota a mitad de un sprint y el avance se detiene. Un plan gratuito de base de datos puede desaparecer, como pasó con el MySQL gratuito de Aiven. |
| **2. Contratiempos operativos** | Claude, Flutter y las descargas necesitan internet en el plantel. Hubo incompatibilidades de versiones: `data_table_2` quedó fijo en 2.6.0 porque la 3.x no funciona con Flutter 3.47. Compilar en Windows exige el modo de desarrollador. | No puedo avanzar ni demostrar el sistema en clase. Una actualización puede romper la app justo antes de presentar. |
| **3. Bajo desempeño** | El código lo genera la IA. Lo mitigué con una prueba de rendimiento (1 000 pagos y tickets), llaves e índices en la base, y 1215 pruebas de backend y 321 del cliente. | Consultas lentas con datos reales, errores de dinero o stock que nadie detecta, y regresiones silenciosas. |
| **4. Falta de claridad** | Un prompt ambiguo hace que la IA invente reglas. Lo mitigué con Spec Kit: 10 decisiones aclaradas en 3 rondas antes de programar. | La IA implementa algo distinto de lo que necesito, y se pierden horas de depuración y de rehacer cosas. |
| **5. Corrupción del alcance** | Es fácil pedirle más funciones a la IA. El Sprint 5 ya salió del MVP original y exigió enmendar la constitución. Quedan los sprints 6 y 7, y el bot de WhatsApp quedó fuera. | El MVP nunca se termina de demostrar, el presupuesto crece y el flujo principal queda sin cerrar. |
| **6. Costos y tiempo** | No llevé un registro de horas ni de costos mientras desarrollaba. Las horas de depuración (H_d), el hosting y la holgura (F_r) son estimaciones. | Subestimo el costo real, no tengo reserva para imprevistos y no puedo justificar el presupuesto. |

## Conclusión

- Hoy conviene el Plan A: el costo es bajo y los recursos alcanzan para un taller.
- El crecimiento natural pasa al Plan B cuando haya datos reales que proteger.
- El Plan C queda como respaldo y camino hacia una infraestructura mayor.
- El MVP cuesta alrededor de 3,770 MXN con reserva de contingencia sin hosting (como está hoy) y alrededor de 3,940 MXN si se aloja en el Plan A; el mayor riesgo es quedarse sin cuota de IA y el segundo es que el alcance crezca sin control.

## Fuentes

- [Tipo de cambio, ElDolar.info](https://www.eldolar.info/es-MX/mexico/dia/20261027)
- [Hostinger KVM 1](https://www.vpsbenchmarks.com/hosters/hostinger/plans/kvm-1)
- [Precios de MySQL en DigitalOcean](https://docs.digitalocean.com/products/databases/mysql/details/pricing/)
- [Precios de Amazon Lightsail](https://www.cloudzero.com/blog/amazon-lightsail-pricing/)
- [Planes de Railway](https://docs.railway.com/pricing/plans)
- [Precios de Render](https://render.com/pricing)
- [Aiven: MySQL gratuito retirado](https://aiven.io/free-mysql-database-retired)
- [Azure para Estudiantes](https://learn.microsoft.com/azure/education-hub/azure-dev-tools-teaching/azure-students-program)
- [Precios de Claude Code](https://www.superblocks.com/blog/claude-code-pricing)
- [Sueldos de desarrollador junior, Indeed México](https://mx.indeed.com/career/junior-developer/salaries)
