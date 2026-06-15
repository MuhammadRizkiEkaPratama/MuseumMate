# CLAUDE.md — MuseumMate Build Specification

> **For Claude Code:** This is the single source of truth for the MuseumMate project. Read it fully before writing any code. It contains the complete spec, architecture, data-model contracts, service contracts, a phased build order, role-based agent behavior, and ticket format. Build the app **one phase at a time** following the BUILD PHASES section. After each phase, STOP and ask the user to build & test in Xcode before continuing. Never build all phases in a single pass — incremental build-and-test catches errors early and is faster overall.

---

## HOW TO WORK WITH THIS FILE

The user will drive you phase by phase ("do Phase 0", then "continue to Phase 1", etc.). For each phase:

1. Read the relevant phase section below.
2. Adopt the matching agent role (see AGENT ROLES).
3. Write code that obeys every rule in HARD CONSTRAINTS.
4. After finishing, append a ticket entry to `tickets/TICKET_LOG.md` (create it if missing).
5. STOP and tell the user: *"Phase N complete. Build & test in Xcode, commit, then ask me to continue to Phase N+1."*

Do **not** auto-advance to the next phase without user confirmation. Build-and-test gates between phases prevent errors from compounding.

Write all code, comments, and identifiers in English. You may explain things to the user in Indonesian if they write in Indonesian, but the codebase itself stays English.

---

## 1. PROJECT OVERVIEW

**MuseumMate** is a native iOS app that recognizes and explains artworks from a photo — captured via live camera, imported from the photo library, or selected as a file. After scanning, it displays: title, artist, year, medium, art style, the museum where the original is held, a rich explanation, and fun facts. Art-style classification runs **offline** via Core ML.

**Core differentiator — dual AI pipeline:**
- **Local path (Core ML):** art-style classification, instant, offline.
- **Cloud path (GPT-4o Vision):** precise identification + detailed explanation.

This parallels the reference app (FitSphere), which used Apple Vision (local) + Groq LLM (cloud). MuseumMate must match or exceed FitSphere's engineering quality in every dimension: clean MVVM architecture, two AI paths, a flagship real-time feature, layered persistence (UserDefaults + Firestore), Firebase Auth, and thorough documentation.

**Practical significance:** museum visitors and art students often stand before a work with no context — museum labels are terse, audio guides are costly or unavailable, and in-building internet is frequently poor. MuseumMate gives instant identification and still provides style information offline.

---

## 2. HARD CONSTRAINTS (never violate)

| Component | Value |
|---|---|
| Xcode | 14.3.1 |
| macOS | 13.7.5 Ventura |
| Swift | 5.8 (project file may say 5.0) |
| iOS Deployment Target | 16.4 minimum |
| Architecture | SwiftUI + MVVM |
| Concurrency | async/await, Task, @MainActor |
| Dependencies | SPM only: firebase-ios-sdk (>=10.0.0), GoogleSignIn-iOS (>=7.0.0) |

### Swift 5.8 / Xcode 14 gotchas (the #1 source of build errors — MANDATORY)

1. `@ViewBuilder` is required on any computed `some View` property that contains a `let` binding before the view expression. Without it, the type checker exhausts.
2. Large `VStack` bodies (10+ items with `if`/`if let` branches) MUST be split into multiple `@ViewBuilder` properties, or you get "Extra argument in call".
3. Capturing a `var` inside a `Task` closure is rejected by strict concurrency — copy it to a `let` constant before crossing an actor boundary.
4. `VNConfidence` is `Float`, not `Double` — cast explicitly when comparing against `Double` thresholds.
5. `GENERATE_INFOPLIST_FILE = NO` because the project uses a custom `Info.plist`. Both cannot be active.
6. `Info.plist` must NOT be in Copy Bundle Resources — it is referenced only via the `INFOPLIST_FILE` build setting.
7. Do not use any API newer than iOS 16.4. Use the iOS 16 single-parameter `.onChange(of:) { newValue in }` form, not the iOS 17 two-parameter version.
8. For navigation, use iOS 16 `NavigationStack` / `NavigationLink` patterns, not iOS 17 refinements.

