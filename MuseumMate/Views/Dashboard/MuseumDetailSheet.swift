//
//  MuseumDetailSheet.swift
//  MuseumMate
//
//  Full info for a museum tapped in the Dashboard "near you" row.
//

import SwiftUI
import CoreLocation

struct MuseumDetailSheet: View {
    let museum: Museum
    let userLocation: CLLocation?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header.fadeSlideIn()
                    if let km = museum.distanceKm(from: userLocation) {
                        distanceBadge(km).fadeSlideIn(delay: 0.06)
                    }
                    description.fadeSlideIn(delay: 0.12)
                    iconic.fadeSlideIn(delay: 0.18)
                    websiteLink.fadeSlideIn(delay: 0.24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "building.columns")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(Color.appAccent)
                .padding(.bottom, 4)
            Text(museum.name)
                .font(.system(.largeTitle, design: .serif).weight(.regular))
                .foregroundStyle(Color.appTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(museum.city), \(museum.country)")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    private func distanceBadge(_ km: Double) -> some View {
        Label(Museum.formattedDistance(km), systemImage: "location.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.appAccent)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.appAccent.opacity(0.16)))
    }

    private var description: some View {
        Text(museum.description)
            .font(.system(size: 16))
            .foregroundStyle(Color.appTextPrimary.opacity(0.92))
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var iconic: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Don't miss").sectionLabel()
            Text("Home of \(museum.iconicWork).")
                .font(.system(.body, design: .serif))
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    @ViewBuilder
    private var websiteLink: some View {
        if let url = URL(string: museum.websiteURL), !museum.websiteURL.isEmpty {
            Link(destination: url) {
                HStack {
                    Text("Visit website")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .foregroundStyle(Color.appBackground)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.appAccent)
                )
            }
        }
    }
}
