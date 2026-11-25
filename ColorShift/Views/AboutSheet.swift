import SwiftUI

/// About (FR11; ios.md §4, §13, §16): the Haptics setting, photo credits with Unsplash referral links, the
/// bundled fonts' OFL licenses, the privacy policy link, and the app version. Opened from the brand row.
struct AboutSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            List {
                Section {
                    Toggle("Haptics", isOn: $model.hapticsEnabled)
                        .accessibilityIdentifier("hapticsToggle")
                } footer: {
                    Text("Taps and ticks when you change photos, move sliders and cross contrast levels.")
                }

                Section {
                    ForEach(PhotoCatalog.all) { photo in
                        Link(destination: photo.photographerURL) {
                            HStack(spacing: Tokens.Spacing.s) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(photo.photographer).foregroundStyle(Color(uiColor: .label))
                                    Text(photo.alt).font(.subheadline).foregroundStyle(Color(uiColor: .secondaryLabel))
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.right")
                                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                                    .accessibilityHidden(true)
                            }
                        }
                        .accessibilityLabel("Photo by \(photo.photographer) on Unsplash: \(photo.alt)")
                        .accessibilityIdentifier("credit.\(photo.id)")
                    }
                } header: {
                    Text("Photos")
                } footer: {
                    Link("All photos from Unsplash", destination: Photo.unsplashURL)
                        .accessibilityIdentifier("unsplashLink")
                }

                Section("Fonts") {
                    ForEach(Self.fonts, id: \.name) { font in
                        NavigationLink(font.name) { LicenseView(title: font.name, file: font.file) }
                            .accessibilityIdentifier("font.\(font.file)")
                    }
                }

                Section {
                    Link("Privacy Policy", destination: AppConfig.privacyPolicyURL)
                        .accessibilityIdentifier("privacyLink")
                } footer: {
                    Text("Color Shift collects no data. Your Haptics setting stays on this iPhone.")
                }

                Section {
                    LabeledContent("Version", value: Self.version)
                }
            }
            .navigationTitle("About Color Shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("aboutDone")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    static let fonts = [(name: "Manrope", file: "Manrope-OFL"), (name: "DM Mono", file: "DMMono-OFL")]

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}

/// A bundled SIL Open Font License text.
private struct LicenseView: View {
    let title: String
    let file: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("license.\(file)")
    }

    private var text: String {
        guard let url = Bundle.main.url(forResource: file, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "SIL Open Font License 1.1" }
        return text
    }
}
