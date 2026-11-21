import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import ExcelJS from 'exceljs';

/**
 * Libro de Excel de un reporte, con la identidad visual de Motorix (design-system.md): logo, encabezado con el color primario
 * vino, filas alternadas en el fondo cálido, bordes suaves y formatos numéricos reales (los importes son números, no texto).
 * Los textos se escriben como cadenas, así que una celda que empiece con `=`, `+`, `-` o `@` nunca se ejecuta como fórmula.
 */

// Colores del sistema de diseño (client/lib/utils/tokens.dart), sin el canal alfa.
const COLORS = {
  primary: '9B4F55',
  sidebar: '2B2325',
  background: 'F5F2F1',
  outline: 'DDD5D4',
  textPrimary: '231F20',
  textSecondary: '574D4E',
  success: '3F6B4A',
  warning: 'C9892B',
  tint: 'EFE3E4',
};

const FONT = 'Calibri';
const LOGO_PATH = fileURLToPath(new URL('../assets/logo.png', import.meta.url));

const FORMATS = {
  money: '"$"#,##0.00',
  int: '#,##0',
  decimal: '#,##0.00',
  percent: '0.00"%"',
};

const solid = (argb) => ({ type: 'pattern', pattern: 'solid', fgColor: { argb: `FF${argb}` } });
const thin = (argb) => ({ style: 'thin', color: { argb: `FF${argb}` } });
const box = (argb) => ({ top: thin(argb), left: thin(argb), bottom: thin(argb), right: thin(argb) });

/** Tamaño del PNG leyendo su cabecera (para no deformar el logo al escalarlo). */
function pngSize(buffer) {
  return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
}

/** Valor de una celda según su tipo de columna: importes y números como números; el resto, como texto. */
function cellValue(raw, type) {
  if (raw === null || raw === undefined || raw === '') return null;
  if (type === 'money' || type === 'int' || type === 'decimal' || type === 'percent') {
    const number = Number(raw);
    return Number.isNaN(number) ? String(raw) : number;
  }
  return String(raw);
}

/**
 * @param {object} definition
 * @param {string} definition.title título del reporte
 * @param {string} definition.subtitle texto bajo el título (el periodo)
 * @param {Array} definition.sections secciones apiladas: `{ title, columns: [{ header, key, width, type }], rows: [obj], totals?: obj, emptyText? }`
 * @returns {Promise<Buffer>}
 */
