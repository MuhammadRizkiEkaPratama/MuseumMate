//
//  EmptyStateView.swift
//  MuseumMate
//
//  Intentional, evocative empty states — never a blank screen.
//

import SwiftUI

struct EmptyStateView: View {
    let symbol: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.appTextMuted)

            Text(message)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)

            if let actionTitle, let action {
                Button {
                    Haptics.tap()
                    action()
                } label: {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appBackground)
                        .padding(.horizontal, 24)
                        .frame(height: 46)
                        .background(
                            Capsule().fill(Color.appAccent)
                        )
                }
                .buttonStyle(.pressable)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .fadeSlideIn()
    }
}

struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyStateView(
            symbol: "photo.artframe",
            message: "Your discoveries will live here.",
            actionTitle: "Scan an Artwork",
            action: {}
        )
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
    }
}