### Resilience rules (graceful degradation — MANDATORY)

- The app MUST NOT crash if `ArtStyleClassifier.mlmodel` is absent → set `isMLAvailable = false`; the GPT-4o path still works.
- The app MUST NOT crash if the network is down → Core ML still returns a style; show a friendly error for the cloud part.
- Never force-unwrap model loading, network responses, or JSON decoding. Use optional binding and typed errors.
- Never hardcode an API key in committed code — read from a config file/.env pattern and document it.

---

## 3. ARCHITECTURE & FOLDER STRUCTURE

```
MuseumMate/
├── MuseumMateApp.swift              # @main, Firebase init, environment objects
├── ContentView.swift                # TabView (5 tabs), onboarding gate
├── Models/
│   ├── Artwork.swift                # GPT-4o identification result
│   ├── ScanResult.swift             # One full scan session
│   ├── ArtStyle.swift               # Art style metadata + color
│   └── UserProfile.swift            # Preferences & onboarding state
├── ViewModels/
│   ├── ScanViewModel.swift          # Orchestrates Core ML -> GPT-4o -> save
│   ├── ExploreViewModel.swift       # Live camera + overlay state
│   ├── HistoryViewModel.swift       # Scan history + filter
│   └── FavoritesViewModel.swift     # Favorites collection
├── Services/
│   ├── VisionService.swift          # GPT-4o Vision API
│   ├── ArtStyleClassifierService.swift  # Offline Core ML classifier
│   ├── CameraService.swift          # AVCaptureSession, frame delivery
│   ├── ScanHistoryStore.swift       # UserDefaults + Firestore
│   ├── FavoritesStore.swift         # UserDefaults + Firestore
│   └── AuthService.swift            # Firebase Auth + Google Sign-In
├── Views/
│   ├── Explore/  (ExploreView, CameraPreviewView, StyleOverlayView)
│   ├── Scan/     (ScanView, ImagePicker, ArtworkDetailView)
│   ├── History/  (HistoryView)
│   ├── Favorites/(FavoritesView)
│   ├── Profile/  (ProfileView)
│   ├── Auth/     (RootView, AuthView)
│   ├── Onboarding/(OnboardingView)
│   └── Shared/   (EmptyStateView, LoadingView)
├── Extensions/
│   ├── Color+Theme.swift            # Museum theme tokens + Color(hex:)
│   └── View+Extensions.swift        # card(), sectionLabel(), if() helpers
├── Resources/
│   ├── ArtStyleClassifier.mlmodel   # Added in Phase 5
│   └── PrivacyInfo.xcprivacy
├── GoogleService-Info.plist
└── Info.plist
```

### Data flow

**Flow A — Scan from photo:**
1. User selects a photo or captures from camera.
2. `ScanViewModel.scan(image:)`: (a) Core ML classify -> `localStyle` instantly; (b) show it provisionally; (c) encode JPEG base64; (d) `VisionService.identifyArtwork` -> `Artwork`; (e) combine into `ScanResult`; (f) save image to disk + `ScanResult` to store; (g) sync to Firestore.
3. Navigate to `ArtworkDetailView`.

**Flow B — Live overlay:**
1. `CameraService` delivers frames, throttled (~every 15th frame).
2. `ArtStyleClassifierService.classify(cgImage:)` per delivered frame.
3. `StyleOverlayView` shows a live style badge that updates in real time.
4. A "Scan This" button captures the current frame and runs Flow A.

---

## 4. DATA MODELS (binding contracts — do not rename fields)

### Artwork.swift
```swift
import Foundation

struct Artwork: Codable, Identifiable {
    var id = UUID()
    var title: String
    var artist: String
    var year: String          // String — may be "c. 1500"
    var medium: String
    var style: String
    var location: String      // museum/gallery holding the original
    var description: String
    var funFacts: [String]
    var confidence: Double

    enum CodingKeys: String, CodingKey {
        case title, artist, year, medium, style
        case location, description, funFacts = "fun_facts", confidence
    }
}
```

