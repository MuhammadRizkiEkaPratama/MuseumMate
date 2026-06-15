//
//  DailyPaintingSheet.swift
//  MuseumMate
//
//  Full presentation of the Met "painting of the day" with its AI quote
//  and a link out to the Met collection page.
//

import SwiftUI

struct DailyPaintingSheet: View {
    let painting: MetObject
    let quote: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    image
                        .fadeSlideIn()

                    VStack(alignment: .leading, spacing: 20) {
                        identity.fadeSlideIn(delay: 0.06)
                        if !quote.isEmpty {
                            quoteBlock.fadeSlideIn(delay: 0.12)
                        }
                        details.fadeSlideIn(delay: 0.18)
                        metLink.fadeSlideIn(delay: 0.24)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 40)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Haptics.tap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.appTextMuted)
                    }
                }
            }
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    @ViewBuilder
    private var image: some View {
        AsyncImage(url: URL(string: painting.primaryImage)) { phase in
            switch phase {
            case .success(let img):
                img.resizable().scaledToFit()
            case .failure:
                fallbackArt
            default:
                SkeletonView(cornerRadius: 0).frame(height: 320)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: 360)
    }

    private var fallbackArt: some View {
        Rectangle()
            .fill(Color.appSurface)
            .frame(height: 320)
            .overlay(
                Image(systemName: "photo.artframe")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color.appTextMuted)
            )
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Met Collection").sectionLabel()
            Text(painting.title)
                .font(.system(.largeTitle, design: .serif).weight(.regular))
                .foregroundStyle(Color.appTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(painting.artistOrUnknown)
                .font(.title3.weight(.light))
                .foregroundStyle(Color.appTextSecondary)
            if !painting.objectDate.isEmpty {
                Text(painting.objectDate)
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextMuted)
            }
        }
    }

    private var quoteBlock: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color.appAccent.opacity(0.6)).frame(width: 4)
            Text(quote)
                .font(.system(.body, design: .serif).italic())
                .foregroundStyle(Color.appTextPrimary)
                .lineSpacing(6)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 0)
    }

    @ViewBuilder
    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Details").sectionLabel()
            detailRow("Medium", painting.medium)
            detailRow("Department", painting.department)
            detailRow("Culture", painting.culture)
            detailRow("Period", painting.period)
            detailRow("Credit", painting.creditLine)
        }
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String) -> some View {
        if !value.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(0.8)
                    .foregroundStyle(Color.appTextMuted)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var metLink: some View {
        if let url = URL(string: painting.objectURL), !painting.objectURL.isEmpty {
            Link(destination: url) {
                HStack {
                    Text("View on Met Museum")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .foregroundStyle(Color.appAccent)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.appSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 0.5)
                )
            }
        }
    }
}
