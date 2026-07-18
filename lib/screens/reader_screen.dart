import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:taplingo/models/library_item.dart';
import 'package:taplingo/models/meaning_result.dart';
import 'package:taplingo/providers/providers.dart';
import 'package:taplingo/utils/image_crop.dart';
import 'package:taplingo/utils/js_injection.dart';
import 'package:taplingo/widgets/meaning_bottom_sheet.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final LibraryItem item;

  const ReaderScreen({super.key, required this.item});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  var _loading = true;
  var _chromeVisible = true;
  Timer? _progressTimer;
  bool _restoredScroll = false;

  bool get _isManga => widget.item.type == LibraryType.manga;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    final startUrl = widget.item.lastReadUrl.isNotEmpty
        ? widget.item.lastReadUrl
        : widget.item.url;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'TapLingoChannel',
        onMessageReceived: _onJsMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            setState(() {
              _loading = true;
              _restoredScroll = false;
            });
          },
          onPageFinished: (url) async {
            await _injectModeScripts();
            await _maybeRestoreScroll(url);
            if (mounted) setState(() => _loading = false);
            _persistUrl(url);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(startUrl));

    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(false);
      platform.setMediaPlaybackRequiresUserGesture(false);
    }

    _progressTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _captureScrollPosition();
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _captureScrollPosition();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _captureScrollPosition();
    }
  }

  Future<void> _injectModeScripts() async {
    final js = _isManga
        ? await JsInjection.mangaTap()
        : await JsInjection.novelTap();
    await _controller.runJavaScript(js);
  }

  Future<void> _maybeRestoreScroll(String url) async {
    if (_restoredScroll) return;

    final currentItem = ref.read(libraryProvider).firstWhere(
          (e) => e.id == widget.item.id,
          orElse: () => widget.item,
        );

    final cleanCurrentUrl = _normalizeUrl(url);
    final cleanSavedUrl = _normalizeUrl(currentItem.lastReadUrl);

    if (cleanCurrentUrl != cleanSavedUrl) {
      _restoredScroll = true;
      return;
    }

    final y = currentItem.lastReadPosition;
    if (y <= 0) {
      _restoredScroll = true;
      return;
    }

    _restoredScroll = true;

    // Retry scrolling a few times as the page/images load to handle layout shifts
    for (final delay in [200, 500, 1000, 1500, 2500]) {
      await Future<void>.delayed(Duration(milliseconds: delay));
      if (!mounted) return;
      try {
        await _controller.runJavaScript(JsInjection.scrollToY(y));
      } catch (_) {}
    }
  }

  String _normalizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      var path = uri.path;
      if (path.endsWith('/')) {
        path = path.substring(0, path.length - 1);
      }
      final query = uri.hasQuery ? '?${uri.query}' : '';
      return '${uri.scheme}://${uri.host}$path$query';
    } catch (_) {
      return url;
    }
  }

  Future<void> _captureScrollPosition() async {
    if (!mounted) return;
    try {
      final result = await _controller
          .runJavaScriptReturningResult(JsInjection.getScrollY)
          .timeout(const Duration(milliseconds: 250));
      final y = double.tryParse(result.toString()) ?? 0;
      final url = await _controller.currentUrl();
      if (url != null && url.isNotEmpty) {
        await ref.read(libraryProvider.notifier).updateProgress(
              id: widget.item.id,
              lastReadUrl: url,
              lastReadPosition: y,
            );
      }
    } catch (_) {}
  }

  Future<void> _persistUrl(String url) async {
    if (url.isEmpty) return;
    final currentItem = ref.read(libraryProvider).firstWhere(
          (e) => e.id == widget.item.id,
          orElse: () => widget.item,
        );
    if (_normalizeUrl(currentItem.lastReadUrl) != _normalizeUrl(url)) {
      // Navigated to a new page/chapter. Save the new URL and reset the scroll position.
      await ref.read(libraryProvider.notifier).updateProgress(
            id: widget.item.id,
            lastReadUrl: url,
            lastReadPosition: 0,
          );
    } else {
      // Just save the URL (though it's the same)
      await ref.read(libraryProvider.notifier).updateProgress(
            id: widget.item.id,
            lastReadUrl: url,
          );
    }
  }

  void _onJsMessage(JavaScriptMessage message) {
    try {
      final map = jsonDecode(message.message) as Map<String, dynamic>;
      final payload = TapPayload.fromJson(map);
      if (payload.taps < 2) return;
      if (_isManga) {
        _handleMangaTap(map, payload);
      } else {
        _handleNovelTap(payload);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tap parse error: $e')),
        );
      }
    }
  }

  Future<void> _handleNovelTap(TapPayload payload) async {
    final apiKey = ref.read(geminiApiKeyProvider).value;
    if (apiKey == null || apiKey.isEmpty) {
      _promptForApiKey();
      return;
    }

    final word = payload.word ?? '';
    final sentence = payload.sentence ?? word;
    final taps = payload.taps;

    if (!mounted) return;
    await showMeaningBottomSheet(
      context: context,
      taps: taps,
      fallbackSpeakText: taps == 3 ? sentence : word,
      load: () async {
        final gemini = ref.read(geminiServiceProvider);
        if (taps == 3) {
          return gemini.explainSentence(apiKey: apiKey, sentence: sentence);
        }
        return gemini.explainWord(
          apiKey: apiKey,
          word: word,
          sentence: sentence,
        );
      },
    );
  }

  Future<void> _handleMangaTap(
    Map<String, dynamic> map,
    TapPayload payload,
  ) async {
    final apiKey = ref.read(geminiApiKeyProvider).value;
    if (apiKey == null || apiKey.isEmpty) {
      _promptForApiKey();
      return;
    }

    final taps = payload.taps;
    final imageSrc = map['imageSrc'] as String?;
    final relX = (map['relX'] as num?)?.toDouble() ?? payload.x ?? 0;
    final relY = (map['relY'] as num?)?.toDouble() ?? payload.y ?? 0;
    
    final rawW = (map['imgWidth'] as num?)?.toDouble() ?? 0;
    final rawH = (map['imgHeight'] as num?)?.toDouble() ?? 0;
    final imgW = rawW <= 0 ? 1.0 : rawW;
    final imgH = rawH <= 0 ? 1.0 : rawH;

    if (!mounted) return;
    await showMeaningBottomSheet(
      context: context,
      taps: taps,
      load: () async {
        if (imageSrc == null || imageSrc.isEmpty) {
          return MeaningResult.error(
            'Could not find a manga image under your tap. Try tapping on the panel art.',
            taps: taps,
          );
        }
        final full = await _downloadImage(imageSrc);
        if (full == null) {
          return MeaningResult.error(
            'Could not download the page image. The site may block hotlinking.',
            taps: taps,
          );
        }
        final crop = await cropAroundTap(
          fullImageBytes: full,
          x: relX,
          y: relY,
          viewportWidth: imgW,
          viewportHeight: imgH,
          cropSize: 220,
        );
        if (crop == null) {
          return MeaningResult.error(
            'Could not crop the tapped region.',
            taps: taps,
          );
        }

        return ref.read(geminiServiceProvider).explainMangaTap(
              apiKey: apiKey,
              fullImageBytes: full,
              cropPng: crop,
              taps: taps,
            );
      },
    );
  }

  Future<Uint8List?> _downloadImage(String url) async {
    try {
      final uri = Uri.parse(url);
      final pageUrl = await _controller.currentUrl();
      final response = await http.get(
        uri,
        headers: {
          'Referer': ?pageUrl,
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  void _promptForApiKey() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gemini API key needed'),
        content: const Text(
          'Add your own Gemini API key in Settings to unlock tap-to-define. '
          'Keys stay on your device — never in the public repo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushNamed('/settings');
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _captureScrollPosition();
        if (mounted) {
          // ignore: use_build_context_synchronously
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            Hero(
              tag: 'library-${widget.item.id}',
              child: Material(
                child: WebViewWidget(controller: _controller),
              ),
            ),
            AnimatedSlide(
              duration: const Duration(milliseconds: 250),
              offset: _chromeVisible ? Offset.zero : const Offset(0, -1.2),
              child: SafeArea(
                child: Material(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.92),
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
                              widget.item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Back in page',
                        onPressed: () async {
                          if (await _controller.canGoBack()) {
                            await _controller.goBack();
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No previous page history.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                      ),
                      IconButton(
                        tooltip: 'Reload',
                        onPressed: () => _controller.reload(),
                        icon: const Icon(Icons.refresh),
                      ),
                      IconButton(
                        tooltip: _chromeVisible ? 'Hide bar' : 'Show bar',
                        onPressed: () =>
                            setState(() => _chromeVisible = !_chromeVisible),
                        icon: Icon(
                          _chromeVisible
                              ? Icons.fullscreen
                              : Icons.fullscreen_exit,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_loading)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (!_chromeVisible)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 4,
                right: 8,
                child: IconButton.filledTonal(
                  onPressed: () => setState(() => _chromeVisible = true),
                  icon: const Icon(Icons.more_horiz),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
