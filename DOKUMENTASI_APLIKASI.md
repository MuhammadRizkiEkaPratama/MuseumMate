# 📘 Dokumentasi Lengkap — MuseumMate

> Dokumen ini adalah **ringkasan teknis menyeluruh** dari aplikasi MuseumMate: apa aplikasinya, kegunaannya, fitur, ML, tools, API/koneksi, arsitektur, struktur folder, alur kerja, dan cara tiap fitur/tombol/fungsi bekerja. Ditulis berdasarkan pembacaan langsung seluruh source code (±11.600 baris Swift).
>
> ⚠️ **Catatan:** Ini bukan laporan akademik. Sesuai aturan course (CLAUDE.md §12), laporan tertulis harus Anda tulis sendiri. Dokumen ini hanya bahan referensi teknis untuk membantu Anda memahami aplikasi Anda sendiri.

---

## 1. Apa Itu MuseumMate?

**MuseumMate** adalah aplikasi iOS native (SwiftUI) yang **mengenali dan menjelaskan karya seni dari sebuah foto** — baik dari kamera langsung, impor dari galeri, maupun frame kamera live. Setelah memindai (scan), aplikasi menampilkan: judul, seniman, tahun, medium, gaya/aliran seni, museum tempat karya asli disimpan, penjelasan kaya, fun facts, kutipan puitis, cerita penciptaan, hingga "love poems".

### Kegunaannya untuk apa?

Pengunjung museum dan pelajar seni sering berdiri di depan sebuah karya **tanpa konteks** — label museum singkat, audio guide mahal/tidak tersedia, dan internet di dalam gedung sering buruk. MuseumMate memberi:

- **Identifikasi instan** sebuah lukisan dari foto.
- **Klasifikasi gaya/aliran offline** (lewat Core ML) — tetap jalan walau tanpa internet.
- **Konten harian** (lukisan hari ini, kutipan, trivia, "On This Day", museum terdekat).
- **Penemuan seniman** (40 seniman + pencarian AI untuk seniman regional).
- **Album kenangan** kunjungan museum.

### Diferensiator utama — *dual AI pipeline*

| Jalur | Teknologi | Sifat |
|---|---|---|
| **Lokal** | Core ML (di perangkat) | Instan, offline, klasifikasi gaya & seniman |
| **Cloud** | Qwen-VL + DeepSeek | Identifikasi presisi + penjelasan mendalam |

---

## 2. Spesifikasi Teknis & Batasan (Hard Constraints)

| Komponen | Nilai |
|---|---|
| Xcode | 14.3.1 (Build 14E300c) |
| macOS | 13.7.5 Ventura |
| Swift | 5.8 |
| iOS Deployment Target | 16.4 minimum |
| Arsitektur | SwiftUI + MVVM |
| Konkurensi | async/await, Task, @MainActor |
| Dependency | SPM saja |

**Aturan ketat:** tidak boleh memakai API iOS 17+ (mis. `PhaseAnimator`, `symbolEffect`, `@Observable`, `.onChange` dua-parameter). Pakai `NavigationStack` gaya iOS 16 dan `.onChange(of:) { newValue in }` satu-parameter.

---

## 3. Tools, Framework & Dependency yang Dipakai

### Framework Apple (native, lewat `import`)
| Framework | Dipakai untuk |
|---|---|
| `SwiftUI` | Seluruh UI (35 file) |
| `CoreML` + `Vision` | Klasifikasi gaya & seniman di perangkat |
| `AVFoundation` | Kamera live + pemutar audio ambient |
| `CoreLocation` | Lokasi pengguna → museum terdekat |
| `Speech` | Voice search (ucapan → teks) |
| `Photos` / `PhotosUI` | Impor foto & galeri foto terbaru |
| `MediaPlayer` | Kontrol audio (Now Playing) |
| `CoreImage` / `CoreGraphics` | Konversi frame kamera → CGImage |
| `AudioToolbox` | Sound effect / haptic |
| `UIKit` | ImagePicker, penyimpanan gambar |

### Dependency eksternal (Swift Package Manager)
| Package | Fungsi |
|---|---|
| **firebase-ios-sdk** | `FirebaseAuth` (login), `FirebaseFirestore` (sinkron cloud), `FirebaseCore` |
| **GoogleSignIn-iOS** | Login dengan akun Google |

Transitive deps (otomatis ikut Firebase/Google): abseil, appauth, googleappmeasurement, gRPC, gtm-session-fetcher, leveldb, nanopb, swift-protobuf, promises, dll.

---

## 4. Machine Learning yang Digunakan

Ada **dua model Core ML offline** yang berjalan di perangkat (file: [ArtStyleClassifierService.swift](MuseumMate/Services/ArtStyleClassifierService.swift)):

| Model | File | Isi | Akurasi |
|---|---|---|---|
| **ArtistClassifier** | `Resources/ArtistClassifier.mlmodel` | 12 seniman (Create ML) | ~77% train / 66% val |
| **ArtStyleClassifier** | `Resources/ArtStyleClassifier.mlpackage` | 8 gaya seni (ViT/HuggingFace) | 75–88% |

**Cara kerja:** `classify(cgImage:)` menjalankan kedua model **paralel** (`withTaskGroup`) dengan `imageCropAndScaleOption = .centerCrop`, mengambil `VNClassificationObservation` teratas, dan mem-publish `detectedArtist`/`detectedStyle` + confidence-nya.

> **⚠️ Penting (keputusan desain terbaru):** model **ArtistClassifier lemah** — menebak seniman spesifik dari foto sangat sulit untuk model 12-kelas, sehingga pada lukisan di luar dataset ia "pede" tapi salah (mis. Mona Lisa → "Salvador Dali"). Karena itu **badge live di kamera sekarang hanya menampilkan STYLE**, dan **hanya kalau confidence ≥ 60%** (lihat [UnifiedScanViewModel.swift](MuseumMate/ViewModels/UnifiedScanViewModel.swift) `liveStyleThreshold`). Tebakan seniman tetap disimpan di `ScanResult.localArtist` tapi tidak ditonjolkan di layar live.
>
> **Tidak ada Core ML model art-style siap-pakai dari Apple** — kedua model di atas dilatih/di-convert sendiri.

