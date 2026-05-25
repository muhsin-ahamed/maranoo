import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// Represents a single shopping or task item.
@HiveType(typeId: 0)
class ShoppingItem {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final bool isPurchased;

  ShoppingItem({
    required this.id,
    required this.name,
    this.isPurchased = false,
  });

  /// Creates a copy of this [ShoppingItem] with modified fields.
  ShoppingItem copyWith({
    String? id,
    String? name,
    bool? isPurchased,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      isPurchased: isPurchased ?? this.isPurchased,
    );
  }
}

/// Custom [TypeAdapter] for serializing [ShoppingItem] objects.
class ShoppingItemAdapter extends TypeAdapter<ShoppingItem> {
  @override
  final int typeId = 0;

  @override
  ShoppingItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ShoppingItem(
      id: fields[0] as String,
      name: fields[1] as String,
      isPurchased: fields[2] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ShoppingItem obj) {
    writer
      ..writeByte(3) // Number of fields serialized
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.isPurchased);
  }
}
