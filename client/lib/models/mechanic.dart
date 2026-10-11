/// Mecánico activo que se puede asignar a una orden (solo id, nombre y usuario).
class Mechanic {
  const Mechanic({required this.id, required this.name, required this.username});

  factory Mechanic.fromJson(Map<String, dynamic> json) => Mechanic(
        id: (json['id'] as num).toInt(),
        name: '${json['name']}',
        username: '${json['username']}',
      );

  final int id;
  final String name;
  final String username;
}
