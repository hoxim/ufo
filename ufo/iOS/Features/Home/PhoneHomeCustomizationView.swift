#if os(iOS)

import SwiftUI
import Charts


struct PhoneHomeCustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences
    let keepsEditModeActive: Bool

    init(keepsEditModeActive: Bool = false) {
        self.keepsEditModeActive = keepsEditModeActive
    }

    var body: some View {
        @Bindable var appPreferences = appPreferences

        NavigationStack {
            List {
                Section {
                    Text("Dodaj, ukryj i ustaw kolejność widgetów ekranu głównego. Przeciągnij uchwyt po prawej, żeby zmienić kolejność.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Widgets") {
                    ForEach($appPreferences.homeWidgets) { $preference in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Label(preference.kind.title, systemImage: preference.kind.systemImage)
                                    .font(.body.weight(.semibold))

                                Spacer()

                                Button {
                                    preference.isVisible.toggle()
                                } label: {
                                    Image(systemName: preference.isVisible ? "minus.circle.fill" : "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(preference.isVisible ? .red : .green)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(preference.isVisible ? "Hide widget" : "Show widget")
                            }

                            if preference.kind.supportedSpans.count > 1 {
                                Picker("Size", selection: $preference.span) {
                                    ForEach(preference.kind.supportedSpans) { span in
                                        Text(span.title).tag(span)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove { fromOffsets, toOffset in
                        appPreferences.homeWidgets.move(fromOffsets: fromOffsets, toOffset: toOffset)
                    }
                }
            }
            .modifier(HomeCustomizationEditModeModifier(isActive: keepsEditModeActive))
            .navigationTitle("Customize Home")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct HomeCustomizationEditModeModifier: ViewModifier {
    let isActive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        content.activeEditModeIfSupported(isActive)
    }
}


#endif
