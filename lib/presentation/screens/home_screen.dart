import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../data/models/shopping_list.dart';
import '../../core/database/database_service.dart';
import '../../core/theme/app_theme.dart';
import 'add_new_list_screen.dart';
import 'list_detail_screen.dart';

/// The [HomeScreen] displays the dynamic, premium overview of all shopping lists pulled from Hive,
/// complete with a header progress dashboard, a dark/light theme toggler, list card overviews,
/// and list-level editing & deletion. Clicking a list card navigates to the [ListDetailScreen].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<Box<ShoppingList>>(
          valueListenable: DatabaseService.listenable,
          builder: (context, box, _) {
            final lists = DatabaseService.allLists;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Elegant premium App Bar with custom Outfit English branding
                SliverAppBar(
                  floating: true,
                  pinned: false,
                  centerTitle: false,
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.shopping_bag_rounded,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Maranoo',
                        style: GoogleFonts.outfit(
                          textStyle: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.primary,
                            fontSize: 28,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    // Theme Mode Toggler button
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeNotifier,
                      builder: (context, currentMode, _) {
                        IconData icon;
                        String tooltip;
                        if (currentMode == ThemeMode.dark) {
                          icon = Icons.light_mode_rounded;
                          tooltip = 'Light Mode';
                        } else if (currentMode == ThemeMode.light) {
                          icon = Icons.dark_mode_rounded;
                          tooltip = 'Dark Mode';
                        } else {
                          icon = Icons.brightness_auto_rounded;
                          tooltip = 'System Theme';
                        }

                        return Container(
                          margin: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: IconButton(
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, anim) => RotationTransition(
                                turns: anim,
                                child: ScaleTransition(scale: anim, child: child),
                              ),
                              child: Icon(icon, key: ValueKey(icon), size: 20),
                            ),
                            tooltip: tooltip,
                            onPressed: () {
                              if (currentMode == ThemeMode.system) {
                                themeNotifier.value = ThemeMode.light;
                              } else if (currentMode == ThemeMode.light) {
                                themeNotifier.value = ThemeMode.dark;
                              } else {
                                themeNotifier.value = ThemeMode.system;
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // Empty state handling
                if (lists.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context),
                  )
                else ...[
                  // Dynamic Summary Metric Dashboard Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      child: _buildOverallSummaryCard(context, lists),
                    ),
                  ),

                  // Dynamic lists section
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final list = lists[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: _buildListCard(context, list),
                          );
                        },
                        childCount: lists.length,
                      ),
                    ),
                  ),

                  // Bottom Spacing for Floating Action Button
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ],
            );
          },
        ),
      ),

      // Floating Action Button to navigate to AddNewListPage
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const AddNewListPage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(0.0, 0.2);
                const end = Offset.zero;
                const curve = Curves.easeOutCubic;

                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);

                return SlideTransition(
                  position: offsetAnimation,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
            ),
          );
        },
        icon: const Icon(Icons.playlist_add_rounded, size: 24),
        label: const Text(
          'New List',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.1),
        ),
      ),
    );
  }

  /// Builds the top general summary dashboard card reflecting statistics across all shopping lists.
  Widget _buildOverallSummaryCard(BuildContext context, List<ShoppingList> lists) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    int totalItems = 0;
    int purchasedItems = 0;
    for (var list in lists) {
      totalItems += list.items.length;
      purchasedItems += list.items.where((i) => i.isPurchased).length;
    }

    final progress = totalItems > 0 ? purchasedItems / totalItems : 0.0;
    final int activeLists = lists.length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  theme.colorScheme.primary.withValues(alpha: 0.18),
                  theme.colorScheme.secondary.withValues(alpha: 0.06),
                ]
              : [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
        border: isDark
            ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.35), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall Progress',
                    style: TextStyle(
                      color: isDark ? theme.colorScheme.onSurface : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$purchasedItems of $totalItems tasks completed • $activeLists active ${activeLists == 1 ? 'list' : 'lists'}',
                    style: TextStyle(
                      color: isDark
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.primary.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    color: isDark ? theme.colorScheme.primary : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark
                  ? theme.colorScheme.surface.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? theme.colorScheme.primary : Colors.white,
              ),
            ),
          )
        ],
      ),
    );
  }

  /// Builds a specific [ShoppingList] card that navigates to its [ListDetailScreen] on tap.
  Widget _buildListCard(BuildContext context, ShoppingList list) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final int total = list.items.length;
    final int completed = list.items.where((i) => i.isPurchased).length;
    final double listProgress = total > 0 ? completed / total : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.4),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ListDetailScreen(listId: list.id),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Smooth circular leading icon matching top bar
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.playlist_add_check_rounded,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    list.title,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      letterSpacing: -0.4,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (list.billImagePath != null) ...[
                                  const SizedBox(width: 8),
                                  Tooltip(
                                    message: 'Receipt attachment uploaded',
                                    child: Icon(
                                      Icons.receipt_long_rounded,
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$completed of $total items completed',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                                  fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Custom delete button for the whole list
                      IconButton(
                        icon: Icon(
                          Icons.delete_sweep_rounded,
                          size: 22,
                          color: theme.colorScheme.error.withValues(alpha: 0.75),
                        ),
                        tooltip: 'Delete List',
                        onPressed: () => _showListDeleteConfirmation(context, list),
                      ),

                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        size: 22,
                      ),
                    ],
                  ),

                  // Progress Bar inside the card
                  if (total > 0) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: listProgress,
                        minHeight: 5,
                        backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  /// Shows the deletion alert popup for a WHOLE list.
  void _showListDeleteConfirmation(BuildContext context, ShoppingList list) {
    final theme = Theme.of(context);

    showDialog(
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
              Icons.delete_forever_rounded,
              color: theme.colorScheme.error,
              size: 28,
            ),
          ),
          title: const Text('Delete List?'),
          content: Text(
            'Are you sure you want to permanently delete the entire list "${list.title}" containing ${list.items.length} items? This will also delete any attached receipt and is irreversible.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
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
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                await DatabaseService.deleteList(list.id);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('List "${list.title}" deleted.'),
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
              },
              child: const Text('Delete List', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// Builds a gorgeous, high-fidelity empty state using native Flutter widgets.
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.playlist_add_check_rounded,
                size: 72,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No lists created yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your workspace is completely clean. Click the button below to add your first shopping or task list and start checking items!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AddNewListPage()),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Create your first list'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
