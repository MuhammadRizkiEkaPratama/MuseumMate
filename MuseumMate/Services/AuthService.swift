//
//  AuthService.swift
//  MuseumMate
//
//  STUB authentication. No real backend yet — all methods simulate an
//  async network delay and persist a local "logged in" flag.
//  Firebase Auth + Google Sign-In are wired in Phase 7.
//

import Foundation
import Combine

@MainActor
final class AuthService: ObservableObject {
    @Published var isAuthenticated: Bool
    @Published var currentUserName: String
    @Published var currentUserEmail: String
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let authed = "museummate_auth_isAuthenticated"
        static let name = "museummate_auth_name"
        static let email = "museummate_auth_email"
    }

    init() {
        isAuthenticated = defaults.bool(forKey: Keys.authed)
        currentUserName = defaults.string(forKey: Keys.name) ?? ""
        currentUserEmail = defaults.string(forKey: Keys.email) ?? ""
    }

    // MARK: - Email / password (stubbed)

    func signIn(email: String, password: String) async {
        errorMessage = nil
        guard validate(email: email, password: password) else { return }
        isLoading = true
        // Simulate network latency.
        try? await Task.sleep(nanoseconds: 800_000_000)
        // TODO: Firebase — replace with Auth.auth().signIn(withEmail:password:).
        finishLogin(name: nameFromEmail(email), email: email)
        isLoading = false
    }

    func signUp(name: String, email: String, password: String) async {
        errorMessage = nil
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your name."
            return
        }
        guard validate(email: email, password: password) else { return }
        isLoading = true
        try? await Task.sleep(nanoseconds: 800_000_000)
        // TODO: Firebase — replace with Auth.auth().createUser(withEmail:password:).
        finishLogin(name: name, email: email)
        isLoading = false
    }

    func signInWithGoogle() async {
        errorMessage = nil
        isLoading = true
        try? await Task.sleep(nanoseconds: 800_000_000)
        // TODO: Firebase — replace with GIDSignIn + Firebase credential exchange.
        finishLogin(name: "Gallery Guest", email: "guest@museummate.app")
        isLoading = false
    }

    func signOut() {
        // TODO: Firebase — call try? Auth.auth().signOut() and GIDSignIn.sharedInstance.signOut().
        isAuthenticated = false
        currentUserName = ""
        currentUserEmail = ""
        defaults.set(false, forKey: Keys.authed)
        defaults.removeObject(forKey: Keys.name)
        defaults.removeObject(forKey: Keys.email)
    }

    // MARK: - Helpers

    private func finishLogin(name: String, email: String) {
        currentUserName = name
        currentUserEmail = email
        isAuthenticated = true
        defaults.set(true, forKey: Keys.authed)
        defaults.set(name, forKey: Keys.name)
        defaults.set(email, forKey: Keys.email)
    }

    private func validate(email: String, password: String) -> Bool {
        guard email.contains("@"), email.contains(".") else {
            errorMessage = "Enter a valid email address."
            return false
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return false
        }
        return true
    }

    private func nameFromEmail(_ email: String) -> String {
        let handle = email.split(separator: "@").first.map(String.init) ?? "Visitor"
        return handle.prefix(1).uppercased() + handle.dropFirst()
    }
}
