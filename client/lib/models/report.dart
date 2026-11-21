/// Periodo de un reporte: dos fechas `AAAA-MM-DD` con los dos días incluidos.
class ReportPeriod {
  const ReportPeriod({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  static String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get fromText => iso(from);
  String get toText => iso(to);

  /// Días del periodo contando los dos extremos.
  int get days => DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays + 1;

  /// Hoy.
  factory ReportPeriod.today(DateTime now) => ReportPeriod(from: DateTime(now.year, now.month, now.day), to: DateTime(now.year, now.month, now.day));

  /// Esta semana: del lunes a hoy.
  factory ReportPeriod.week(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return ReportPeriod(from: DateTime(today.year, today.month, today.day - (today.weekday - 1)), to: today);
  }

  /// Este mes: del día 1 a hoy.
  factory ReportPeriod.month(DateTime now) =>
      ReportPeriod(from: DateTime(now.year, now.month, 1), to: DateTime(now.year, now.month, now.day));
}

/// Ingresos de un método de pago o de un día.
class IncomeRow {
  const IncomeRow({required this.label, required this.payments, required this.total});

  final String label;
  final int payments;
  final String total;
}

class IncomeReport {
  const IncomeReport({required this.total, required this.paymentsCount, required this.byMethod, required this.byDay});

  factory IncomeReport.fromJson(Map<String, dynamic> json) => IncomeReport(
        total: '${json['total']}',
        paymentsCount: (json['paymentsCount'] as num).toInt(),
        byMethod: [
          for (final item in (json['byMethod'] as List)) _row(item as Map, 'method'),
        ],
        byDay: [
          for (final item in (json['byDay'] as List)) _row(item as Map, 'day'),
        ],
      );

  static IncomeRow _row(Map item, String key) =>
      IncomeRow(label: '${item[key]}', payments: (item['payments'] as num).toInt(), total: '${item['total']}');

  final String total;
  final int paymentsCount;
  final List<IncomeRow> byMethod;
  final List<IncomeRow> byDay;

  bool get isEmpty => paymentsCount == 0;
}

class ServiceStat {
  const ServiceStat({required this.name, required this.times, required this.amount});

  factory ServiceStat.fromJson(Map<String, dynamic> json) =>
      ServiceStat(name: '${json['name']}', times: (json['times'] as num).toInt(), amount: '${json['amount']}');

  final String name;
  final int times;
  final String amount;
}

class MechanicStat {
  const MechanicStat({required this.name, required this.ordersFinished, required this.laborAmount});

  factory MechanicStat.fromJson(Map<String, dynamic> json) => MechanicStat(
        name: '${json['name']}',
        ordersFinished: (json['ordersFinished'] as num).toInt(),
        laborAmount: '${json['laborAmount']}',
      );

  final String name;
  final int ordersFinished;
  final String laborAmount;
}

/// Refacción del reporte de costo y margen. [noCost] marca las que no tienen precio de compra («Sin costo»).
class PartStat {
  const PartStat({
    required this.code,
    required this.name,
    required this.units,
    required this.revenue,
    required this.noCost,
    this.cost,
    this.margin,
    this.marginPercent,
  });

  factory PartStat.fromJson(Map<String, dynamic> json) => PartStat(
        code: '${json['code']}',
        name: '${json['name']}',
        units: (json['units'] as num).toInt(),
        revenue: '${json['revenue']}',
        noCost: json['noCost'] as bool? ?? false,
        cost: json['cost'] == null ? null : '${json['cost']}',
        margin: json['margin'] == null ? null : '${json['margin']}',
        marginPercent: json['marginPercent'] == null ? null : '${json['marginPercent']}',
      );

  final String code;
  final String name;
  final int units;
  final String revenue;
  final String? cost;
  final String? margin;
  final String? marginPercent;
  final bool noCost;
}

class PartsReport {
  const PartsReport({required this.items, required this.revenue, required this.cost, required this.margin, this.marginPercent, required this.noCostLines});

  factory PartsReport.fromJson(Map<String, dynamic> json) {
    final totals = Map<String, dynamic>.from(json['totals'] as Map);
    return PartsReport(
      items: [for (final item in (json['items'] as List)) PartStat.fromJson(Map<String, dynamic>.from(item as Map))],
      revenue: '${totals['revenue']}',
      cost: '${totals['cost']}',
      margin: '${totals['margin']}',
      marginPercent: totals['marginPercent'] == null ? null : '${totals['marginPercent']}',
      noCostLines: (totals['noCostLines'] as num).toInt(),
    );
  }

  final List<PartStat> items;
  final String revenue;
  final String cost;
  final String margin;
  final String? marginPercent;
  final int noCostLines;
}

class RotationStat {
  const RotationStat({required this.code, required this.name, required this.out, required this.stockStart, required this.stockEnd, required this.averageStock, this.rotation});

  factory RotationStat.fromJson(Map<String, dynamic> json) => RotationStat(
        code: '${json['code']}',
        name: '${json['name']}',
        out: (json['out'] as num).toInt(),
        stockStart: (json['stockStart'] as num).toInt(),
        stockEnd: (json['stockEnd'] as num).toInt(),
        averageStock: '${json['averageStock']}',
        rotation: json['rotation'] == null ? null : '${json['rotation']}',
      );

  final String code;
  final String name;
  final int out;
  final int stockStart;
  final int stockEnd;
  final String averageStock;
  final String? rotation;
}

/// Archivo de Excel descargado del servidor.
class DownloadedFile {
  const DownloadedFile({required this.filename, required this.bytes});

  final String filename;
  final List<int> bytes;
}
