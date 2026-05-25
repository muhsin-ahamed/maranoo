import 'dart:io';
import 'package:flutter/material.dart';

/// A modern immersive zoomable fullscreen overlay display for receipt/bill attachments.
/// Equips the user with fluid pinch-to-zoom gestures and a quick deletion feature.
class BillPreviewModal extends StatelessWidget {
  final String imagePath;
  final VoidCallback onDeleteConfirm;

  const BillPreviewModal({
    super.key,
    required this.imagePath,
    required this.onDeleteConfirm,
  });

  /// Static helper to trigger opening the preview modal seamlessly.
  static void show(
    BuildContext context, {
    required String imagePath,
    required VoidCallback onDeleteConfirm,
  }) {
    final file = File(imagePath);
    final theme = Theme.of(context);

    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Local receipt file not found! It may have been deleted.'),
          backgroundColor: theme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Receipt Image',
      barrierColor: Colors.black.withValues(alpha: 0.9), // Immersive dark overlay backdrop
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, anim1, anim2) {
        return BillPreviewModal(
          imagePath: imagePath,
          onDeleteConfirm: onDeleteConfirm,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(imagePath);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Immersive Zoomable Receipt Viewer
          Center(
            child: InteractiveViewer(
              clipBehavior: Clip.none,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(
                file,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Control Overlays
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Circular Close Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      tooltip: 'Close Preview',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),

                  // Circular Delete Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                      tooltip: 'Delete Bill',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete receipt?'),
                            content: const Text('Are you sure you want to permanently delete this bill receipt attachment?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error),
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('Delete', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          onDeleteConfirm();
                          if (context.mounted) {
                            Navigator.of(context).pop(); // Close fullscreen preview
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
