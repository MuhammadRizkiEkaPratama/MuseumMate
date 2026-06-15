//
//  UserProfile.swift
//  MuseumMate
//
//  Lightweight user state, persisted to UserDefaults. Each @Published
//  field writes its key on didSet. Firestore sync arrives in Phase 7.
//

import Foundation
import Combine

@MainActor
final class UserProfile: ObservableObject {
    @Published var name: String {
        didSet { defaults.set(name, forKey: Keys.name) }
    }
    @Published var email: String {
        didSet { defaults.set(email, forKey: Keys.email) }
    }
    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) }
    }
    @Published var scanCount: Int {
        didSet { defaults.set(scanCount, forKey: Keys.scanCount) }
    }
    @Published var joinDate: Date {
        didSet { defaults.set(joinDate.timeIntervalSince1970, forKey: Keys.joinDate) }
    }

    // TODO: Firebase uid — wire in Phase 7.

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let name = "museummate_profile_name"
        static let email = "museummate_profile_email"
        static let onboarding = "museummate_profile_onboarding"
        static let scanCount = "museummate_profile_scancount"
        static let joinDate = "museummate_profile_joindate"
    }

    init() {
        name = defaults.string(forKey: Keys.name) ?? ""
        email = defaults.string(forKey: Keys.email) ?? ""
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
        scanCount = defaults.integer(forKey: Keys.scanCount)
        let stored = defaults.double(forKey: Keys.joinDate)
        joinDate = stored > 0 ? Date(timeIntervalSince1970: stored) : Date()
        // Persist join date on first run.
        if stored == 0 { defaults.set(joinDate.timeIntervalSince1970, forKey: Keys.joinDate) }
    }

    var initial: String {
        let source = name.isEmpty ? email : name
        return String(source.prefix(1)).uppercased()
    }

    func reset() {
        name = ""
        email = ""
        scanCount = 0
        // hasCompletedOnboarding intentionally preserved across sign-out.
    }

    // TODO: Firebase — syncToFirestore() / loadFromFirestore(uid:) in Phase 7.
}
