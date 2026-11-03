# MuseumMate

**An iOS app that recognizes artworks through your camera and tells you the story behind them.**

Point your phone at a painting. MuseumMate identifies the artist and the art style using on-device machine learning, then uses a cloud AI pipeline to generate the artwork's details, its creation story, and a short biography of the artist. It also shows nearby museums and a daily feed of art history.

Built solo as a final project during an exchange program at Nanjing Xiaozhuang University (2+2 programme with Universitas Islam Indonesia).

![Platform](https://img.shields.io/badge/platform-iOS%2016.4%2B-blue)
![Swift](https://img.shields.io/badge/Swift-SwiftUI-orange)
![Architecture](https://img.shields.io/badge/architecture-MVVM-lightgrey)
![ML](https://img.shields.io/badge/ML-Core%20ML%20%2B%20Vision-green)

---

## Table of Contents

1. [Features](#features)
2. [Screenshots](#screenshots)
3. [How It Works](#how-it-works)
4. [Tech Stack](#tech-stack)
5. [Project Structure](#project-structure)
6. [Getting Started](#getting-started)
7. [Configuration and Secrets](#configuration-and-secrets)
8. [Machine Learning Models](#machine-learning-models)
9. [Security Notes](#security-notes)
10. [Known Limitations](#known-limitations)
11. [Roadmap](#roadmap)
12. [Author](#author)

---

## Features

**Scan**
- Unified scan tab with a live camera view and a swipe-up sheet to import photos from the library.
- On-device artist identification for 12 artists and art-style classification for 8 styles.
- Detailed artwork page: title, artist, period, metadata, creation story, and a quote.

**Discover**
- Dashboard with a hero artwork pulled from The Met Museum API.
- "On This Day" feed of art history events.
- Birthday artist: highlights artists born on today's date.
- Artists tab with search, Wikipedia portraits, and AI-written biographies.
- Nearby museums based on your GPS location.

**Collection**
- "Art Pieces" gallery: a two-column grid of everything you have scanned.
- Scan history and personal memories stored per user.

**Account**
- Sign in with Firebase Authentication and Google Sign-In.
- First-time profile setup, including a birthday picker.
- Per-user data stored in Cloud Firestore.

---

## Screenshots

> Add screenshots to a `docs/screenshots/` folder and link them here.

| Dashboard | Scan | Artwork Detail | Artists |
|:---:|:---:|:---:|:---:|
| _coming soon_ | _coming soon_ | _coming soon_ | _coming soon_ |

---

## How It Works

MuseumMate combines **on-device ML** (fast, private, works offline) with a **cloud AI pipeline** (rich text content).

```
Camera / Photo
      │
      ▼
┌───────────────────────────────┐
│ On-device (Core ML + Vision)  │
│  • ArtistClassifier  (12)     │
│  • ArtStyleClassifier (8)     │
└──────────────┬────────────────┘
               ▼
┌───────────────────────────────┐
│ Cloud AI pipeline (3 stages)  │
│  1. Qwen-VL  → name only      │
│  2. DeepSeek → full details   │
│  3. Enrichment (story, quote) │
└──────────────┬────────────────┘
               ▼
   Artwork detail  +  Collection
   (Firestore)        (local history)
```

1. **Vision stage.** Qwen-VL (Alibaba DashScope) looks at the photo and returns only the artwork name. DeepSeek cannot read images, so a vision model has to go first.
2. **Detail stage.** DeepSeek takes that name and generates the full detail: artist, period, metadata, creation story, and quote.
3. **Context stage.** Wikipedia supplies artist portraits, The Met API supplies dashboard content, and OpenStreetMap Overpass (with CoreLocation) supplies nearby museums.

---

## Tech Stack

| Area | Technology |
|---|---|
| Language / UI | Swift, SwiftUI |
| Architecture | MVVM |
| On-device ML | Core ML, Vision |
| Cloud AI | Qwen-VL (Alibaba DashScope), DeepSeek |
| Auth and database | Firebase Authentication, Cloud Firestore, Google Sign-In |
| External data | The Metropolitan Museum of Art API, Wikipedia, OpenStreetMap Overpass |
| System frameworks | CoreLocation, Speech, AVFoundation |
| Minimum OS | iOS 16.4 |

---

## Project Structure

```
MuseumMate/
├── MuseumMate.xcodeproj
├── MuseumMate/
│   ├── MuseumMateApp.swift          # App entry point
│   ├── Models/                      # Data models (ScanResult, UserProfile, MemoryPhoto, ...)
│   ├── Services/                    # AppConfig, AuthService, stores, audio, discovery services
│   ├── ViewModels/                  # Dashboard, UnifiedScan, ArtistDiscovery, ...
│   ├── Views/
│   │   ├── Auth/                    # Sign-in and profile setup
│   │   ├── Dashboard/               # Home feed, museum detail
│   │   ├── Explore/                 # Style overlay
│   │   └── Scan/                    # Camera, artwork detail
│   └── Resources/
│       ├── ArtistClassifier.mlmodel
│       └── ArtStyleClassifier.mlpackage
└── tickets/                         # Development tickets / task notes
```

---

## Getting Started

### Requirements

- macOS with **Xcode** (iOS 16.4 SDK or newer)
- **Git LFS** (the style classifier weights are about 164 MB)
- A DeepSeek API key and a Qwen (DashScope) API key
- A Firebase project of your own

### 1. Clone with Git LFS

```bash
git lfs install
git clone https://github.com/MuhammadRizkiEkaPratama/MuseumMate.git
cd MuseumMate
```

If you cloned before installing LFS, run `git lfs pull` to download the model weights.

### 2. Add your secrets

This repository does **not** include any API keys or Firebase configuration. See [Configuration and Secrets](#configuration-and-secrets).

### 3. Build and run

Open `MuseumMate.xcodeproj` in Xcode, choose a simulator or a physical device, and press **Run**. Camera features need a physical device.

---

## Configuration and Secrets

Two files are required locally and are intentionally listed in `.gitignore`:

| File | Purpose |
|---|---|
| `Secrets.plist` | AI provider API keys |
| `GoogleService-Info.plist` | Firebase configuration (download from your Firebase console) |

Create `Secrets.plist` in the app target with these string keys:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>DeepSeekAPIKey</key>
    <string>YOUR_DEEPSEEK_API_KEY</string>
    <key>QwenAPIKey</key>
    <string>YOUR_QWEN_API_KEY</string>
</dict>
</plist>
```

- DeepSeek key: <https://platform.deepseek.com/api_keys>
- Qwen key: <https://bailian.console.alibabacloud.com> (Model Studio)

`AppConfig.swift` reads these values at runtime. If a key is missing, the app still builds and runs, but the cloud AI features are disabled.

---

## Machine Learning Models

| Model | Task | Classes | Notes |
|---|---|---|---|
| `ArtistClassifier` | Artist identification | 12 | Van Gogh, Degas, Picasso, Renoir, Gauguin, Goya, Rembrandt, Titian, Botticelli, da Vinci, Dali, Raphael. About 66% validation accuracy. |
| `ArtStyleClassifier` | Art-style classification | 8 | ViT-based. Weights are stored with Git LFS. |

Both models run on-device through Core ML and Vision, so inference needs no network connection and does not send the photo anywhere.

---

## Security Notes

- No API key is hardcoded. Keys are loaded at runtime from the gitignored `Secrets.plist`.
- The repository history was scanned for leaked keys before publishing.
- `Secrets.plist` is bundled into the app at build time, so keys can be extracted from a built app. This is acceptable for a class project. For a public release (TestFlight or App Store), route AI requests through a backend proxy so keys never ship in the client.
- The app requests camera, location, and speech permissions. Location is used only to find nearby museums.

---

## Known Limitations

- `ArtistClassifier` has limited accuracy (about 66% on validation) and only covers 12 artists. Treat its output as an estimate.
- The AI-generated text (creation story, biography, quote) can contain mistakes. Verify important facts before relying on them.
- Cloud features depend on third-party APIs and need valid keys and an internet connection.
- No automated test suite yet.

---

## Roadmap

- [ ] Expand the artist classifier with more artists and more training data.
- [ ] Move AI requests behind a backend proxy.
- [ ] Add unit tests for view models and services.
- [ ] Add screenshots and a demo video to this README.
- [ ] Offline caching for the dashboard and collection.

---

## Author

**Muhammad Rizki Eka Pratama**
Software Engineering, Universitas Islam Indonesia × Nanjing Xiaozhuang University

GitHub: [@MuhammadRizkiEkaPratama](https://github.com/MuhammadRizkiEkaPratama)