export async function buildWorkbook({ title, subtitle, sections, generatedAt = new Date() }) {
  const workbook = new ExcelJS.Workbook();
  workbook.creator = 'Motorix';
  workbook.title = title;
  workbook.created = generatedAt;

  const sheet = workbook.addWorksheet('Reporte', {
    properties: { tabColor: { argb: `FF${COLORS.primary}` }, defaultRowHeight: 18 },
    views: [{ showGridLines: false }],
    pageSetup: { orientation: 'landscape', fitToPage: true, fitToWidth: 1, fitToHeight: 0, paperSize: 9 },
  });

  // Todas las secciones comparten las columnas: se usa el máximo de columnas y el mayor ancho pedido en cada posición.
  const columnCount = Math.max(...sections.map((section) => section.columns.length), 2);
  const widths = Array.from({ length: columnCount }, (_, i) =>
    Math.max(14, ...sections.map((section) => section.columns[i]?.width ?? 0)),
  );
  widths.forEach((width, i) => {
    sheet.getColumn(i + 1).width = width;
  });
  const lastColumn = columnCount;

  // ---- Encabezado: logo, marca, título y periodo sobre el fondo cálido ----
  for (let row = 1; row <= 3; row += 1) {
    sheet.getRow(row).height = 24;
    for (let col = 1; col <= lastColumn; col += 1) sheet.getCell(row, col).fill = solid(COLORS.background);
  }
  const logo = readFileSync(LOGO_PATH);
  const { width: logoW, height: logoH } = pngSize(logo);
  const logoHeight = 66;
  const imageId = workbook.addImage({ buffer: logo, extension: 'png' });
  sheet.addImage(imageId, { tl: { col: 0.15, row: 0.1 }, ext: { width: Math.round((logoW / logoH) * logoHeight), height: logoHeight } });

  sheet.mergeCells(1, 2, 1, lastColumn);
  sheet.mergeCells(2, 2, 2, lastColumn);
  sheet.mergeCells(3, 2, 3, lastColumn);
  Object.assign(sheet.getCell(1, 2), {
    value: 'MOTORIX',
    font: { name: FONT, size: 20, bold: true, color: { argb: `FF${COLORS.primary}` } },
    alignment: { vertical: 'middle', indent: 1 },
  });
  Object.assign(sheet.getCell(2, 2), {
    value: title,
    font: { name: FONT, size: 14, bold: true, color: { argb: `FF${COLORS.textPrimary}` } },
    alignment: { vertical: 'middle', indent: 1 },
  });
  Object.assign(sheet.getCell(3, 2), {
    value: subtitle,
    font: { name: FONT, size: 10, color: { argb: `FF${COLORS.textSecondary}` } },
    alignment: { vertical: 'middle', indent: 1 },
  });
  // Franja de color primario bajo el encabezado.
  sheet.getRow(4).height = 5;
  for (let col = 1; col <= lastColumn; col += 1) sheet.getCell(4, col).fill = solid(COLORS.primary);
  sheet.getRow(5).height = 8;

  // ---- Secciones ----
  let row = 6;
  let firstHeaderRow = null;
  sections.forEach((section, sectionIndex) => {
    if (section.title) {
      sheet.mergeCells(row, 1, row, lastColumn);
      Object.assign(sheet.getCell(row, 1), {
        value: section.title,
        font: { name: FONT, size: 12, bold: true, color: { argb: `FF${COLORS.textPrimary}` } },
        alignment: { vertical: 'middle' },
        border: { bottom: { style: 'medium', color: { argb: `FF${COLORS.primary}` } } },
      });
      sheet.getRow(row).height = 22;
      row += 1;
    }

    // Encabezado de la tabla.
    section.columns.forEach((column, i) => {
      Object.assign(sheet.getCell(row, i + 1), {
        value: column.header,
        font: { name: FONT, size: 11, bold: true, color: { argb: 'FFFFFFFF' } },
        fill: solid(COLORS.primary),
        alignment: { vertical: 'middle', horizontal: column.type === 'text' || !column.type ? 'left' : 'right', wrapText: true, indent: 1 },
        border: box(COLORS.primary),
      });
    });
    sheet.getRow(row).height = 22;
    if (firstHeaderRow === null) firstHeaderRow = row;
    row += 1;

    // Filas con color alterno.
    if (section.rows.length === 0) {
      sheet.mergeCells(row, 1, row, section.columns.length);
      Object.assign(sheet.getCell(row, 1), {
        value: section.emptyText ?? 'No hay datos en este periodo',
        font: { name: FONT, size: 11, italic: true, color: { argb: `FF${COLORS.textSecondary}` } },
        alignment: { horizontal: 'center', vertical: 'middle' },
        border: box(COLORS.outline),
      });
      row += 1;
    }
    section.rows.forEach((item, rowIndex) => {
      section.columns.forEach((column, i) => {
        const cell = sheet.getCell(row, i + 1);
        const type = item.__types?.[column.key] ?? column.type ?? 'text';
        cell.value = cellValue(item[column.key], type);
        cell.font = { name: FONT, size: 11, color: { argb: `FF${COLORS.textPrimary}` } };
        cell.fill = solid(rowIndex % 2 === 0 ? 'FFFFFF' : COLORS.background);
        cell.border = box(COLORS.outline);
        cell.alignment = { vertical: 'middle', horizontal: type === 'text' ? 'left' : 'right', indent: 1 };
        if (FORMATS[type]) cell.numFmt = FORMATS[type];
      });
      row += 1;
    });

    // Fila de totales.
    if (section.totals) {
      section.columns.forEach((column, i) => {
        const cell = sheet.getCell(row, i + 1);
        const type = column.type ?? 'text';
        cell.value = cellValue(section.totals[column.key], type);
        cell.font = { name: FONT, size: 11, bold: true, color: { argb: `FF${COLORS.textPrimary}` } };
        cell.fill = solid(COLORS.tint);
        cell.border = { ...box(COLORS.outline), top: { style: 'medium', color: { argb: `FF${COLORS.primary}` } } };
        cell.alignment = { vertical: 'middle', horizontal: type === 'text' ? 'left' : 'right', indent: 1 };
        if (FORMATS[type]) cell.numFmt = FORMATS[type];
      });
      row += 1;
    }

    row += sectionIndex < sections.length - 1 ? 1 : 0;
  });

  // ---- Pie ----
  row += 1;
  sheet.mergeCells(row, 1, row, lastColumn);
  const generated = `${generatedAt.getFullYear()}-${String(generatedAt.getMonth() + 1).padStart(2, '0')}-${String(generatedAt.getDate()).padStart(2, '0')}`;
  Object.assign(sheet.getCell(row, 1), {
    value: `Motorix · Sistema de gestión para taller mecánico · Generado el ${generated}`,
    font: { name: FONT, size: 9, italic: true, color: { argb: `FF${COLORS.textSecondary}` } },
    alignment: { horizontal: 'left', indent: 1 },
  });

  // Con una sola tabla: encabezado fijo y filtros para ordenar y buscar en Excel.
  if (sections.length === 1 && firstHeaderRow !== null) {
    sheet.views = [{ showGridLines: false, state: 'frozen', ySplit: firstHeaderRow }];
    if (sections[0].rows.length > 0) {
      sheet.autoFilter = { from: { row: firstHeaderRow, column: 1 }, to: { row: firstHeaderRow, column: sections[0].columns.length } };
    }
  }

  return Buffer.from(await workbook.xlsx.writeBuffer());
}

