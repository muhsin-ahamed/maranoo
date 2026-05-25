import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'shopping_item.dart';

/// Represents a list containing multiple shopping/task items.
@HiveType(typeId: 1)
class ShoppingList {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final List<ShoppingItem> items;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final String? billImagePath;

  ShoppingList({
    required this.id,
    required this.title,
    required this.items,
    required this.createdAt,
    this.billImagePath,
  });

  /// Creates a copy of this [ShoppingList] with modified fields.
  ShoppingList copyWith({
    String? id,
    String? title,
    List<ShoppingItem>? items,
    DateTime? createdAt,
    String? billImagePath,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      title: title ?? this.title,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      billImagePath: billImagePath ?? this.billImagePath,
    );
  }
}

/// Custom [TypeAdapter] for serializing [ShoppingList] objects.
/// Supports the nullable [billImagePath] field with complete backwards compatibility.
class ShoppingListAdapter extends TypeAdapter<ShoppingList> {
  @override
  final int typeId = 1;

  @override
  ShoppingList read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ShoppingList(
      id: fields[0] as String,
      title: fields[1] as String,
      items: List<ShoppingItem>.from(fields[2] as List),
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[3] as int),
      billImagePath: fields[4] as String?, // Reads null if not present in older records
    );
  }

  @override
  void write(BinaryWriter writer, ShoppingList obj) {
    writer
      ..writeByte(5) // Serializes all 5 fields
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.items)
      ..writeByte(3)
      ..write(obj.createdAt.millisecondsSinceEpoch)
      ..writeByte(4)
      ..write(obj.billImagePath);
  }
}
