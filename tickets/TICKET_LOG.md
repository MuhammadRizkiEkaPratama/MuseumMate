# MuseumMate — Ticket Log

---

```
Ticket #001
Assigned to : architect
Phase       : Phase 0
Task        : Project setup — build settings, custom Info.plist, SPM dependencies, folder structure, design-system foundation
Status      : Completed
Iterations  : 1
Collaboration: Handed off to ui-ux (Phase 1 — Auth & navigation shell)
Notes       : Started from the user-created Xcode 14.3.1 SwiftUI template.
              Switched GENERATE_INFOPLIST_FILE to NO with a custom
              MuseumMate/Info.plist (camera + photo library usage strings,
              portrait-first, forced Dark UI style, dark launch screen color).
              Removed CLAUDE.md from Copy Bundle Resources — it was being
              shipped inside the app bundle. Added SPM dependencies:
              firebase-ios-sdk pinned to 10.0.0 ..< 10.23.0 (Firebase 10.23+
              requires Xcode 15.2; this project is locked to Xcode 14.3.1)
              and GoogleSignIn-iOS 7.x. Created the full MVVM folder/group
              layout (Models, ViewModels, Services, Views/{Explore, Scan,
              History, Favorites, Profile, Auth, Onboarding, Shared},
              Extensions, Resources). Design system: Color+Theme.swift
              (museum palette + Color(hex:)) and View+Extensions.swift
              (card(), sectionLabel(), if(), PressableButtonStyle 0.97 scale,
              fadeSlideIn entrance honoring Reduce Motion, single
              Animation.museumSpring vocabulary, Haptics helpers).
              AccentColor asset set to museum gold #C9A227. Added
              PrivacyInfo.xcprivacy (UserDefaults, reason CA92.1).
              ContentView is a themed serif splash placeholder until the
              Phase 1 tab shell. GoogleService-Info.plist is gitignored —
              the user must download it from the Firebase console and drag
              it into the Xcode project during Phase 1.
```

---

> **Scope change before Phase 1:** the user temporarily removed the
> firebase-ios-sdk and GoogleSignIn-iOS SPM packages to speed up
> development. AuthService and the stores are therefore local-only stubs;
> every Firebase/Firestore/Google touch point is marked
> `// TODO: Firebase — wire in Phase 7`. No Firebase imports anywhere.

```
Ticket #002
Assigned to : ui-ux / architect
Phase       : Phase 1
Task        : Stub auth, UserProfile, RootView gate, AuthView, 3-screen onboarding, 5-tab shell
Status      : Completed
Iterations  : 1
Collaboration: Handed off to architect (Phase 2 models)
Notes       : AuthService is a local UserDefaults stub (isAuthenticated,
              currentUserName/Email, isLoading, errorMessage) with 0.8s
              simulated latency; signInWithGoogle is a UI-only stub.
              UserProfile persists name/email/hasCompletedOnboarding/
              scanCount/joinDate via @Published didSet. AuthView: sliding
              gold-underline mode switcher (not a segmented control),
              @FocusState glowing fields, inline validation hints (no
              alerts), staggered entrances. Onboarding: 3 pages, custom
              capsule dots, sets hasCompletedOnboarding on finish. RootView
              gate order: onboarding → auth → main, cross-fade. ContentView
              TabView: flat appBackground bar, gold tint, no separator,
              gallery SF Symbols, light haptic on tab change.
```

```
Ticket #003
Assigned to : architect
Phase       : Phase 2
Task        : Artwork, ScanResult, ArtStyle + ArtStyleLibrary, ImageStore
Status      : Completed
Iterations  : 1
Collaboration: Handed off to vision-integration (Phase 3)
Notes       : Artwork uses the exact CodingKeys contract (fun_facts →
              funFacts, year as String). ScanResult adds thumbnailFileName
              plus displayTitle/displayStyle/formattedDate helpers. ArtStyle
              gains an `era` grouping (Classical / 19th Century / Modern)
              and a tolerant style(named:) lookup that maps richer cloud
              labels like "Post-Impressionism" back to a library style.
              ImageStore writes a full JPEG + center-cropped 300×300
              thumbnail to Documents under UUID names, with load/delete.
```

