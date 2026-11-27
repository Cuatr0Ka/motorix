-- Términos y condiciones y aviso de privacidad como dos textos separados.
-- La versión 1.0 llevaba ambos en un solo texto (`body`). Desde la 2.0, `body` guarda los términos y condiciones y
-- `privacy_notice` guarda el aviso de privacidad. Una versión publicada no se edita: esta migración agrega la versión 2.0
-- y todos los usuarios la aceptan en su siguiente inicio de sesión.
--
-- Los textos usan marcadores que el servidor reemplaza con los datos de Configuración > Taller al consultarlos:
-- {{TALLER_NOMBRE}}, {{TALLER_DOMICILIO}}, {{TALLER_TELEFONO}} y {{TALLER_CORREO}}.
-- Texto de referencia basado en la LFPDPPP vigente (DOF 20-03-2025); no constituye asesoría legal y conviene que lo revise
-- quien corresponda antes de usarlo con clientes reales.

ALTER TABLE terms_versions ADD COLUMN privacy_notice MEDIUMTEXT NULL AFTER body;

INSERT INTO terms_versions (version, title, body, privacy_notice) VALUES (
  '2.0',
  'Términos y condiciones de uso',
  'TÉRMINOS Y CONDICIONES DE USO DE MOTORIX
Versión 2.0 · Última actualización: 26 de noviembre de 2026

1. Objeto y aceptación
Estos términos regulan el uso de Motorix, el sistema de gestión de {{TALLER_NOMBRE}} (en adelante, "el Taller"), por parte de las personas a quienes el Taller les asigna una cuenta (en adelante, "la persona usuaria"). Al marcar la casilla de aceptación y continuar, la persona usuaria confirma que leyó estos términos, que los entiende y que se obliga a cumplirlos. Sin esta aceptación no es posible usar el sistema.

2. Qué es Motorix
Motorix es una herramienta de trabajo para registrar y consultar clientes, vehículos, citas, órdenes de servicio, diagnósticos, refacciones, inventario, pagos, tickets, mantenimientos y avisos internos. El sistema no envía mensajes a los clientes: los recordatorios los realiza el personal del Taller por llamada o en persona.

3. Cuentas y roles
a) Cada cuenta es personal e intransferible y tiene un rol (administración, recepción o mecánico) que define lo que se puede consultar y hacer.
b) La persona usuaria debe usar una contraseña de al menos 10 caracteres, con mayúscula, minúscula y número, no compartirla con nadie y cerrar la sesión cuando se aleje del equipo.
c) Tras varios intentos fallidos de acceso la cuenta se bloquea de forma temporal como medida de protección.
d) Si sospecha que alguien más usó su cuenta, debe avisarlo de inmediato a la administración.
e) Todo lo que se haga con una cuenta se considera hecho por su titular.

4. Uso permitido
La persona usuaria debe usar el sistema solo para las actividades de su puesto en el Taller, con información veraz y completa, y registrar las operaciones (órdenes, cobros, movimientos de inventario) cuando ocurren y tal como ocurrieron.

5. Usos prohibidos
Queda prohibido: a) intentar acceder a información o funciones que el rol no permite; b) usar la cuenta de otra persona; c) copiar, extraer, publicar o enviar información del sistema fuera de lo necesario para atender al cliente; d) usar los datos para fines personales, comerciales o ajenos al Taller; e) alterar, borrar u ocultar registros para encubrir un error o una irregularidad; f) introducir código malicioso o intentar vulnerar la seguridad del sistema; g) capturar en el sistema datos de tarjetas bancarias o contraseñas de clientes.

6. Confidencialidad
La información de clientes, vehículos, cobros y precios es confidencial. Los precios de compra de las refacciones son información reservada de la administración. Esta obligación continúa aunque la persona usuaria deje de trabajar en el Taller. El tratamiento de los datos personales se rige además por el Aviso de privacidad, que forma parte de esta aceptación.

7. Registro de actividad
Por seguridad, el sistema guarda una bitácora de acciones sensibles (intentos fallidos de acceso y bloqueos de cuenta, cambios de contraseña, de usuarios, de configuración y de precios, cancelaciones de pagos y aceptación de estos textos). La bitácora no contiene contraseñas ni datos de tarjeta, y solo la consulta la administración. Al aceptar estos términos la persona usuaria acepta que sus acciones queden registradas.

8. Cobros
El sistema registra los cobros en efectivo, con tarjeta (terminal del Taller), por transferencia y por Mercado Pago. Motorix no almacena números de tarjeta ni datos bancarios de los clientes. En los cobros por Mercado Pago, el cliente captura sus datos de pago directamente en la plataforma de ese proveedor, que los trata bajo sus propias condiciones.

9. Propiedad de la información y del sistema
La información capturada en el sistema pertenece al Taller. Motorix, su diseño y su código son propiedad de sus autores; la persona usuaria no adquiere ningún derecho sobre ellos más allá del uso aquí permitido.