### ScanResult.swift
```swift
import Foundation

struct ScanResult: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var imageFileName: String
    var localStyle: String        // Core ML result
    var localConfidence: Double
    var artwork: Artwork?         // GPT-4o result (nil when offline)
    var isFavorite: Bool = false
}

extension ScanResult {
    var hasCloudData: Bool { artwork != nil }
    var displayTitle: String { artwork?.title ?? "Unknown Artwork (\(localStyle))" }
}
```

### ArtStyle.swift
```swift
import SwiftUI

struct ArtStyle: Identifiable {
    let id = UUID()
    let name: String
    let period: String
    let shortDescription: String
    let accentColorHex: String
    var accentColor: Color { Color(hex: accentColorHex) }
}

struct ArtStyleLibrary {
    // 8 styles — MUST match the Create ML dataset folder labels exactly
    static let all: [ArtStyle] = [
        ArtStyle(name: "Impressionism", period: "1860s-1880s",
                 shortDescription: "Quick brushwork, focus on light and momentary impressions.",
                 accentColorHex: "#5B8DEF"),
        ArtStyle(name: "Baroque", period: "1600s-1750s",
                 shortDescription: "Dramatic, strong light-dark contrast, grandeur.",
                 accentColorHex: "#C9A227"),
        ArtStyle(name: "Renaissance", period: "1400s-1600s",
                 shortDescription: "Proportion, perspective, classical realism.",
                 accentColorHex: "#A0522D"),
        ArtStyle(name: "Cubism", period: "1907-1920s",
                 shortDescription: "Geometric forms, multiple viewpoints at once.",
                 accentColorHex: "#E07A5F"),
        ArtStyle(name: "Surrealism", period: "1920s-1950s",
                 shortDescription: "Dreams, the subconscious, illusion.",
                 accentColorHex: "#8E7CC3"),
        ArtStyle(name: "Pop Art", period: "1950s-1970s",
                 shortDescription: "Popular culture, bold colors, iconic imagery.",
                 accentColorHex: "#EF476F"),
        ArtStyle(name: "Romanticism", period: "1800s-1850s",
                 shortDescription: "Emotion, wild nature, the sublime.",
                 accentColorHex: "#06A77D"),
        ArtStyle(name: "Realism", period: "1840s-1880s",
                 shortDescription: "Everyday life depicted as it is.",
                 accentColorHex: "#6C757D"),
    ]
    static func style(named name: String) -> ArtStyle? {
        all.first { $0.name.lowercased() == name.lowercased() }
    }
}
```

### UserProfile.swift (pattern)
`ObservableObject` with `@Published` fields persisted to UserDefaults (each `didSet` writes the key), plus optional Firestore sync. Keep it lean: `name`, `email`, `hasCompletedOnboarding`, `joinDate`. Mirror the FitSphere UserProfile pattern (UserDefaults-backed init + `syncToFirestore()` + `loadFromFirestore(uid:)`).

### Color+Theme.swift (museum palette + hex init)
```swift
import SwiftUI

extension Color {
    static let appBackground    = Color(hex: "#12100E")
    static let appSurface       = Color(hex: "#1E1B18")
    static let appSurfaceUp     = Color(hex: "#2A2620")
    static let appAccent        = Color(hex: "#C9A227")  // museum gold
    static let appAccentMuted   = Color(hex: "#5C4A1A")
    static let appTextPrimary   = Color.white
    static let appTextSecondary = Color(hex: "#B8AE9E")
    static let appTextMuted     = Color(hex: "#6B6258")
    static let appDanger        = Color(hex: "#E5484D")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
```

---

## 5. SERVICE CONTRACTS

### VisionService.swift (cloud path) — mirror FitSphere's GroqService

```swift
import UIKit

class VisionService {
    private let apiKey = "YOUR_OPENAI_API_KEY"   // read from config; never commit
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-4o"

    func identifyArtwork(imageBase64: String) async throws -> Artwork
    // 1. Build /v1/chat/completions payload with the image as a base64 data URL.
    // 2. Use the system prompt below (strict JSON).
    // 3. Decode: strip markdown fences, then JSONDecoder; on failure, extract the
    //    first "{" ... last "}" substring and retry; otherwise throw.

    private func stripMarkdown(_ s: String) -> String { /* drop ```json / ``` wrappers */ }
}

enum VisionError: LocalizedError {
    case invalidURL, invalidResponse, emptyResponse, rateLimited
    case httpError(Int, String)
    var errorDescription: String? { /* human-friendly messages; 429 -> rate limited */ }
}
```