### Resilience (graceful degradation)
- Jika file `.mlmodelc` tidak ada → `isMLAvailable = false`, aplikasi tetap jalan (jalur cloud tetap bekerja).
- Jika tidak ada internet → Core ML tetap memberi gaya; bagian cloud menampilkan error ramah.

---

## 5. API & Koneksi Eksternal (Aplikasi Ini Konek ke Mana Saja)

| Layanan | Endpoint | Untuk apa | Key? |
|---|---|---|---|
| **Qwen-VL-Plus** (Alibaba DashScope) | `dashscope-intl.aliyuncs.com/compatible-mode/v1` | **Stage 1 scan** — identifikasi judul+seniman dari gambar | ✅ `QwenAPIKey` |
| **DeepSeek** (`deepseek-chat`) | `api.deepseek.com/chat/completions` | **Stage 2 scan** (detail lengkap) + kutipan, trivia, bio seniman, "On This Day" | ✅ `DeepSeekAPIKey` |
| **The Met Museum Collection API** | `collectionapi.metmuseum.org/public/collection/v1` | Lukisan harian di Dashboard | ❌ gratis |
| **Wikipedia REST API** | `en.wikipedia.org/api/rest_v1/...` | Foto potret seniman (`/page/summary`) + kelahiran tokoh (`/feed/onthisday/births`) | ❌ gratis |
| **OpenStreetMap Overpass API** | `overpass-api.de` + mirror `overpass.kumi.systems` | Museum nyata di sekitar pengguna (GPS) | ❌ gratis |
| **Firebase Auth** | Google Cloud | Login email/password + Google | (GoogleService-Info.plist) |
| **Cloud Firestore** | Google Cloud | Sinkron scan, memories, profil | (sda) |

> Selain itu ada ±40 URL website museum (Louvre, MoMA, dll) yang **hanya tautan statis** di `Museum.swift` — bukan API.

### Keamanan API key
- Key **tidak di-hardcode**. Dibaca runtime dari `Secrets.plist` (gitignored) atau `Info.plist` lewat [AppConfig.swift](MuseumMate/Services/AppConfig.swift).
- Jika key kosong → `hasValidAPIKey == false`, fitur AI di-skip dengan aman (tidak crash).
- Key sekarang: `DeepSeekAPIKey`, `QwenAPIKey`.

---

## 6. Arsitektur (MVVM)

```
View (SwiftUI)  ←→  ViewModel (@MainActor ObservableObject)  ←→  Service  ←→  API / ML / Disk / Firestore
        ▲                                                              
        └── EnvironmentObject global: AuthService, UserProfile, ScanHistoryStore,
            FavoritesStore, MemoriesStore, AmbientAudioService
```

**Entry point** — [MuseumMateApp.swift](MuseumMate/MuseumMateApp.swift):
- `FirebaseApp.configure()` di `init()`.
- Membuat 6 `@StateObject` global (auth, profile, 3 store, ambient audio) → di-inject sebagai `environmentObject`.
- `.onChange(of: auth.currentUserUID)` → menyambungkan/memutus Firestore saat login/logout, dan **menghapus cache lokal hanya jika akun berbeda** (agar sesi yang sama saat relaunch tidak menghapus data).
- `.onOpenURL` → menangani callback Google Sign-In.

**Shell navigasi** — [ContentView.swift](MuseumMate/ContentView.swift): `ZStack` dengan 5 tab via `CustomTabBar` mengambang (gold). Enum `AppTab`: `dashboard, scan, collection, artists, profile`.

---

## 7. Struktur Folder Detail

```
MuseumMate/
├── MuseumMateApp.swift          @main, init Firebase, environment objects, wiring auth↔store
├── ContentView.swift            ZStack 5-tab + CustomTabBar mengambang
├── Secrets.plist                API keys (gitignored) — DeepSeekAPIKey, QwenAPIKey
├── Info.plist                   Izin (kamera, foto, lokasi, mic, speech) + ATS exceptions
├── GoogleService-Info.plist     Konfigurasi Firebase
│
├── Models/                      (struktur data murni)
│   ├── Artwork.swift            Hasil detail DeepSeek — 23 field (judul…artistStory), custom decoder toleran
│   ├── ScanResult.swift         1 sesi scan: gambar, localArtist, artwork?, isFavorite + firestoreSlug
│   ├── ArtStyle.swift           struct Artist + ArtistLibrary (40 seniman: 12 Core ML + 28 discovery)
│   ├── ArtistProfile.swift      Bio kaya seniman (dari DeepSeek + foto Wikipedia)
│   ├── Museum.swift             struct Museum + MuseumLibrary (atlas dunia + distanceKm/nearest)
│   ├── MetObject.swift          Objek dari Met Museum API + fallback
│   ├── ArtHistoryEvent.swift    Event "On This Day" + ArtHistoryLibrary kurasi
│   ├── TriviaQuestion.swift     Soal pilihan ganda harian
│   ├── MemoryPhoto.swift        Foto kenangan museum (bisa di-link ke scan)
│   └── UserProfile.swift        ObservableObject: nama, email, scanCount, birthDate, dll (UserDefaults+Firestore)
│
├── ViewModels/                  (@MainActor ObservableObject)
│   ├── UnifiedScanViewModel.swift   Orkestrasi tab Scan: kamera, badge live, pipeline 3-stage, sheet impor
│   ├── DashboardViewModel.swift     Lukisan harian, kutipan, trivia, On This Day, museum terdekat (paralel+cache)
│   ├── ArtistDiscoveryViewModel.swift  Grid seniman, portret Wikipedia, bio DeepSeek, "born on your birthday"
│   ├── MemoriesViewModel.swift      Tambah/kelola foto kenangan
│   └── ScanViewModel.swift          (versi lama; UnifiedScanViewModel yang aktif)
│
├── Services/                    (logika & I/O)
│   ├── AppConfig.swift          Baca API key dari Secrets/Info.plist (tanpa hardcode)
│   ├── VisionService.swift      Stage 1 (Qwen-VL identify) + teks DeepSeek (kutipan/trivia/onthisday)
│   ├── ArtworkDetailService.swift   Stage 2 (DeepSeek → katalog lengkap Artwork)
│   ├── ArtStyleClassifierService.swift  2 model Core ML offline (artist + style)
│   ├── ArtistInfoService.swift  Bio seniman + searchArtist + birthday (Wikipedia→DeepSeek)
│   ├── ArtistImageService.swift Foto potret seniman dari Wikipedia
│   ├── MetMuseumService.swift   Lukisan harian deterministik + cache harian
│   ├── MuseumDiscoveryService.swift  Museum terdekat via Overpass (OpenStreetMap)
│   ├── LocationService.swift    Wrapper CLLocationManager (when-in-use, 1 fix)
│   ├── VoiceSearchService.swift Speech→teks (SFSpeechRecognizer + AVAudioEngine)
│   ├── CameraService.swift      AVCaptureSession, frame throttle ~2 fps, torch, capture frame
│   ├── AuthService.swift        Firebase Auth (email + Google), firestoreKey berbasis email
│   ├── ScanHistoryStore.swift   Riwayat scan: UserDefaults + Firestore (snapshot listener)
│   ├── FavoritesStore.swift     Favorit (turunan dari riwayat scan)
│   ├── MemoriesStore.swift      Foto kenangan: UserDefaults + Firestore
│   ├── ImageStore.swift         Simpan gambar+thumbnail 300×300 ke Documents (UUID)
│   ├── AmbientAudioService.swift Pemutar musik klasik (shuffle + per-movement)
│   └── SoundEffectService.swift Sound effect UI ringan
│
├── Views/
│   ├── Auth/      RootView (gate onboarding/login), AuthView (login), ProfileSetupView (setup pertama)
│   ├── Onboarding/ OnboardingView (3 layar)
│   ├── Dashboard/ DashboardView (940 baris), DailyPaintingSheet, MuseumDetailSheet
│   ├── Scan/      UnifiedScanView (682), ArtworkDetailView (765), ImagePicker
│   ├── Collection/ CollectionView (filter All/Favorites + search + voice)
│   ├── Artists/   ArtistDiscoveryView (587) — grid + search + bio sheet + birthday
│   ├── Memories/  MemoriesView, MemoryDetailView
│   ├── History/   HistoryView
│   ├── Favorites/ FavoritesView
│   ├── Profile/   ProfileView (akun, scan count, sign out)
│   ├── Explore/   CameraPreviewView (UIViewRepresentable), StyleOverlayView (badge live)
│   └── Shared/    CustomTabBar, EmptyStateView, LoadingView, ScanThumbnail, SkeletonView
│
├── Extensions/
│   ├── Color+Theme.swift        Palet museum (gold #C9A227, dark) + Color(hex:)
│   └── View+Extensions.swift    card(), sectionLabel(), if(), animasi museumSpring
│
└── Resources/
    ├── ArtistClassifier.mlmodel         Model 12 seniman
    ├── ArtStyleClassifier.mlpackage     Model 8 gaya
    └── Audio/classical_01..05.mp3       Musik ambient klasik
```

