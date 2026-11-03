//
//  UserProfile.swift
//  MuseumMate
//
//  User state persisted to UserDefaults + Firestore.
//  REQUIRES: firebase-ios-sdk (FirebaseFirestore) SPM packages.
//

import Foundation
import Combine
import FirebaseFirestore

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
    @Published var birthDate: Date? {
        didSet { defaults.set(birthDate?.timeIntervalSince1970 ?? 0, forKey: Keys.birthDate) }
    }
    @Published var country: String {
        didSet { defaults.set(country, forKey: Keys.country) }
    }

    private let defaults = UserDefaults.standard
    private let db = Firestore.firestore()

    private enum Keys {
        static let name       = "museummate_profile_name"
        static let email      = "museummate_profile_email"
        static let onboarding = "museummate_profile_onboarding"
        static let scanCount  = "museummate_profile_scancount"
        static let joinDate   = "museummate_profile_joindate"
        static let birthDate  = "museummate_user_birthdate"
        static let country    = "museummate_user_country"
    }

    init() {
        name     = defaults.string(forKey: Keys.name)  ?? ""
        email    = defaults.string(forKey: Keys.email) ?? ""
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
        scanCount = defaults.integer(forKey: Keys.scanCount)
        let stored = defaults.double(forKey: Keys.joinDate)
        joinDate   = stored > 0 ? Date(timeIntervalSince1970: stored) : Date()
        let storedBirth = defaults.double(forKey: Keys.birthDate)
        birthDate  = storedBirth > 0 ? Date(timeIntervalSince1970: storedBirth) : nil
        country    = defaults.string(forKey: Keys.country) ?? ""
        if stored == 0 { defaults.set(joinDate.timeIntervalSince1970, forKey: Keys.joinDate) }
    }

    var initial: String {
        let source = name.isEmpty ? email : name
        return String(source.prefix(1)).uppercased()
    }

    var hasProfileDetails: Bool { birthDate != nil }

    var birthdayMonthDay: (month: Int, day: Int)? {
        guard let birthDate else { return nil }
        let comps = Calendar.current.dateComponents([.month, .day], from: birthDate)
        guard let m = comps.month, let d = comps.day else { return nil }
        return (m, d)
    }

    // MARK: - Firestore sync

    func syncToFirestore(uid: String) {
        var dict: [String: Any] = [
            "name":      name,
            "email":     email,
            "scanCount": scanCount,
            "country":   country,
            "joinDate":  joinDate.timeIntervalSince1970
        ]
        if let b = birthDate { dict["birthDate"] = b.timeIntervalSince1970 }
        db.collection("users").document(uid).setData(dict, merge: true)
    }

    func loadFromFirestore(uid: String) {
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            guard let self, let data = snapshot?.data(), error == nil else { return }
            Task { @MainActor in
                if let n = data["name"]    as? String { self.name    = n }
                if let e = data["email"]   as? String { self.email   = e }
                if let c = data["country"] as? String { self.country = c }
                if let j = data["joinDate"] as? Double, j > 0 {
                    self.joinDate = Date(timeIntervalSince1970: j)
                }
                if let b = data["birthDate"] as? Double, b > 0 {
                    self.birthDate = Date(timeIntervalSince1970: b)
                }
            }
        }
    }

    // MARK: - Reset on sign-out

    func reset() {
        name      = ""
        email     = ""
        scanCount = 0
        birthDate = nil
        country   = ""
        // hasCompletedOnboarding preserved across sign-out intentionally.
    }

    func clearAllLocalData() {
        for key in [Keys.name, Keys.email, Keys.scanCount, Keys.joinDate,
                    Keys.birthDate, Keys.country] {
            defaults.removeObject(forKey: key)
        }
        reset()
    }
}
