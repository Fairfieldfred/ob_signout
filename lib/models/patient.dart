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
  int? gestationalAgeWeeks;

  @HiveField(11)
  int? gestationalAgeDays;

  @HiveField(12)
  DateTime? gestationalAgeSetDate;

  @HiveField(13)
  bool isRounded;

  @HiveField(14)
  bool isDischarged;

  @HiveField(15)
  List<String>? laborStatuses; // For Labor patients: ["Ante", "Labor", "Induction", "TOLAC"]

  Patient({
    required this.id,
    required this.initials,
    required this.roomNumber,
    required this.type,
    this.age,
    this.gravida,
    this.para,
    this.gestationalAgeWeeks,
    this.gestationalAgeDays,
    this.gestationalAgeSetDate,
    this.isRounded = false,
    this.isDischarged = false,
    List<String>? laborStatuses,
    Map<String, dynamic>? parameters,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : laborStatuses = laborStatuses ?? [],
        parameters = parameters ?? {},
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
      'gestationalAgeWeeks': gestationalAgeWeeks,
      'gestationalAgeDays': gestationalAgeDays,
      'gestationalAgeSetDate': gestationalAgeSetDate?.toIso8601String(),
      'isRounded': isRounded,
      'isDischarged': isDischarged,
      'laborStatuses': laborStatuses,
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
      gestationalAgeWeeks: json['gestationalAgeWeeks'] as int?,
      gestationalAgeDays: json['gestationalAgeDays'] as int?,
      gestationalAgeSetDate: json['gestationalAgeSetDate'] != null
          ? DateTime.parse(json['gestationalAgeSetDate'] as String)
          : null,
      isRounded: json['isRounded'] as bool? ?? false,
      isDischarged: json['isDischarged'] as bool? ?? false,
      laborStatuses: json['laborStatuses'] != null
          ? List<String>.from(json['laborStatuses'] as List)
          : [],
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
    int? gestationalAgeWeeks,
    int? gestationalAgeDays,
    DateTime? gestationalAgeSetDate,
    bool? isRounded,
    bool? isDischarged,
    List<String>? laborStatuses,
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
      gestationalAgeWeeks: gestationalAgeWeeks ?? this.gestationalAgeWeeks,
      gestationalAgeDays: gestationalAgeDays ?? this.gestationalAgeDays,
      gestationalAgeSetDate: gestationalAgeSetDate ?? this.gestationalAgeSetDate,
      isRounded: isRounded ?? this.isRounded,
      isDischarged: isDischarged ?? this.isDischarged,
      laborStatuses: laborStatuses ?? List<String>.from(this.laborStatuses ?? []),
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

  /// Calculates current gestational age with auto-increment for Labor patients.
  /// Returns (weeks, days) tuple. Returns null if GA not set.
  (int, int)? get currentGestationalAge {
    if (gestationalAgeWeeks == null || gestationalAgeDays == null || gestationalAgeSetDate == null) {
      return null;
    }

    // Only increment for Labor patients
    if (type != PatientType.labor) {
      return (gestationalAgeWeeks!, gestationalAgeDays!);
    }

    // Calculate days elapsed since GA was set
    final now = DateTime.now();
    final setDate = DateTime(
      gestationalAgeSetDate!.year,
      gestationalAgeSetDate!.month,
      gestationalAgeSetDate!.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    final daysElapsed = today.difference(setDate).inDays;

    // Add elapsed days to original GA
    int totalDays = gestationalAgeDays! + daysElapsed;
    int totalWeeks = gestationalAgeWeeks!;

    // Convert excess days to weeks
    while (totalDays >= 7) {
      totalWeeks++;
      totalDays -= 7;
    }

    return (totalWeeks, totalDays);
  }

  String get gestationalAgeString {
    final ga = currentGestationalAge;
    if (ga == null) return '';

    final (weeks, days) = ga;
    return '${weeks}wk ${days}d';
  }

  /// Combined patient info string for card display: {}y G{}P{} @ {}wk {}d
  String get combinedInfoString {
    final parts = <String>[];

    if (age != null) {
      parts.add('${age}y');
    }

    if (gravida != null && para != null) {
      parts.add('G$gravida P$para');
    }

    final ga = currentGestationalAge;
    if (ga != null) {
      final (weeks, days) = ga;
      parts.add('@ ${weeks}wk ${days}d');
    }

    return parts.join(' ');
  }

  @override
  String toString() {
    return 'Patient{id: $id, initials: $initials, roomNumber: $roomNumber, type: ${type.displayName}, age: $age, G$gravida P$para, GA: $gestationalAgeString}';
  }
}