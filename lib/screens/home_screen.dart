import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taplingo/models/library_item.dart';
import 'package:taplingo/providers/providers.dart';
import 'package:taplingo/screens/reader_screen.dart';
import 'package:taplingo/screens/search_webview_screen.dart';
import 'package:taplingo/screens/settings_screen.dart';
import 'package:taplingo/widgets/add_item_dialog.dart';
import 'package:taplingo/widgets/empty_state.dart';
import 'package:taplingo/widgets/library_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptApiKey());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _maybePromptApiKey() async {
    final key = await ref.read(secureStorageProvider).getGeminiApiKey();
    if (key != null && key.isNotEmpty) return;
    if (!mounted) return;
    // Soft prompt only once per cold start via dialog
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Welcome to TapLingo'),
        content: const Text(
          'Bring your own Gemini API key to unlock instant word & sentence meanings. '
          'You can add it anytime in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            child: const Text('Add API key'),
          ),
        ],
      ),
    );
  }

  LibraryType get _activeType =>
      _tabs.index == 0 ? LibraryType.novel : LibraryType.manga;

  Future<void> _addItem() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AddItemDialog(type: _activeType),
    );
    if (name == null || name.isEmpty || !mounted) return;

    await Navigator.of(context).push<LibraryItem>(
      MaterialPageRoute(
        builder: (_) => SearchWebViewScreen(name: name, type: _activeType),
      ),
    );
  }

  void _openReader(LibraryItem item) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) =>
            ReaderScreen(item: item),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(libraryProvider);
    final novels = items.where((e) => e.type == LibraryType.novel).toList();
    final mangas = items.where((e) => e.type == LibraryType.manga).toList();
    final hasKey =
        ref.watch(geminiApiKeyProvider).value?.isNotEmpty == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TapLingo',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          if (!hasKey)
            IconButton(
              tooltip: 'Add Gemini API key',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              icon: Badge(
                smallSize: 8,
                child: const Icon(Icons.key_off_rounded),
              ),
            ),
          IconButton(
            tooltip: 'Search Library',
            onPressed: () async {
              final library = ref.read(libraryProvider);
              final selected = await showSearch(
                context: context,
                delegate: LibrarySearchDelegate(
                  library: library,
                  onDelete: (id) => ref.read(libraryProvider.notifier).remove(id),
                ),
              );
              if (selected != null) {
                _openReader(selected);
              }
            },
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Novel', icon: Icon(Icons.menu_book_rounded, size: 18)),
            Tab(
              text: 'Manga',
              icon: Icon(Icons.auto_stories_rounded, size: 18),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _LibraryGrid(
            items: novels,
            type: LibraryType.novel,
            onAdd: _addItem,
            onOpen: _openReader,
            onDelete: (id) =>
                ref.read(libraryProvider.notifier).remove(id),
          ),
          _LibraryGrid(
            items: mangas,
            type: LibraryType.manga,
            onAdd: _addItem,
            onOpen: _openReader,
            onDelete: (id) =>
                ref.read(libraryProvider.notifier).remove(id),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        tooltip: 'Add',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _LibraryGrid extends StatelessWidget {
  final List<LibraryItem> items;
  final LibraryType type;
  final VoidCallback onAdd;
  final void Function(LibraryItem) onOpen;
  final void Function(String id) onDelete;

  const _LibraryGrid({
    required this.items,
    required this.type,
    required this.onAdd,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(type: type, onAdd: onAdd);
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return LibraryCard(
          item: item,
          onTap: () => onOpen(item),
          onDelete: () => onDelete(item.id),
        );
      },
    );
  }
}

class LibrarySearchDelegate extends SearchDelegate<LibraryItem?> {
  final List<LibraryItem> library;
  final void Function(String id) onDelete;

  LibrarySearchDelegate({required this.library, required this.onDelete})
      : super(searchFieldLabel: 'Search library...');

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isEmpty) return [];
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final lower = query.toLowerCase().trim();
    final matches = library
        .where((e) => e.name.toLowerCase().contains(lower))
        .toList()
        .reversed
        .toList();

    if (matches.isEmpty) {
      return Center(
        child: Text(
          'No matching items found.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return _LibraryGrid(
      items: matches,
      type: LibraryType.novel, // Arbitrary, since it won't be empty here
      onAdd: () {},
      onOpen: (item) => close(context, item),
      onDelete: onDelete,
    );
  }
}
