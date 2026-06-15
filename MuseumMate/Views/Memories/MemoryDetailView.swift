//
//  MemoryDetailView.swift
//  MuseumMate
//
//  Full-bleed memory photo with an editable caption and an optional link
//  to the scan it belongs with.
//

import SwiftUI
import UIKit

struct MemoryDetailView: View {
    let photo: MemoryPhoto

    @EnvironmentObject private var memoriesStore: MemoriesStore
    @EnvironmentObject private var historyStore: ScanHistoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var image: UIImage?
    @State private var caption = ""
    @State private var isEditingCaption = false
    @State private var showLinkPicker = false
    @State private var showShare = false
    @FocusState private var captionFocused: Bool

    private var current: MemoryPhoto {
        memoriesStore.memories.first { $0.id == photo.id } ?? photo
    }

    private var linkedScan: ScanResult? {
        guard let id = current.linkedScanResultID else { return nil }
        return historyStore.scans.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                photoLayer
                topBar
                bottomPanel
            }
            .navigationBarHidden(true)
            .onAppear {
                image = ImageStore.loadImage(named: current.imageFileName)
                caption = current.caption
            }
            .sheet(isPresented: $showLinkPicker) {
                ScanLinkPicker(photo: current)
            }
            .sheet(isPresented: $showShare) {
                if let image { ShareSheet(items: [image]) }
            }
        }
    }

    // MARK: - Photo

    @ViewBuilder
    private var photoLayer: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
        } else {
            Color.appSurface.ignoresSafeArea()
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                Haptics.tap(); dismiss()
            } label: {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(radius: 4)
            }
            Spacer()
            Button {
                Haptics.tap(); showShare = true
            } label: {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(radius: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Bottom panel

    private var bottomPanel: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 16) {
                captionBlock
                if let scan = linkedScan {
                    linkedCard(scan)
                } else {
                    linkButton
                }
                Text(current.formattedDate)
                    .font(.caption)
                    .foregroundStyle(Color.appTextMuted)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .background(Color.appBackground.opacity(0.6))
            .clipShape(RoundedCornerShape(radius: 24, corners: [.topLeft, .topRight]))
        }
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private var captionBlock: some View {
        if isEditingCaption {
            VStack(alignment: .leading, spacing: 8) {
                TextField("", text: $caption, prompt: Text("Add a caption").foregroundColor(.appTextMuted), axis: .vertical)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Color.appTextPrimary)
                    .tint(Color.appAccent)
                    .focused($captionFocused)
                    .lineLimit(1...4)
                Rectangle().fill(Color.appAccent).frame(height: 1)
                Button {
                    saveCaption()
                } label: {
                    Text("Done")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appAccent)
                }
            }
        } else {
            Button {
                isEditingCaption = true
                captionFocused = true
            } label: {
                Text(current.caption.isEmpty ? "Tap to add a caption" : current.caption)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(current.caption.isEmpty ? Color.appTextMuted : Color.appTextPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.plain)
        }
    }

    private func linkedCard(_ scan: ScanResult) -> some View {
        NavigationLink {
            ArtworkDetailView(result: scan)
        } label: {
            HStack(spacing: 12) {
                ScanThumbnail(result: scan, cornerRadius: 8)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Linked scan").sectionLabel()
                    Text(scan.displayTitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.up.right").foregroundStyle(Color.appAccent)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.appSurface))
        }
        .buttonStyle(.pressable)
    }

    private var linkButton: some View {
        Button {
            Haptics.tap(); showLinkPicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "link")
                Text("Link to a Scan").font(.subheadline.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(Color.appAccent)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.appSurface))
        }
        .buttonStyle(.pressable)
    }

    private func saveCaption() {
        var updated = current
        updated.caption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        memoriesStore.update(updated)
        isEditingCaption = false
        captionFocused = false
        Haptics.tap()
    }
}

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Rounded specific corners

struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
