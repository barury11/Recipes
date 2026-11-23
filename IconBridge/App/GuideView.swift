import SwiftUI

struct GuideView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "square.stack.3d.up.fill").font(.system(size: 72)).foregroundStyle(.purple.gradient).padding(20)
                Text("Od obrazu do aplikacji").font(.largeTitle.bold()).multilineTextAlignment(.center)
                InfoCard(title: "1. Zbierz swój styl", text: "Utwórz paczkę. Importuj obrazy ze Zdjęć lub Plików. Folder z obrazami możesz wybrać z Plików; import obejmuje jego bezpośrednią zawartość.", symbol: "photo.stack")
                InfoCard(title: "2. Przypisz otwieranie", text: "Wybierz aplikację z katalogu i zaimportuj gotowy skrót. Dla innej aplikacji utwórz „Otwórz aplikację” w Skrótach i podaj jego dokładną nazwę.", symbol: "arrow.up.forward.app")
                InfoCard(title: "3. Dodaj własne ikony", text: "Standardowo: szczegóły skrótu → Do ekranu początkowego → własny obraz. Eksperymentalnie: pobierz profil całej paczki i zatwierdź go w Ustawieniach.", symbol: "iphone.homebutton")
                InfoCard(title: "4. Uporządkuj ekran", text: "Usuń oryginalne ikony wyłącznie z ekranu początkowego i zachowaj aplikacje w Bibliotece. Przeciągnij nowe ikony na wybrane miejsca.", symbol: "hand.draw")
                InfoCard(title: "Co zmienia się w iOS?", text: "To dodatkowe przyciski uruchamiające aplikacje. Pozycje i oryginalne ikony zmieniasz samodzielnie. Liczniki powiadomień i menu długiego naciśnięcia aplikacji nie przechodzą na nowe przyciski.")
            }.padding(20)
        }.navigationTitle("Jak to działa").navigationBarTitleDisplayMode(.inline)
    }
}
struct SettingsView: View {
    @EnvironmentObject private var store: IconStore
    @State private var share: ShareFile?
    @StateObject private var server = ProfileServer()
    @State private var working = false
    var body: some View {
        List {
            Section("Skrót towarzyszący") {
                Label("IconBridge - Importuj", systemImage: "photo.badge.plus").font(.headline)
                Text("Wybierz zdjęcie w skrócie. Skrót skopiuje obraz do schowka i otworzy IconBridge, gdzie wybierzesz paczkę. iOS może poprosić o zgodę na wklejenie.")
                Button("Dodaj skrót przez Safari") {
                    working = true
                    Task { @MainActor in
                        defer { working = false }
                        do {
                            guard let file = store.launcherURL(id: "import") else { throw BridgeError.invalid("Brakuje podpisanego skrótu. Pobierz build z GitHub Actions.") }
                            let url = try await server.serve(Data(contentsOf: file), filename: "IconBridge - Importuj.shortcut", mime: "application/octet-stream")
                            await UIApplication.shared.open(url)
                        } catch { store.problem = error.localizedDescription }
                    }
                }.disabled(working)
                Button("Udostępnij plik skrótu") {
                    if let file = store.launcherURL(id: "import") { share = ShareFile(url: file) }
                    else { store.problem = "Brakuje podpisanego skrótu w tym buildzie." }
                }
            }
            Section("Własne automatyzacje") {
                Text("W aplikacji Skróty znajdziesz czynności IconBridge: „Dodaj ikonę do paczki” i „Eksportuj profil paczki”. Pozwalają przekazać obraz lub pobrać profil bez ręcznego wybierania pliku.")
            }
            Section("Prywatność") {
                Text("Paczki i obrazy są zapisane na urządzeniu. Aplikacja nie wysyła Twoich ikon na serwer. Tymczasowy adres 127.0.0.1 służy wyłącznie do pobrania pliku na tym samym urządzeniu i wygasa po 2 minutach lub wcześniej, gdy iOS wstrzyma aplikację.")
                Text("Pliki .iconpack zawierają obrazy i adresy przypisanych skrótów. Udostępniaj je świadomie. Import paczki dodaje nową kopię i nie uruchamia jej adresów.")
            }
            Section("Wersja 0.1.0") {
                Text("Wymaga iOS 17 lub nowszego. IPA jest niepodpisane; instalator musi je podpisać. Same pliki .shortcut są podpisywane oddzielnie narzędziem Apple na GitHub Actions.")
                Link("Kod, instrukcje i wydania", destination: URL(string: "https://github.com/barury11/Recipes/tree/iconbridge/IconBridge")!)
            }
        }.navigationTitle("Skróty i informacje")
        .sheet(item: $share) { ShareSheet(items: [$0.url]) }
        .onDisappear { server.stop() }
    }
}
