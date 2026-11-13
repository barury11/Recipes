# Recipes / Przepisy

Prototyp dla iPhone’a z iOS 26 lub nowszym. Otwórz `Recipes.xcodeproj` w Xcode 26+ i uruchom schemat **Recipes** w symulatorze iPhone’a.

- Ekran przepisu pokazuje przykładowy krem z dyni, kategorię, czas i liczbę porcji.
- **Składniki** otwierają checklistę. Zaznaczenia pozostają w pamięci do zamknięcia przepisu.
- **Zacznij gotować** otwiera jeden krok naraz. Strzałki przełączają kroki, a przycisk checklisty otwiera te same Składniki co ekran przepisu.
- Stuknij wyróżniony czas w tekście, by uruchomić minutnik Recipes przez systemowe AlarmKit. Przy pierwszym użyciu iOS może poprosić o zgodę na alarmy. Rozszerzenie Live Activities wyświetla odliczanie na ekranie blokady i w Dynamic Island.
- W **Ustawieniach** można wybrać dostawcę AI i wpisać klucz w pole maskowane. Po zamknięciu arkusza klucz i ewentualny adres własnego API są usuwane.
- Rozszerzenie pokazuje ten sam przykładowy przepis po wybraniu **Safari → Udostępnij → Przepisy / Recipes**. Jeśli skrót jest ukryty, przejdź do **Więcej** na liście aplikacji. **X** w rozszerzeniu wraca do Safari, a w aplikacji zamyka widok przepisu.
- Prototyp korzysta z przykładowego przepisu. [Prompt do ekstrakcji](Docs/recipe-extraction-prompt.md) definiuje dzielenie instrukcji na kroki i oznaczanie czasów na potrzeby przyszłego importu z AI.

## GitHub Actions

1. Wgraj zawartość tego katalogu do repozytorium, razem z ukrytym katalogiem `.github`. `Recipes.xcodeproj` i `.github` powinny być bezpośrednio w katalogu głównym repozytorium.
2. Wypchnięcie zmian na `main` uruchamia **Build Recipes IPA**. Można też użyć **Actions → Build Recipes IPA → Run workflow**.
3. Otwórz ukończone uruchomienie i pobierz **Recipes-unsigned-ipa** z sekcji **Artifacts**. W środku jest `Recipes.ipa` z aplikacją oraz rozszerzeniami udostępniania i Live Activities.

Workflow przygotowuje niepodpisane IPA i nie potrzebuje sekretów. Do uruchomienia na fizycznym iPhonie potrzebne jest podpisanie aplikacji i obu rozszerzeń. W Xcode ustaw swój zespół w **Signing & Capabilities** wszystkich targetów. Jeśli identyfikator aplikacji jest zajęty, zmień `com.barury11.recipes` i użyj nowego identyfikatora z sufiksami `.share` i `.timer` dla rozszerzeń.
