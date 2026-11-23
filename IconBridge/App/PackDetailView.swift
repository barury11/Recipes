import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct PackDetailView: View {
    @EnvironmentObject private var store: IconStore
    let packID: UUID
    @State private var photos: [PhotosPickerItem] = []
    @State private var importing = false
    @State private var share: ShareFile?
    @State private var installing = false
    @State private var renaming = false
    @State private var name = ""
    @State private var busy = false
    @State private var importReport: String?
    var body: some View {
        Group {
            if let pack = store.pack(packID) {
                List {
                    Section {
                        HStack(spacing: 14) {
                            Image(systemName: "square.stack.3d.up.fill").font(.largeTitle).foregroundStyle(.purple)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pack.name).font(.title2.bold())
                                Text("\(pack.readyCount) z \(pack.icons.count) ikon przypisanych").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 8)
                        HStack {
                            PhotosPicker(selection: $photos, maxSelectionCount: max(1, 200 - pack.icons.count), matching: .images) { Label("Zdjęcia", systemImage: "photo.on.rectangle") }
                            Spacer()
                            Button { importing = true } label: { Label("Pliki", systemImage: "folder") }
                        }.disabled(busy || pack.icons.count >= 200)
                    } footer: { Text("PNG, JPEG i HEIC. Każdy obraz zostanie przycięty centralnie do kwadratu. Nazwy plików mogą automatycznie dopasować aplikację z katalogu.") }
                    Section {
                        Button { installing = true } label: { Label("Przygotuj ekran początkowy", systemImage: "iphone.homebutton").font(.headline) }
                            .disabled(pack.icons.isEmpty)
                    }
                    Section("Ikony · dotknij, aby przypisać aplikację") {
                        ForEach(pack.icons) { icon in
                            NavigationLink { IconDetailView(packID: packID, iconID: icon.id) } label: {
                                HStack(spacing: 12) {
                                    IconImage(data: icon.image, size: 48)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(icon.name).font(.headline)
                                        Text(icon.target?.value ?? "Wybierz aplikację lub skrót").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer()
                                    if icon.prepared { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).accessibilityLabel("Oznaczona jako dodana") }
                                }
                            }
                            .contextMenu {
                                if store.packs.count > 1 {
                                    Menu("Przenieś do paczki") {
                                        ForEach(store.packs.filter { $0.id != packID }) { destination in
                                            Button(destination.name) { do { try store.move(icon: icon.id, from: packID, to: destination.id) } catch { store.problem = error.localizedDescription } }
                                        }
                                    }
                                }
                            }
                        }
                        .onDelete { offsets in
                            var changed = pack; changed.icons.remove(atOffsets: offsets)
                            do { try store.save(changed) } catch { store.problem = error.localizedDescription }
                        }
                        .onMove { source, destination in
                            var changed = pack; changed.icons.move(fromOffsets: source, toOffset: destination)
                            do { try store.save(changed) } catch { store.problem = error.localizedDescription }
                        }
                        if pack.icons.isEmpty { Text("Dodaj pierwsze obrazy przyciskami powyżej.").foregroundStyle(.secondary) }
                    }
                    Section {
                        Button {
                            do { share = ShareFile(url: try store.writeTemporary(JSONEncoder().encode(PackArchive(pack: pack)), filename: "Paczka.iconpack")) }
                            catch { store.problem = error.localizedDescription }
                        } label: { Label("Eksportuj paczkę z obrazami", systemImage: "square.and.arrow.up") }
                        Button { name = pack.name; renaming = true } label: { Label("Zmień nazwę paczki", systemImage: "pencil") }
                    }
                    if busy { Section { ProgressView("Importowanie obrazów…") } }
                    if let importReport { Section { Text(importReport).font(.footnote).foregroundStyle(.secondary) } }
                }
                .navigationTitle(pack.name).navigationBarTitleDisplayMode(.inline)
                .toolbar { EditButton() }
                .sheet(isPresented: $installing) { NavigationStack { InstallView(packID: packID) } }
                .alert("Nazwa paczki", isPresented: $renaming) {
                    TextField("Nazwa", text: $name)
                    Button("Zapisz") {
                        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !clean.isEmpty, clean.count <= 100 else { store.problem = "Nazwa musi mieć od 1 do 100 znaków."; return }
                        var changed = pack; changed.name = clean
                        do { try store.save(changed) } catch { store.problem = error.localizedDescription }
                    }
                    Button("Anuluj", role: .cancel) {}
                }
            } else { ContentUnavailableView("Paczka została usunięta", systemImage: "square.stack.3d.up") }
        }
        .sheet(item: $share) { ShareSheet(items: [$0.url]) }
        .onChange(of: photos) { _, items in
            guard !items.isEmpty else { return }; busy = true
            Task { @MainActor in
                var imported = 0; var failures: [String] = []
                for (index, item) in items.enumerated() {
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self) else { throw BridgeError.invalid("Nie można pobrać obrazu.") }
                        try store.addImage(data, name: "Ikona \((store.pack(packID)?.icons.count ?? 0) + 1)", to: packID); imported += 1
                    } catch { failures.append("Zdjęcie \(index + 1): \(error.localizedDescription)") }
                }
                importReport = "Dodano \(imported) ikon." + (failures.isEmpty ? "" : "\n" + failures.joined(separator: "\n"))
                photos = []; busy = false
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.image, .folder], allowsMultipleSelection: true) { result in
            do {
                let selected = try result.get(); busy = true
                Task { @MainActor in
                    var imported = 0; var failures: [String] = []
                    for url in selected {
                        let scope = url.startAccessingSecurityScopedResource(); defer { if scope { url.stopAccessingSecurityScopedResource() } }
                        do {
                            let isDirectory = try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
                            let files = isDirectory ? try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentTypeKey], options: [.skipsHiddenFiles]) : [url]
                            for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                                if isDirectory, (try? file.resourceValues(forKeys: [.contentTypeKey]).contentType?.conforms(to: .image)) != true { continue }
                                do {
                                    guard (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 20 * 1024 * 1024 else { throw BridgeError.invalid("Obraz przekracza 20 MB.") }
                                    try store.addImage(Data(contentsOf: file), name: file.deletingPathExtension().lastPathComponent, to: packID); imported += 1
                                } catch { failures.append("\(file.lastPathComponent): \(error.localizedDescription)") }
                                if (store.pack(packID)?.icons.count ?? 0) >= 200 { failures.append("Osiągnięto limit 200 ikon."); break }
                            }
                        } catch { failures.append(error.localizedDescription) }
                    }
                    importReport = "Dodano \(imported) ikon." + (failures.isEmpty ? "" : "\n" + failures.prefix(10).joined(separator: "\n"))
                    busy = false
                }
            } catch { store.problem = error.localizedDescription }
        }
    }
}
