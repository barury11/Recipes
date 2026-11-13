# Recipes / Przepisy

Prototyp dla iPhone’a z iOS 26 lub nowszym. Otwórz `Recipes.xcodeproj` w Xcode 26+ i uruchom schemat **Recipes** w symulatorze iPhone’a.

- Ekran przepisu pokazuje przykładowy krem z dyni, kategorię, czas i liczbę porcji.
- **Składniki** otwierają checklistę od razu na pełną wysokość. Zaznaczenia pozostają w pamięci do zamknięcia przepisu.
- **Zacznij gotować** otwiera jeden krok naraz. Strzałki przełączają kroki, a przycisk checklisty otwiera te same Składniki co ekran przepisu.
- Stuknij wyróżniony czas w tekście, by uruchomić minutnik Recipes przez systemowe AlarmKit. Przy pierwszym użyciu iOS może poprosić o zgodę na alarmy. Rozszerzenie Live Activities wyświetla odliczanie na ekranie blokady i w Dynamic Island.
- W **Ustawieniach** można zapisać wybór **Klasyczny** lub **Inteligentny**. Prototyp wyświetla wygląd klasyczny.
- W **Ustawienia → Dostawca → Google Gemini** zapisz klucz API z [Google AI Studio](https://aistudio.google.com/api-keys). Pozostali dostawcy są nieaktywni.
- Otwórz stronę z przepisem w Safari. Użyj **Udostępnij → Przepisy**. Jeśli skrót jest ukryty, przejdź do **Więcej**. Można też wkleić adres w aplikacji przez **+**.
- Kompletne dane Schema.org importujemy lokalnie. Dla stron bez kompletu danych wysyłamy krótki tekst i metadane do Gemini 3.5 Flash-Lite, sprawdzamy odpowiedź i wyliczamy klikalne czasy z instrukcji. Treść przepisu zachowuje język źródła.
- Przepisy zapisują się jako JSON ze zdjęciem do **Pliki → Na moim iPhonie → Przepisy**. Jeśli podpis obsługuje współdzieloną grupę, otwórz aplikację po imporcie z Safari, aby przenieść je ze współdzielonej skrzynki do Plików. Bez grupy rozszerzenie wyświetli przycisk **Zapisz w Plikach**. Zapisz klucz Gemini w rozszerzeniu, jeśli zostaniesz o niego poproszony.

Jeśli podpisujesz projekt w Xcode z App Groups, przypisz tę samą grupę do aplikacji i rozszerzenia Safari oraz dopasuj identyfikator w `RecipeFiles.group` do grupy w plikach uprawnień. Konfiguracja z podpisem bez współdzielonej grupy obsługuje ręczny zapis z Safari.

## GitHub Actions

1. Wgraj zawartość tego katalogu do repozytorium, razem z ukrytym katalogiem `.github`. `Recipes.xcodeproj` i `.github` powinny być bezpośrednio w katalogu głównym repozytorium.
2. Wypchnięcie zmian na `main` uruchamia **Build Recipes IPA**. Można też użyć **Actions → Build Recipes IPA → Run workflow**.
3. Otwórz ukończone uruchomienie i pobierz **Recipes-unsigned-ipa** z sekcji **Artifacts**. W środku jest `Recipes.ipa` z aplikacją oraz rozszerzeniami udostępniania i Live Activities.

Workflow przygotowuje niepodpisane IPA i nie potrzebuje sekretów. Do uruchomienia na fizycznym iPhonie potrzebne jest podpisanie aplikacji i obu rozszerzeń. W Xcode ustaw swój zespół w **Signing & Capabilities** wszystkich targetów. Jeśli identyfikator aplikacji jest zajęty, zmień `com.barury11.recipes` i użyj nowego identyfikatora z sufiksami `.share` i `.timer` dla rozszerzeń.
