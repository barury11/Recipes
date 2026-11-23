import SwiftUI

struct InstallView: View {
    @EnvironmentObject private var store: IconStore
    @Environment(\.dismiss) private var dismiss
    let packID: UUID
    @StateObject private var server = ProfileServer()
    @State private var share: ShareFile?
    @State private var status: String?
    @State private var busy = false
    @State private var confirmProfile = false
    var body: some View {
        List {
            if let pack = store.pack(packID) {
                Section {
                    InfoCard(title: "Przygotuj \(pack.name)", text: "\(pack.readyCount) z \(pack.icons.count) ikon ma przypisaną aplikację. Najpierw dodaj potrzebne skróty i sprawdź ich działanie.", symbol: "iphone")
                        .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                Section("1. Dodaj skróty i obrazy") {
                    Text("Wróć do ikony w paczce, wybierz aplikację z katalogu i dodaj jej gotowy skrót. Możesz też podać nazwę dowolnego własnego skrótu z czynnością „Otwórz aplikację”.")
                    Text("Sprawdź przyciskiem „Zapisz i przetestuj otwieranie”, czy skrót otwiera właściwą aplikację.")
                }
                Section("2. Standardowa metoda Apple") {
                    Text("W szczegółach ikony zapisz jej obraz. W aplikacji Skróty otwórz przypisany skrót → szczegóły → Do ekranu początkowego. Wybierz własny obraz i nazwę, a następnie Dodaj.")
                    Text("Ta metoda wymaga dodania każdej ikony osobno. Nie potrzebuje profilu konfiguracji.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Opcjonalnie: cała paczka naraz · eksperymentalne") {
                    Text("Profil Web Clip dodaje wiele przycisków z obrazami jednocześnie. Ich adresy uruchamiają przypisane skróty lub adresy aplikacji. W zależności od iOS może pojawić się Safari, Skróty albo pytanie o zgodę. Jeśli aplikacja się nie otwiera, użyj standardowej metody powyżej.")
                        .font(.subheadline)
                    Button { confirmProfile = true } label: { Label("Pobierz profil ikon w Safari", systemImage: "square.and.arrow.down") }
                        .disabled(pack.readyCount != pack.icons.count || pack.icons.isEmpty || busy)
                    Button {
                        do { share = ShareFile(url: try store.writeTemporary(ProfileBuilder.build(pack: pack), filename: "IconBridge.mobileconfig")) }
                        catch { store.problem = error.localizedDescription }
                    } label: { Label("Zapisz kopię profilu do Plików", systemImage: "doc") }
                        .disabled(pack.readyCount != pack.icons.count || pack.icons.isEmpty)
                    Text("Po pobraniu: Ustawienia → Pobrano profil lub Ogólne → VPN i urządzenia zarządzane → IconBridge → Zainstaluj. Profil jest niepodpisany i zawiera wyłącznie usuwalne ikony. Instalację zawsze zatwierdzasz w iOS.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let status { Text(status).font(.footnote).foregroundStyle(.secondary) }
                    if busy { ProgressView() }
                }
                Section("3. Podmień ekran początkowy") {
                    Text("Przytrzymaj oryginalną ikonę → Usuń aplikację → Usuń z ekranu początkowego. Wybierz usunięcie z ekranu, aby zachować aplikację w Bibliotece aplikacji. Przenieś nową ikonę na jej miejsce.")
                    Text("iOS nie udostępnia aplikacjom odczytu ani automatycznej podmiany układu ekranu. Nowe przyciski nie pokazują liczników powiadomień oryginalnych aplikacji.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Twoja lista · oznacz po sprawdzeniu na ekranie") {
                    ForEach(pack.icons) { icon in
                        Toggle(isOn: Binding(get: { store.pack(packID)?.icons.first { $0.id == icon.id }?.prepared ?? false }, set: { ready in
                            guard var changed = store.pack(packID), let index = changed.icons.firstIndex(where: { $0.id == icon.id }) else { return }
                            changed.icons[index].prepared = ready
                            do { try store.save(changed) } catch { store.problem = error.localizedDescription }
                        })) {
                            HStack { IconImage(data: icon.image, size: 38); Text(icon.name) }
                        }
                    }
                }
                Section("Zmiana lub usunięcie stylu") {
                    Text("Zachowaj oryginalne aplikacje w Bibliotece aplikacji. Usunięcie profilu w Ustawieniach usuwa jego przyciski. Skróty dodane standardowo usuń z ekranu ręcznie. Możesz następnie przeciągnąć oryginalne aplikacje z Biblioteki na ekran.")
                    Text("Ponowny eksport tej samej paczki zachowuje identyfikator profilu. iOS może zaproponować aktualizację. W razie duplikatów usuń poprzedni profil przed instalacją nowego. Nie zakładamy, że pozycje ikon zostaną zachowane.").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Dodaj ikony").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Gotowe") { dismiss() } } }
        .sheet(item: $share) { ShareSheet(items: [$0.url]) }
        .confirmationDialog("Pobrać profil zawierający ikony tej paczki?", isPresented: $confirmProfile, titleVisibility: .visible) {
            Button("Pobierz w Safari") { Task { await download() } }
        } message: { Text("To funkcja eksperymentalna. iOS poprosi Cię osobno o zgodę na pobranie i instalację profilu.") }
        .onDisappear { server.stop() }
    }
    private func download() async {
        guard let pack = store.pack(packID) else { return }; busy = true; defer { busy = false }
        do {
            let url = try await server.serve(ProfileBuilder.build(pack: pack))
            let success = await UIApplication.shared.open(url)
            status = success ? "Otwarto adres pobierania. Po zatwierdzeniu w Safari przejdź do Ustawień. Jeśli iOS wstrzyma aplikację przed pobraniem, wróć i spróbuj ponownie." : "Nie udało się otworzyć Safari. Zapisz profil do Plików i otwórz go tam."
        } catch { status = error.localizedDescription }
    }
}
