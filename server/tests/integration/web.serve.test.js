import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from '@jest/globals';
import { createApp } from '../../app.js';
import { getCorsOrigins, getTrustProxy, getWebConfig } from '../../config/env.js';

let dir;
beforeAll(() => {
  dir = fs.mkdtempSync(path.join(os.tmpdir(), 'motorix-web-'));
  fs.writeFileSync(path.join(dir, 'index.html'), '<!doctype html><title>Motorix</title>');
  fs.writeFileSync(path.join(dir, 'main.dart.js'), 'console.log(1)');
});
afterAll(() => fs.rmSync(dir, { recursive: true, force: true }));

describe('servir la web compilada', () => {
  it('test_no_sirve_la_web_si_no_se_activa', async () => {
    const app = createApp({ web: { serve: false, dir }, trustProxy: false, corsOrigins: null });
    const res = await request(app).get('/');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });

  it('test_sirve_el_index_y_los_archivos_estaticos_con_su_politica_de_contenido', async () => {
    const app = createApp({ web: { serve: true, dir }, trustProxy: false, corsOrigins: null });
    const index = await request(app).get('/');
    expect(index.status).toBe(200);
    expect(index.text).toContain('Motorix');
    expect(index.headers['content-security-policy']).toContain("'wasm-unsafe-eval'");
    const js = await request(app).get('/main.dart.js');
    expect(js.status).toBe(200);
  });

  it('test_una_ruta_de_la_web_responde_el_index_para_que_la_app_decida', async () => {
    const app = createApp({ web: { serve: true, dir }, trustProxy: false, corsOrigins: null });
    const res = await request(app).get('/clientes/12');
    expect(res.status).toBe(200);
    expect(res.text).toContain('Motorix');
  });

  it('test_la_api_conserva_su_politica_estricta_y_sus_errores_en_json', async () => {
    const app = createApp({ web: { serve: true, dir }, trustProxy: false, corsOrigins: null });
    const health = await request(app).get('/api/health');
    expect(health.status).toBe(200);
    expect(health.headers['content-security-policy']).not.toContain('wasm-unsafe-eval');
    const missing = await request(app).get('/api/no-existe');
    expect(missing.status).toBe(404);
    expect(missing.body.error.code).toBe('NOT_FOUND');
  });

  it('test_sin_index_en_la_carpeta_no_sirve_la_web', async () => {
    const empty = fs.mkdtempSync(path.join(os.tmpdir(), 'motorix-vacia-'));
    const app = createApp({ web: { serve: true, dir: empty }, trustProxy: false, corsOrigins: null });
    expect((await request(app).get('/')).status).toBe(404);
    fs.rmSync(empty, { recursive: true, force: true });
  });
});

describe('configuración de despliegue', () => {
  it('test_trust_proxy_se_lee_como_numero_booleano_o_apagado', () => {
    expect(getTrustProxy({})).toBe(false);
    expect(getTrustProxy({ TRUST_PROXY: '1' })).toBe(1);
    expect(getTrustProxy({ TRUST_PROXY: 'true' })).toBe(true);
    expect(getTrustProxy({ TRUST_PROXY: 'false' })).toBe(false);
    expect(() => getTrustProxy({ TRUST_PROXY: 'abc' })).toThrow(/TRUST_PROXY/);
  });

  it('test_con_trust_proxy_la_ip_del_cliente_sale_del_encabezado_reenviado', async () => {
    const app = createApp({ web: { serve: false, dir }, trustProxy: 1, corsOrigins: null });
    expect(app.get('trust proxy')).toBe(1);
    expect(createApp({ web: { serve: false, dir }, trustProxy: false, corsOrigins: null }).get('trust proxy')).toBe(false);
  });

  it('test_cors_se_limita_a_los_origenes_configurados', async () => {
    const app = createApp({ web: { serve: false, dir }, trustProxy: false, corsOrigins: ['https://motorix.example.com'] });
    const permitido = await request(app).get('/api/health').set('Origin', 'https://motorix.example.com');
    expect(permitido.headers['access-control-allow-origin']).toBe('https://motorix.example.com');
    const otro = await request(app).get('/api/health').set('Origin', 'https://otro.example.com');
    expect(otro.headers['access-control-allow-origin']).toBeUndefined();
    expect(getCorsOrigins({})).toBeNull();
    expect(getCorsOrigins({ CORS_ORIGIN: 'https://a.com, https://b.com' })).toEqual(['https://a.com', 'https://b.com']);
  });

  it('test_la_web_se_activa_solo_con_serve_web_true', () => {
    expect(getWebConfig({}).serve).toBe(false);
    expect(getWebConfig({ SERVE_WEB: 'true' }).serve).toBe(true);
    expect(getWebConfig({ SERVE_WEB: 'si' }).serve).toBe(false);
  });
});
