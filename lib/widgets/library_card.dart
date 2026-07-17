import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:taplingo/models/library_item.dart';

class LibraryCard extends StatelessWidget {
  final LibraryItem item;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const LibraryCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNovel = item.type == LibraryType.novel;
    final last = item.lastOpenedAt ?? item.dateAdded;
    final when = _relative(last);

    return Hero(
      tag: 'library-${item.id}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onDelete == null
              ? null
              : () => _confirmDelete(context),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: theme.cardTheme.color ??
                  theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isNovel
                            ? [
                                const Color(0xFF7F00FF).withValues(alpha: 0.85),
                                const Color(0xFF2A0054),
                              ]
                            : [
                                const Color(0xFFFF007F).withValues(alpha: 0.85),
                                const Color(0xFF7F00FF).withValues(alpha: 0.95),
                              ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Huge background letter watermark
                        Positioned(
                          right: -12,
                          bottom: -20,
                          child: Text(
                            item.name.isNotEmpty
                                ? item.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 100,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                        // Type Badge
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isNovel
                                      ? Icons.menu_book_rounded
                                      : Icons.auto_stories_rounded,
                                  size: 12,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isNovel ? 'NOVEL' : 'MANGA',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Center icon with glowing circle
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Icon(
                              isNovel
                                  ? Icons.local_library_rounded
                                  : Icons.collections_bookmark_rounded,
                              size: 28,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Last read $when',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _relative(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(dt);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from library?'),
        content: Text('“${item.name}” will be removed. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) onDelete?.call();
  }
}