---

## 8. Workflow Aplikasi

### 8.1 Alur startup
1. `MuseumMateApp` → `FirebaseApp.configure()` → tampilkan `RootView`.
2. **RootView** = gerbang: jika belum login → `AuthView`; jika sudah login tapi profil belum lengkap → `ProfileSetupView`; lalu → `ContentView` (5 tab).
3. Saat `currentUserUID` berubah → Firestore tersambung, profil/scan/memories ditarik dari cloud.

### 8.2 Alur SCAN (fitur inti) — pipeline 3 tahap
File: [UnifiedScanViewModel.swift](MuseumMate/ViewModels/UnifiedScanViewModel.swift) → `runPipeline(image:)`

```
Foto (kamera frame / impor galeri)
   │
   ├─(a) LOKAL  → ArtStyleClassifierService.classify()  → localArtist + style (instan, offline)
   │                phase: "Detecting artist…"
   │
   ├──  ImageStore.save() → simpan full JPEG + thumbnail 300×300 ke Documents
   │
   ├─(b) CLOUD stage 1 → VisionService.quickIdentify()  [Qwen-VL]  → {title, artist, confidence}
   │                phase: "Identifying artwork…"
   │
   ├─(c) CLOUD stage 2 → ArtworkDetailService.generateFullDetail()  [DeepSeek]  → Artwork lengkap (23 field)
   │                phase: "Gathering details…"
   │
   └──  ScanResult dibuat → store.save() (UserDefaults + Firestore) → navigasi ke ArtworkDetailView
```

- Jika cloud gagal (offline/rate-limit) → `ScanResult` **tetap disimpan** dengan `artwork = nil`, plus pesan error ramah yang auto-hilang setelah 4 detik. Gaya offline tetap ada.
- Sukses → haptic success + sound effect.

### 8.3 Alur DASHBOARD
File: [DashboardViewModel.swift](MuseumMate/ViewModels/DashboardViewModel.swift) → `loadIfNeeded()`
- Tampilkan data lokal instan (On This Day kurasi, trivia tersimpan).
- Jalankan **4 task paralel**: kutipan, trivia, On This Day (fallback DeepSeek), lukisan harian (Met API).
- Minta lokasi → Overpass cari museum terdekat (fallback ke atlas kurasi bila gagal/ditolak, timeout 6 detik).
- Semua di-cache per hari (`DailyCache` berbasis `yyyyMMdd`) → kunjungan ulang instan.

---

## 9. Fitur, Tombol & Fungsi (Cara Tiap Bagian Bekerja)

### 🏠 Tab 1 — Dashboard ([DashboardView.swift](MuseumMate/Views/Dashboard/DashboardView.swift))
- **Greeting** dinamis (pagi/siang/malam) + tanggal.
- **Kartu Lukisan Hari Ini** — dari Met API; tap → `DailyPaintingSheet`.
- **Kutipan harian** — di-generate DeepSeek dari lukisan tsb.
- **Trivia harian** — pilihan ganda; `answerTrivia(index)` → haptic benar/salah, state tersimpan; tombol **"Try another"** → `loadNewTrivia()`.
- **On This Day** — event sejarah seni; tap kartu → `toggleEvent()` memuat penjelasan DeepSeek (di-cache).
- **Museum near you** — daftar via GPS/Overpass; tap → `MuseumDetailSheet`.

