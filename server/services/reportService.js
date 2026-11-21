import * as reportModel from '../models/reportModel.js';
import { fromCents, parseRange, toCents } from './reportRules.js';

const header = (range) => ({ from: range.from, to: range.to });
const sum = (items, key) => items.reduce((total, item) => total + item[key], 0);

/** Ingresos: solo pagos PAGADO con paid_at en el periodo. El total es igual a la suma por método y a la suma por día. */
export async function income(rawRange) {
  const range = parseRange(rawRange);
  const [methods, days] = await Promise.all([reportModel.incomeByMethod(range), reportModel.incomeByDay(range)]);
  const total = sum(methods, 'cents');
  if (total !== sum(days, 'cents')) throw new Error('El desglose de ingresos por método y por día no suma lo mismo.');
  return {
    ...header(range),
    total: fromCents(total),
    paymentsCount: sum(methods, 'payments'),
    byMethod: methods.map((item) => ({ method: item.method, payments: item.payments, total: fromCents(item.cents) })),
    byDay: days.map((item) => ({ day: item.day, payments: item.payments, total: fromCents(item.cents) })),
  };
}

export async function services(rawRange) {
  const range = parseRange(rawRange);
  const items = await reportModel.services(range);
  return { ...header(range), items: items.map((item) => ({ name: item.name, times: item.times, amount: fromCents(item.cents) })) };
}

export async function productivity(rawRange) {
  const range = parseRange(rawRange);
  const items = await reportModel.productivity(range);
  return {
    ...header(range),
    items: items.map((item) => ({
      mechanicId: item.mechanicId,
      name: item.name,
      ordersFinished: item.ordersFinished,
      laborAmount: fromCents(item.laborCents),
    })),
  };
}

const percent = (margin, revenue) => (revenue > 0 ? ((margin * 100) / revenue).toFixed(2) : null);

/**
 * Refacciones: ingreso, costo y margen por refacción. Una refacción sin precio de compra (nulo o cero) llega como «Sin costo»
 * y NO entra en los totales de costo ni de margen (cuenta en `noCostLines`).
 */
export async function parts(rawRange) {
  const range = parseRange(rawRange);
  const rows = await reportModel.parts(range);
  let revenue = 0;
  let cost = 0;
  let margin = 0;
  let costedRevenue = 0;
  let noCostLines = 0;

  const items = rows.map((row) => {
    const noCost = row.purchasePrice === null || row.purchasePrice === 0;
    revenue += row.revenueCents;
    if (noCost) {
      noCostLines += 1;
      return { partId: row.partId, code: row.code, name: row.name, units: row.units, revenue: fromCents(row.revenueCents), cost: null, margin: null, marginPercent: null, noCost: true };
    }
    const costCents = row.units * toCents(row.purchasePrice);
    const marginCents = row.revenueCents - costCents;
    cost += costCents;
    margin += marginCents;
    costedRevenue += row.revenueCents;
    return {
      partId: row.partId,
      code: row.code,
      name: row.name,
      units: row.units,
      revenue: fromCents(row.revenueCents),
      cost: fromCents(costCents),
      margin: fromCents(marginCents),
      marginPercent: percent(marginCents, row.revenueCents),
      noCost: false,
    };
  });

  return {
    ...header(range),
    items,
    totals: { revenue: fromCents(revenue), cost: fromCents(cost), margin: fromCents(margin), marginPercent: percent(margin, costedRevenue), noCostLines },
  };
}

/** Rotación del inventario: salidas del periodo, existencia inicial y final, promedio y rotación (null con promedio cero). */
export async function rotation(rawRange) {
  const range = parseRange(rawRange);
  const rows = await reportModel.rotation(range);
  return {
    ...header(range),
    items: rows.map((row) => {
      const average = (row.stockStart + row.stockEnd) / 2;
      return {
        partId: row.partId,
        code: row.code,
        name: row.name,
        out: row.out,
        stockStart: row.stockStart,
        stockEnd: row.stockEnd,
        averageStock: average.toFixed(2),
        rotation: average > 0 ? (row.out / average).toFixed(2) : null,
      };
    }),
  };
}

export const REPORTS = { income, services, productivity, parts, rotation };
