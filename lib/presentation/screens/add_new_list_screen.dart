import 'package:flutter/material.dart';
import '../../data/models/shopping_item.dart';
import '../../data/models/shopping_list.dart';
import '../../core/database/database_service.dart';

/// AddNewListPage offers an updated modern flow to create a brand new shopping list.
/// It features a prominent title input at the top, followed directly by an inline
/// field to rapidly populate the list with items in real-time before saving.
class AddNewListPage extends StatefulWidget {
  const AddNewListPage({super.key});

  @override
  State<AddNewListPage> createState() => _AddNewListPageState();
}

class _AddNewListPageState extends State<AddNewListPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _itemController = TextEditingController();

  final _titleFocusNode = FocusNode();
  final _itemFocusNode = FocusNode();

  final List<ShoppingItem> _items = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus the list title on entrance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _itemController.dispose();
    _titleFocusNode.dispose();
    _itemFocusNode.dispose();
    super.dispose();
  }

  /// Adds a new item to the temporary list in-memory.
  void _addItem() {
    final text = _itemController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _items.add(
        ShoppingItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: text,
          isPurchased: false,
        ),
      );
      _itemController.clear();
    });

    // Auto-focus the item input field so they can add multiple items rapidly
    _itemFocusNode.requestFocus();
  }

  /// Deletes a temporary item from the list.
  void _deleteItem(String itemId) {
    setState(() {
      _items.removeWhere((item) => item.id == itemId);
    });
  }

  /// Toggles an item's in-memory edit mode.
  void _editItemInline(ShoppingItem item) {
    final editController = TextEditingController(text: item.name);
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Edit Item'),
          content: TextField(
            controller: editController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Enter new name',
              prefixIcon: Icon(Icons.edit_rounded),
            ),
            autofocus: true,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                setState(() {
                  final index = _items.indexWhere((i) => i.id == item.id);
                  if (index != -1) {
                    _items[index] = _items[index].copyWith(name: value.trim());
                  }
                });
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final value = editController.text.trim();
                if (value.isNotEmpty) {
                  setState(() {
                    final index = _items.indexWhere((i) => i.id == item.id);
                    if (index != -1) {
                      _items[index] = _items[index].copyWith(name: value);
                    }
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  /// Saves the complete list (with its in-memory items) to the database.
  Future<void> _handleSaveList() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    final String listId = DateTime.now().microsecondsSinceEpoch.toString();
    final newList = ShoppingList(
      id: listId,
      title: title,
      items: List<ShoppingItem>.from(_items),
      createdAt: DateTime.now(),
    );

    try {
      await DatabaseService.addList(newList);

      if (mounted) {
        // High fidelity feedback SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'List "$title" created successfully!',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save list: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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
        title: const Text('New Shopping List'),
        actions: [
          if (!_isSaving)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                icon: const Icon(Icons.done_all_rounded, size: 20),
                label: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
                onPressed: _handleSaveList,
              ),
            ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Heading prominent input field
                TextFormField(
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.sentences,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'List Name (e.g. Town Shopping)',
                    hintStyle: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a list name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Thin aesthetic divider
                Divider(
                  color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFECEFF1),
                  thickness: 1.5,
                ),
                const SizedBox(height: 20),

                // Add Items Section Header
                Text(
                  'Add Items',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 10),

                // Clean inline item input field
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _itemController,
                        focusNode: _itemFocusNode,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Add an item (e.g. Milk, Apples)',
                          prefixIcon: Icon(
                            Icons.add_shopping_cart_rounded,
                            color: theme.colorScheme.primary.withValues(alpha: 0.7),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        onFieldSubmitted: (_) => _addItem(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Square action button for item addition
                    GestureDetector(
                      onTap: _addItem,
                      child: Container(
                        height: 56,
                        width: 56,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // In-memory items list area
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Items in this list (${_items.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                    if (_items.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() => _items.clear()),
                        child: Text(
                          'Clear All',
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_items.isEmpty)
                  _buildEmptyItemsState(context)
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _items[index];

                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.horizontal,
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.startToEnd) {
                            // Swipe Right -> Edit inline dialog
                            _editItemInline(item);
                            return false; // Remain in list tree
                          } else if (direction == DismissDirection.endToStart) {
                            // Swipe Left -> Delete from memory immediately
                            _deleteItem(item.id);
                            return true;
                          }
                          return false;
                        },
                        background: _buildSwipeBackground(
                          color: theme.colorScheme.secondary,
                          icon: Icons.edit_rounded,
                          alignment: Alignment.centerLeft,
                        ),
                        secondaryBackground: _buildSwipeBackground(
                          color: theme.colorScheme.error,
                          icon: Icons.delete_outline_rounded,
                          alignment: Alignment.centerRight,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              // Manual Edit Icon
                              IconButton(
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                onPressed: () => _editItemInline(item),
                              ),
                              // Manual Delete Icon
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: theme.colorScheme.error.withValues(alpha: 0.8),
                                ),
                                onPressed: () => _deleteItem(item.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
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
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }

  /// Builds a clean sub-empty state inside the builder view.
  Widget _buildEmptyItemsState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          style: BorderStyle.solid,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.playlist_add_rounded,
            size: 40,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          Text(
            'No items added yet',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Type above to add items to your new list!',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
