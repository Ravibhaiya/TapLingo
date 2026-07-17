# TapLingo

Read novels & manga from any free website. Tap any word for an instant simple + Hinglish meaning — powered by **Google Gemini**.

**Platform:** Android only  
**AI:** Gemini only (bring your own API key)

## Features

- **Novel / Manga tabs** — one library, switch with a single tap
- **Add from the web** — search Google in-app, browse freely, save any chapter/page
- **Novel tap-to-define** — JS injection defeats `user-select` blocks; double-tap a word, triple-tap for the whole sentence
- **Manga vision define** — double/triple-tap on a panel; screenshot + crop + coordinates go to Gemini Vision
- **Kid-simple explanations** + **Hinglish** translations
- **Read aloud** via device TTS
- **Resume where you left off** (URL + scroll for novels, URL for manga)
- **Secure API key storage** (`flutter_secure_storage`) — never commit keys

### Tap cheat-sheet

| Gesture | What you get |
|--------|----------------|
| **Double-tap** | Meaning of the **word** (+ contextual use, Hinglish, example) |
| **Triple-tap** | Meaning of the whole **sentence** / dialogue line (+ Hinglish) |

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
