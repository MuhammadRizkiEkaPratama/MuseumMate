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