Image encoding helper: convert `UIImage` -> JPEG `compressionQuality: 0.6` -> base64. Artworks do not need full resolution; smaller payloads are faster and cheaper.

OpenAI request body shape:
```json
{
  "model": "gpt-4o",
  "max_tokens": 900,
  "messages": [
    {"role": "system", "content": "<SYSTEM PROMPT BELOW>"},
    {"role": "user", "content": [
      {"type": "text", "text": "Identify this artwork."},
      {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,<BASE64>"}}
    ]}
  ]
}
```

System prompt (exact):
```
You are an art historian. Identify the artwork in the image. Respond ONLY with
valid JSON — no markdown, no extra text:
{
  "title": "...",
  "artist": "...",
  "year": "...",
  "medium": "...",
  "style": "...",
  "location": "the museum or gallery currently holding the original",
  "description": "2-3 paragraph rich explanation: history, meaning, technique",
  "fun_facts": ["fact 1", "fact 2", "fact 3"],
  "confidence": 0.0 to 1.0
}
If you cannot identify it, set title to "Unknown" and a low confidence, but still
fill style and a general description so the result is still useful.
```

### ArtStyleClassifierService.swift (local path) — mirror FitSphere's ExerciseClassifierService

```swift
import Vision
import CoreML
import CoreGraphics

class ArtStyleClassifierService: ObservableObject {
    @Published var detectedStyle = "unknown"
    @Published var confidence: Double = 0.0
    @Published var isMLAvailable = false
    private var mlModel: VNCoreMLModel?

    init() { loadMLModel() }

    func loadMLModel() {
        guard
            let url = Bundle.main.url(forResource: "ArtStyleClassifier", withExtension: "mlmodelc"),
            let core = try? MLModel(contentsOf: url),
            let vn = try? VNCoreMLModel(for: core)
        else { isMLAvailable = false; return }   // graceful: app still runs
        mlModel = vn
        isMLAvailable = true
    }

    func classify(cgImage: CGImage) async {
        guard let mlModel else { return }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNCoreMLRequest(model: mlModel)
        do {
            try handler.perform([request])
            guard let top = request.results?.first as? VNClassificationObservation else { return }
            let style = top.identifier.replacingOccurrences(of: "_", with: " ")
            let conf = Double(top.confidence)   // VNConfidence is Float -> cast
            await MainActor.run {
                self.detectedStyle = style
                self.confidence = conf
            }
        } catch { /* ignore; keep previous values */ }
    }
}
```

### Store pattern (ScanHistoryStore & FavoritesStore)

```swift
import Foundation
import FirebaseFirestore

@MainActor
class ScanHistoryStore: ObservableObject {
    @Published var scans: [ScanResult] = []
    private let key = "museummate_scans"
    var firestoreUID: String?
    private let db = Firestore.firestore()

    func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ScanResult].self, from: data) {
            scans = decoded
        }
    }
    func save(_ result: ScanResult) {
        scans.insert(result, at: 0)
        persist()
        syncToFirestore(result)
    }
    func delete(_ result: ScanResult) {
        scans.removeAll { $0.id == result.id }
        persist()
        // also delete from Firestore by id.uuidString
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(scans) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    private func syncToFirestore(_ result: ScanResult) {
        guard let uid = firestoreUID,
              let data = try? JSONEncoder().encode(result),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        db.collection("users").document(uid)
          .collection("scans").document(result.id.uuidString)
          .setData(dict, merge: true)
    }
}
```
`FavoritesStore` follows the same shape with key `museummate_favorites` and Firestore subcollection `favorites`.

