//
//  AuthView.swift
//  MuseumMate
//
//  The first impression after the splash. Premium, editorial, calm.
//  Stub auth only — see AuthService. Firebase wiring arrives in Phase 7.
//

import SwiftUI

struct AuthView: View {
    enum Mode { case signIn, signUp }
    private enum Field { case name, email, password }

    @EnvironmentObject private var auth: AuthService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var mode: Mode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focused: Field?

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    header
                    modeSwitcher
                    fields
                    if let message = auth.errorMessage {
                        errorHint(message)
                    }
                    primaryButton
                    divider
                    googleButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 64)
                .padding(.bottom, 40)
            }
        }
        .onChange(of: mode) { _ in
            auth.errorMessage = nil
            Haptics.tap()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        VStack(spacing: 14) {
            Text("MuseumMate")
                .font(.system(.largeTitle, design: .serif).weight(.light))
                .foregroundStyle(Color.appTextPrimary)

            Rectangle()
                .fill(Color.appAccent)
                .frame(width: 44, height: 2)

            Text("Every artwork has a story.")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
        .fadeSlideIn()
    }

    // MARK: - Mode switcher (sliding gold underline)

    @ViewBuilder
    private var modeSwitcher: some View {
        HStack(spacing: 0) {
            switcherTab("Sign In", target: .signIn)
            switcherTab("Sign Up", target: .signUp)
        }
        .background(alignment: .bottom) {
            GeometryReader { proxy in
                Rectangle()
                    .fill(Color.appAccent)
                    .frame(width: proxy.size.width / 2, height: 2)
                    .offset(x: mode == .signIn ? 0 : proxy.size.width / 2)
                    .animation(.museumSpring, value: mode)
            }
            .frame(height: 2)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
        .fadeSlideIn(delay: 0.06)
    }

    private func switcherTab(_ title: String, target: Mode) -> some View {
        Button {
            withAnimation(.museumSpring) { mode = target }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(mode == target ? Color.appTextPrimary : Color.appTextMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(mode == target ? .isSelected : [])
    }

    // MARK: - Fields

    @ViewBuilder
    private var fields: some View {
        VStack(spacing: 16) {
            if mode == .signUp {
                AuthField(
                    title: "Name",
                    text: $name,
                    isFocused: focused == .name,
                    icon: "person"
                )
                .focused($focused, equals: .name)
                .textContentType(.name)
                .submitLabel(.next)
                .onSubmit { focused = .email }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            AuthField(
                title: "Email",
                text: $email,
                isFocused: focused == .email,
                icon: "envelope"
            )
            .focused($focused, equals: .email)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .textContentType(.emailAddress)
            .autocorrectionDisabled()
            .submitLabel(.next)
            .onSubmit { focused = .password }

            AuthField(
                title: "Password",
                text: $password,
                isFocused: focused == .password,
                icon: "lock",
                isSecure: true
            )
            .focused($focused, equals: .password)
            .textContentType(.password)
            .submitLabel(.go)
            .onSubmit { Task { await submit() } }
        }
        .animation(.museumSpring, value: mode)
        .fadeSlideIn(delay: 0.12)
    }

    private func errorHint(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
            Text(message)
                .font(.footnote)
        }
        .foregroundStyle(Color.appDanger)
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity)
    }

    // MARK: - Buttons

    @ViewBuilder
    private var primaryButton: some View {
        Button {
            Haptics.tap()
            Task { await submit() }
        } label: {
            ZStack {
                if auth.isLoading {
                    PulsingDots()
                } else {
                    Text(mode == .signIn ? "Sign In" : "Create Account")
                        .font(.headline)
                }
            }
            .foregroundStyle(Color.appBackground)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appAccent)
            )
        }
        .buttonStyle(.pressable)
        .disabled(auth.isLoading)
        .fadeSlideIn(delay: 0.18)
    }

    @ViewBuilder
    private var divider: some View {
        HStack(spacing: 12) {
            line
            Text("or")
                .font(.caption)
                .foregroundStyle(Color.appTextMuted)
            line
        }
        .fadeSlideIn(delay: 0.24)
    }

    private var line: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
    }

    @ViewBuilder
    private var googleButton: some View {
        Button {
            Haptics.tap()
            Task { await auth.signInWithGoogle() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "g.circle.fill")
                    .font(.title3)
                Text("Continue with Google")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(Color.appTextPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.appAccent.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.pressable)
        .disabled(auth.isLoading)
        .fadeSlideIn(delay: 0.30)
    }

    // MARK: - Actions

    private func submit() async {
        focused = nil
        switch mode {
        case .signIn:
            await auth.signIn(email: email, password: password)
        case .signUp:
            await auth.signUp(name: name, email: email, password: password)
        }
    }
}

// MARK: - Field component

private struct AuthField: View {
    let title: String
    @Binding var text: String
    let isFocused: Bool
    let icon: String
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(isFocused ? Color.appAccent : Color.appTextMuted)
                .frame(width: 20)

            Group {
                if isSecure {
                    SecureField("", text: $text, prompt: prompt)
                } else {
                    TextField("", text: $text, prompt: prompt)
                }
            }
            .font(.body)
            .foregroundStyle(Color.appTextPrimary)
            .tint(Color.appAccent)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    Color.appAccent.opacity(isFocused ? 0.55 : 0.15),
                    lineWidth: isFocused ? 1 : 0.5
                )
        )
        .animation(.museumSpring, value: isFocused)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    private var prompt: Text {
        Text(title).foregroundColor(.appTextMuted)
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
            .environmentObject(AuthService())
            .preferredColorScheme(.dark)
    }
}
