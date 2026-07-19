# TapLingo

Read novels & manga from any free website. Tap any word for an instant simple + Hinglish meaning — powered by **Google Gemini**.

**Platform:** Android only  
**AI:** Gemini only (bring your own API key)

## Features

- **Novel / Manga tabs** — one library, switch with a single tap
- **Add from the web** — search Google in-app, browse freely, save any chapter/page
- **Novel tap-to-define** — JS injection defeats `user-select` blocks; single-tap a word, long-press for the whole sentence
- **Manga vision define** — single-tap/long-press on a panel; screenshot + crop + coordinates go to Gemini Vision

### Meaning Display

A sleek, animated bottom sheet parses Gemini’s JSON response into:
1. **Identified Word**
2. **Contextual Meaning** (what it means in that exact sentence)
3. **Plain Meaning**
4. **Hinglish** (Hindi-English colloquial explanation)
5. **Example Sentence**

| Action | Result |
|--------|--------|
| **Single-tap** | Meaning of a specific **word** (+ Hinglish + Example) |
| **Long-press** | Meaning of the whole **sentence** / dialogue line (+ Hinglish) |

## Setup

### Prerequisites

- Flutter 3.22+ (stable)
- Android SDK
- A free [Gemini API key](https://aistudio.google.com/apikey)

### Clone & run

```bash
git clone https://github.com/<you>/TapLingo.git
cd TapLingo
flutter pub get
flutter run
```

On first launch, open **Settings** and paste your Gemini API key. It is stored only on-device.

### Build a release APK

```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

## Project structure

```
lib/
  main.dart
  theme/app_theme.dart
  models/          # LibraryItem, MeaningResult
  services/        # Hive library, Gemini, TTS, secure storage
  providers/       # Riverpod
  screens/         # Home, Reader, Search WebView, Settings
  widgets/         # Cards, empty state, meaning bottom sheet
  utils/           # JS injection, image crop
```

## Privacy & keys

This repo is **public**. Never commit:

- `.env`
- `key.properties`
- `local.properties`
- any Gemini API key

Users always bring their own key via Settings.

## License

MIT — see [LICENSE](LICENSE).
