import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taplingo/models/library_item.dart';
import 'package:taplingo/providers/providers.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Opens Google search for the named title; user browses freely, then
/// taps "Save this page" to add a library entry.
class SearchWebViewScreen extends ConsumerStatefulWidget {
  final String name;
  final LibraryType type;

  const SearchWebViewScreen({
    super.key,
    required this.name,
    required this.type,
  });

  @override
  ConsumerState<SearchWebViewScreen> createState() =>
      _SearchWebViewScreenState();
}

class _SearchWebViewScreenState extends ConsumerState<SearchWebViewScreen> {
  late final WebViewController _controller;
  var _loading = true;
  var _saving = false;
  String _currentUrl = '';
  String _title = '';

  @override
  void initState() {
    super.initState();
    final query = Uri.encodeComponent('${widget.name} read online');
    final startUrl = 'https://www.google.com/search?q=$query';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _loading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (url) async {
            final t = await _controller.getTitle();
            if (!mounted) return;
            setState(() {
              _loading = false;
              _currentUrl = url;
              _title = t ?? widget.name;
            });
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(startUrl));
  }

  Future<void> _savePage() async {
    final url = await _controller.currentUrl() ?? _currentUrl;
    if (url.isEmpty || url.contains('google.com/search')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open a chapter/page first, then save.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final item = LibraryItem(
      id: const Uuid().v4(),
      name: widget.name,
      type: widget.type,
      url: url,
      dateAdded: DateTime.now(),
      lastReadUrl: url,
      lastReadPosition: 0,
      lastOpenedAt: DateTime.now(),
    );
    await ref.read(libraryProvider.notifier).add(item);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved “${widget.name}” to your library')),
    );
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              'Find a page, then Save',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Back',
            onPressed: () async {
              if (await _controller.canGoBack()) {
                await _controller.goBack();
              }
            },
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
          IconButton(
            tooltip: 'Forward',
            onPressed: () async {
              if (await _controller.canGoForward()) {
                await _controller.goForward();
              }
            },
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
          ),
          IconButton(
            tooltip: 'Reload',
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          Positioned(
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: FloatingActionButton.extended(
                heroTag: 'save-page',
                onPressed: _saving ? null : _savePage,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bookmark_add_rounded),
                label: const Text('Save this page'),
              ),
            ),
          ),
          if (_title.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              top: 8,
              child: IgnorePointer(
                child: Material(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      _currentUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
