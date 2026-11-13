# Recipes / Przepisy

Prototyp dla iPhone’a z iOS 26 lub nowszym. Otwórz `Recipes.xcodeproj` w Xcode 26+ i uruchom schemat **Recipes** w symulatorze iPhone’a.

- Ekran przepisu pokazuje przykładowy krem z dyni, kategorię, czas i liczbę porcji.
- **Składniki** otwierają checklistę. Zaznaczenia pozostają w pamięci do zamknięcia przepisu.
- **Zacznij gotować** reaguje wizualnie na dotyk.
- W **Ustawieniach** można wybrać dostawcę AI i wpisać klucz w pole maskowane. Po zamknięciu arkusza klucz i ewentualny adres własnego API są usuwane.
- Rozszerzenie pokazuje ten sam przykładowy przepis po wybraniu **Safari → Udostępnij → Przepisy / Recipes**. Jeśli skrót jest ukryty, przejdź do **Więcej** na liście aplikacji. **X** w rozszerzeniu wraca do Safari, a w aplikacji zamyka widok przepisu.
- Import treści, połączenia z AI i gotowanie są poza zakresem prototypu. [Prompt do ekstrakcji](Docs/recipe-extraction-prompt.md) jest gotowy do podłączenia w kolejnej wersji.

## GitHub Actions

1. Wgraj zawartość tego katalogu do repozytorium, razem z ukrytym katalogiem `.github`. `Recipes.xcodeproj` i `.github` powinny być bezpośrednio w katalogu głównym repozytorium.
2. Wypchnięcie zmian na `main` uruchamia **Build Recipes IPA**. Można też użyć **Actions → Build Recipes IPA → Run workflow**.
3. Otwórz ukończone uruchomienie i pobierz **Recipes-unsigned-ipa** z sekcji **Artifacts**. W środku jest `Recipes.ipa` z aplikacją i rozszerzeniem udostępniania.

Workflow przygotowuje niepodpisane IPA i nie potrzebuje sekretów. Do uruchomienia na fizycznym iPhonie potrzebne jest podpisanie aplikacji **i jej rozszerzenia**. W Xcode ustaw swój zespół w **Signing & Capabilities** obu targetów. Jeśli identyfikator aplikacji jest zajęty, zmień `com.barury11.recipes` i użyj nowego identyfikatora z sufiksem `.share` dla rozszerzenia.
