import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:taplingo/models/meaning_result.dart';
import 'package:taplingo/providers/providers.dart';

Future<void> showMeaningBottomSheet({
  required BuildContext context,
  required Future<MeaningResult> Function() load,
  required int taps,
  String? fallbackSpeakText,
  String? sentenceContext,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => MeaningBottomSheet(
      load: load,
      taps: taps,
      fallbackSpeakText: fallbackSpeakText,
      sentenceContext: sentenceContext,
    ),
  );
}

class MeaningBottomSheet extends ConsumerStatefulWidget {
  final Future<MeaningResult> Function() load;
  final int taps;
  final String? fallbackSpeakText;
  final String? sentenceContext;

  const MeaningBottomSheet({
    super.key,
    required this.load,
    required this.taps,
    this.fallbackSpeakText,
    this.sentenceContext,
  });

  @override
  ConsumerState<MeaningBottomSheet> createState() => _MeaningBottomSheetState();
}

class _MeaningBottomSheetState extends ConsumerState<MeaningBottomSheet> {
  MeaningResult? _result;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.load();
      if (!mounted) return;
      setState(() {
        _result = r;
        _loading = false;
        if (r.hasError) _error = r.error;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _speak() async {
    final r = _result;
    final text = r?.identifiedText ??
        widget.fallbackSpeakText ??
        r?.plainMeaning ??
        '';
    await ref.read(ttsServiceProvider).speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWord = widget.taps != 3;

    return DraggableScrollableSheet(
      initialChildSize: 0.48,
      minChildSize: 0.28,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.bottomSheetTheme.backgroundColor ??
                theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isWord ? 'Word meaning' : 'Sentence meaning',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Read aloud',
                      onPressed: _loading ? null : _speak,
                      icon: const Icon(Icons.volume_up_rounded),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  children: [
                    if (_loading) ..._shimmer(theme),
                    if (!_loading && _error != null)
                      _ErrorBlock(
                        message: _error.toString(),
                        onRetry: _fetch,
                      ),
                    if (!_loading && _result != null && _error == null)
                      ..._content(theme, _result!, isWord),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _content(ThemeData theme, MeaningResult r, bool isWord) {
    final widgets = <Widget>[];

    if (r.identifiedText != null && r.identifiedText!.isNotEmpty) {
      widgets.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            r.identifiedText!,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }

    final actualSentenceContext = widget.sentenceContext ?? r.sentenceContext;

    if (isWord && actualSentenceContext != null && actualSentenceContext.isNotEmpty) {
      widgets.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.format_quote_rounded, size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  actualSentenceContext,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }

    widgets.add(_Section(
      title: 'Meaning',
      body: r.plainMeaning,
      icon: Icons.lightbulb_outline_rounded,
    ));

    if (isWord &&
        r.contextualMeaning != null &&
        r.contextualMeaning!.isNotEmpty) {
      widgets.add(const SizedBox(height: 14));
      widgets.add(_Section(
        title: 'Meaning according to the sentence',
        body: r.contextualMeaning!,
        icon: Icons.format_quote_rounded,
      ));
    }

    if (r.hinglish.isNotEmpty) {
      widgets.add(const SizedBox(height: 14));
      widgets.add(_Section(
        title: 'Meaning in Hinglish',
        body: r.hinglish,
        icon: Icons.translate_rounded,
      ));
    }

    if (isWord && r.example != null && r.example!.isNotEmpty) {
      widgets.add(const SizedBox(height: 14));
      widgets.add(_Section(
        title: 'Example',
        body: r.example!,
        icon: Icons.edit_note_rounded,
      ));
    }

    return widgets;
  }

  List<Widget> _shimmer(ThemeData theme) {
    final base = theme.colorScheme.surfaceContainerHighest;
    final highlight = theme.colorScheme.surface;
    return [
      Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            4,
            (i) => Container(
              height: i == 0 ? 48 : 64,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;

  const _Section({
    required this.title,
    required this.body,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(body, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBlock({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.error_outline, size: 40, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}
