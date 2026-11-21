import * as reportService from '../services/reportService.js';
import { buildReportWorkbook } from '../services/reportWorkbook.js';
import { ok } from '../utils/response.js';

const XLSX_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/**
 * Fábrica de controladores: cada reporte responde JSON o, con `format=xlsx`, el libro de Excel generado con LOS MISMOS datos
 * (la misma función de servicio), de modo que el archivo nunca difiere de la pantalla.
 */
export function reportController(name) {
  return async function report(req, res) {
    const { format, ...range } = req.validQuery;
    const data = await reportService.REPORTS[name](range);
    if (format !== 'xlsx') return ok(res, data);

    const buffer = await buildReportWorkbook(name, data);
    res.setHeader('Content-Type', XLSX_TYPE);
    res.setHeader('Content-Disposition', `attachment; filename="reporte-${name}-${data.from}_${data.to}.xlsx"`);
    return res.status(200).send(buffer);
  };
}
