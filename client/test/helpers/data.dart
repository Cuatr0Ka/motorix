import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_api.dart';

Map<String, dynamic> clientJson(int id, String name, {String? email, int vehicles = 0, String phone = '5512345678'}) => {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': null,
      'vehicleCount': vehicles,
    };

Map<String, dynamic> vehicleJson(
  int id, {
  String brand = 'Honda',
  String model = 'Civic',
  int year = 2020,
  String plate = 'MNO-345-E',
  int ownerId = 1,
  String ownerName = 'Ana Morales',
  String ownerPhone = '5512345678',
  int? mileage = 51200,
}) =>
    {
      'id': id,
      'brand': brand,
      'model': model,
      'year': year,
      'licensePlate': plate,
      'vin': null,
      'color': null,
      'currentMileage': mileage,
      'client': {'id': ownerId, 'name': ownerName, 'phone': ownerPhone},
    };

/// Atiende `GET /clients` con la lista indicada y delega el resto en [extra].
FakeHandler clientsHandler({List<Map<String, dynamic>>? items, FakeHandler? extra}) {
  final list = items ?? [clientJson(1, 'Ana Morales', email: 'ana@x.local', vehicles: 2), clientJson(2, 'Luis Pérez')];
  return (r) {
    final custom = extra?.call(r);
    if (custom != null) return custom;
    if (r.method == 'GET' && r.path == '/clients') {
      final search = (r.query['search'] ?? '').toLowerCase();
      final filtered = list.where((c) => search.isEmpty || '${c['name']}'.toLowerCase().contains(search)).toList();
      return ok(filtered, meta: {'page': 1, 'pageSize': 20, 'total': filtered.length});
    }
    return null;
  };
}

/// Atiende `GET /vehicles` con la lista indicada y delega el resto en [extra].
FakeHandler vehiclesHandler({List<Map<String, dynamic>>? items, FakeHandler? extra}) {
  final list = items ?? [vehicleJson(1), vehicleJson(2, brand: 'Toyota', model: 'Hilux', plate: 'DEF-456-B', ownerId: 2, ownerName: 'Luis Pérez')];
  final clients = clientsHandler();
  return (r) {
    final custom = extra?.call(r);
    if (custom != null) return custom;
    if (r.method == 'GET' && r.path == '/vehicles') {
      return ok(list, meta: {'page': 1, 'pageSize': 20, 'total': list.length});
    }
    return clients(r);
  };
}

/// Abre una sección del menú lateral (por ejemplo, "Clientes" o "Vehículos").
Future<void> openSection(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text(label)));
  await tester.pumpAndSettle();
}

// ---- Sprint 2: citas y órdenes de servicio ----

Map<String, dynamic> appointmentJson(
  int id, {
  String status = 'PENDIENTE',
  String scheduledAt = '2030-10-12T15:30:00.000Z',
  String reason = 'Servicio de 50 000 km',
  String? notes,
  int clientId = 1,
  String clientName = 'Ana Morales',
  int vehicleId = 1,
  String plate = 'MNO-345-E',
  Map<String, dynamic>? order,
}) =>
    {
      'id': id,
      'status': status,
      'scheduledAt': scheduledAt,
      'reason': reason,
      'notes': notes,
      'cancelReason': null,
      'cancelledAt': null,
      'client': {'id': clientId, 'name': clientName, 'phone': '5512345678'},
      'vehicle': {'id': vehicleId, 'brand': 'Honda', 'model': 'Civic', 'year': 2020, 'licensePlate': plate},
      'order': order,
    };

Map<String, dynamic> orderSummaryJson(
  int id, {
  String status = 'RECIBIDO',
  String problem = 'Ruido al frenar',
  int mileage = 51200,
  String clientName = 'Ana Morales',
  String plate = 'MNO-345-E',
  Map<String, dynamic>? mechanic,
}) =>
    {
      'id': id,
      'folio': 'OS-${id.toString().padLeft(6, '0')}',
      'status': status,
      'reportedProblem': problem,
      'entryMileage': mileage,
      'createdAt': '2030-10-10T14:00:00.000Z',
      'client': {'id': 1, 'name': clientName},
      'vehicle': {'id': 1, 'brand': 'Honda', 'model': 'Civic', 'licensePlate': plate},
      'mechanic': mechanic,
    };

