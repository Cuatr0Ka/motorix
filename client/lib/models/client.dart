/// Resumen de un vehículo dentro del detalle de un cliente.
class VehicleSummary {
  const VehicleSummary({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.licensePlate,
    this.currentMileage,
  });

  factory VehicleSummary.fromJson(Map<String, dynamic> json) => VehicleSummary(
        id: (json['id'] as num).toInt(),
        brand: '${json['brand']}',
        model: '${json['model']}',
        year: (json['year'] as num).toInt(),
        licensePlate: '${json['licensePlate']}',
        currentMileage: (json['currentMileage'] as num?)?.toInt(),
      );

  final int id;
  final String brand;
  final String model;
  final int year;
  final String licensePlate;
  final int? currentMileage;
}

class Client {
  const Client({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.vehicleCount = 0,
    this.vehicles = const [],
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    final vehicles = (json['vehicles'] as List?)
            ?.map((v) => VehicleSummary.fromJson(Map<String, dynamic>.from(v as Map)))
            .toList() ??
        const <VehicleSummary>[];
    return Client(
      id: (json['id'] as num).toInt(),
      name: '${json['name']}',
      phone: '${json['phone']}',
      email: json['email'] as String?,
      address: json['address'] as String?,
      vehicleCount: (json['vehicleCount'] as num?)?.toInt() ?? vehicles.length,
      vehicles: vehicles,
    );
  }

  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final int vehicleCount;
  final List<VehicleSummary> vehicles;
}

/// Datos capturados en el formulario de cliente.
class ClientInput {
  const ClientInput({required this.name, required this.phone, this.email, this.address});

  final String name;
  final String phone;
  final String? email;
  final String? address;

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
      };
}
