//
//  AuthService.swift
//  MuseumMate
//
//  Firebase Auth + Google Sign-In.
//  REQUIRES: firebase-ios-sdk (FirebaseAuth) + GoogleSignIn-iOS SPM packages.
//

import Foundation
import FirebaseAuth
import GoogleSignIn
import FirebaseCore

@MainActor
final class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUserName  = ""
    @Published var currentUserEmail = ""
    @Published var currentUserUID: String? = nil
    @Published var isLoading  = false
    @Published var errorMessage: String?

    private var authListener: AuthStateDidChangeListenerHandle?

    init() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isAuthenticated   = user != nil
                self.currentUserName   = user?.displayName ?? user?.email?.components(separatedBy: "@").first ?? ""
                self.currentUserEmail  = user?.email ?? ""
                self.currentUserUID    = user?.uid
            }
        }
    }

    deinit {
        if let listener = authListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Email / Password

    func signIn(email: String, password: String) async {
        errorMessage = nil
        guard validate(email: email, password: password) else { return }
        isLoading = true
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            errorMessage = firebaseMessage(error)
        }
        isLoading = false
    }

    func signUp(name: String, email: String, password: String) async {
        errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter your name."
            return
        }
        guard validate(email: email, password: password) else { return }
        isLoading = true
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = trimmedName
            try await changeRequest.commitChanges()
        } catch {
            errorMessage = firebaseMessage(error)
        }
        isLoading = false
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() async {
        errorMessage = nil
        isLoading = true
        do {
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                errorMessage = "Firebase is not configured."
                isLoading = false
                return
            }
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config

            guard let windowScene = await UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  let rootVC = await windowScene.windows.first?.rootViewController
            else {
                errorMessage = "Cannot present sign-in screen."
                isLoading = false
                return
            }

            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google sign-in failed."
                isLoading = false
                return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            try await Auth.auth().signIn(with: credential)
        } catch {
            if (error as NSError).code != GIDSignInError.canceled.rawValue {
                errorMessage = firebaseMessage(error)
            }
        }
        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        } catch {
            errorMessage = firebaseMessage(error)
        }
    }

    // MARK: - Helpers

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

    private func firebaseMessage(_ error: Error) -> String {
        let code = (error as NSError).code
        switch AuthErrorCode(rawValue: code) {
        case .wrongPassword, .invalidCredential:
            return "Incorrect email or password."
        case .emailAlreadyInUse:
            return "This email is already registered."
        case .userNotFound:
            return "No account found for this email."
        case .networkError:
            return "Network error. Check your connection."
        case .tooManyRequests:
            return "Too many attempts. Try again later."
        case .weakPassword:
            return "Password is too weak. Use at least 6 characters."
        default:
            return error.localizedDescription
        }
    }
}
