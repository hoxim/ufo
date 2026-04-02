import SwiftUI

/// Extends View to provide an adaptive way of presenting forms:
/// - iOS: Uses `.sheet` (or `.fullScreenCover` implicitly based on environment, but `.sheet` by default).
/// - macOS: Uses `.navigationDestination` to push the form natively replacing the detail pane.
public extension View {
    @ViewBuilder
    func adaptiveFormPresentation<V: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder destination: @escaping () -> V
    ) -> some View {
        #if os(macOS)
        self.navigationDestination(isPresented: isPresented, destination: destination)
        #else
        self.sheet(isPresented: isPresented, content: destination)
        #endif
    }
    
    @ViewBuilder
    func adaptiveFormPresentation<Item: Identifiable & Hashable, V: View>(
        item: Binding<Item?>,
        @ViewBuilder destination: @escaping (Item) -> V
    ) -> some View {
        #if os(macOS)
        self.navigationDestination(item: item, destination: destination)
        #else
        self.sheet(item: item, content: destination)
        #endif
    }
}

/// Wraps form content to ensure it looks native and properly proportioned on both platforms.
/// - iOS: Injects a `NavigationStack` which is required for `.sheet` presentations to have a title and toolbar.
/// - macOS: Assumes it inherits the parent's `NavigationStack` (due to being pushed) and applies a maximum width
///   with centered alignment so the form doesn't awkwardly stretch across massive displays.
public struct AdaptiveFormContent<Content: View>: View {
    @ViewBuilder let content: () -> Content
    
    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    public var body: some View {
        #if os(macOS)
        content()
            .formStyle(.grouped)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(Color.clear)
        #else
        NavigationStack {
            content()
        }
        #endif
    }
}
