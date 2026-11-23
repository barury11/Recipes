import SwiftUI

@main struct IconBridgeApp: App {
    @StateObject private var store = IconStore.shared
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).tint(.purple)
                .onOpenURL { store.handle($0) }
                .alert("IconBridge", isPresented: Binding(get: { store.problem != nil }, set: { if !$0 { store.problem = nil } })) {
                    Button("OK") { store.problem = nil }
                } message: { Text(store.problem ?? "") }
        }
    }
}
struct RootView: View {
    @EnvironmentObject private var store: IconStore
    @State private var selection = 0
    var body: some View {
        TabView(selection: $selection) {
            PacksView().tabItem { Label("Paczki", systemImage: "square.grid.2x2") }.tag(0)
            NavigationStack { GuideView() }.tabItem { Label("Jak to działa", systemImage: "wand.and.stars") }.tag(1)
            NavigationStack { SettingsView() }.tabItem { Label("Skróty", systemImage: "square.stack.3d.up") }.tag(2)
        }
        .sheet(isPresented: Binding(get: { store.clipboardImport != nil }, set: { if !$0 { store.clipboardImport = nil } })) {
            if let data = store.clipboardImport { ClipboardImportView(data: data) }
        }
        .onChange(of: store.requestedPack) { _, value in if value != nil { selection = 0 } }
    }
}
