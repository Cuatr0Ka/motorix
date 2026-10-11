import 'package:flutter/foundation.dart';

import '../models/maintenance.dart';
import '../models/order_work.dart';
import '../models/service_order.dart';
import '../services/api_client.dart';
import '../services/maintenance_service.dart';
import '../services/orders_service.dart';
import '../utils/status_labels.dart';

/// Estado del detalle de una orden: carga, errores y acciones (asignar mecánico, registrar el trabajo,
/// cambiar el estado). Cada acción devuelve el mensaje de error en español, o null si salió bien; la
/// orden se actualiza con la respuesta del servidor, que es la fuente de verdad.
class OrderDetailProvider extends ChangeNotifier {
  OrderDetailProvider(this.service, this.orderId, {required this.maintenanceService});

  final OrdersService service;
  final MaintenanceService maintenanceService;
  final int orderId;

  ServiceOrder? _order;
  String? _error;
  bool _loading = false;
  bool _busy = false;

  ServiceOrder? get order => _order;
  String? get error => _error;
  bool get loading => _loading;

  /// Hay una acción en curso (se deshabilitan los botones para evitar envíos dobles).
  bool get busy => _busy;

  /// Carga (o recarga) el detalle desde el servidor.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _order = await service.get(orderId);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
    }
    _loading = false;
    notifyListeners();
  }

  /// Ejecuta una acción que devuelve la orden actualizada. Si el estado cambió mientras tanto
  /// (`STATE_CONFLICT`), recarga la orden para mostrar el estado vigente.
  Future<String?> run(Future<ServiceOrder> Function() action) async {
    if (_busy) return 'Hay otra acción en curso. Espera un momento.';
    _busy = true;
    notifyListeners();
    String? failure;
    try {
      _order = await action();
    } on ApiException catch (e) {
      failure = e.message;
      if (e.code == 'STATE_CONFLICT') {
        try {
          _order = await service.get(orderId);
        } on ApiException {
          // Se conserva la orden anterior; el mensaje del conflicto ya explica lo ocurrido.
        }
      }
    } catch (_) {
      failure = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
    }
    _busy = false;
    notifyListeners();
    return failure;
  }

  /// Asigna, reasigna (o quita con `null`) el mecánico de la orden.
  Future<String?> assignMechanic(int? mechanicId) => run(() => service.assignMechanic(orderId, mechanicId));

  /// Cambia el estado de la orden. Ante un conflicto (otra persona la cambió antes) la orden se recarga
  /// y el mensaje del servidor indica el estado vigente.
  Future<String?> changeStatus(OrderStatus status) => run(() => service.changeStatus(orderId, status));

  /// Registra o edita un campo del trabajo (`diagnosis`, `observations` o `recommendations`).
  Future<String?> saveWorkField(String field, String? value) => run(() => service.updateWork(orderId, {field: value}));

  /// Registra el kilometraje del servicio de una orden Terminada.
  Future<String?> setServiceMileage(int mileage) => run(() => service.setServiceMileage(orderId, mileage));

  /// Programa el próximo mantenimiento y recarga la orden para mostrarlo.
  Future<String?> scheduleMaintenance(MaintenanceInput input) => run(() async {
        await maintenanceService.schedule(orderId, input);
        return service.get(orderId);
      });

  Future<String?> updateMaintenance(int id, MaintenanceInput input) => run(() async {
        await maintenanceService.update(id, input);
        return service.get(orderId);
      });

  Future<String?> attendMaintenance(int id) => run(() async {
        await maintenanceService.attend(id);
        return service.get(orderId);
      });

  /// Agrega, corrige o quita refacciones de la orden y recarga el detalle (el servidor actualiza el stock).
  Future<String?> addPart(int partId, int quantity) => run(() async {
        await service.addPart(orderId, partId, quantity);
        return service.get(orderId);
      });

  Future<String?> updatePart(int lineId, int quantity) => run(() async {
        await service.updatePart(orderId, lineId, quantity);
        return service.get(orderId);
      });

  Future<String?> removePart(int lineId) => run(() async {
        await service.removePart(orderId, lineId);
        return service.get(orderId);
      });

  Future<String?> addLine(OrderLineKind kind, OrderLineInput input) => _changeLines(() => service.addLine(orderId, kind, input));

  Future<String?> updateLine(OrderLineKind kind, int lineId, OrderLineInput input) =>
      _changeLines(() => service.updateLine(orderId, kind, lineId, input));

  Future<String?> removeLine(OrderLineKind kind, int lineId) => _changeLines(() => service.removeLine(orderId, kind, lineId));

  /// Ejecuta un cambio de líneas y recarga la orden: el servidor recalcula los totales.
  Future<String?> _changeLines(Future<Object> Function() change) => run(() async {
        await change();
        return service.get(orderId);
      });
}