### 📷 Tab 2 — Scan ([UnifiedScanView.swift](MuseumMate/Views/Scan/UnifiedScanView.swift))
- **Preview kamera live** (`CameraPreviewView`) + **badge gaya live** (`StyleOverlayView`) — kini **style saja, gate ≥60%**.
- **Tombol senter** (torch) — `viewModel.toggleTorch()` (no-op bila device tanpa torch).
- **Tombol shutter** (lingkaran gold) — `scanCurrentFrame()` ambil frame terakhir → pipeline 3-tahap. Saat scan, berubah jadi `PulsingRing`.
- **Sheet "Import Photo"** (drag) — `RecentPhotosLoader` menampilkan foto galeri terbaru; pilih → `scan(image:)`. Saat sheet penuh, kamera di-pause hemat baterai.

### 🖼️ Tab 3 — Collection / Art Pieces ([CollectionView.swift](MuseumMate/Views/Collection/CollectionView.swift))
- Riwayat semua scan (thumbnail dari disk).
- **Filter chip** `All / Favorites` (enum `Mode`) + filter per gaya.
- **Search bar** (judul/seniman) + **voice search** (mic → `VoiceSearchService`).
- Tap item → `ArtworkDetailView`; swipe → favorit / hapus.

### 🎨 Tab 4 — Artists ([ArtistDiscoveryView.swift](MuseumMate/Views/Artists/ArtistDiscoveryView.swift))
- Grid **40 seniman** dengan potret Wikipedia (`loadPortrait`).
- **Search**: jika tak ada di daftar lokal → setelah debounce 0.7s, `searchArtist()` (DeepSeek) menemukan seniman regional (mis. Raden Saleh, Affandi).
- **"Born on your birthday"**: Wikipedia (fakta) → filter seniman visual → DeepSeek (perkaya) → kartu seniman yang lahir di tanggal lahir Anda.
- Tap seniman → bio sheet kaya (`fetchArtistInfo` DeepSeek + potret).

### 👤 Tab 5 — Profile ([ProfileView.swift](MuseumMate/Views/Profile/ProfileView.swift))
- Info akun (inisial, nama, email), **jumlah scan**, jumlah gaya unik.
- Bagian app (privasi, dll) + **Sign Out** (konfirmasi → `auth.signOut()` → cache lokal dibersihkan).

### 📄 ArtworkDetailView (layar hasil scan, [765 baris](MuseumMate/Views/Scan/ArtworkDetailView.swift))
Menampilkan semua field `Artwork`: hero image, judul/seniman, **confidence ring**, deskripsi, sejarah singkat (expandable), creation story, kutipan, fun facts, love poems, romantic line, artist story, lokasi pameran.
- **Tombol ♥ (favorit)** — `toggleFavorite()` → `historyStore.toggleFavorite()`.
- **Tombol 🎵 (musik)** — `ambientAudio.togglePlayback(forMovement:)` putar musik klasik sesuai aliran.
- **Tombol share** — `ShareLink` membagikan ringkasan teks.

### 🖼️ Memories ([MemoriesView.swift](MuseumMate/Views/Memories/MemoriesView.swift))
- **Tombol kamera/galeri** → ambil foto kenangan → `addPhoto()` simpan ke disk+Firestore.
- Tiap foto: lihat detail, **link ke scan** tertentu, atau hapus.

---

## 10. Model Data (Kontrak Penting)

| Model | Field kunci |
|---|---|
| **Artwork** | 23 field: title, artist, year, medium, style, location, description, funFacts, confidence, quote, creationStory, romanticLine, artistNationality, exhibitionLocation/Since, category, artStyle, creationTime, material, theme, genre, shortHistory, lovePoems, artistStory. **CodingKeys snake_case**, custom decoder toleran field hilang. |
| **ScanResult** | id, date, imageFileName, thumbnailFileName, localArtist, localConfidence, artwork?, isFavorite + `firestoreDocID` (slug judul + 8 char UUID). |
| **Artist** | name, datasetLabel, nationality, movement, born, died, accentColorHex. |
| **MetObject** | objectID, title, artistDisplayName, objectDate, medium, primaryImage(+Small), isHighlight, dll. |
| **UserProfile** | name, email, hasCompletedOnboarding, scanCount, joinDate, birthDate?, country — tiap `didSet` tulis UserDefaults. |
| **MemoryPhoto** | imageFileName, caption, dateTaken, linkedScanResultID?, linkedScanTitle?. |

---

## 11. Persistence (Penyimpanan Data) — 3 Lapis

1. **Disk (Documents)** — gambar scan full + thumbnail 300×300 (`ImageStore`, nama UUID). Hanya nama file yang disimpan di model.
2. **UserDefaults** — cache offline: riwayat scan (`museummate_scans`), memories, profil, cache harian dashboard, volume audio.
3. **Cloud Firestore** — sinkron lintas perangkat di `users/{key}/scans`, `/memories`, dan field `profile`. Key dokumen = email yang disanitasi (mis. `riski_gmail_com`) agar mudah dibaca di console. Memakai **snapshot listener** real-time.

**Alur login/logout:** akun baru → cache lokal dihapus & ditarik dari Firestore; akun sama saat relaunch → cache dipertahankan; logout → semua cache lokal dibersihkan.

---

## 12. Izin (Info.plist)

| Key | Alasan |
|---|---|
| `NSCameraUsageDescription` | Kamera live & scan lukisan |
| `NSPhotoLibraryUsageDescription` | Impor foto untuk identifikasi |
| `NSPhotoLibraryAddUsageDescription` | Simpan foto kenangan |
| `NSLocationWhenInUseUsageDescription` | Museum terdekat |
| `NSMicrophoneUsageDescription` | Voice search |
| `NSSpeechRecognitionUsageDescription` | Ucapan → query pencarian |
| `NSAppTransportSecurity` | Exception domain untuk Wikipedia/Wikimedia (gambar) |

---

## 13. Catatan Build & Kondisi Saat Ini

- Build diverifikasi: **BUILD SUCCEEDED** di Xcode 14.3.1 / iOS 16.4 SDK (warning hanya dari AppAuth pihak ketiga).
- File `.swift` & resource baru **harus didaftarkan manual** di `project.pbxproj` (Xcode 14 tanpa folder auto-sync).
- Perintah cek kompilasi CLI:
  ```
  xcodebuild -project MuseumMate.xcodeproj -scheme MuseumMate \
    -sdk iphonesimulator16.4 -destination 'generic/platform=iOS Simulator' \
    -configuration Debug CODE_SIGNING_ALLOWED=NO build
  ```

