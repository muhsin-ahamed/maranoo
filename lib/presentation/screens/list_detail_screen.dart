import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../data/models/shopping_item.dart';
import '../../data/models/shopping_list.dart';
import '../../core/database/database_service.dart';
import '../widgets/bill_preview_modal.dart';

/// The [ListDetailScreen] displays all current items in a specific [ShoppingList].
/// It supports extending the list with new items via a beautiful sticky input dock.
/// It also implements rich inline gestures, manual actions, instant Hive check status,
/// and a dual-button Bottom action bar for receipt upload & interactive fullscreen preview.
class ListDetailScreen extends StatefulWidget {
  final String listId;

  const ListDetailScreen({
    super.key,
    required this.listId,
  });

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  // Controller for adding new items to the list
  final TextEditingController _addItemController = TextEditingController();
  final FocusNode _addItemFocusNode = FocusNode();

  final ImagePicker _picker = ImagePicker();
  bool _isUploadingBill = false;

  @override
  void dispose() {
    _addItemController.dispose();
    _addItemFocusNode.dispose();
    super.dispose();
  }

  /// Appends a new item to the active shopping list in Hive.
  Future<void> _addNewItem() async {
    final text = _addItemController.text.trim();
    if (text.isEmpty) return;

    final newItem = ShoppingItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: text,
      isPurchased: false,
    );

    // Keep focus on the field for rapid multiple additions
    _addItemFocusNode.requestFocus();