### AuthService.swift
Firebase Auth (email/password + Google Sign-In). Standard pattern: `@Published currentUser`, `signUp`, `signIn`, `signInWithGoogle`, `signOut`, and an `addStateDidChangeListener` that wires `firestoreUID` into the stores on login. Reuse the FitSphere AuthService almost verbatim; change Firestore collection names to MuseumMate's.

### Image storage on disk
Save scanned images as JPEG into the app's Documents directory; store only the filename in `ScanResult.imageFileName`. Provide helpers `saveImage(_:) -> String` and `loadImage(named:) -> UIImage?`.

### ScanViewModel.swift (orchestration)

```swift
import SwiftUI

@MainActor
class ScanViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var currentResult: ScanResult?
    @Published var errorMessage: String?

    let classifier = ArtStyleClassifierService()
    private let vision = VisionService()

    func scan(image: UIImage, store: ScanHistoryStore) async {
        isScanning = true
        errorMessage = nil

        // (a) LOCAL: instant style guess (no-op if model absent)
        if let cg = image.cgImage { await classifier.classify(cgImage: cg) }
        let localStyle = classifier.detectedStyle
        let localConf  = classifier.confidence

        // save image to disk
        let fileName = saveImageToDisk(image)   // helper

        // (b) CLOUD: precise identification (may fail offline)
        var artwork: Artwork?
        do {
            let base64 = jpegBase64(image, quality: 0.6)   // helper
            artwork = try await vision.identifyArtwork(imageBase64: base64)
        } catch {
            errorMessage = "Could not reach the identification service. Style detected offline."
        }

        let result = ScanResult(
            date: Date(), imageFileName: fileName,
            localStyle: localStyle, localConfidence: localConf, artwork: artwork
        )
        store.save(result)
        currentResult = result
        isScanning = false
    }
}
```

### ImagePicker.swift (PhotosUI)
A `UIViewControllerRepresentable` wrapping `PHPickerViewController` (single image, `.images` filter). On pick, load the `UIImage` and return it via a binding/closure. Provide a separate camera capture path using `UIImagePickerController` (sourceType `.camera`) for direct capture in the Scan tab.

---

## 6. BUILD PHASES (do in order; build & test after each)