10. Disponibilidad
El Taller procura que el sistema esté disponible, pero no garantiza que funcione sin interrupciones ni libre de errores. Pueden ocurrir pausas por mantenimiento o por fallas del proveedor de alojamiento. La persona usuaria debe revisar la información importante antes de actuar con base en ella.

11. Suspensión y baja de cuentas
La administración puede suspender o dar de baja una cuenta en cualquier momento, en particular si se incumplen estos términos. Los registros hechos con la cuenta se conservan por razones de trazabilidad.

12. Limitación de responsabilidad
El Taller no responde por daños derivados del uso indebido de una cuenta por causas atribuibles a su titular (por ejemplo, compartir la contraseña) ni por la información que la persona usuaria capture de forma errónea o falsa.

13. Cambios a estos términos
El Taller puede actualizar estos términos. Cada versión tiene número y fecha. Cuando se publique una versión nueva, la persona usuaria deberá leerla y aceptarla para seguir usando el sistema. El sistema conserva el historial de las versiones y de quién aceptó cada una.

14. Legislación aplicable y contacto
Estos términos se rigen por las leyes de los Estados Unidos Mexicanos. Para cualquier controversia, las partes se someten a los tribunales competentes del domicilio del Taller. Dudas sobre estos términos: {{TALLER_NOMBRE}}, {{TALLER_DOMICILIO}}, teléfono {{TALLER_TELEFONO}}, correo {{TALLER_CORREO}}.',
  'AVISO DE PRIVACIDAD INTEGRAL
Versión 2.0 · Última actualización: 26 de noviembre de 2026

Este aviso se emite conforme a la Ley Federal de Protección de Datos Personales en Posesión de los Particulares (LFPDPPP). Explica quién usa sus datos personales, cuáles son, para qué se usan y cómo puede ejercer sus derechos. Aplica a los clientes del Taller y al personal que usa Motorix.

1. Quién es el responsable de sus datos
Responsable: {{TALLER_NOMBRE}} (en adelante, "el Taller").
Domicilio: {{TALLER_DOMICILIO}}.
Teléfono de contacto para asuntos de privacidad: {{TALLER_TELEFONO}}.
Correo electrónico para asuntos de privacidad: {{TALLER_CORREO}}.
La persona responsable del Taller atiende las solicitudes sobre datos personales (derechos ARCO) en el horario de atención del establecimiento.

2. Qué datos personales tratamos
a) De los clientes: nombre; teléfono; correo electrónico (opcional); domicilio (opcional); y de su vehículo: marca, modelo, año, placas, número de serie (VIN, opcional), color y kilometraje. También el historial de citas, órdenes, diagnósticos, servicios, refacciones, mantenimientos programados y cobros (importe, método, referencia de pago y ticket).
b) Del personal que usa el sistema: nombre, nombre de usuario, correo electrónico, rol, contraseña (se guarda cifrada de forma irreversible, nunca en texto legible), fecha de aceptación de los términos y el registro de sus acciones en el sistema.
c) Datos sensibles: el Taller no solicita datos personales sensibles (como salud, origen étnico, creencias o preferencias). Le pedimos no proporcionarlos.
d) Datos financieros: el Taller no almacena números de tarjeta ni cuentas bancarias. Solo guarda el importe, el método de pago, el estado del cobro y una referencia del movimiento.

3. Para qué usamos sus datos
Finalidades necesarias para la relación con el cliente (no requieren su consentimiento porque son indispensables para prestar el servicio):
- Registrarlo como cliente y a su vehículo.
- Programar citas y abrir órdenes de servicio.
- Diagnosticar, reparar y dar mantenimiento al vehículo, y registrar las refacciones usadas.
- Cobrar el servicio y emitir el ticket o comprobante.
- Mantener el historial de servicios del vehículo y atender aclaraciones o garantías.
- Cumplir obligaciones legales, fiscales y de autoridades competentes.
Finalidades relacionadas con el servicio que usted puede rechazar:
- Recordarle por llamada o en persona su próximo mantenimiento o servicio pendiente. Motorix no envía mensajes automáticos.
Finalidades del personal que usa el sistema: crear y administrar su cuenta, controlar el acceso según su rol, mantener la seguridad del sistema y llevar la bitácora de acciones.
El Taller no usa sus datos para publicidad, mercadotecnia ni perfilamiento, ni los vende. Si en el futuro lo hiciera, solicitaría antes su consentimiento.

4. Cómo limitar el uso o la divulgación de sus datos
Puede pedir en cualquier momento, en el establecimiento o por teléfono, que no se le contacte para recordatorios de mantenimiento, que se le contacte solo por un medio determinado (por ejemplo, solo por llamada) o que no se registre su correo o domicilio, que son datos opcionales. Su solicitud se atenderá sin costo y sin que afecte el servicio que ya contrató.

