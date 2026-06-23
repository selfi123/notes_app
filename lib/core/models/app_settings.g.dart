// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 2;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      isPremium: fields[0] as bool,
      razorpaySubscriptionId: fields[1] as String?,
      premiumExpiresAt: fields[2] as DateTime?,
      cloudSyncEnabled: fields[3] as bool,
      lastSyncAt: fields[4] as DateTime?,
      useFolderLayout: fields[5] == null ? false : fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.isPremium)
      ..writeByte(1)
      ..write(obj.razorpaySubscriptionId)
      ..writeByte(2)
      ..write(obj.premiumExpiresAt)
      ..writeByte(3)
      ..write(obj.cloudSyncEnabled)
      ..writeByte(4)
      ..write(obj.lastSyncAt)
      ..writeByte(5)
      ..write(obj.useFolderLayout);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
