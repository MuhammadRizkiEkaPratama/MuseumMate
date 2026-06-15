//
//  SkeletonView.swift
//  MuseumMate
//
//  A pulsing-gold placeholder shown while content loads — never a spinner.
//  Honors Reduce Motion (settles to a static dim fill).
//

import SwiftUI

struct SkeletonView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var cornerRadius: CGFloat = 12
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.appAccent.opacity(reduceMotion ? 0.12 : (pulse ? 0.18 : 0.06)))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.appSurface.opacity(0.4))
                    .blendMode(.overlay)
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .accessibilityHidden(true)
    }
}

/// A few stacked skeleton lines for text blocks.
struct SkeletonLines: View {
    var count: Int = 2
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                SkeletonView(cornerRadius: 6)
                    .frame(height: 14)
                    .frame(maxWidth: index == count - 1 ? 180 : .infinity, alignment: .leading)
            }
        }
    }
}

struct SkeletonView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            SkeletonView().frame(height: 120)
            SkeletonLines(count: 3)
        }
        .padding()
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
    }
}