### Perubahan terakhir (badge live)
- Badge kamera live sekarang **hanya menampilkan gaya/aliran** (bukan seniman), **gate confidence ≥ 60%**.
- Tebakan seniman dari Core ML tetap disimpan di `ScanResult.localArtist`, tapi tidak ditonjolkan di layar live karena tidak andal.
- Seniman & gaya yang akurat tetap muncul di **ArtworkDetailView** (dari DeepSeek).

---

## 14. Alur Test Case (Langkah User di Tiap Fitur)

Format: **Langkah yang dilakukan user** → **Hasil yang diharapkan**. Berguna untuk bagian Testing laporan dan demo.

### TC-01 — Sign Up (daftar akun baru)
1. Buka aplikasi pertama kali → muncul layar onboarding 3 halaman → tap **Get Started**.
2. Di `AuthView`, pilih **Sign Up**, isi nama, email, password (min. 6 karakter), tap daftar.
3. (Pertama kali) isi `ProfileSetupView` — tanggal lahir & negara → **Continue**.
- **Diharapkan:** akun dibuat di Firebase, masuk ke Dashboard (5 tab muncul). Validasi: email tanpa "@" / password <6 → pesan error ramah.

### TC-02 — Sign In & Sign Out
1. Tutup app, buka lagi → otomatis masih login (sesi tersimpan).
2. Buka tab **Profile** → **Sign Out** → konfirmasi.
3. Login ulang dengan email/password yang sama.
- **Diharapkan:** setelah sign out kembali ke `AuthView`; setelah login ulang, semua scan/memories/profil **muncul lagi dari Firestore**.

### TC-03 — Login dengan Google
1. Di `AuthView` tap **Continue with Google** → pilih akun Google.
- **Diharapkan:** masuk ke Dashboard; jika dibatalkan, tidak ada pesan error (cancel di-handle diam-diam).

### TC-04 — Scan lukisan dari kamera (jalur utama)
1. Buka tab **Scan**, arahkan kamera ke sebuah lukisan (mis. Mona Lisa / Starry Night).
2. Perhatikan **badge gaya** muncul di layar (hanya bila yakin ≥60%).
3. Tekan **tombol shutter** (lingkaran gold).
- **Diharapkan:** muncul fase "Detecting → Identifying → Gathering details"; lalu pindah ke `ArtworkDetailView` berisi judul, seniman, tahun, medium, lokasi museum, deskripsi, fun facts. Tersimpan otomatis di Collection.

### TC-05 — Scan dari impor galeri
1. Di tab Scan, **drag sheet "Import Photo"** ke atas → pilih foto lukisan dari galeri terbaru.
- **Diharapkan:** overlay scanning muncul di atas foto, lalu hasil detail tampil. Hasil sama seperti TC-04.

### TC-06 — Core ML offline (graceful degradation)
1. **Matikan Wi-Fi & data**, lakukan scan (TC-04).
- **Diharapkan:** gaya tetap terdeteksi offline (Core ML), `ScanResult` tetap tersimpan, muncul **pesan error ramah** untuk bagian cloud (hilang sendiri ~4 detik). Aplikasi **tidak crash**.

### TC-07 — Foto buram / bukan lukisan
1. Scan foto acak (wajah, tembok, objek non-seni).
- **Diharapkan:** confidence rendah / "Unknown", tidak ada crash, tetap ada hasil yang aman.

### TC-08 — Badge live bergerak
1. Di tab Scan, gerakkan kamera melintasi beberapa lukisan berbeda.
- **Diharapkan:** badge gaya **update real-time** saat confidence cukup; hilang saat ragu (tidak menampilkan tebakan ngawur).

### TC-09 — Favorit & batal favorit
1. Buka sebuah hasil scan di `ArtworkDetailView` → tap **tombol ♥**.
2. Buka tab **Collection** → filter **Favorites**.
3. Tap ♥ lagi untuk membatalkan.
- **Diharapkan:** ikon berubah terisi/kosong; item muncul/hilang dari filter Favorites; **status bertahan setelah restart app**.

### TC-10 — Riwayat scan bertahan
1. Lakukan beberapa scan, lalu **tutup paksa & buka lagi** aplikasi.
- **Diharapkan:** semua scan lama muncul di Collection lengkap dengan thumbnail (dari disk).

### TC-11 — Sinkronisasi cloud (Firestore)
1. Login di perangkat/simulator lain dengan akun yang sama (atau hapus app lalu install ulang & login).
- **Diharapkan:** scan, memories, dan profil **muncul kembali** karena ditarik dari Firestore.

### TC-12 — Putar musik ambient
1. Di `ArtworkDetailView` tap **tombol 🎵**.
- **Diharapkan:** musik klasik diputar (sesuai aliran lukisan bila tersedia); tap lagi untuk berhenti. Berhenti otomatis saat keluar layar.

### TC-13 — Share artwork
1. Di `ArtworkDetailView` tap **tombol share**.
- **Diharapkan:** share sheet iOS muncul berisi ringkasan teks artwork.

### TC-14 — Dashboard harian
1. Buka tab **Dashboard**.
- **Diharapkan:** muncul greeting + tanggal, **Lukisan Hari Ini** (Met API), kutipan, trivia, On This Day, dan museum terdekat. Kunjungan kedua di hari sama = instan (cache).

### TC-15 — Jawab trivia
1. Di Dashboard, pilih satu jawaban trivia → lalu tap **Try another**.
- **Diharapkan:** jawaban benar/salah ditandai + haptic; "Try another" memuat soal baru; status jawaban bertahan di hari yang sama.

### TC-16 — On This Day (penjelasan)
1. Tap salah satu kartu event "On This Day".
- **Diharapkan:** kartu mengembang, penjelasan AI dimuat (lalu di-cache untuk tap berikutnya).

### TC-17 — Museum terdekat (GPS)
1. Saat diminta izin lokasi → **Allow While Using App**.
- **Diharapkan:** daftar museum nyata di sekitar (Overpass/OSM). Jika **ditolak** → fallback ke daftar museum terkenal dunia (tidak kosong).

### TC-18 — Penemuan seniman + pencarian AI
1. Buka tab **Artists** → scroll grid 40 seniman (potret termuat).
2. Ketik nama seniman regional yang **tidak ada di daftar** (mis. "Raden Saleh", "Affandi").
- **Diharapkan:** setelah jeda singkat, DeepSeek menemukan seniman tsb & menampilkan kartunya; tap → bio kaya + potret Wikipedia.