5. Sus derechos: acceso, rectificación, cancelación y oposición (ARCO)
Usted tiene derecho a: acceder a sus datos y conocer cómo se usan; rectificarlos si son inexactos o están incompletos; cancelarlos cuando considere que no se necesitan o se usan de forma indebida; y oponerse a que se usen para una finalidad concreta. También puede revocar en cualquier momento el consentimiento que haya dado, sin efectos retroactivos.
Cómo ejercerlos: presente su solicitud por escrito, en persona o por correo electrónico, con la persona responsable del Taller, en el domicilio, teléfono o correo del punto 1. Indique su nombre, un medio para responderle, la descripción clara de los datos y del derecho que quiere ejercer, y acompañe una identificación oficial (o, si actúa por otra persona, el documento que acredite su representación).
Plazos: el Taller le comunicará su respuesta en un máximo de 20 días hábiles y, si procede, hará efectiva la solicitud en los 15 días hábiles siguientes. Ambos plazos pueden ampliarse una sola vez por un periodo igual cuando exista causa justificada, y se le avisará. El ejercicio de sus derechos es gratuito; solo podrían cobrarse los costos justificados de reproducción o envío.
Límites: algunos datos (por ejemplo, los cobros y tickets) pueden tener que conservarse por obligaciones legales o fiscales. En ese caso se bloquearán, es decir, solo se conservarán para esos fines y se eliminarán al terminar el plazo legal.

6. Con quién compartimos sus datos
El Taller no vende sus datos ni los transfiere a terceros para sus propios fines. Solo puede entregarlos a autoridades competentes cuando una ley o una orden lo requiera.
Proveedores que actúan por cuenta del Taller: la información de Motorix se aloja en servicios de infraestructura en la nube (servidor y base de datos). Estos proveedores solo almacenan y procesan la información para que el sistema funcione, no la usan para fines propios, y alguno puede encontrarse fuera de México.
Cobros por Mercado Pago: cuando usted elige pagar por este medio, el Taller solo envía a Mercado Pago el concepto (el folio de la orden), el importe y una referencia. No se envían su nombre, teléfono, correo, domicilio ni datos del vehículo. Sus datos de pago los captura usted directamente en la plataforma de Mercado Pago, que los trata conforme a su propio aviso de privacidad.

7. Cómo protegemos sus datos
Aplicamos medidas administrativas, técnicas y físicas razonables: acceso por cuentas personales y roles, contraseñas cifradas, bloqueo temporal tras intentos fallidos, conexión cifrada, bitácora de acciones sensibles y confidencialidad obligatoria del personal. Si ocurriera una vulneración de seguridad que afecte de forma significativa sus derechos patrimoniales o morales, el Taller se lo informará sin demora para que pueda tomar medidas.

8. Cuánto tiempo conservamos sus datos
Conservamos sus datos mientras exista la relación con el Taller y durante el tiempo necesario para el historial del vehículo, las garantías y las obligaciones legales y fiscales aplicables. Después se bloquean y se suprimen. Los datos de las cuentas del personal se conservan mientras la cuenta exista y, por trazabilidad, los registros que hizo.

9. Menores de edad
El sistema no está dirigido a menores de edad. Si se registra a un menor, debe hacerlo su madre, padre o tutor.

10. Cambios a este aviso
Este aviso puede cambiar por nuevas disposiciones legales o por cambios en nuestras prácticas. Cada versión tiene número y fecha. La versión vigente está disponible en el Taller y en Motorix; al personal que usa el sistema se le pedirá aceptar cada versión nueva, y a los clientes se les informará en el establecimiento.

11. Consentimiento
Al proporcionar sus datos al Taller y no manifestar su oposición, entendemos que conoce este aviso y que consiente el tratamiento de sus datos para las finalidades descritas. El personal que usa Motorix confirma con su aceptación en el sistema que lo leyó y que tratará los datos de los clientes conforme a él.

12. Autoridad
Si considera que su derecho a la protección de datos personales ha sido vulnerado, puede acudir a la Secretaría Anticorrupción y Buen Gobierno, autoridad en la materia desde la desaparición del INAI.

AVISO DE PRIVACIDAD SIMPLIFICADO (para mostrador y formatos)
{{TALLER_NOMBRE}}, con domicilio en {{TALLER_DOMICILIO}}, es responsable de sus datos personales. Tratamos sus datos de identificación y contacto, los de su vehículo y los de cobro (sin datos de tarjeta) para registrarlo como cliente, programar citas, prestar y cobrar el servicio, llevar el historial del vehículo y recordarle su próximo mantenimiento. No tratamos datos sensibles ni usamos sus datos para publicidad, y no los transferimos a terceros para fines propios. Puede pedir que no le contactemos para recordatorios, y ejercer sus derechos de acceso, rectificación, cancelación y oposición, en {{TALLER_DOMICILIO}}, al teléfono {{TALLER_TELEFONO}} o al correo {{TALLER_CORREO}}. El aviso integral está disponible en el Taller.'
);
