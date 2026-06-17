//
//  CustomTabBar.swift
//  MuseumMate
//
//  Floating museum-gold tab bar: a rounded pill above the home indicator with
//  a moving gold highlight circle under the active tab icon. iOS 16 safe —
//  uses manual offset animation rather than matchedGeometryEffect across tabs.
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selection: AppTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let tabs: [(AppTab, String, String)] = [
        (.dashboard,  "square.grid.2x2", "Home"),
        (.scan,       "camera.aperture",  "Scan"),
        (.collection, "rectangle.stack",  "Art"),
        (.artists,    "person.2",         "Artists"),
        (.profile,    "person.crop.circle", "Profile")
    ]

    private let barHeight: CGFloat = 62

    var body: some View {
        GeometryReader { geo in
            let tabWidth = geo.size.width / CGFloat(tabs.count)
            let activeIndex = tabs.firstIndex(where: { $0.0 == selection }) ?? 0

            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.element.0.hashValue) { index, tab in
                    tabItem(tab: tab, isActive: selection == tab.0)
                        .frame(width: tabWidth)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard selection != tab.0 else { return }
                            Haptics.impact(.light)
                            withAnimation(reduceMotion ? nil : .museumSpring) {
                                selection = tab.0
                            }
                        }
                }
            }
            .frame(height: barHeight)
            .background(alignment: .leading) {
                // Gold raised circle sliding under the active icon
                Circle()
                    .fill(Color.appAccent.opacity(0.18))
                    .frame(width: 48, height: 48)
                    .overlay(Circle().strokeBorder(Color.appAccent.opacity(0.35), lineWidth: 0.5))
                    .offset(
                        x: tabWidth * CGFloat(activeIndex) + (tabWidth - 48) / 2,
                        y: (barHeight - 48) / 2
                    )
                    .animation(reduceMotion ? nil : .museumSpring, value: activeIndex)
            }
            .background(
                // Frosted pill background
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.appBackground.opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 4)
            )
        }
        .frame(height: barHeight)
        .padding(.horizontal, 20)
    }

    private func tabItem(tab: (AppTab, String, String), isActive: Bool) -> some View {
        let active = isActive
        return VStack(spacing: 4) {
            Image(systemName: tab.1)
                .font(.system(size: tab.0 == .scan ? 20 : 18, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? Color.appAccent : Color.appTextMuted)
                .scaleEffect(active ? 1.08 : 1.0)

            Text(tab.2)
                .font(.system(size: 9, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? Color.appAccent : Color.appTextMuted)
        }
        .animation(nil, value: active)
    }
}
