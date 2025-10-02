import 'package:hive/hive.dart';
import 'patient_type.dart';

part 'patient.g.dart';

@HiveType(typeId: 1)
class Patient extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String initials;

  @HiveField(2)
  String roomNumber;

  @HiveField(3)
  PatientType type;

  @HiveField(4)
  Map<String, dynamic> parameters;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  @HiveField(7)
  int? age;

  @HiveField(8)
  int? gravida;

  @HiveField(9)
  int? para;

  @HiveField(10)
  String? gestationalAge;

  Patient({
    required this.id,
    required this.initials,
    required this.roomNumber,
    required this.type,
    this.age,
    this.gravida,
    this.para,
    this.gestationalAge,
    Map<String, dynamic>? parameters,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : parameters = parameters ?? {},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'initials': initials,
      'roomNumber': roomNumber,
      'type': type.name,
      'age': age,
      'gravida': gravida,
      'para': para,
      'gestationalAge': gestationalAge,
      'parameters': parameters,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] as String,
      initials: json['initials'] as String,
      roomNumber: json['roomNumber'] as String,
      type: PatientType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PatientType.consult,
      ),
      age: json['age'] as int?,
      gravida: json['gravida'] as int?,
      para: json['para'] as int?,
      gestationalAge: json['gestationalAge'] as String?,
      parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Patient copyWith({
    String? id,
    String? initials,
    String? roomNumber,
    PatientType? type,
    int? age,
    int? gravida,
    int? para,
    String? gestationalAge,
    Map<String, dynamic>? parameters,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Patient(
      id: id ?? this.id,
      initials: initials ?? this.initials,
      roomNumber: roomNumber ?? this.roomNumber,
      type: type ?? this.type,
      age: age ?? this.age,
      gravida: gravida ?? this.gravida,
      para: para ?? this.para,
      gestationalAge: gestationalAge ?? this.gestationalAge,
      parameters: parameters ?? Map<String, dynamic>.from(this.parameters),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  void updateParameter(String key, dynamic value) {
    parameters[key] = value;
    updatedAt = DateTime.now();
  }

  void removeParameter(String key) {
    parameters.remove(key);
    updatedAt = DateTime.now();
  }

  String get gravidaParaString {
    if (gravida == null && para == null) return '';
    final g = gravida?.toString() ?? '?';
    final p = para?.toString() ?? '?';
    return 'G$g P$p';
  }

  String get ageString {
    return age != null ? '${age}y' : '';
  }

  String get gestationalAgeString {
    return gestationalAge?.isNotEmpty == true ? gestationalAge! : '';
  }

  @override
  String toString() {
    return 'Patient{id: $id, initials: $initials, roomNumber: $roomNumber, type: ${type.displayName}, age: $age, G$gravida P$para, GA: $gestationalAge}';
  }
}