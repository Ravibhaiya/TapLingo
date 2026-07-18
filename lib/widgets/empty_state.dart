import 'package:flutter/material.dart';
import 'package:taplingo/models/library_item.dart';

class EmptyState extends StatelessWidget {
  final LibraryType type;
  final VoidCallback? onAdd;

  const EmptyState({super.key, required this.type, this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isNovel = type == LibraryType.novel;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNovel ? Icons.menu_book_rounded : Icons.auto_stories_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isNovel ? 'No novels yet' : 'No manga yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isNovel
                  ? 'Tap + to search any free novel site and save a chapter. Tap words for kid-simple meanings.'
                  : 'Tap + to find free manga online. Tap dialogue bubbles for instant meanings.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
              textAlign: TextAlign.center,
            ),
            if (onAdd != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(isNovel ? 'Add novel' : 'Add manga'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
