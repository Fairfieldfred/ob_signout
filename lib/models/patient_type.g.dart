// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patient_type.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PatientTypeAdapter extends TypeAdapter<PatientType> {
  @override
  final int typeId = 0;

  @override
  PatientType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PatientType.labor;
      case 1:
        return PatientType.postpartum;
      case 2:
        return PatientType.gynPostOp;
      case 3:
        return PatientType.consult;
      default:
        return PatientType.labor;
    }
  }

  @override
  void write(BinaryWriter writer, PatientType obj) {
    switch (obj) {
      case PatientType.labor:
        writer.writeByte(0);
        break;
      case PatientType.postpartum:
        writer.writeByte(1);
        break;
      case PatientType.gynPostOp:
        writer.writeByte(2);
        break;
      case PatientType.consult:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatientTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