```
Ticket #004
Assigned to : vision-integration / ui-ux
Phase       : Phase 3
Task        : VisionService (GPT-4o), ScanViewModel, stores, ScanView, ArtworkDetailView, History, Favorites
Status      : Completed
Iterations  : 1
Collaboration: Handed off to coreml (Phase 4) and qa
Notes       : VisionService posts gpt-4o (temperature 0.3, max_tokens 900),
              base64 JPEG at 0.55. JSON hardening: stripMarkdown → direct
              decode → first-{…}-last-} substring fallback → typed
              VisionError (429 → rateLimited, missing key surfaced). API key
              read at runtime from Secrets.plist/Info.plist via AppConfig —
              never committed. ScanViewModel drives a ScanPhase state
              machine (idle → detectingStyle → identifyingArtwork →
              complete/failed) and always saves a result (partial on cloud
              failure). ScanHistoryStore = UserDefaults, newest-first,
              bumps scanCount. FavoritesStore is a live Combine projection
              of history where isFavorite == true. ArtworkDetailView: hero
              + vignette, museum-label identity card, confidence gauge that
              animates from 0, catalog copy, em-dash fun facts, favorite
              spring-pop + ShareLink. History list groups by recency past
              5 items with swipe-to-delete confirmation; Favorites is a
              2-column vignette grid. Both have empty states.
```

```
Ticket #005
Assigned to : coreml
Phase       : Phase 4
Task        : ArtStyleClassifierService + wire local path into ScanViewModel
Status      : Completed
Iterations  : 1
Collaboration: Handed off to ui-ux (Phase 5) and qa
Notes       : VNCoreMLModel loaded from ArtStyleClassifier.mlmodelc;
              absent model → isMLAvailable = false and classify() is a safe
              no-op (no crash, GPT path intact). VNConfidence (Float) cast
              to Double; identifier underscores normalized to spaces.
              Runs off the main actor (non-isolated async) and publishes on
              MainActor. ScanViewModel runs it FIRST so a style preview is
              available before the 2–3s cloud call returns. Model file to be
              trained in Create ML and dropped into Resources later.
```

```
Ticket #006
Assigned to : ui-ux
Phase       : Phase 5
Task        : CameraService + Explore live overlay (flagship feature)
Status      : Completed
Iterations  : 1
Collaboration: Handed off to ui-ux (Phase 6) and qa
Notes       : CameraService: AVCaptureSession, VGA preset, continuous
              autofocus + low-light boost, every-15th-frame delivery (~2fps)
              as CGImage, keeps latest frame for "Scan This". ExploreViewModel
              streams frames into the classifier (drops frames while busy)
              and mirrors permission state via Combine. CameraPreviewView
              wraps AVCaptureVideoPreviewLayer with a Simulator placeholder.
              StyleOverlayView: blurred pill, accent stripe, cross-fade on
              style change. ExploreView: edge-to-edge camera, serif
              watermark, gold "Scan This" (medium haptic) → full pipeline →
              detail, inline camera-denied state with Open Settings.
```

```
Ticket #007
Assigned to : ui-ux / qa
Phase       : Phase 6
Task        : ProfileView + full polish pass; verified build
Status      : Completed
Iterations  : 2
Collaboration: Handed back to user for in-Xcode testing before Phase 7 (Firebase)
Notes       : ProfileView: serif initial avatar, scans/favorites/styles
              stat cards, Account + App (Bundle version) + Sign Out (danger,
              confirmation alert) sections, staggered entrances. Polish:
              consistent 24pt gutters, one card/button/animation vocabulary,
              empty states on every tab, inline error cards (no
              UIAlertControllers for errors), pulsing-gold loaders (no
              spinners), dark-only via app-level preferredColorScheme,
              Reduce-Motion-aware entrances, accessibility labels on
              interactive elements. Iter 1 → BUILD SUCCEEDED on Xcode
              14.3.1 / iOS 16.4 simulator with two dictionary-literal
              warnings in VisionService. Iter 2 → hoisted the request
              messages into typed [[String: Any]] locals; BUILD SUCCEEDED,
              warning-clean. All 29 new Swift files wired into the project.
```

