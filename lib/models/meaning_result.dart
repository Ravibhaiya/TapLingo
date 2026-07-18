/// Result of a Gemini meaning lookup.
///
/// Single-tap (word) fills [plainMeaning], [contextualMeaning], [hinglish],
/// [example], and optionally [identifiedText].
/// Long-press (sentence) fills [plainMeaning], [hinglish], and [identifiedText].
class MeaningResult {
  final int taps;
  final String? identifiedText;
  final String? sentenceContext;
  final String plainMeaning;
  final String? contextualMeaning;
  final String hinglish;
  final String? example;
  final String? error;

  const MeaningResult({
    required this.taps,
    this.identifiedText,
    this.sentenceContext,
    required this.plainMeaning,
    this.contextualMeaning,
    required this.hinglish,
    this.example,
    this.error,
  });

  bool get isWordMode => taps == 1;
  bool get isSentenceMode => taps == 3;
  bool get hasError => error != null && error!.isNotEmpty;

  factory MeaningResult.error(String message, {int taps = 1}) => MeaningResult(
        taps: taps,
        plainMeaning: '',
        hinglish: '',
        error: message,
      );

  factory MeaningResult.fromJson(Map<String, dynamic> json, int taps) {
    return MeaningResult(
      taps: taps,
      identifiedText: json['identifiedText'] as String?,
      sentenceContext: json['sentenceContext'] as String?,
      plainMeaning: (json['plainMeaning'] as String?) ??
          (json['meaning'] as String?) ??
          '',
      contextualMeaning: json['contextualMeaning'] as String?,
      hinglish: (json['hinglish'] as String?) ?? '',
      example: json['example'] as String?,
    );
  }
}

/// Payload received from WebView JS channel (novel) or manga tap.
class TapPayload {
  final String? word;
  final String? sentence;
  final int taps;
  final double? x;
  final double? y;

  const TapPayload({
    this.word,
    this.sentence,
    required this.taps,
    this.x,
    this.y,
  });

  factory TapPayload.fromJson(Map<String, dynamic> json) {
    return TapPayload(
      word: json['word'] as String?,
      sentence: json['sentence'] as String?,
      taps: (json['taps'] as num?)?.toInt() ?? 1,
      x: (json['x'] as num?)?.toDouble(),
      y: (json['y'] as num?)?.toDouble(),
    );
  }
}
