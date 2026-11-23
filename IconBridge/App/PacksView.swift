import SwiftUI
import UniformTypeIdentifiers

struct PacksView: View {
    @EnvironmentObject private var store: IconStore
    @State private var adding = false
    @State private var newName = ""
    @State private var importing = false
    @State private var path: [UUID] = []
    @State private var deleting: IconPack?
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Twój ekran.\nTwoje ikony.").font(.system(size: 38, weight: .bold, design: .rounded))
                        Text("Zbierz obrazy w paczkę, przypisz aplikacje i przygotuj nowy ekran początkowy.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.top, 12)
                    HStack(spacing: 12) {
                        Button { adding = true } label: { Label("Nowa paczka", systemImage: "plus").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                        Button { importing = true } label: { Image(systemName: "square.and.arrow.down").padding(5) }
                            .buttonStyle(.bordered).controlSize(.large).accessibilityLabel("Importuj paczkę")
                    }
                    if store.packs.isEmpty {
                        InfoCard(title: "Zacznij od paczki", text: "Dodaj ikony ze Zdjęć lub Plików. Możesz mieć osobne paczki dla różnych stylów.", symbol: "square.grid.2x2.fill")
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 16)], spacing: 16) {
                        ForEach(store.packs) { pack in
                            NavigationLink(value: pack.id) { PackCard(pack: pack) }.buttonStyle(.plain)
                                .contextMenu { Button("Usuń paczkę", role: .destructive) { deleting = pack } }
                        }
                    }
                }.padding(20)
            }
            .background(LinearGradient(colors: [.purple.opacity(0.12), Color(uiColor: .systemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .navigationTitle("IconBridge").navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { id in PackDetailView(packID: id) }
            .alert("Nowa paczka", isPresented: $adding) {
                TextField("Nazwa paczki", text: $newName)
                Button("Utwórz") { do { path.append(try store.addPack(name: newName)); newName = "" } catch { store.problem = error.localizedDescription } }
                Button("Anuluj", role: .cancel) {}
            }
            .confirmationDialog("Usunąć paczkę „\(deleting?.name ?? "")” i zapisane w niej obrazy?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Usuń paczkę", role: .destructive) {
                    do { if let id = deleting?.id { try store.removePack(id) } } catch { store.problem = error.localizedDescription }; deleting = nil
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .data], allowsMultipleSelection: false) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let scope = url.startAccessingSecurityScopedResource(); defer { if scope { url.stopAccessingSecurityScopedResource() } }
                    guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= PackArchive.maximumBytes else { throw BridgeError.invalid("Plik przekracza 32 MB.") }
                    path.append(try store.importArchive(Data(contentsOf: url)))
                } catch { store.problem = error.localizedDescription }
            }
            .onChange(of: store.requestedPack) { _, id in
                if let id { path = [id]; store.requestedPack = nil }
            }
        }
    }
}
struct PackCard: View {
    let pack: IconPack
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(0..<4, id: \.self) { index in
                    if index < pack.icons.count { IconImage(data: pack.icons[index].image, size: 48) }
                    else { RoundedRectangle(cornerRadius: 12).fill(.purple.opacity(0.09)).frame(width: 48, height: 48).overlay { Image(systemName: "sparkle").foregroundStyle(.purple.opacity(0.4)) } }
                }
            }.padding(14).frame(maxWidth: .infinity).background(.purple.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
            VStack(alignment: .leading, spacing: 4) {
                Text(pack.name).font(.headline).lineLimit(2)
                Text("\(pack.icons.count) ikon · \(pack.readyCount) przypisanych").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(14).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
}

struct ClipboardImportView: View {
    @EnvironmentObject private var store: IconStore
    @Environment(\.dismiss) private var dismiss
    let data: Data
    @State private var name = "Nowa ikona"
    @State private var packID: UUID?
    @State private var packName = "Moja paczka"
    var body: some View {
        NavigationStack {
            Form {
                Section { HStack { Spacer(); IconImage(data: data, size: 100); Spacer() }.listRowBackground(Color.clear) }
                Section("Ikona ze skrótu") { TextField("Nazwa ikony", text: $name) }
                if store.packs.isEmpty { Section("Nowa paczka") { TextField("Nazwa paczki", text: $packName) } }
                else {
                    Picker("Paczka", selection: $packID) { ForEach(store.packs) { Text($0.name).tag(Optional($0.id)) } }
                }
            }
            .navigationTitle("Dodaj ikonę")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Dodaj") {
                        do {
                            let id: UUID
                            if let packID { id = packID } else { id = try store.addPack(name: packName) }
                            try store.addImage(data, name: name, to: id); store.requestedPack = id; dismiss()
                        } catch { store.problem = error.localizedDescription }
                    }
                }
            }.onAppear { packID = store.packs.first?.id }
        }
    }
}
