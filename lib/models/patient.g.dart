// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patient.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PatientAdapter extends TypeAdapter<Patient> {
  @override
  final int typeId = 1;

  @override
  Patient read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Patient(
      id: fields[0] as String,
      initials: fields[1] as String,
      roomNumber: fields[2] as String,
      type: fields[3] as PatientType,
      age: fields[7] as int?,
      gravida: fields[8] as int?,
      para: fields[9] as int?,
      gestationalAgeWeeks: fields[10] as int?,
      gestationalAgeDays: fields[11] as int?,
      gestationalAgeSetDate: fields[12] as DateTime?,
      isRounded: fields[13] as bool,
      isDischarged: fields[14] as bool,
      laborStatuses: (fields[15] as List?)?.cast<String>(),
      parameters: (fields[4] as Map?)?.cast<String, dynamic>(),
      createdAt: fields[5] as DateTime?,
      updatedAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Patient obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.initials)
      ..writeByte(2)
      ..write(obj.roomNumber)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.parameters)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.age)
      ..writeByte(8)
      ..write(obj.gravida)
      ..writeByte(9)
      ..write(obj.para)
      ..writeByte(10)
      ..write(obj.gestationalAgeWeeks)
      ..writeByte(11)
      ..write(obj.gestationalAgeDays)
      ..writeByte(12)
      ..write(obj.gestationalAgeSetDate)
      ..writeByte(13)
      ..write(obj.isRounded)
      ..writeByte(14)
      ..write(obj.isDischarged)
      ..writeByte(15)
      ..write(obj.laborStatuses);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatientAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
