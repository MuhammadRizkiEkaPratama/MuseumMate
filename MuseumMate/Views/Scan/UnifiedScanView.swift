//
//  UnifiedScanView.swift
//  MuseumMate
//
//  The unified Scan experience (Opsi C): a fullscreen live camera that
//  classifies art style in real time, a large gold shutter to identify the
//  framed work, and a draggable bottom sheet for importing from the photo
//  library. Replaces the separate Explore and Scan tabs.
//

import SwiftUI
import Photos

struct UnifiedScanView: View {
    @EnvironmentObject private var historyStore: ScanHistoryStore
    @StateObject private var viewModel = UnifiedScanViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragTranslation: CGFloat = 0
    @State private var showDetail = false
    @State private var showPicker = false
    @State private var flash = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    cameraLayer
                    dimmingOverlay(geo)
                    topOverlay
                    controlsLayer(geo)
                    bottomSheet(geo)
                    errorLayer(geo)
                    captureFlash
                    importScanningOverlay
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: detailBinding) {
                detailDestination
            }
        }
        .onAppear { viewModel.startCamera() }
        .onDisappear { viewModel.stopCamera() }
        .sheet(isPresented: $showPicker) {
            PhotoLibraryPicker { image in
                collapseSheet()
                Task { await viewModel.scan(image: image, store: historyStore) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: viewModel.scanPhase) { phase in
            if phase == .complete {
                collapseSheet()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { showDetail = true }
            }
        }
        .onChange(of: viewModel.sheetState) { state in
            if state != .collapsed { viewModel.recents.loadIfNeeded() }
        }
    }

    // MARK: - Navigation

    private var detailBinding: Binding<Bool> {
        Binding(
            get: { showDetail },
            set: { newValue in
                showDetail = newValue
                if !newValue { viewModel.clearResult() }
            }
        )
    }

    @ViewBuilder
    private var detailDestination: some View {
        if let result = viewModel.currentResult {
            ArtworkDetailView(result: result)
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            Haptics.tap()
                            showDetail = false
                        } label: {
                            Label("Camera", systemImage: "chevron.left")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.appAccent)
                        }
                    }
                }
        }
    }

    // MARK: - Layer 1 — camera

    @ViewBuilder
    private var cameraLayer: some View {
        Group {
            if viewModel.permissionDenied {
                permissionDeniedView
            } else {
                CameraPreviewView(session: viewModel.camera.session)
            }
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionDeniedView: some View {
        ZStack {
            Color.appBackground
            VStack(spacing: 16) {
                Image(systemName: "camera.slash")
                    .font(.system(size: 46, weight: .light))
                    .foregroundStyle(Color.appTextMuted)
                Text("Camera access is off")
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Color.appTextSecondary)
                Text("Enable the camera in Settings to scan live, or import a photo from the sheet below.")
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
                Button {
                    Haptics.tap()
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appBackground)
                        .padding(.horizontal, 22)
                        .frame(height: 44)
                        .background(Capsule().fill(Color.appAccent))
                }
                .buttonStyle(.pressable)
            }
            .padding(.bottom, 120)
        }
    }

    // MARK: - Background dimming (when the sheet is up)

    @ViewBuilder
    private func dimmingOverlay(_ geo: GeometryProxy) -> some View {
        let opacity = dimOpacity(geo)
        Color.appBackground
            .opacity(opacity)
            .ignoresSafeArea()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(opacity > 0.02)
            .onTapGesture { collapseSheet() }
    }

    // MARK: - Layer 2 — top overlay

    private var topOverlay: some View {
        VStack {
            HStack {
                Text("MuseumMate")
                    .font(.system(.subheadline, design: .serif).weight(.medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 6, y: 1)

                Spacer()

                if viewModel.hasTorch {
                    torchButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var torchButton: some View {
        Button {
            viewModel.toggleTorch()
        } label: {
            Image(systemName: viewModel.torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(viewModel.torchOn ? Color.appAccent : .white)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(viewModel.torchOn ? Color.appAccent.opacity(0.3) : .clear)
                )
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(viewModel.torchOn ? "Turn off flashlight" : "Turn on flashlight")
    }

    // MARK: - Layers 3 & 4 — style badge + shutter

    @ViewBuilder
    private func controlsLayer(_ geo: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            if showStyleBadge {
                StyleOverlayView(style: viewModel.detectedArtist, confidence: viewModel.styleConfidence)
            }
            if viewModel.isScanning && viewModel.importPreview == nil {
                phaseCapsule
            }
            shutterButton
        }
        .opacity(controlsOpacity(geo))
        .padding(.bottom, shownHeight(geo) + 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(controlsOpacity(geo) > 0.2)
    }

    private var phaseCapsule: some View {
        Text(viewModel.scanPhase.label)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .id(viewModel.scanPhase.label)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: viewModel.scanPhase)
    }

    @ViewBuilder
    private var shutterButton: some View {
        if viewModel.isScanning && viewModel.importPreview == nil {
            PulsingRing(size: 72)
                .frame(width: 72, height: 72)
                .accessibilityLabel("Scanning")
        } else {
            Button {
                guard !viewModel.isScanning else { return }
                if !reduceMotion { triggerFlash() }
                Task { await viewModel.scanCurrentFrame(store: historyStore) }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(Color.appAccent, lineWidth: 3)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 48, height: 48)
                }
                .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
            }
            .buttonStyle(ShutterButtonStyle())
            .disabled(viewModel.permissionDenied)
            .accessibilityLabel("Scan artwork")
            .accessibilityHint("Captures the current camera frame and identifies the artwork")
        }
    }

    // MARK: - Layer 5 — bottom sheet

    @ViewBuilder
    private func bottomSheet(_ geo: GeometryProxy) -> some View {
        let full = fullHeight(geo)
        let shown = shownHeight(geo)
        sheetContent(geo)
            .frame(height: full, alignment: .top)
            .frame(maxWidth: .infinity)
            .background(sheetBackground)
            .offset(y: full - shown)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(edges: .bottom)
            .gesture(sheetDrag(geo))
    }

    private var sheetBackground: some View {
        UnevenTopRoundedRectangle(radius: 24)
            .fill(Color.appBackground.opacity(0.85))
            .background(.ultraThinMaterial, in: UnevenTopRoundedRectangle(radius: 24))
            .overlay(
                UnevenTopRoundedRectangle(radius: 24)
                    .strokeBorder(Color.appAccent.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.4), radius: 12, y: -4)
    }

    @ViewBuilder
    private func sheetContent(_ geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            handleBar
            importHeaderRow
            expandedSheetBody
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }

    private var handleBar: some View {
        Capsule()
            .fill(Color.appTextMuted.opacity(0.5))
            .frame(width: 36, height: 4)
            .padding(.top, 12)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Photo import sheet")
            .accessibilityHint("Drag up to import a photo")
    }

    private var importHeaderRow: some View {
        Button {
            Haptics.tap()
            viewModel.recents.loadIfNeeded()
            snap(to: viewModel.sheetState == .collapsed ? .halfExpanded : .collapsed)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.appAccent)
                Text("Import Photo")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: viewModel.sheetState == .collapsed ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appTextMuted)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }

    @ViewBuilder
    private var expandedSheetBody: some View {
        VStack(alignment: .leading, spacing: 18) {
            recentPhotosSection
            libraryButtons
        }
        .padding(.top, 20)
    }

    @ViewBuilder
    private var recentPhotosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Photos").sectionLabel()
                Spacer()
                if !viewModel.recents.items.isEmpty {
                    Text("\(viewModel.recents.items.count)")
                        .font(.caption2)
                        .foregroundStyle(Color.appTextMuted)
                }
            }

            if viewModel.recents.items.isEmpty {
                Text(viewModel.recents.authorized
                     ? "No recent photos found."
                     : "Allow photo access to see recent photos here.")
                    .font(.caption)
                    .foregroundStyle(Color.appTextMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 80)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.recents.items) { item in
                            recentThumbnail(item)
                        }
                    }
                }
            }
        }
    }

    private func recentThumbnail(_ item: RecentPhotosLoader.Item) -> some View {
        Button {
            Haptics.tap()
            collapseSheet()
            Task {
                if let full = await viewModel.recents.fullImage(for: item.asset) {
                    await viewModel.scan(image: full, store: historyStore)
                }
            }
        } label: {
            Image(uiImage: item.thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Scan this recent photo")
    }

    private var libraryButtons: some View {
        VStack(spacing: 10) {
            Button {
                Haptics.tap()
                showPicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "photo.stack")
                    Text("Choose from Library").font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.appSurface))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.appAccent.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.pressable)

            Button {
                Haptics.tap()
                showPicker = true
            } label: {
                Text("Browse All")
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.pressable)
        }
    }

    // MARK: - Error card

    @ViewBuilder
    private func errorLayer(_ geo: GeometryProxy) -> some View {
        if let message = viewModel.errorMessage {
            errorCard(message)
                .padding(.horizontal, 20)
                .padding(.bottom, shownHeight(geo) + 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.museumSpring, value: viewModel.errorMessage)
        }
    }

    private func errorCard(_ message: String) -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color.appDanger).frame(width: 4)
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Haptics.tap()
                    viewModel.dismissError()
                } label: {
                    Text("Try Again")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appAccent)
                }
                .buttonStyle(.pressable)
            }
            .padding(14)
            Spacer(minLength: 0)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.appSurface)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 10, y: 2)
    }

    // MARK: - Capture flash

    @ViewBuilder
    private var captureFlash: some View {
        Color.white
            .opacity(flash ? 0.6 : 0)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    // MARK: - Import scanning overlay

    @ViewBuilder
    private var importScanningOverlay: some View {
        if viewModel.isScanning, let preview = viewModel.importPreview {
            ZStack {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                Color.appBackground.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 18) {
                    PulsingRing(size: 56)
                    Text(viewModel.scanPhase.label)
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)
                        .id(viewModel.scanPhase.label)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: viewModel.scanPhase)
                }
            }
            .transition(.opacity)
        }
    }

    // MARK: - Sheet geometry

    private func collapsedHeight(_ geo: GeometryProxy) -> CGFloat { 80 + geo.safeAreaInsets.bottom }
    private func halfHeight(_ geo: GeometryProxy) -> CGFloat { geo.size.height * 0.40 }
    private func fullHeight(_ geo: GeometryProxy) -> CGFloat { geo.size.height * 0.85 }

    private func baseHeight(for state: UnifiedScanViewModel.SheetState, _ geo: GeometryProxy) -> CGFloat {
        switch state {
        case .collapsed: return collapsedHeight(geo)
        case .halfExpanded: return halfHeight(geo)
        case .fullExpanded: return fullHeight(geo)
        }
    }

    private func shownHeight(_ geo: GeometryProxy) -> CGFloat {
        let base = baseHeight(for: viewModel.sheetState, geo)
        return min(max(base - dragTranslation, collapsedHeight(geo)), fullHeight(geo))
    }

    private func controlsOpacity(_ geo: GeometryProxy) -> CGFloat {
        guard !viewModel.permissionDenied else { return 0 }
        let half = halfHeight(geo)
        let full = fullHeight(geo)
        let shown = shownHeight(geo)
        let toFull = min(max((shown - half) / max(full - half, 1), 0), 1)
        return 1 - toFull
    }

    private func dimOpacity(_ geo: GeometryProxy) -> CGFloat {
        let collapsed = collapsedHeight(geo)
        let half = halfHeight(geo)
        let shown = shownHeight(geo)
        let progress = min(max((shown - collapsed) / max(half - collapsed, 1), 0), 1)
        return progress * 0.45
    }

    private var showStyleBadge: Bool {
        viewModel.isMLAvailable
            && !viewModel.permissionDenied
            && viewModel.detectedArtist != "—"
            && !viewModel.detectedArtist.isEmpty
    }

    // MARK: - Sheet drag & snapping

    private func sheetDrag(_ geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                onDragEnded(value, geo)
            }
    }

    private func onDragEnded(_ value: DragGesture.Value, _ geo: GeometryProxy) {
        let predicted = value.predictedEndTranslation.height
        let target: UnifiedScanViewModel.SheetState
        if predicted < -200 {            // fast flick up → expand
            target = nextState(after: viewModel.sheetState)
        } else if predicted > 200 {      // fast flick down → collapse
            target = previousState(before: viewModel.sheetState)
        } else {                         // settle to the closest state
            target = nearestState(toShown: shownHeight(geo), geo)
        }
        snap(to: target, resettingDrag: true)
    }

    private func nextState(after state: UnifiedScanViewModel.SheetState) -> UnifiedScanViewModel.SheetState {
        switch state {
        case .collapsed: return .halfExpanded
        case .halfExpanded: return .fullExpanded
        case .fullExpanded: return .fullExpanded
        }
    }

    private func previousState(before state: UnifiedScanViewModel.SheetState) -> UnifiedScanViewModel.SheetState {
        switch state {
        case .fullExpanded: return .halfExpanded
        case .halfExpanded: return .collapsed
        case .collapsed: return .collapsed
        }
    }

    private func nearestState(toShown shown: CGFloat, _ geo: GeometryProxy) -> UnifiedScanViewModel.SheetState {
        let candidates: [(UnifiedScanViewModel.SheetState, CGFloat)] = [
            (.collapsed, collapsedHeight(geo)),
            (.halfExpanded, halfHeight(geo)),
            (.fullExpanded, fullHeight(geo))
        ]
        return candidates.min { abs($0.1 - shown) < abs($1.1 - shown) }?.0 ?? .collapsed
    }

    private var snapAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.2)
            : .spring(response: 0.35, dampingFraction: 0.75)
    }

    private func snap(to state: UnifiedScanViewModel.SheetState, resettingDrag: Bool = true) {
        withAnimation(snapAnimation) {
            if resettingDrag { dragTranslation = 0 }
            viewModel.sheetState = state
        }
    }

    private func collapseSheet() {
        snap(to: .collapsed)
    }

    // MARK: - Flash

    private func triggerFlash() {
        flash = true
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.15)) { flash = false }
        }
    }
}

// MARK: - Shutter button style (a more dramatic press than the app default)

private struct ShutterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.museumSpring, value: configuration.isPressed)
    }
}

// MARK: - Top-only rounded rectangle (iOS 16 safe)

/// A rectangle with only its top two corners rounded — the sheet shape.
private struct UnevenTopRoundedRectangle: InsettableShape {
    var radius: CGFloat
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = min(radius, min(rect.width, rect.height) / 2)
        let inset = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path()
        path.move(to: CGPoint(x: inset.minX, y: inset.maxY))
        path.addLine(to: CGPoint(x: inset.minX, y: inset.minY + r))
        path.addArc(
            center: CGPoint(x: inset.minX + r, y: inset.minY + r),
            radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )
        path.addLine(to: CGPoint(x: inset.maxX - r, y: inset.minY))
        path.addArc(
            center: CGPoint(x: inset.maxX - r, y: inset.minY + r),
            radius: r, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false
        )
        path.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

struct UnifiedScanView_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedScanView()
            .environmentObject(ScanHistoryStore())
            .preferredColorScheme(.dark)
    }
}