Map<String, dynamic> orderDetailJson(
  int id, {
  String status = 'RECIBIDO',
  Map<String, dynamic>? mechanic,
  List<String> allowedTransitions = const [],
  List<Map<String, dynamic>> services = const [],
  List<Map<String, dynamic>> labor = const [],
  String? diagnosis,
  String? observations,
  String? recommendations,
  Map<String, dynamic>? appointment,
}) {
  double sum(List<Map<String, dynamic>> lines) =>
      lines.fold(0.0, (total, line) => total + double.parse('${line['amount']}'));
  final servicesTotal = sum(services);
  final laborTotal = sum(labor);
  return {
    ...orderSummaryJson(id, status: status, mechanic: mechanic),
    'diagnosis': diagnosis,
    'observations': observations,
    'recommendations': recommendations,
    'mileageCorrection': false,
    'mileageCorrectionReason': null,
    'appointment': appointment,
    'services': services,
    'labor': labor,
    'totals': {
      'services': servicesTotal.toStringAsFixed(2),
      'labor': laborTotal.toStringAsFixed(2),
      'total': (servicesTotal + laborTotal).toStringAsFixed(2),
    },
    'allowedTransitions': allowedTransitions,
    'statusHistory': [
      {
        'fromStatus': null,
        'toStatus': 'RECIBIDO',
        'changedBy': {'id': 2, 'name': 'Recepción del taller'},
        'changedAt': '2030-10-10T14:00:00.000Z',
      },
    ],
    'deliveredAt': null,
  };
}

Map<String, dynamic> mechanicJson(int id, String name) => {'id': id, 'name': name, 'username': 'mecanico$id'};

Map<String, dynamic> lineJson(int id, String description, String amount) =>
    {'id': id, 'description': description, 'amount': amount};

/// Atiende `GET /orders` (filtra por `status`), `GET /orders/:id` y `GET /mechanics`, y delega citas,
/// clientes y vehículos en [appointmentsHandler]. [details] permite fijar el detalle de cada orden.
FakeHandler ordersHandler({
  List<Map<String, dynamic>>? items,
  Map<int, Map<String, dynamic>>? details,
  List<Map<String, dynamic>>? mechanics,
  FakeHandler? extra,
}) {
  final list = items ??
      [
        orderSummaryJson(1, status: 'RECIBIDO'),
        orderSummaryJson(2, status: 'DIAGNOSTICO', problem: 'Falla el motor', clientName: 'Luis Pérez', plate: 'DEF-456-B', mechanic: {'id': 3, 'name': 'Mario Mecánico'}),
      ];
  final mechanicList = mechanics ?? [mechanicJson(3, 'Mario Mecánico'), mechanicJson(4, 'Marta Mecánica')];
  final base = appointmentsHandler();
  return (r) {
    final custom = extra?.call(r);
    if (custom != null) return custom;
    if (r.method == 'GET' && r.path == '/orders') {
      final status = r.query['status'];
      final filtered = list.where((o) => status == null || o['status'] == status).toList();
      return ok(filtered, meta: {'page': 1, 'pageSize': 20, 'total': filtered.length});
    }
    final match = RegExp(r'^/orders/(\d+)$').firstMatch(r.path);
    if (r.method == 'GET' && match != null) {
      final id = int.parse(match.group(1)!);
      final detail = details?[id];
      if (detail != null) return ok(detail);
      final summary = list.firstWhere((o) => o['id'] == id, orElse: () => orderSummaryJson(id));
      return ok(orderDetailJson(id, status: '${summary['status']}', mechanic: summary['mechanic'] as Map<String, dynamic>?));
    }
    if (r.method == 'GET' && r.path == '/mechanics') return ok(mechanicList);
    return base(r);
  };
}

/// Atiende `GET /appointments` (filtra por `status`) y delega clientes y vehículos en [vehiclesHandler].
FakeHandler appointmentsHandler({List<Map<String, dynamic>>? items, FakeHandler? extra}) {
  final list = items ??
      [
        appointmentJson(1),
        appointmentJson(2, status: 'CONFIRMADA', clientName: 'Luis Pérez', clientId: 2, plate: 'DEF-456-B', reason: 'Revisión de frenos'),
      ];
  // Los vehículos se filtran por `clientId`, como hace la API real.
  final vehiclesByClient = vehiclesHandler(extra: (r) {
    if (r.method == 'GET' && r.path == '/vehicles' && r.query['clientId'] != null) {
      final all = [
        vehicleJson(1),
        vehicleJson(2, brand: 'Toyota', model: 'Hilux', plate: 'DEF-456-B', ownerId: 2, ownerName: 'Luis Pérez'),
      ].where((v) => '${(v['client'] as Map)['id']}' == r.query['clientId']).toList();
      return ok(all, meta: {'page': 1, 'pageSize': 20, 'total': all.length});
    }
    return null;
  });
  return (r) {
    final custom = extra?.call(r);
    if (custom != null) return custom;
    if (r.method == 'GET' && r.path == '/appointments') {
      final status = r.query['status'];
      final filtered = list.where((a) => status == null || a['status'] == status).toList();
      return ok(filtered, meta: {'page': 1, 'pageSize': 20, 'total': filtered.length});
    }
    return vehiclesByClient(r);
  };
}
