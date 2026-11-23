import SwiftUI

struct IconDetailView: View {
    @EnvironmentObject private var store: IconStore
    let packID: UUID
    let iconID: UUID
    @State private var name = ""
    @State private var kind: LaunchKind = .shortcut
    @State private var value = ""
    @State private var search = ""
    @State private var share: ShareFile?
    @State private var testStatus: String?
    @StateObject private var server = ProfileServer()
    private var icon: IconItem? { store.pack(packID)?.icons.first { $0.id == iconID } }
    private var matched: CatalogApp? { store.catalog.first { $0.shortcutName == value && kind == .shortcut } }
    var body: some View {
        Form {
            if let icon {
                Section {
                    HStack { Spacer(); IconImage(data: icon.image, size: 100); Spacer() }.padding().listRowBackground(Color.clear)
                    TextField("Nazwa pod ikoną", text: $name).onSubmit(save)
                    Button("Zapisz nazwę i przypisanie", action: save).fontWeight(.semibold)
                }
                Section {
                    Picker("Typ", selection: $kind) {
                        Text("Skrót").tag(LaunchKind.shortcut); Text("Adres aplikacji").tag(LaunchKind.url)
                    }.pickerStyle(.segmented)
                    TextField(kind == .shortcut ? "Dokładna nazwa skrótu" : "np. spotify://", text: $value)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().onSubmit(save)
                    Button("Zapisz i przetestuj otwieranie") {
                        do {
                            try persist()
                            let url = try LaunchTarget(kind: kind, value: value).resolvedURL()
                            UIApplication.shared.open(url, options: [:]) { success in
                                testStatus = success ? "iOS przyjął adres. Sprawdź, czy otworzyła się właściwa aplikacja; samo przyjęcie adresu tego nie potwierdza." : "iOS nie otworzył adresu. Sprawdź aplikację lub nazwę skrótu."
                            }
                        } catch { store.problem = error.localizedDescription }
                    }
                    if let testStatus { Text(testStatus).font(.footnote).foregroundStyle(.secondary) }
                } header: { Text("Otwieranie") } footer: {
                    Text(kind == .shortcut ? "Skrót musi być już dodany do aplikacji Skróty. Gotowy wybierz poniżej. Dla dowolnej innej aplikacji utwórz skrót z jedną czynnością „Otwórz aplikację” i wpisz jego nazwę." : "Użyj adresu udokumentowanego przez twórcę aplikacji. Bez adresu wybierz typ Skrót. iOS może wyświetlić potwierdzenie lub otworzyć Safari.")
                }
                if let matched {
                    Section("Gotowy skrót: \(matched.name)") {
                        Button { Task { await downloadLauncher(matched) } } label: { Label("Dodaj skrót przez Safari", systemImage: "arrow.down.circle") }
                        Button {
                            if let url = store.launcherURL(id: matched.id) { share = ShareFile(url: url) }
                            else { store.problem = "Ten build nie zawiera podpisanego skrótu. Pobierz go z wydania GitHub albo utwórz „Otwórz aplikację” ręcznie." }
                        } label: { Label("Udostępnij plik skrótu", systemImage: "square.and.arrow.up") }
                        Text("Dodaj skrót pod nazwą „\(matched.shortcutName)”. Nie zmieniaj jej, jeśli ikony już do niej prowadzą. Katalog nie sprawdza, czy dana aplikacja jest zainstalowana.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if kind == .shortcut {
                    Section("Katalog gotowych skrótów") {
                        TextField("Szukaj aplikacji", text: $search)
                        ForEach(store.catalog.filter { search.isEmpty || $0.name.localizedStandardContains(search) }) { app in
                            Button {
                                kind = .shortcut; value = app.shortcutName; save()
                            } label: {
                                HStack { Label(app.name, systemImage: app.symbol); Spacer(); if value == app.shortcutName { Image(systemName: "checkmark") } }
                            }
                        }
                    }
                }
                Section("Standardowe dodanie ikony") {
                    Button {
                        do { try persist(); share = ShareFile(url: try store.writeTemporary(icon.image, filename: "Ikona.png")) }
                        catch { store.problem = error.localizedDescription }
                    } label: { Label("Zapisz obraz do Plików lub Zdjęć", systemImage: "photo") }
                    Text("Otwórz przypisany skrót → szczegóły → Do ekranu początkowego → dotknij miniatury → Wybierz plik lub zdjęcie → wybierz ten obraz → Dodaj.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Edytuj ikonę").navigationBarTitleDisplayMode(.inline)
        .onAppear { if let icon { name = icon.name; kind = icon.target?.kind ?? .shortcut; value = icon.target?.value ?? "" } }
        .onDisappear { server.stop() }
        .sheet(item: $share) { ShareSheet(items: [$0.url]) }
    }
    private func persist() throws {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 100 else { throw BridgeError.invalid("Nazwa ikony musi mieć od 1 do 100 znaków.") }
        guard var pack = store.pack(packID), let index = pack.icons.firstIndex(where: { $0.id == iconID }) else { return }
        let target = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : LaunchTarget(kind: kind, value: value)
        if let target { _ = try target.resolvedURL() }
        if pack.icons[index].name != clean || pack.icons[index].target != target { pack.icons[index].prepared = false }
        pack.icons[index].name = clean; pack.icons[index].target = target; try store.save(pack)
    }
    private func save() { do { try persist() } catch { store.problem = error.localizedDescription } }
    private func downloadLauncher(_ app: CatalogApp) async {
        do {
            try persist()
            guard let file = store.launcherURL(id: app.id) else { throw BridgeError.invalid("Brakuje podpisanego pliku skrótu w tym buildzie.") }
            // Filename determines the imported shortcut's name; preserve spaces and Polish-safe ASCII catalog names.
            let data = try Data(contentsOf: file)
            let filename = app.shortcutName + ".shortcut"
            let url = try await server.serve(data, filename: filename, mime: "application/octet-stream")
            await UIApplication.shared.open(url)
            testStatus = "Po imporcie ustaw dokładną nazwę: \(app.shortcutName). Gdy pobieranie wygaśnie, wróć tutaj i ponów próbę."
        } catch { store.problem = error.localizedDescription }
    }
}