### PHASE 0 — Project setup
- New Xcode SwiftUI project, iOS 16.4 target, name MuseumMate.
- Set `GENERATE_INFOPLIST_FILE = NO`; add custom `Info.plist`.
- Add SPM: firebase-ios-sdk, GoogleSignIn-iOS.
- Add `GoogleService-Info.plist` from the Firebase console.
- Create the folder groups from Section 3.
- Add `Color+Theme.swift` (Section 4) and `View+Extensions.swift` (`card()`, `sectionLabel()`, `if()`).
- Info.plist permissions: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`.
- **Checkpoint:** builds & runs; shows an empty screen.

### PHASE 1 — Auth & navigation shell
- `AuthService.swift` (Firebase Auth + Google, `users` collection).
- `RootView.swift` + `AuthView.swift` (MuseumMate branding).
- `MuseumMateApp.swift` (FirebaseApp.configure + environment objects).
- `ContentView.swift` TabView with 5 tabs (Explore, Scan, History, Favorites, Profile) — placeholders for now.
- `OnboardingView.swift` (single screen for now).
- **Checkpoint:** sign up / sign in works -> TabView appears -> all 5 tabs tappable.

### PHASE 2 — Data models
- `Artwork`, `ScanResult`, `ArtStyle` + `ArtStyleLibrary`, `UserProfile` (Section 4).
- **Checkpoint:** project builds; models instantiate in a preview.

### PHASE 3 — Cloud path (GPT-4o) — DO THIS BEFORE CORE ML
- `VisionService.swift` (Section 5).
- `ScanHistoryStore.swift` (UserDefaults + Firestore).
- `ScanViewModel.swift` (GPT-4o path; the classify call is a safe no-op when `isMLAvailable == false`).
- `ImagePicker.swift` (PhotosUI + camera capture).
- `ScanView.swift` (pick/capture photo + Scan button).
- `ArtworkDetailView.swift` (all Artwork fields, nicely laid out).
- `LoadingView.swift` (spinner during the GPT call).
- **Checkpoint:** pick a famous artwork photo -> title, artist, location, explanation appear and are saved in History. Test with Mona Lisa / Starry Night (GPT-4o is most accurate there).

### PHASE 4 — History & Favorites
- `HistoryViewModel` + `HistoryView` (list of ScanResults with thumbnails loaded from disk).
- `FavoritesStore` + `FavoritesViewModel` + `FavoritesView`.
- Favorite toggle in `ArtworkDetailView`.
- **Checkpoint:** scans appear in History, can be favorited, favorites show in the Favorites tab, all data survives an app restart.

### PHASE 5 — Local path (Core ML)
- (User trains the model in Create ML — see Section 8 — and drops `ArtStyleClassifier.mlmodel` into Resources.)
- `ArtStyleClassifierService.swift` (Section 5, with graceful fallback).
- Wire into `ScanViewModel`: run Core ML BEFORE the GPT call so the UI shows an instant style guess.
- Show `localStyle` + confidence in `ArtworkDetailView`, styled with the matching `ArtStyle.accentColor`.
- **Checkpoint:** on scan, a style appears instantly; turn off Wi-Fi -> Core ML still returns a style and the app shows a friendly cloud-error.

### PHASE 6 — Live camera overlay (flagship feature)
- `CameraService.swift` (throttled frame delivery; reuse FitSphere's AVCaptureSession setup, stripped of pose logic).
- `CameraPreviewView.swift` (UIViewRepresentable + simulator placeholder).
- `ExploreViewModel.swift` (frame -> Core ML classify).
- `StyleOverlayView.swift` (real-time style badge using ArtStyle colors).
- `ExploreView.swift` (camera + overlay + "Scan This" button).
- "Scan This" -> current frame -> Flow A.
- **Checkpoint:** point the camera at a painting -> the badge updates in real time; "Scan This" -> full detail view.

### PHASE 7 — Polish & Profile
- `ProfileView` (account info, scan count, sign out, privacy).
- `EmptyStateView` on every empty tab.
- Confidence indicator (ring/bar) in the detail view.
- Fun-facts card.
- Robust error handling (no network, GPT failure, rate limit).
- 3-screen onboarding.
- Smooth transitions/animations consistent with the museum theme.
- **Checkpoint:** the app feels complete and professional; no empty tab without an empty state.

### PHASE 8 — Testing & docs
- Run the test cases (Section 9); record expected vs actual, bugs, and fixes.
- Write a complete README (architecture, environment constraints, design system, dual-AI integration points) in the FitSphere style.
- Finalize `tickets/TICKET_LOG.md`.
- **Checkpoint:** every Definition of Done item is checked.

---

## 7. AGENT ROLES (adopt per phase)

When working a phase, adopt the matching role. If the user keeps separate `.claude/agents/*.md` files, those define the same roles; the core behavior is here.

- **architect** — Phases 0, 2. MVVM structure, model & service-contract definitions. Leave `// TODO(agent)` stubs for implementations.
- **vision-integration** — Phases 3, 4. VisionService (GPT-4o), networking, base64, JSON parsing, ScanViewModel cloud path, stores.
- **coreml** — Phase 5. ArtStyleClassifierService, ScanViewModel local path, graceful fallback, accuracy notes.
- **ui-ux** — Phases 1, 3–7. All SwiftUI views, 5 tabs, live overlay, detail view, onboarding, design system.
- **qa** — end of each phase. Test cases, edge cases, graceful-degradation checks, bug log.

Collaboration narrative (for the report): architect defines the models -> vision-integration and coreml consume them -> ui-ux assembles the screens -> qa verifies each checkpoint and files bugs back to the owning role.

---

## 8. DATASET & CORE ML TRAINING (manual, for Phase 5)

This component is lightweight and built into macOS — unlike TensorFlow, there is no install, no conda, no metal plugin.

- Source: WikiArt Art Movements/Styles (Kaggle: `sivarazadi/wikiart-art-movementsstyles`).
- Use the 8 styles from `ArtStyleLibrary`, 300–500 images per class, balanced.
- Folder name = model label = must match `ArtStyleLibrary` names (underscores are normalized to spaces at runtime in the classifier).
- Structure: `ArtDataset/Training/<StyleName>/*.jpg`.
- Open Xcode -> Open Developer Tool -> Create ML -> Image Classification (lightest template, supported since macOS 10.14 — safe on Ventura).
- Drag the Training folder, enable augmentation (crop, rotate, blur, flip, expose, noise), iterations 20–25, Train.
- Target accuracy 75–88% (art style is inherently ambiguous — this is normal and demo-ready).
- Export `ArtStyleClassifier.mlmodel` -> drag into Resources in Xcode -> check Target Membership. Xcode compiles it to `.mlmodelc` at build time.

Record iteration-1 accuracy (no augmentation) vs iteration-2 (with augmentation) for the report's Testing section.

---

## 9. TEST CASES (Phase 8 / report material)

| # | Test | Expected |
|---|---|---|
| 1 | Scan Mona Lisa | Correct title & artist, location = Louvre |
| 2 | Scan Starry Night | Style = Post-Impressionism, location = MoMA |
| 3 | Core ML offline (Wi-Fi off) | Still returns a style; friendly cloud error |
| 4 | Blurry / non-art photo | Low confidence, no crash |
| 5 | Live overlay | Badge updates as the camera moves |
| 6 | Favorite & unfavorite | State persists across restart |
| 7 | History persistence | Old scans appear after restart |
| 8 | Firestore sync | New session login -> data appears |
| 9 | Sign out / sign in | Auth flow correct |
| 10 | Core ML accuracy | Iteration 1 vs 2 (augmentation) — number rises |

---

## 10. TICKET FORMAT (write to tickets/TICKET_LOG.md each phase)

This is the "agent tickets & workflow documentation" the course requires. Fill it honestly during development.

```
Ticket #[NUMBER]
Assigned to : [architect | vision-integration | coreml | ui-ux | qa]
Phase       : [Phase 0–8]
Task        : [one sentence]
Status      : [ Todo | In Progress | Completed | Blocked ]
Iterations  : [how many revisions]
Collaboration: [which role receives the handoff next]
Notes       : [results, problems, decisions, accuracy numbers]
```

Filled example:
```
Ticket #003
Assigned to : vision-integration
Phase       : Phase 3
Task        : Implement VisionService + ScanViewModel cloud path
Status      : Completed
Iterations  : 2
Collaboration: Handed off to ui-ux (ArtworkDetailView) and qa
Notes       : Iter 1 — GPT replied with markdown fences. Iter 2 — added
              stripMarkdown + "{...}" extraction fallback. JPEG compression 0.6.
              Verified Mona Lisa: title/artist/location (Louvre) correct.
```

---

## 11. USER SETUP (outside coding)

- OpenAI API key (platform.openai.com, top up ~$5). Read from config; never commit.
- New Firebase project: Auth (email + Google), Firestore (test mode). Download `GoogleService-Info.plist`.
- Build & run in Xcode (VS Code for editing, Xcode for compile/simulator).
- NEW Swift files created in VS Code must be dragged into the Xcode project once (Xcode 14 does not auto-sync folders).

---

## 12. REPORT NOTE (read carefully)

The written report (70%) MUST be written by the user, word by word, with no AI-generated text — an explicit course rule. This file exists to BUILD the app and to produce raw material (architecture, tickets, test results). Do NOT write the report for the user. Help build the app and document the process only.

---

## DEFINITION OF DONE

- [ ] App builds & runs on a physical iPhone (iOS 16.4+) with no errors.
- [ ] Live camera overlay shows real-time art style.
- [ ] Import/capture photo -> scan -> full GPT-4o detail.
- [ ] Core ML classifier returns a label + confidence.
- [ ] History persists (UserDefaults + Firestore).
- [ ] Favorites save & remove.
- [ ] Firebase Auth (email + Google) works.
- [ ] First-launch onboarding.
- [ ] tickets/TICKET_LOG.md is filled.
- [ ] Complete README.
- [ ] Source code compiles from a fresh clone.
