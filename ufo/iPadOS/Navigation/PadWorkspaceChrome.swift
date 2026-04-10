#if os(iOS)

import SwiftUI

struct PadSidebarWorkspaceScaffold<Sidebar: View, Content: View, Detail: View>: View {
    private let sidebarMinWidth: CGFloat
    private let sidebarIdealWidth: CGFloat
    private let sidebarMaxWidth: CGFloat
    private let contentMinWidth: CGFloat
    private let contentIdealWidth: CGFloat
    private let contentMaxWidth: CGFloat
    private let sidebar: Sidebar
    private let content: Content
    private let detail: Detail

    init(
        sidebarMinWidth: CGFloat = 300,
        sidebarIdealWidth: CGFloat = 340,
        sidebarMaxWidth: CGFloat = 380,
        contentMinWidth: CGFloat = 320,
        contentIdealWidth: CGFloat = 360,
        contentMaxWidth: CGFloat = 520,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder content: () -> Content,
        @ViewBuilder detail: () -> Detail
    ) {
        self.sidebarMinWidth = sidebarMinWidth
        self.sidebarIdealWidth = sidebarIdealWidth
        self.sidebarMaxWidth = sidebarMaxWidth
        self.contentMinWidth = contentMinWidth
        self.contentIdealWidth = contentIdealWidth
        self.contentMaxWidth = contentMaxWidth
        self.sidebar = sidebar()
        self.content = content()
        self.detail = detail()
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(
                    min: sidebarMinWidth,
                    ideal: sidebarIdealWidth,
                    max: sidebarMaxWidth
                )
        } content: {
            content
                .navigationSplitViewColumnWidth(
                    min: contentMinWidth,
                    ideal: contentIdealWidth,
                    max: contentMaxWidth
                )
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .appScreenBackground()
    }
}

struct PadEmbeddedDetailHeader<TitleContent: View, Subtitle: View>: View {
    private let titleContent: TitleContent
    private let subtitleContent: Subtitle

    init(
        @ViewBuilder title: () -> TitleContent,
        @ViewBuilder subtitle: () -> Subtitle
    ) {
        self.titleContent = title()
        self.subtitleContent = subtitle()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            titleContent
            subtitleContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .background(Color.systemBackground)
    }
}

struct PadWorkspaceColumnHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    let selectedSpaceName: String?
    let itemCount: Int?
    private let trailing: Trailing

    init(
        title: LocalizedStringKey,
        selectedSpaceName: String? = nil,
        itemCount: Int? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.selectedSpaceName = selectedSpaceName
        self.itemCount = itemCount
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)

                if selectedSpaceName != nil || itemCount != nil {
                    HStack(spacing: 8) {
                        if let selectedSpaceName, !selectedSpaceName.isEmpty {
                            Text(selectedSpaceName)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if let itemCount {
                            Text(verbatim: "\(itemCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.footnote)
                }
            }

            Spacer(minLength: 12)

            trailing
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .background(Color.systemBackground)
    }
}

struct PadWorkspaceTopBarTitle: View {
    private let title: Text

    init(_ title: LocalizedStringKey) {
        self.title = Text(title)
    }

    init(verbatim title: String) {
        self.title = Text(verbatim: title)
    }

    var body: some View {
        title
            .font(.system(size: 21, weight: .bold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .accessibilityAddTraits(.isHeader)
    }
}

extension PadEmbeddedDetailHeader where Subtitle == EmptyView {
    init(@ViewBuilder title: () -> TitleContent) {
        self.init(title: title) {
            EmptyView()
        }
    }
}

extension PadWorkspaceColumnHeader where Trailing == EmptyView {
    init(
        title: LocalizedStringKey,
        selectedSpaceName: String? = nil,
        itemCount: Int? = nil
    ) {
        self.init(title: title, selectedSpaceName: selectedSpaceName, itemCount: itemCount) {
            EmptyView()
        }
    }
}

private struct PadDetailNavigationChromeModifier: ViewModifier {
    let title: String
    let presentationMode: DetailPresentationMode
    let showsEmbeddedHeader: Bool

    func body(content: Content) -> some View {
        if presentationMode == .modal {
            content
                .navigationTitle(title)
                .inlineNavigationTitle()
        } else {
            content
                .navigationTitle(showsEmbeddedHeader ? "" : title)
                .inlineNavigationTitle()
        }
    }
}

private struct PadWorkspaceTopBarTitleModifier: ViewModifier {
    let title: PadWorkspaceTopBarTitle

    func body(content: Content) -> some View {
        content
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    title
                }
            }
    }
}

extension View {
    func padDetailNavigationChrome(
        title: String,
        presentationMode: DetailPresentationMode,
        showsEmbeddedHeader: Bool = true
    ) -> some View {
        modifier(
            PadDetailNavigationChromeModifier(
                title: title,
                presentationMode: presentationMode,
                showsEmbeddedHeader: showsEmbeddedHeader
            )
        )
    }

    func padWorkspaceTopBarTitle(_ title: LocalizedStringKey) -> some View {
        modifier(PadWorkspaceTopBarTitleModifier(title: PadWorkspaceTopBarTitle(title)))
    }

    func padWorkspaceTopBarTitle(verbatim title: String) -> some View {
        modifier(PadWorkspaceTopBarTitleModifier(title: PadWorkspaceTopBarTitle(verbatim: title)))
    }
}

#endif
