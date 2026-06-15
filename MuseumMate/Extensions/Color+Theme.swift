//
//  Color+Theme.swift
//  MuseumMate
//
//  Museum palette — semantic tokens only; never use raw hex in views.
//

import SwiftUI

extension Color {
    static let appBackground    = Color(hex: "#12100E")
    static let appSurface       = Color(hex: "#1E1B18")
    static let appSurfaceUp     = Color(hex: "#2A2620")
    static let appAccent        = Color(hex: "#C9A227")  // museum gold
    static let appAccentMuted   = Color(hex: "#5C4A1A")
    static let appTextPrimary   = Color.white
    static let appTextSecondary = Color(hex: "#B8AE9E")
    static let appTextMuted     = Color(hex: "#6B6258")
    static let appDanger        = Color(hex: "#E5484D")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
