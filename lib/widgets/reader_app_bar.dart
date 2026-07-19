import 'package:flutter/material.dart';

class ReaderAppBar extends StatelessWidget {
  final String title;
  final bool chromeVisible;
  final VoidCallback onToggleChrome;
  final Future<void> Function() onGoBack;
  final VoidCallback onReload;

  const ReaderAppBar({
    super.key,
    required this.title,
    required this.chromeVisible,
    required this.onToggleChrome,
    required this.onGoBack,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 250),
      offset: chromeVisible ? Offset.zero : const Offset(0, -1.2),
      child: SafeArea(
        child: Material(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.maybePop(context);
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Back in page',
                onPressed: onGoBack,
                icon: const Icon(Icons.arrow_back_ios_new, size: 16),
              ),
              IconButton(
                tooltip: 'Reload',
                onPressed: onReload,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: chromeVisible ? 'Hide bar' : 'Show bar',
                onPressed: onToggleChrome,
                icon: Icon(
                  chromeVisible ? Icons.fullscreen : Icons.fullscreen_exit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
