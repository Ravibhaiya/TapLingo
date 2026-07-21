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

import 'package:taplingo/widgets/manga_selection_overlay.dart';
import 'package:taplingo/widgets/meaning_bottom_sheet.dart';
import 'package:taplingo/widgets/reader_app_bar.dart';
import 'package:taplingo/widgets/reader_skeleton.dart';
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
  Timer? _restorationFallbackTimer;
  bool _restoredScroll = false;
  bool _restoringScroll = false;
  bool _isBottomSheetOpen = false;

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
            
            // Wait for document.readyState to be "complete" so that the website's onload event triggers
            for (int i = 0; i < 50; i++) {
              if (!mounted) return;
              try {
                final state = await _controller.runJavaScriptReturningResult('document.readyState');
                final stateStr = state.toString().replaceAll('"', '').replaceAll("'", "").trim();
                if (stateStr == 'complete') {
                  break;
                }
              } catch (_) {}
              await Future<void>.delayed(const Duration(milliseconds: 100));
            }

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
  }

  @override
  void dispose() {
    _restorationFallbackTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    // Do not call async _captureScrollPosition here — after dispose, ref/WebView
    // may be invalid. Progress is saved via PopScope (awaited) and lifecycle pause.
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
    final js = await JsInjection.readerTap();
    await _controller.runJavaScript(js);
  }

  Future<void> _maybeRestoreScroll(String url) async {
    if (!mounted) return;
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

    _restoringScroll = true;
    _restoredScroll = true;

    if (_isManga) {
      _restorationFallbackTimer?.cancel();
      // Start a safety fallback timer (30 seconds) to clear the flag in case the JS message is lost
      _restorationFallbackTimer = Timer(const Duration(seconds: 30), () {
        _restoringScroll = false;
      });
      await _controller.runJavaScript(JsInjection.scrollWithImageWait(y));
    } else {
      // For novels: simple retry is sufficient since text content is deterministic.
      if (mounted) setState(() => _restoringScroll = true);
      for (final delay in [200, 500, 1000, 1500, 2500]) {
        await Future<void>.delayed(Duration(milliseconds: delay));
        if (!mounted) return;
        try {
          await _controller.runJavaScript(JsInjection.scrollToY(y));
        } catch (_) {}
      }
      if (mounted) setState(() => _restoringScroll = false);
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
    if (!mounted || _restoringScroll) return;
    try {
      final result = await _controller
          .runJavaScriptReturningResult(JsInjection.getScrollY)
          .timeout(const Duration(milliseconds: 250));
      if (!mounted) return;
      final y = double.tryParse(result.toString()) ?? 0;
      final url = await _controller.currentUrl();
      if (!mounted) return;
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
      
      // Handle scroll restoration message from injected JS
      if (map['type'] == 'scrollRestoration') {
        _restorationFallbackTimer?.cancel();
        if (mounted) {
          setState(() {
            _restoringScroll = false;
          });
        }
        final status = map['status'] as String?;
        debugPrint('[ScrollRestoration] Completed with status: $status');
        return;
      }

      // Handle real-time scroll updates from JS
      if (map['type'] == 'scrollPosition') {
        if (!_restoringScroll) {
          final y = (map['y'] as num?)?.toDouble() ?? 0.0;
          final url = map['url'] as String?;
          if (url != null && url.isNotEmpty) {
            ref.read(libraryProvider.notifier).updateProgress(
                  id: widget.item.id,
                  lastReadUrl: url,
                  lastReadPosition: y,
                );
          }
        }
        return;
      }

      final payload = TapPayload.fromJson(map);
      if (payload.taps < 1) return;
      
      final hasImage = map.containsKey('imageSrc') && map['imageSrc'] != null;
      if (hasImage) {
        _handleImageTap(map, payload);
      } else {
        _handleTextTap(payload);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tap parse error: $e')),
        );
      }
    }
  }

  Future<void> _handleTextTap(TapPayload payload) async {
    if (_isBottomSheetOpen) return;
    final apiKey = ref.read(geminiApiKeyProvider).value;
    if (apiKey == null || apiKey.isEmpty) {
      _promptForApiKey();
      return;
    }

    final word = payload.word ?? '';
    final sentence = payload.sentence ?? word;
    final taps = payload.taps;

    if (!mounted) return;
    _isBottomSheetOpen = true;
    try {
      await showMeaningBottomSheet(
        context: context,
        taps: taps,
        fallbackSpeakText: taps == 3 ? sentence : word,
        sentenceContext: taps != 3 ? sentence : null,
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
    } finally {
      if (mounted) _isBottomSheetOpen = false;
    }
  }

  Future<void> _handleImageTap(
    Map<String, dynamic> map,
    TapPayload payload,
  ) async {
    if (_isBottomSheetOpen) return;
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

    // Use natural (intrinsic) image dimensions for accurate cropping
    final rawNaturalW = (map['naturalWidth'] as num?)?.toDouble() ?? 0;
    final rawNaturalH = (map['naturalHeight'] as num?)?.toDouble() ?? 0;
    final naturalW = rawNaturalW <= 0 ? imgW : rawNaturalW;
    final naturalH = rawNaturalH <= 0 ? imgH : rawNaturalH;

    if (!mounted) return;
    
    if (taps == 3) {
      if (imageSrc == null || imageSrc.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find image to select.')),
        );
        return;
      }
      
      bool dialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  height: 40,
                  width: 40,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Downloading high-res page...',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'This may take a moment on slower networks.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      dialogOpen = false;
                      Navigator.pop(ctx);
                    },
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ).then((_) => dialogOpen = false);
      
      final full = await _downloadImage(imageSrc);
      
      if (mounted && dialogOpen) Navigator.of(context).pop();
      if (!dialogOpen) return;
      
      if (full == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to download image')),
          );
        }
        return;
      }
      
      if (!mounted) return;
      final normalizedRect = await Navigator.of(context).push<Rect>(
        MaterialPageRoute(
          builder: (_) => MangaSelectionOverlay(
            imageBytes: full,
            viewportWidth: naturalW,
            viewportHeight: naturalH,
          ),
        ),
      );
      
      if (normalizedRect == null) return;
      
      if (!mounted) return;
      _isBottomSheetOpen = true;
      try {
        await showMeaningBottomSheet(
          context: context,
          taps: taps,
          load: () async {
            final crop = await cropSelectedRect(
              fullImageBytes: full,
              normalizedRect: normalizedRect,
            );
            if (crop == null) {
              return MeaningResult.error(
                'Could not crop the selected region.',
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
      } finally {
        if (mounted) _isBottomSheetOpen = false;
      }
      return;
    }

    _isBottomSheetOpen = true;
    try {
      await showMeaningBottomSheet(
        context: context,
        taps: taps,
        load: () async {
          if (imageSrc == null || imageSrc.isEmpty) {
            return MeaningResult.error(
              'Could not find an image under your tap. Try tapping on the image.',
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
    } finally {
      if (mounted) _isBottomSheetOpen = false;
    }
  }

  Future<Uint8List?> _downloadImage(String url) async {
    try {
      final uri = Uri.parse(url);
      final pageUrl = await _controller.currentUrl();
      final response = await http.get(
        uri,
        headers: {
          'Referer': pageUrl ?? '',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        },
      ).timeout(const Duration(seconds: 15));
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
                child: Stack(
                  children: [
                    WebViewWidget(controller: _controller),
                    if (_loading || _restoringScroll)
                      Positioned.fill(
                        child: Container(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: ReaderSkeleton(isManga: _isManga),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            ReaderAppBar(
              title: widget.item.name,
              chromeVisible: _chromeVisible,
              onToggleChrome: () => setState(() => _chromeVisible = !_chromeVisible),
              onReload: () => _controller.reload(),
              onGoBack: () async {
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
            ),
            if (_loading || _restoringScroll)
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
