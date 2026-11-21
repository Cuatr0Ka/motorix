import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from '@jest/globals';

// SC-006 y FR-019: el sistema NO envía mensajes al cliente por ningún canal (WhatsApp, correo o SMS). El aviso lo
// hace la persona de recepción por teléfono o en persona y el sistema solo lo registra.
const serverDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const clientDir = path.resolve(serverDir, '..', 'client');

const MENSAJERIA = /nodemailer|sendgrid|twilio|mailgun|whatsapp|telegram|smtp|firebase_messaging|flutter_local_notifications|\bsms\b/i;

const ARCHIVOS_DEL_SPRINT = [
  'services/notificationService.js',
  'services/clientNoticeService.js',
  'services/noticeRules.js',
  'models/noticeModel.js',
  'models/clientNoticeModel.js',
  'models/notificationReadModel.js',
  'controllers/notificationController.js',
  'controllers/clientNoticeController.js',
  'routes/notificationRoutes.js',
  'routes/clientNoticeRoutes.js',
  'validators/noticeValidators.js',
];

describe('el sistema no envía mensajes al cliente (SC-006, FR-019)', () => {
  it('test_el_backend_no_depende_de_ninguna_libreria_de_mensajeria', () => {
    const paquete = JSON.parse(fs.readFileSync(path.join(serverDir, 'package.json'), 'utf8'));
    const dependencias = Object.keys({ ...paquete.dependencies, ...paquete.devDependencies });

    expect(dependencias.filter((nombre) => MENSAJERIA.test(nombre))).toEqual([]);
  });

  it('test_el_cliente_no_depende_de_ninguna_libreria_de_mensajeria', () => {
    const pubspec = fs.readFileSync(path.join(clientDir, 'pubspec.yaml'), 'utf8');
    const dependencias = [...pubspec.matchAll(/^ {2}([a-z_0-9]+):/gm)].map((coincidencia) => coincidencia[1]);

    expect(dependencias.length).toBeGreaterThan(0);
    expect(dependencias.filter((nombre) => MENSAJERIA.test(nombre))).toEqual([]);
  });

  it('test_el_codigo_del_sprint_no_importa_ni_llama_a_servicios_externos', () => {
    for (const archivo of ARCHIVOS_DEL_SPRINT) {
      const texto = fs.readFileSync(path.join(serverDir, archivo), 'utf8');
      expect({ archivo, mensajeria: MENSAJERIA.test(texto) }).toEqual({ archivo, mensajeria: false });
      expect({ archivo, red: /\bfetch\(|axios|node:https?|require\('https?'\)|from 'https?'/.test(texto) }).toEqual({ archivo, red: false });
    }
  });

  it('test_marcar_como_avisado_solo_escribe_en_la_base', () => {
    const servicio = fs.readFileSync(path.join(serverDir, 'services', 'clientNoticeService.js'), 'utf8');

    expect(servicio).toContain('clientNoticeModel.insertIgnore');
    expect(servicio).not.toMatch(/integrations\//);
  });
});