### TC-19 — "Born on your birthday"
1. Pastikan tanggal lahir terisi (TC-01), buka tab Artists.
- **Diharapkan:** muncul seniman terkenal yang lahir di tanggal lahir Anda (data faktual Wikipedia + diperkaya AI).

### TC-20 — Voice search
1. Di tab **Collection**, tap ikon **mic**, ucapkan judul/nama seniman.
- **Diharapkan:** minta izin Speech & mic; ucapan jadi teks → daftar terfilter real-time.

### TC-21 — Foto kenangan (Memories)
1. Buka Memories → tap **kamera/galeri** → ambil/pilih foto → simpan.
2. **Link** foto ke salah satu hasil scan, lalu hapus salah satu foto.
- **Diharapkan:** foto tersimpan (disk+Firestore), bisa di-link ke scan, hapus menghilangkan foto & filenya.

### TC-22 — Senter (torch)
1. Di tab Scan (perangkat fisik), tap **ikon senter**.
- **Diharapkan:** lampu belakang menyala/mati; di simulator tombol no-op (tidak crash).

### Ringkasan cakupan
| Area | Test case |
|---|---|
| Auth | TC-01, 02, 03 |
| Scan & ML | TC-04, 05, 06, 07, 08, 22 |
| Detail & favorit | TC-09, 12, 13 |
| Persistence & cloud | TC-10, 11 |
| Dashboard | TC-14, 15, 16, 17 |
| Artists | TC-18, 19 |
| Lain-lain | TC-20 (voice), TC-21 (memories) |

---

# 📎 APPENDIX (Detail Teknis Mendalam)

## Appendix A — Design System (Sistem Desain)

Filosofi: **"consistency over novelty"** — satu gaya kartu, satu gaya tombol, satu kosakata animasi. File: [Color+Theme.swift](MuseumMate/Extensions/Color+Theme.swift), [View+Extensions.swift](MuseumMate/Extensions/View+Extensions.swift).

### A.1 Palet warna (semantic tokens — jangan pakai hex mentah di view)
| Token | Hex | Pemakaian |
|---|---|---|
| `appBackground` | `#12100E` | Latar utama (hampir hitam, hangat) |
| `appSurface` | `#1E1B18` | Permukaan kartu |
| `appSurfaceUp` | `#2A2620` | Permukaan terangkat (elevated) |
| `appAccent` | `#C9A227` | **Emas museum** — aksen utama, tombol aktif |
| `appAccentMuted` | `#5C4A1A` | Emas redup |
| `appTextPrimary` | putih | Teks utama |
| `appTextSecondary` | `#B8AE9E` | Teks sekunder |
| `appTextMuted` | `#6B6258` | Teks samar / label |
| `appDanger` | `#E5484D` | Aksi destruktif (hapus, sign out) |

`Color(hex:)` — inisializer custom yang parse string heksadesimal jadi RGB. Tema global di-set `.preferredColorScheme(.dark)`.

### A.2 Helper view (modifier reusable)
| Helper | Fungsi |
|---|---|
| `.card(padding:cornerRadius:)` | Kartu museum: fill `appSurface` + border tipis + sudut kontinu |
| `.sectionLabel()` | Caption kapital, spasi huruf 1.4 — gaya label museum |
| `.fadeSlideIn(delay:)` | Animasi masuk fade + geser ke atas; `delay` untuk stagger daftar |
| `.if(condition) { }` | Terapkan transform view secara kondisional |

### A.3 Animasi, haptic, sound effect
- **`Animation.museumSpring`** = `spring(response: 0.4, dampingFraction: 0.8)` — **satu-satunya** spring di seluruh app.
- **`PressableButtonStyle`** (`.pressable`) — label mengecil 0.97 saat ditekan.
- **`Haptics`** — `tap()`, `success()`, `error()`, `impact(_:)`, `notification(_:)`.
- **`SoundEffect`** ([SoundEffectService.swift](MuseumMate/Services/SoundEffectService.swift)) — `tabChange()`, `scanCapture()`, `scanSuccess()`, `error()`, `saved()`, `sheetOpen()`, `navigation()` (pakai `SystemSoundID`).
- **Aksesibilitas:** semua animasi menghormati **Reduce Motion** (fade di tempat tanpa gerakan).

---

## Appendix B — Referensi Method Tiap Service

### B.1 VisionService ([VisionService.swift](MuseumMate/Services/VisionService.swift))
| Method | Provider | Output |
|---|---|---|
| `quickIdentify(imageBase64:)` | Qwen-VL-Plus | `QuickIdentification {title, artist, confidence}` |
| `generateArtworkQuote(painting:)` | DeepSeek | Kutipan ≤35 kata |
| `generateDailyTrivia(painting:)` | DeepSeek | `TriviaQuestion` |
| `generateOnThisDayFallback(month:day:)` | DeepSeek | `[ArtHistoryEvent]` |
| `generateOnThisDayExplanation(event:)` | DeepSeek | Penjelasan 2–3 kalimat |
| `static base64(from:quality:)` | — | JPEG → base64 (default quality 0.55) |
| `private completeText(...)` | DeepSeek | Pembungkus chat completion bersama |

