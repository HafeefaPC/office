class Office {
  final int id;
  final String name;
  final String? officeEmail;
  final double area;
  final double lat;
  final double lng;
  final List<Employee> employees;
  final DateTime timestamp;

  Office({
    required this.id,
    required this.name,
    this.officeEmail,
    required this.area,
    required this.lat,
    required this.lng,
    required this.employees,
    required this.timestamp,
  });

  factory Office.fromJson(Map<String, dynamic> json) {
    return Office(
      id: json['id'],
      name: json['name'],
      officeEmail: json['office_email'],
      area: (json['area'] as num).toDouble(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      employees: (json['employees'] as List<dynamic>?)
          ?.map((e) => Employee.fromJson(e))
          .toList() ?? [],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'office_email': officeEmail,
      'area': area,
      'lat': lat,
      'lng': lng,
      'employees': employees.map((e) => e.toJson()).toList(),
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class Employee {
  final String name;
  final String email;

  Employee({
    required this.name,
    required this.email,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      name: json['name'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
    };
  }
}