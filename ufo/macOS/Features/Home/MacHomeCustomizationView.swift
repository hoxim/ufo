#if os(macOS)

import SwiftUI
import Charts


struct MacHomeCustomizationView: View {
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
                    Text("home.customization.description")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("home.customization.section.widgets") {
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
                                .accessibilityLabel(preference.isVisible ? "home.customization.action.hideWidget" : "home.customization.action.showWidget")
                            }

                            if preference.kind.supportedSpans.count > 1 {
                                Picker("home.customization.field.size", selection: $preference.span) {
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
            .navigationTitle("home.customization.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("home.customization.action.done") {
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
