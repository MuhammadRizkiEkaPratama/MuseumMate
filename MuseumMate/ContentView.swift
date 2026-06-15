//
//  ContentView.swift
//  MuseumMate
//
//  Phase 0 placeholder — replaced by the five-tab shell in Phase 1.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("MuseumMate")
                    .font(.system(.largeTitle, design: .serif))
                    .foregroundStyle(Color.appTextPrimary)
                    .fadeSlideIn()

                Rectangle()
                    .fill(Color.appAccent)
                    .frame(width: 44, height: 2)
                    .fadeSlideIn(delay: 0.12)

                Text("Every artwork has a story")
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
                    .fadeSlideIn(delay: 0.24)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
