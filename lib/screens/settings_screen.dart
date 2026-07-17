import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taplingo/providers/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _keyController = TextEditingController();
  bool _obscure = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = ref.read(geminiApiKeyProvider).value;
      if (key != null) _keyController.text = key;
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(geminiApiKeyProvider.notifier).setKey(_keyController.text);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _keyController.text.trim().isEmpty
              ? 'API key cleared'
              : 'Gemini API key saved securely',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final keyAsync = ref.watch(geminiApiKeyProvider);
    final hasKey = keyAsync.value?.isNotEmpty == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Gemini API key',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'TapLingo uses Google Gemini only. Get a free key from Google AI Studio and paste it here. '
            'It is stored on-device with secure storage and never committed to the repo.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keyController,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'API key',
              hintText: 'AIza…',
              prefixIcon: const Icon(Icons.key_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text('Save key'),
              ),
              const SizedBox(width: 12),
              if (hasKey)
                TextButton(
                  onPressed: () async {
                    _keyController.clear();
                    await ref.read(geminiApiKeyProvider.notifier).clear();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('API key removed')),
                    );
                  },
                  child: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          keyAsync.when(
            data: (k) => Text(
              k == null || k.isEmpty
                  ? 'Status: no key set — meanings will not work until you add one.'
                  : 'Status: key saved (${k.length} chars)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 32),
          Text(
            'Appearance',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (s) {
              ref.read(themeModeProvider.notifier).setMode(s.first);
            },
          ),
          const SizedBox(height: 32),
          Text(
            'How to use',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          const _Tip(
            icon: Icons.touch_app,
            title: 'Double-tap',
            body: 'Meaning of the tapped word (or manga word under your finger).',
          ),
          const _Tip(
            icon: Icons.touch_app,
            title: 'Triple-tap',
            body: 'Meaning of the whole sentence / dialogue line.',
          ),
          const _Tip(
            icon: Icons.volume_up,
            title: 'Read aloud',
            body: 'Use the speaker button in the meaning sheet.',
          ),
          const SizedBox(height: 24),
          Text(
            'Get a key: https://aistudio.google.com/apikey',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _Tip({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(body),
    );
  }
}
