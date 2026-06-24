//
//  ProfileSetupView.swift
//  MuseumMate
//
//  Shown once, right after the first sign-up, before the main app. Collects
//  the visitor's full name, date of birth, and country. The birth date powers
//  the "born on your birthday" artist feature in the Artists tab. Saving sets
//  profile.birthDate, which lets RootView advance into ContentView.
//

import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var profile: UserProfile

    @State private var name: String = ""
    @State private var birthDate: Date = ProfileSetupView.defaultBirthDate
    @State private var country: String = ""
    @State private var showValidation = false

    // Default the picker to a sensible adult date (~25 years ago).
    private static var defaultBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var trimmedCountry: String { country.trimmingCharacters(in: .whitespaces) }
    private var isValid: Bool { !trimmedName.isEmpty && !trimmedCountry.isEmpty }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
                        .fadeSlideIn()
                    nameField
                        .fadeSlideIn(delay: 0.06)
                    birthField
                        .fadeSlideIn(delay: 0.12)
                    countryField
                        .fadeSlideIn(delay: 0.18)
                    saveButton
                        .fadeSlideIn(delay: 0.24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            if name.isEmpty { name = auth.currentUserName }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color.appAccent)
            Text("Tell us about you")
                .font(.system(.largeTitle, design: .serif).weight(.regular))
                .foregroundStyle(Color.appTextPrimary)
            Text("A few details to personalize your gallery — including which master shares your birthday.")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Full Name").sectionLabel()
            TextField("", text: $name, prompt: Text("Your name").foregroundColor(.appTextMuted))
                .font(.body)
                .foregroundStyle(Color.appTextPrimary)
                .tint(Color.appAccent)
                .textContentType(.name)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.appSurface))
                .overlay(fieldBorder(invalid: showValidation && trimmedName.isEmpty))
        }
    }

    private var birthField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date of Birth").sectionLabel()
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(Color.appAccent)
                DatePicker(
                    "",
                    selection: $birthDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Color.appAccent)
                .colorScheme(.dark)
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.appSurface))
        }
    }

    private var countryField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Country").sectionLabel()
            TextField("", text: $country, prompt: Text("Where you live").foregroundColor(.appTextMuted))
                .font(.body)
                .foregroundStyle(Color.appTextPrimary)
                .tint(Color.appAccent)
                .textContentType(.countryName)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.appSurface))
                .overlay(fieldBorder(invalid: showValidation && trimmedCountry.isEmpty))
        }
    }

    private var saveButton: some View {
        VStack(spacing: 10) {
            Button {
                save()
            } label: {
                Text("Enter MuseumMate")
                    .font(.headline)
                    .foregroundStyle(Color.appBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isValid ? Color.appAccent : Color.appAccent.opacity(0.4))
                    )
            }
            .buttonStyle(.pressable)

            if showValidation && !isValid {
                Text("Please fill in your name and country.")
                    .font(.caption)
                    .foregroundStyle(Color.appDanger)
            }
        }
    }

    private func fieldBorder(invalid: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(invalid ? Color.appDanger.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 0.5)
    }

    // MARK: - Save

    private func save() {
        guard isValid else {
            withAnimation(.museumSpring) { showValidation = true }
            Haptics.error()
            return
        }
        Haptics.success()
        profile.name = trimmedName
        profile.country = trimmedCountry
        auth.currentUserName = trimmedName
        // Set birthDate last — RootView watches it to advance into the app.
        profile.birthDate = birthDate
    }
}

struct ProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSetupView()
            .environmentObject(AuthService())
            .environmentObject(UserProfile())
            .preferredColorScheme(.dark)
    }
}