const METHOD_LABELS = { EFECTIVO: 'Efectivo', TARJETA: 'Tarjeta', TRANSFERENCIA: 'Transferencia', MERCADO_PAGO: 'Mercado Pago' };

const REPORT_TITLES = {
  income: 'Reporte de ingresos',
  services: 'Reporte de servicios más frecuentes',
  productivity: 'Reporte de productividad por mecánico',
  parts: 'Reporte de costo y margen de refacciones',
  rotation: 'Reporte de rotación del inventario',
};

/** Traduce los datos de cada reporte (los mismos del JSON) a las secciones del libro. */
function sectionsFor(name, data) {
  if (name === 'income') {
    return [
      {
        title: 'Resumen',
        columns: [
          { header: 'Concepto', key: 'concept', width: 34, type: 'text' },
          { header: 'Valor', key: 'value', width: 18, type: 'text' },
        ],
        rows: [
          { concept: 'Total de ingresos', value: data.total, __types: { value: 'money' } },
          { concept: 'Pagos registrados', value: data.paymentsCount, __types: { value: 'int' } },
        ],
      },
      {
        title: 'Ingresos por método de pago',
        columns: [
          { header: 'Método de pago', key: 'method', type: 'text' },
          { header: 'Pagos', key: 'payments', type: 'int' },
          { header: 'Total', key: 'total', type: 'money' },
        ],
        rows: data.byMethod.map((item) => ({ ...item, method: METHOD_LABELS[item.method] ?? item.method })),
        totals: { method: 'Total', payments: data.paymentsCount, total: data.total },
      },
      {
        title: 'Ingresos por día',
        columns: [
          { header: 'Día', key: 'day', type: 'text' },
          { header: 'Pagos', key: 'payments', type: 'int' },
          { header: 'Total', key: 'total', type: 'money' },
        ],
        rows: data.byDay,
        totals: { day: 'Total', payments: data.paymentsCount, total: data.total },
      },
    ];
  }
  if (name === 'services') {
    return [
      {
        columns: [
          { header: 'Servicio', key: 'name', width: 40, type: 'text' },
          { header: 'Veces realizado', key: 'times', width: 18, type: 'int' },
          { header: 'Importe', key: 'amount', width: 18, type: 'money' },
        ],
        rows: data.items,
      },
    ];
  }
  if (name === 'productivity') {
    return [
      {
        columns: [
          { header: 'Mecánico', key: 'name', width: 34, type: 'text' },
          { header: 'Órdenes terminadas', key: 'ordersFinished', width: 22, type: 'int' },
          { header: 'Mano de obra', key: 'laborAmount', width: 20, type: 'money' },
        ],
        rows: data.items,
      },
    ];
  }
  if (name === 'parts') {
    return [
      {
        columns: [
          { header: 'Código', key: 'code', width: 16, type: 'text' },
          { header: 'Refacción', key: 'name', width: 34, type: 'text' },
          { header: 'Unidades', key: 'units', width: 12, type: 'int' },
          { header: 'Ingreso', key: 'revenue', width: 16, type: 'money' },
          { header: 'Costo', key: 'cost', width: 16, type: 'money' },
          { header: 'Margen', key: 'margin', width: 16, type: 'money' },
          { header: 'Margen %', key: 'marginPercent', width: 12, type: 'percent' },
        ],
        // Una refacción sin precio de compra se marca como «Sin costo» (texto) y no suma en los totales de costo y margen.
        rows: data.items.map((item) => ({
          ...item,
          cost: item.noCost ? 'Sin costo' : item.cost,
          margin: item.noCost ? 'Sin costo' : item.margin,
          marginPercent: item.noCost ? null : item.marginPercent,
          __types: item.noCost ? { cost: 'text', margin: 'text' } : undefined,
        })),
        totals: {
          name: 'Total (sin las refacciones «Sin costo»)',
          revenue: data.totals.revenue,
          cost: data.totals.cost,
          margin: data.totals.margin,
          marginPercent: data.totals.marginPercent,
        },
      },
    ];
  }
  return [
    {
      columns: [
        { header: 'Código', key: 'code', width: 16, type: 'text' },
        { header: 'Refacción', key: 'name', width: 34, type: 'text' },
        { header: 'Salidas', key: 'out', width: 12, type: 'int' },
        { header: 'Existencia inicial', key: 'stockStart', width: 18, type: 'int' },
        { header: 'Existencia final', key: 'stockEnd', width: 18, type: 'int' },
        { header: 'Promedio', key: 'averageStock', width: 14, type: 'decimal' },
        { header: 'Rotación', key: 'rotation', width: 14, type: 'decimal' },
      ],
      rows: data.items,
    },
  ];
}

/** Libro de Excel de uno de los cinco reportes a partir de los datos que devuelve su servicio. */
export function buildReportWorkbook(name, data) {
  return buildWorkbook({
    title: REPORT_TITLES[name],
    subtitle: `Periodo: del ${data.from} al ${data.to}`,
    sections: sectionsFor(name, data),
  });
}