    await DatabaseService.addItemToList(widget.listId, newItem);
    _addItemController.clear();
  }

  /// Triggers a modern alert dialog to edit an item.
  void _editItemDialog(ShoppingItem item) {
    final theme = Theme.of(context);
    final editController = TextEditingController(text: item.name);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.edit_note_rounded,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ),
          title: const Text('Edit Item'),
          content: TextField(
            controller: editController,
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter item name',
              prefixIcon: Icon(Icons.shopping_cart_rounded),
            ),
            onSubmitted: (value) async {
              final newName = value.trim();
              if (newName.isNotEmpty) {
                await DatabaseService.updateItemName(widget.listId, item.id, newName);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = editController.text.trim();
                if (newName.isNotEmpty) {
                  await DatabaseService.updateItemName(widget.listId, item.id, newName);
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// Triggers image selection from Gallery or Camera and copies it permanently.
  Future<void> _handleBillUpload(BuildContext context) async {
    final theme = Theme.of(context);

    // Show beautiful bottom sheet to pick Camera vs Gallery
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: theme.brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Bill Source',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(ImageSource.camera),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.photo_camera_rounded, size: 28, color: theme.colorScheme.primary),
                              const SizedBox(height: 8),
                              const Text('Camera', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.photo_library_rounded, size: 28, color: theme.colorScheme.primary),
                              const SizedBox(height: 8),
                              const Text('Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    setState(() {
      _isUploadingBill = true;
    });

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85, // Balance size and quality for premium storage
      );

      if (!mounted) return;

      if (pickedFile != null) {
        // Save the image permanently inside App Documents Directory to prevent OS cleanups
        final directory = await getApplicationDocumentsDirectory();
        final String fileExtension = p.extension(pickedFile.path).toLowerCase();
        final String newFileName = 'bill_${widget.listId}_${DateTime.now().millisecondsSinceEpoch}$fileExtension';

        final File permanentFile = File(p.join(directory.path, newFileName));
        await File(pickedFile.path).copy(permanentFile.path);

        // Update database with permanent path
        final list = Hive.box<ShoppingList>('shopping_lists_box').get(widget.listId);
        if (list != null) {
          // If a previous bill existed, delete the old file to clear space
          if (list.billImagePath != null) {
            try {
              final oldFile = File(list.billImagePath!);
              if (await oldFile.exists()) {
                await oldFile.delete();
              }
            } catch (_) {}
          }

          await DatabaseService.updateList(list.copyWith(billImagePath: permanentFile.path));

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Receipt uploaded and saved successfully!'),
                    ),
                  ],
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick or copy image: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingBill = false;
        });
      }
    }
  }

  /// Opens zoomable fullscreen dialog displaying the receipt.
  void _previewBill(BuildContext context, String path) {
    BillPreviewModal.show(
      context,
      imagePath: path,
      onDeleteConfirm: () async {
        // Clear value from Hive database and file system
        final list = Hive.box<ShoppingList>('shopping_lists_box').get(widget.listId);
        if (list != null) {
          if (list.billImagePath != null) {
            try {
              final oldFile = File(list.billImagePath!);
              if (await oldFile.exists()) {
                await oldFile.delete();
              }
            } catch (_) {}
          }
          await DatabaseService.updateList(list.copyWith(billImagePath: null));

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Receipt attachment deleted.'),
                backgroundColor: Theme.of(context).colorScheme.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: ValueListenableBuilder<Box<ShoppingList>>(
          valueListenable: DatabaseService.listenable,
          builder: (context, box, _) {
            final list = box.get(widget.listId);
            return Text(list?.title ?? 'List Details');
          },
        ),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<Box<ShoppingList>>(
          valueListenable: DatabaseService.listenable,
          builder: (context, box, _) {
            final list = box.get(widget.listId);
            if (list == null) {
              return const Center(child: Text('List not found'));
            }

            final items = list.items;
            final completedCount = items.where((i) => i.isPurchased).length;
            final totalCount = items.length;
            final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
            final hasBill = list.billImagePath != null;

            return Column(
              children: [
                // Interactive Progress Dashboard Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.surface
                          : theme.colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.15),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progress Status',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${(progress * 100).toInt()}% Done',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$completedCount of $totalCount items marked as purchased',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Items List or Gorgeous Empty State
                Expanded(
                  child: items.isEmpty
                      ? _buildEmptyState(context)
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                          itemCount: items.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _buildItemRow(context, item);
                          },
                        ),
                ),

                // Extend List Feature: Sticky Bottom Input Dock
                _buildAddDock(context),

                // persistent receipt action row
                _buildBillActionBar(context, list, hasBill),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Persistent bottom row containing 'Upload Bill' and 'Preview Bill' side-by-side.
  Widget _buildBillActionBar(BuildContext context, ShoppingList list, bool hasBill) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171717) : const Color(0xFFF9FBFC),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // 'Upload Bill' Button
          Expanded(
            child: _isUploadingBill
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: () => _handleBillUpload(context),
                    icon: Icon(Icons.receipt_long_rounded, color: theme.colorScheme.primary, size: 20),
                    label: Text(
                      hasBill ? 'Change Bill' : 'Upload Bill',
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 16),

          // 'Preview Bill' Button
          Expanded(
            child: InkWell(
              onTap: hasBill
                  ? () => _previewBill(context, list.billImagePath!)
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: theme.colorScheme.onPrimary, size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text('No receipt uploaded yet! Please tap "Upload Bill" first.'),
                              ),
                            ],
                          ),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: hasBill
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasBill
                        ? Colors.transparent
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.visibility_rounded,
                      color: hasBill ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Preview Bill',
                      style: TextStyle(
                        color: hasBill ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a specific [ShoppingItem] card with swipe-to-edit and swipe-to-delete actions.
  Widget _buildItemRow(BuildContext context, ShoppingItem item) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right: Inline Edit dialog
          _editItemDialog(item);
          return false; // Retain widget in tree
        } else if (direction == DismissDirection.endToStart) {
          // Swipe Left: Delete confirmation dialog
          return await _showDeleteConfirmation(context, item);
        }
        return false;
      },
      // Swipe Right background (Edit)
      background: _buildSwipeBackground(
        color: theme.colorScheme.primary,
        icon: Icons.edit_rounded,
        alignment: Alignment.centerLeft,
      ),
      // Swipe Left background (Delete)
      secondaryBackground: _buildSwipeBackground(
        color: theme.colorScheme.error,
        icon: Icons.delete_outline_rounded,
        alignment: Alignment.centerRight,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isPurchased
                ? theme.colorScheme.outlineVariant.withValues(alpha: 0.15)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        child: Opacity(
          opacity: item.isPurchased ? 0.5 : 1.0,
          child: Row(
            children: [
              // Checkbox Toggle
              Transform.scale(
                scale: 1.1,
                child: Checkbox(
                  value: item.isPurchased,
                  activeColor: theme.colorScheme.primary,
                  checkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  side: BorderSide(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  onChanged: (value) async {
                    await DatabaseService.toggleItemPurchased(widget.listId, item.id);
                  },
                ),
              ),
              const SizedBox(width: 4),

              // Item Content Text
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    await DatabaseService.toggleItemPurchased(widget.listId, item.id);
                  },
                  child: Text(
                    item.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: item.isPurchased ? FontWeight.w500 : FontWeight.w600,
                      decoration: item.isPurchased ? TextDecoration.lineThrough : null,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),

              // Edit Action Icon
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
                tooltip: 'Rename Item',
                onPressed: () => _editItemDialog(item),
              ),

              // Delete Action Icon
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.error.withValues(alpha: 0.75),
                ),
                tooltip: 'Delete Item',
                onPressed: () async {
                  final confirmed = await _showDeleteConfirmation(context, item);
                  if (confirmed) {
                    await DatabaseService.deleteItemFromList(widget.listId, item.id);
                    if (context.mounted) {
                      _showDeletionSnackBar(context, item.name);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a gorgeous aesthetic background for gesture swipes.
  Widget _buildSwipeBackground({
    required Color color,
    required IconData icon,
    required Alignment alignment,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Icon(
        icon,
        color: color,
        size: 22,
      ),
    );
  }

  /// Sticky Bottom Dock to EXTEND the active shopping list with new items easily.
  Widget _buildAddDock(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171717) : const Color(0xFFF9FBFC),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _addItemController,
              focusNode: _addItemFocusNode,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Add new item to list...',
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                ),
              ),
              onSubmitted: (_) => _addNewItem(),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _addNewItem,
            child: Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Modern confirmation Dialog popup before deleting an item.
  Future<bool> _showDeleteConfirmation(BuildContext context, ShoppingItem item) async {
    final theme = Theme.of(context);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delete_sweep_rounded,
              color: theme.colorScheme.error,
              size: 28,
            ),
          ),
          title: const Text('Delete Item?'),
          content: Text(
            'Are you sure you want to permanently remove "${item.name}"? This action cannot be undone.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (result == true) {
      if (widget.listId.isNotEmpty) {
        await DatabaseService.deleteItemFromList(widget.listId, item.id);
        if (context.mounted) {
          _showDeletionSnackBar(context, item.name);
        }
      }
      return true;
    }
    return false;
  }

  /// Floating feedback SnackBar when an item is deleted.
  void _showDeletionSnackBar(BuildContext context, String itemName) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('"$itemName" deleted.'),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: theme.colorScheme.error.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  /// Builds a gorgeous aesthetic empty state for an empty shopping list.
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_shopping_cart_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No items added yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This shopping list is currently empty. Extend it by typing an item below and clicking "+"!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