---

> **Phase 7 — New Features (no Firebase).** Tab bar restructured to
> Dashboard · Scan · Collection · Memories · Profile. The old Explore tab
> was removed from the shell; ExploreView/HistoryView/FavoritesView files
> remain in the project but are no longer referenced (safe to delete later).
> Firebase still not installed — all backend remains stubbed (Phase 8).

```
Ticket #008
Assigned to : vision-integration / ui-ux
Phase       : Phase 7A
Task        : Dashboard tab — Met daily painting, GPT quote + trivia, On This Day, nearby museums
Status      : Completed
Iterations  : 2
Collaboration: Handed off to qa; Firebase deferred to Phase 8
Notes       : MetMuseumService hits the public Met Collection API (no key):
              deterministic daily highlight via a yyyyMMdd seed, 5-attempt
              image validation, cached per day in UserDefaults. VisionService
              gained text-only GPT-4o calls (generateArtworkQuote,
              generateDailyTrivia → TriviaQuestion JSON, generateOnThisDay
              Explanation) reusing the same endpoint/key; all responses
              cached per day. ArtHistoryLibrary holds 73 curated events (≥5
              per month); MuseumLibrary holds 30 museums with real coords +
              CoreLocation sorting and a famous-museum fallback when denied.
              DashboardViewModel parallelizes quote+trivia (async let), lazy-
              loads On-This-Day explanations on expand, persists trivia answer
              for the day. DashboardView: skeleton-loaded hero painting card →
              detail sheet, AI quote block, interactive trivia with reveal,
              On This Day expandable cards, horizontal museum cards → sheet,
              time-aware greeting, and a Scan CTA that switches tabs via a
              @Binding<AppTab>. Iter 2 fixed iOS-17 .topBarTrailing →
              .navigationBarTrailing for Xcode 14.
```

```
Ticket #009
Assigned to : ui-ux
Phase       : Phase 7B
Task        : Collection tab merging History + Favorites
Status      : Completed
Iterations  : 1
Collaboration: Handed off to qa
Notes       : CollectionView replaces History/Favorites in the shell: two
              stat pills, a custom sliding-gold-underline All/Favorites
              switcher (museumSpring), live search over title/artist/style,
              horizontal style filter chips, and a row list with leading-
              swipe favorite toggle and trailing-swipe delete (confirmation,
              removes image + thumbnail via ImageStore). Distinct empty
              states for no scans (with Start-Scanning tab switch), no
              favorites, and no search results.
```

```
Ticket #010
Assigned to : ui-ux / vision-integration
Phase       : Phase 7C
Task        : Museum Memories tab with auto-link to scans
Status      : Completed
Iterations  : 1
Collaboration: Handed back to user for Xcode testing before Phase 8 (Firebase)
Notes       : MemoryPhoto model + MemoriesStore (UserDefaults, key
              museummate_memories_v1, deletes image on remove). MemoriesView:
              3-column square grid (2pt gaps), link badge on linked photos,
              long-press context menu (Edit Caption / Link to Artwork /
              Delete), camera + library toolbar add. On add, MemoriesViewModel
              auto-links to the nearest scan within ±2h and surfaces a
              confirm/skip suggestion sheet (presentationDetents). Memory
              DetailView: full-bleed photo, ultraThinMaterial bottom panel
              with inline editable caption, linked-scan card → ArtworkDetail
              View, link picker, and UIActivityViewController share. New
              Info.plist keys added: NSLocationWhenInUseUsageDescription and
              NSPhotoLibraryAddUsageDescription. Verified BUILD SUCCEEDED,
              warning-clean, Xcode 14.3.1 / iOS 16.4 simulator. 17 new Swift
              files + 3 new view groups wired into the project.
```
