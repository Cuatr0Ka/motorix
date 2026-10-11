/// Propietario de un vehículo (datos mínimos que devuelve la API).
class VehicleOwner {
  const VehicleOwner({required this.id, required this.name, this.phone});

  factory VehicleOwner.fromJson(Map<String, dynamic> json) => VehicleOwner(
        id: (json['id'] as num).toInt(),
        name: '${json['name']}',
        phone: json['phone'] as String?,
      );

  final int id;
  final String name;
  final String? phone;
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.licensePlate,
    required this.owner,
    this.vin,
    this.color,
    this.currentMileage,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: (json['id'] as num).toInt(),
        brand: '${json['brand']}',
        model: '${json['model']}',
        year: (json['year'] as num).toInt(),
        licensePlate: '${json['licensePlate']}',
        vin: json['vin'] as String?,
        color: json['color'] as String?,
        currentMileage: (json['currentMileage'] as num?)?.toInt(),
        owner: VehicleOwner.fromJson(Map<String, dynamic>.from(json['client'] as Map)),
      );

  final int id;
  final String brand;
  final String model;
  final int year;
  final String licensePlate;
  final String? vin;
  final String? color;
  final int? currentMileage;
  final VehicleOwner owner;
}

/// Datos capturados en el formulario de vehículo.
class VehicleInput {
  const VehicleInput({
    required this.clientId,
    required this.brand,
    required this.model,
    required this.year,
    required this.licensePlate,
    this.vin,
    this.color,
    this.currentMileage,
  });

  final int clientId;
  final String brand;
  final String model;
  final int year;
  final String licensePlate;
  final String? vin;
  final String? color;
  final int? currentMileage;

  Map<String, dynamic> toJson() => {
        'clientId': clientId,
        'brand': brand,
        'model': model,
        'year': year,
        'licensePlate': licensePlate,
        'vin': vin,
        'color': color,
        'currentMileage': currentMileage,
      };
}
