enum VehicleStatus { active, inactive, maintenance }

class DriverVehicle {
  const DriverVehicle({
    required this.vehicleId,
    required this.make,
    required this.model,
    required this.year,
    required this.licensePlate,
    required this.color,
    required this.seats,
    required this.status,
  });

  final String vehicleId;
  final String make;
  final String model;
  final int year;
  final String licensePlate;
  final String color;
  final int seats;
  final VehicleStatus status;

  String get title => '$year $make $model';
}

abstract interface class VehicleRepository {
  List<DriverVehicle> get all;

  DriverVehicle? get active;

  Future<List<DriverVehicle>> load();

  Future<void> upsert(DriverVehicle vehicle);
}

class InMemoryVehicleRepository implements VehicleRepository {
  InMemoryVehicleRepository({List<DriverVehicle>? seed})
    : _vehicles = List<DriverVehicle>.from(seed ?? const []);

  final List<DriverVehicle> _vehicles;

  @override
  List<DriverVehicle> get all => List.unmodifiable(_vehicles);

  @override
  DriverVehicle? get active {
    for (final vehicle in _vehicles) {
      if (vehicle.status == VehicleStatus.active) {
        return vehicle;
      }
    }
    return null;
  }

  @override
  Future<List<DriverVehicle>> load() async {
    if (_vehicles.isEmpty) {
      _vehicles.add(
        const DriverVehicle(
          vehicleId: 'V-418',
          make: 'Mercedes-Benz',
          model: 'E 220',
          year: 2022,
          licensePlate: 'MVR 418',
          color: 'Black',
          seats: 4,
          status: VehicleStatus.active,
        ),
      );
    }
    return all;
  }

  @override
  Future<void> upsert(DriverVehicle vehicle) async {
    final index = _vehicles.indexWhere(
      (item) => item.vehicleId == vehicle.vehicleId,
    );
    if (index >= 0) {
      _vehicles[index] = vehicle;
    } else {
      _vehicles.add(vehicle);
    }
  }
}
