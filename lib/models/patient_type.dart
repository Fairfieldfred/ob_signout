import 'package:hive/hive.dart';

part 'patient_type.g.dart';

@HiveType(typeId: 0)
enum PatientType {
  @HiveField(0)
  labor,

  @HiveField(1)
  postpartum,

  @HiveField(2)
  gynPostOp,

  @HiveField(3)
  consult,
}

extension PatientTypeExtension on PatientType {
  String get displayName {
    switch (this) {
      case PatientType.labor:
        return 'Labor';
      case PatientType.postpartum:
        return 'Postpartum';
      case PatientType.gynPostOp:
        return 'GYN Post-op';
      case PatientType.consult:
        return 'Consult';
    }
  }

  String get shortName {
    switch (this) {
      case PatientType.labor:
        return 'L';
      case PatientType.postpartum:
        return 'PP';
      case PatientType.gynPostOp:
        return 'GYN';
      case PatientType.consult:
        return 'CON';
    }
  }
}