Parsing kebal-markdown: `stripMarkdown()` buang fence ```` ```json ````; bila gagal decode → ambil substring dari `{` pertama ke `}` terakhir lalu coba lagi.

### B.2 ArtworkDetailService
- `generateFullDetail(title:artist:)` → DeepSeek menghasilkan `Artwork` lengkap (23 field) dari system prompt katalog. `max_tokens: 1200, temperature: 0.7`.

### B.3 ArtStyleClassifierService (Core ML)
- `classify(cgImage:)` → jalankan **2 model paralel** via `withTaskGroup`.
- Publish: `detectedArtist`/`artistConfidence`, `detectedStyle`/`styleConfidence`, `isArtistMLAvailable`/`isStyleMLAvailable`.
- `summary` → string gabungan "Artist · Style".

### B.4 ArtistInfoService
| Method | Sumber |
|---|---|
| `fetchArtistInfo(name:)` | DeepSeek → `ArtistProfile` lengkap |
| `searchArtist(query:)` | DeepSeek → `Artist` (untuk seniman regional tak dikenal) |
| `fetchArtistBornOn(month:day:)` | **Wikipedia** (fakta) → filter seniman → **DeepSeek** (perkaya) → `BirthdayArtist` |

Strategi anti-halusinasi: Wikipedia `/feed/onthisday/births` dipakai sebagai sumber **faktual** tanggal lahir; DeepSeek hanya memperkaya nama yang sudah dikonfirmasi (karena LLM murni sering salah tanggal). Ada daftar kata kunci `artistWords`/`excludeWords` untuk menyaring pelukis vs politisi/atlet/musisi.

### B.5 Service lain
| Service | Method kunci |
|---|---|
| **MetMuseumService** | `fetchDailyPainting()` (seed harian deterministik + cache), `fetchObjectDetail(id:)`, `fetchHighlightIDs()` |
| **MuseumDiscoveryService** | `nearbyMuseums(near:radiusKm:limit:)` — Overpass QL museum+gallery, 2 endpoint mirror |
| **ArtistImageService** | `fetchPortraitURL(for:)` — Wikipedia `/page/summary` → `thumbnail.source` |
| **LocationService** | `requestLocation()` — when-in-use, 1 fix, akurasi kilometer |
| **VoiceSearchService** | `requestPermissions()`, `startListening()`, `stopListening()`, `clear()` |
| **CameraService** | `start()`, `stop()`, `toggleTorch()`, `captureCurrentFrame()`, callback `onFrame` |
| **ImageStore** | `save(_:)`→(full+thumb), `loadImage(named:)`, `delete(_:)` |
| **AuthService** | `signIn`, `signUp`, `signInWithGoogle`, `signOut`, `firestoreKey` |

---

## Appendix C — Referensi Lengkap Field Tiap Model

### C.1 Artwork (23 field) — hasil DeepSeek
`title, artist, year, medium, style, location, description, funFacts[], confidence, quote, creationStory, romanticLine, artistNationality, exhibitionLocation, exhibitionSince, category, artStyle, creationTime, material, theme, genre, shortHistory, lovePoems[], artistStory`
- **CodingKeys snake_case** (mis. `fun_facts`, `creation_story`).
- **Custom decoder toleran**: setiap field hilang → default kosong, sehingga data lama tetap bisa di-load (backward compatible).
- Helper: `isUnknown`, `metadataLine` ("Tahun • Medium").

### C.2 ScanResult
`id, date, imageFileName, thumbnailFileName?, localArtist, localConfidence, artwork?, isFavorite`
- `hasCloudData` = `artwork != nil`.
- `firestoreDocID` = slug judul + 8 char UUID (mis. `the-starry-night_1a2b3c4d`).
- `displayTitle` / `displayStyle` — fallback cerdas saat cloud gagal.

### C.3 Artist & ArtistLibrary
`name, datasetLabel, nationality, movement, born, died, accentColorHex` → `accentColor`.
- **40 seniman total** = 12 Core ML + 28 discovery (termasuk regional: **Raden Saleh, Affandi, Basuki Abdullah**, Hokusai, dll).

### C.4 ArtistProfile
`name, nationality, born, died, movement, bio, famousWorks[], portraitURL, accentColorHex` → `lifespan` ("1853 – 1890").

### C.5 MetObject (dari Met API)
`objectID, title, artistDisplayName, objectDate, medium, department, primaryImage, primaryImageSmall, objectURL, isHighlight, culture, period, creditLine` → `hasValidImage`, `artistOrUnknown`. Ada `.fallback` & `.preview`.

### C.6 ArtHistoryEvent
`month, day, year, title, dateDescription, category`. Enum `EventCategory`: `birth, death, creation, exhibition, movement, discovery` — masing-masing punya SF Symbol & label.

### C.7 TriviaQuestion
`question, options[], correctIndex, explanation` + `isCorrect(_:)`.

### C.8 MemoryPhoto
`id, imageFileName, caption, dateTaken, linkedScanResultID?, linkedScanTitle?` → `isLinked`, `firestoreDocID`.

### C.9 UserProfile (ObservableObject)
`name, email, hasCompletedOnboarding, scanCount, joinDate, birthDate?, country` — tiap `didSet` menulis UserDefaults; ada `syncToFirestore`, `loadFromFirestore`, `reset`, `clearAllLocalData`, `birthdayMonthDay`.

---

## Appendix D — Konten Kurasi Bawaan (Offline)

### D.1 Atlas museum — **38 museum** ([Museum.swift](MuseumMate/Models/Museum.swift))
Louvre, MoMA, Met, Uffizi, Prado, Rijksmuseum, Tate, British Museum, Hermitage, Vatican, Musée d'Orsay, Guggenheim (NYC & Bilbao), Pompidou, dll — plus museum Indonesia & Asia (Galeri Nasional, Museum MACAN, Affandi, Museum Nasional, NPM Taiwan, TNM Jepang, dll). Tiap museum punya koordinat → `distanceKm(from:)` & `nearest(to:count:)`. `famousFallback` = 5 teratas.

### D.2 Seniman — **40 artist** (Appendix C.3).

### D.3 "On This Day" — **±75 event kurasi** ([ArtHistoryEvent.swift](MuseumMate/Models/ArtHistoryEvent.swift))
Minimal 5 event per bulan (kelahiran/kematian seniman, pembukaan museum, penciptaan karya). `eventsForToday()` memfilter berdasarkan bulan+hari. Jika tanggal kosong → fallback ke DeepSeek.

### D.4 Pemetaan aliran → musik ambient ([AmbientAudioService.swift](MuseumMate/Services/AmbientAudioService.swift))
`movementAudioMap`: baroque→`audio_baroque`, impressionism→`audio_impressionism`, surrealism→`audio_surrealism`, cubism/abstract→`audio_modern`, pop art→`audio_popart`, ukiyo/japanese→`audio_eastern`, dll. Jika file spesifik tak ada → shuffle `classical_*.mp3`.
- Method: `startMuseumAmbient()`, `play(forMovement:)`, `pause/resume/next/previous`, `importTrack(from:)` (impor MP3 user ke `Documents/UserMusic/`), `volume` (persisted).

---

## Appendix E — Struktur Data di Cloud Firestore

```
users/
└── {firestoreKey}              ← email disanitasi, mis. "riski_gmail_com"
    ├── (field) profile: { name, email, scanCount, country, joinDate, birthDate }
    ├── scans/
    │   └── {slug}_{uuid8}       ← 1 dokumen per ScanResult (JSON Artwork penuh)
    └── memories/
        └── {docID}             ← 1 dokumen per MemoryPhoto
