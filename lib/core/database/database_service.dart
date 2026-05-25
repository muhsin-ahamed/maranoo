import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../data/models/shopping_item.dart';
import '../../data/models/shopping_list.dart';

/// DatabaseService handles all native local database operations with Hive CE.
/// Exposes structured CRUD methods for ShoppingLists and sub-items.
class DatabaseService {
  static const String _boxName = 'shopping_lists_box';

  /// Initializes Hive, registers custom adapters, and opens the box.
  static Future<void> init() async {
    await Hive.initFlutter();

    // Register custom hand-coded adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ShoppingItemAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ShoppingListAdapter());
    }

    // Open the box for storing our shopping lists
    await Hive.openBox<ShoppingList>(_boxName);
  }

  /// Helper getter to access the opened lists box.
  static Box<ShoppingList> get _box => Hive.box<ShoppingList>(_boxName);

  /// Exposes a ValueListenable of the shopping lists box.
  /// Rebuilds parts of the UI dynamically on database modification.
  static ValueListenable<Box<ShoppingList>> get listenable => _box.listenable();

  /// Retrieves all lists sorted by creation date (newest first).
  static List<ShoppingList> get allLists {
    final lists = _box.values.toList();
    lists.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return lists;
  }

  // --- List-Level CRUD Operations ---

  /// Adds a brand new [ShoppingList] to the local database.
  static Future<void> addList(ShoppingList list) async {
    await _box.put(list.id, list);
  }

  /// Updates an entire [ShoppingList] configuration.
  static Future<void> updateList(ShoppingList list) async {
    await _box.put(list.id, list);
  }

  /// Deletes an entire [ShoppingList] by its id.
  static Future<void> deleteList(String listId) async {
    final list = _box.get(listId);
    if (list != null && list.billImagePath != null) {
      // Clean up bill image file from storage to save device space
      try {
        final file = File(list.billImagePath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
    await _box.delete(listId);
  }

  /// Updates a list's title.
  static Future<void> renameList(String listId, String newTitle) async {
    final list = _box.get(listId);
    if (list != null) {
      await updateList(list.copyWith(title: newTitle));
    }
  }

  // --- Sub-Item CRUD Operations ---

  /// Appends a new [ShoppingItem] to an existing [ShoppingList].
  static Future<void> addItemToList(String listId, ShoppingItem item) async {
    final list = _box.get(listId);
    if (list != null) {
      final updatedItems = List<ShoppingItem>.from(list.items)..add(item);
      await updateList(list.copyWith(items: updatedItems));
    }
  }

  /// Updates an existing [ShoppingItem]'s properties within a specific [ShoppingList].
  static Future<void> updateItemInList(String listId, ShoppingItem updatedItem) async {
    final list = _box.get(listId);
    if (list != null) {
      final updatedItems = list.items.map((item) {
        return item.id == updatedItem.id ? updatedItem : item;
      }).toList();
      await updateList(list.copyWith(items: updatedItems));
    }
  }

  /// Toggles the isPurchased state of a specific [ShoppingItem].
  static Future<void> toggleItemPurchased(String listId, String itemId) async {
    final list = _box.get(listId);
    if (list != null) {
      final updatedItems = list.items.map((item) {
        if (item.id == itemId) {
          return item.copyWith(isPurchased: !item.isPurchased);
        }
        return item;
      }).toList();
      await updateList(list.copyWith(items: updatedItems));
    }
  }

  /// Modifies the text name of a specific [ShoppingItem].
  static Future<void> updateItemName(String listId, String itemId, String newName) async {
    final list = _box.get(listId);
    if (list != null) {
      final updatedItems = list.items.map((item) {
        if (item.id == itemId) {
          return item.copyWith(name: newName);
        }
        return item;
      }).toList();
      await updateList(list.copyWith(items: updatedItems));
    }
  }

  /// Removes an individual [ShoppingItem] from a specific [ShoppingList].
  static Future<void> deleteItemFromList(String listId, String itemId) async {
    final list = _box.get(listId);
    if (list != null) {
      final updatedItems = list.items.where((item) => item.id != itemId).toList();
      await updateList(list.copyWith(items: updatedItems));
    }
  }
}