```
- **`firestoreKey`** berbasis email (bukan UID acak) agar mudah dibaca di Firebase Console.
- **Snapshot listener** real-time di `scans` (urut `date` desc) & `memories` (urut `dateTaken` desc) → UI update otomatis lintas perangkat.
- Penulisan pakai `setData(..., merge: true)`; penghapusan via `firestoreDocID`.

---

## Appendix F — Model Konkurensi & Threading

- **`@MainActor`** pada semua ViewModel & store → mutasi state UI selalu di main thread.
- **`async/await` + `Task`** untuk semua I/O jaringan (`URLSession.shared.data(for:)`).
- **`withTaskGroup`** — dua model Core ML berjalan paralel.
- **`async let`** — Dashboard menjalankan 4 fetch (kutipan/trivia/onthisday/painting) bersamaan.
- **Kamera**: `AVCaptureSession` di antrian `sessionQueue` khusus; frame di `videoQueue`; throttle **setiap frame ke-15 (~2 fps)** untuk hemat baterai; `latestFrame` dilindungi `NSLock`.
- **Combine** — `@Published` di-`assign`/`sink` (mis. `camera.$permissionDenied` → viewModel; `history.$scans` → favorites).
- **Gotcha Swift 5.8** dipatuhi: `VNConfidence` (Float) di-cast eksplisit ke `Double`; `var` disalin ke `let` sebelum melintasi boundary aktor.

---

## Appendix G — Strategi Caching (Berlapis)

| Data | Mekanisme | Masa berlaku |
|---|---|---|
| Lukisan harian (Met) | UserDefaults `museummate_daily_painting_v1` | Per hari (`yyyyMMdd`) |
| Kutipan / trivia / On This Day | `DailyCache` generic (`Dated<T>`) | Per hari |
| Penjelasan On This Day | UserDefaults (per event UUID) | Per hari |
| Riwayat scan / memories / profil | UserDefaults + Firestore | Persisten |
| Gambar scan | Disk (Documents, UUID) | Persisten |
| Volume audio | UserDefaults | Persisten |

`DailyCache.load(_:key:)` hanya mengembalikan nilai bila `date == hari ini`, jika tidak → dianggap basi dan di-fetch ulang. Efeknya: buka pertama hari ini = fetch jaringan; buka berikutnya = instan.

---

## Appendix H — Panduan Setup & Menjalankan

1. **API keys** — buat `MuseumMate/Secrets.plist` (gitignored) berisi 2 string:
   - `DeepSeekAPIKey` → dari `platform.deepseek.com/api_keys`
   - `QwenAPIKey` → dari `bailian.console.alibabacloud.com` (Model Studio, OpenAI-compatible)
2. **Firebase** — project baru, aktifkan Auth (Email + Google) & Firestore (test mode), unduh `GoogleService-Info.plist` ke root target.
3. **Buka di Xcode 14.3.1**, target iOS 16.4, jalankan di perangkat fisik (kamera & torch tak ada di simulator).
4. **File baru** — daftarkan manual di `project.pbxproj` (Xcode 14 tanpa folder auto-sync); `plutil -lint` setelah edit.
5. **Cek kompilasi via CLI:**
   ```
   xcodebuild -project MuseumMate.xcodeproj -scheme MuseumMate \
     -sdk iphonesimulator16.4 -destination 'generic/platform=iOS Simulator' \
     -configuration Debug CODE_SIGNING_ALLOWED=NO build
   ```

> Tanpa API key, aplikasi **tetap berjalan**: scan menampilkan gaya offline (Core ML) + pesan error ramah; Dashboard menampilkan data lokal/fallback.

---

## Appendix I — Penanganan Error (Graceful Degradation)

| Kondisi | Perilaku |
|---|---|
| Model Core ML tidak ada | `isMLAvailable = false`, app jalan normal, jalur cloud tetap bekerja |
| Tidak ada internet saat scan | Gaya offline tetap muncul, `ScanResult` disimpan dgn `artwork = nil`, pesan ramah auto-hilang 4 detik |
| HTTP 429 (rate limit) | `VisionError.rateLimited` → "Too many requests…" |
| JSON respons kotor | `stripMarkdown` + ekstraksi `{...}` → retry; gagal → `decodingFailed` |
| Izin lokasi ditolak | Fallback ke 5 museum terkenal dunia |
| Met API gagal | Pakai `MetObject.fallback` |
| Wikipedia tak punya potret | Kartu seniman tampil tanpa foto (tidak crash) |
| Google sign-in dibatalkan | Diam-diam, tanpa pesan error |

`enum VisionError` (LocalizedError): `missingAPIKey, invalidURL, invalidResponse, emptyResponse, rateLimited, encodingFailed, decodingFailed, network(String), httpError(Int,String)` — semua punya `errorDescription` ramah pengguna.

**Aturan emas:** tidak ada force-unwrap pada loading model, respons jaringan, atau decode JSON. Selalu optional binding + typed error.

---

## Appendix J — Gotchas Swift 5.8 / Xcode 14 yang Dipatuhi

1. `@ViewBuilder` pada computed `some View` yang memuat `let` sebelum ekspresi view.
2. `VStack` body besar (10+ item dgn `if`) dipecah jadi beberapa `@ViewBuilder` (lihat `detailSectionsTop`/`detailSectionsBottom` di ArtworkDetailView).
3. `var` disalin ke `let` sebelum masuk closure `Task` (strict concurrency).
4. `VNConfidence` (Float) di-cast eksplisit ke `Double`.
5. `GENERATE_INFOPLIST_FILE = NO` (pakai Info.plist custom).
6. Info.plist tidak di Copy Bundle Resources (hanya via `INFOPLIST_FILE`).
7. `.onChange(of:) { newValue in }` bentuk satu-parameter (iOS 16), bukan dua-parameter (iOS 17).
8. `NavigationStack`/`NavigationLink` gaya iOS 16.

---

*Dokumen ini dibuat dari pembacaan langsung source code MuseumMate. Untuk laporan akademik, tulis ulang dengan kata-kata Anda sendiri sesuai aturan course.*
