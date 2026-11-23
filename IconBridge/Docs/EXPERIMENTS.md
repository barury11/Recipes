# Dziennik metod — 2026-11-23

| Metoda | Stan i dowód | Powód / wybrany dalszy krok |
| --- | --- | --- |
| Zmiana ikon innych aplikacji przez `setAlternateIconName` | Odrzucona na podstawie dokumentacji Apple, bez próby na urządzeniu | API dotyczy tylko własnej aplikacji i ikon zadeklarowanych w jej bundle. Używamy dodatkowych przycisków. |
| Nadpisanie układu SpringBoard w zwykłej aplikacji | Brak publicznego API; niewdrożone | Aplikacja nie ma dostępu do układu. Jest ręczna lista podmiany. Nie odczytujemy plików systemowych. |
| Web Clip + `TargetApplicationBundleIdentifier` | Odrzucona na podstawie dokumentacji Apple | Od 14.3 wymaga MDM, a aplikacje Apple nie są wspierane. Nie umieszczamy tego pola w profilu. |
| Tworzenie i import unsigned `.shortcut` bezpośrednio na iOS | Odrzucone jako ścieżka dystrybucji | Brak publicznego API do podpisywania i importowania dowolnych workflow na iOS. Źródła podpisuje oficjalny CLI Apple na macOS Actions. |
| Gotowe podpisane „Otwórz aplikację” z katalogu | Wdrożone; podpisanie i build weryfikuje CI | Stałe pliki nie wymagają zewnętrznego serwera ani konta API. Uruchomienie konkretnych aplikacji wymaga sprawdzenia na iPhonie. |
| Dowolna aplikacja przez własny skrót | Wdrożona ścieżka podstawowa wg dokumentacji Apple | Jeden skrót „Otwórz aplikację” z wyborem przez użytkownika. IconBridge przypisuje jego nazwę, bez zgadywania bundle ID. |
| Własny obraz w „Do ekranu początkowego” | Wdrożona ścieżka podstawowa wg instrukcji Apple | Ręczne dodanie każdej ikony. Plik obrazu jest eksportowany z aplikacji. |
| Cała paczka przez profil usuwalnych Web Clips | Wdrożona jako eksperymentalna, nieweryfikowana na fizycznym iPhonie | Generator tworzy profil z ikonami i adresami skrótów; ręczna instalacja i zgodność niestandardowych URL zależą od iOS. Gdy zawiedzie, ścieżka podstawowa pozostaje dostępna. |
| Dostarczenie profilu / skrótu przez localhost Safari | Wdrożone; parser testowany, przejście w tle wymaga testu urządzenia | Tylko 127.0.0.1, losowy token, maks. 120 s. Alternatywa: plik przez arkusz udostępniania. |
| Nowe repozytorium przez integrację GitHub | Niedostępne w udostępnionych narzędziach; formularz WWW wymaga zalogowania | Osobna gałąź `iconbridge` i katalog `IconBridge` w dostępnym repozytorium. Brak zmian w targetach Recipes. |

Nie opisujemy analizy dokumentacji jako wykonanej próby na telefonie. Kolejne rzeczywiste błędy buildu i poprawki będą dopisywane poniżej.

## Źródła Apple

- [Zmiana własnej ikony](https://developer.apple.com/documentation/uikit/uiapplication/setalternateiconname(_:completionhandler:))
- [WebClip: payload i ograniczenia](https://developer.apple.com/documentation/devicemanagement/webclip)
- [iOS 14.3: ograniczenie TargetApplicationBundleIdentifier i zalecenie Open App](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-14_3-release-notes)
- [Własna ikona skrótu na ekranie](https://support.apple.com/guide/shortcuts/apd735880972/ios)
- [Uruchamianie skrótu przez URL](https://support.apple.com/guide/shortcuts/apd624386f42/ios)
- [Podpisywanie skrótów oficjalnym CLI](https://support.apple.com/guide/shortcuts-mac/apd455c82f02/mac)

## Rzeczywiste próby CI

- Pierwszy run `45218280111`: GitHub utrzymywał job `macos-26` w kolejce, bez runnera i bez wykonania kroków. Nie jest to błąd kompilacji. Drugie podejście używa `macos-15`, zgodnego z projektem iOS 17+. Poprzedni run zostaje anulowany przez grupę concurrency po wypchnięciu poprawki.

- Run `45219117021`: runner macOS 15 wystartował. Generator zakończył się `FileNotFoundError`, ponieważ Git nie zapisuje pustego katalogu `Shortcuts`, a `mkdir` nie tworzył rodziców. Poprawka: `parents=True` dla katalogów źródeł i podpisanych plików. Dodany test generatora w zupełnie pustym drzewie z samym katalogiem aplikacji. Dalsze kroki nie uruchomiły się w tej próbie.

- Adnotacje GitHuba potwierdziły ograniczoną pojemność runnerów macOS arm64. `macos-15` również oznacza arm64. Kolejny wariant to oficjalny standardowy runner `macos-15-intel`; nie wymaga Apple Silicon do kompilacji iPhone arm64 ani do podpisania skrótów. Źródło etykiety: https://docs.github.com/en/actions/reference/runners/github-hosted-runners.

- Run `45220463094`: 5 testów Pythona i wszystkie 8 testów Swift zakończone sukcesem. Lokalny CLI Apple odmówił podpisania: `In order to do this, you must be signed into iCloud.` Runner nie ma konta iCloud, więc ta metoda nie jest samowystarczalna w Actions.
- Druga metoda podpisywania: udokumentowane publiczne API Shortcuty V1, bez klucza API. Rzeczywista próba launchera Safari zwróciła HTTP 200, plik AEA1, profil 0 i zgodne sumy SHA-256 wejścia i wyjścia. Wdrożono tę ścieżkę zapasową tylko dla stałych publicznych szablonów. CI dodatkowo weryfikuje podpis AEA i porównuje rozpakowane pola oraz czynności ze źródłem. Nie wysyłamy ikon użytkownika ani danych osobistych. Weryfikacja zaufania/importu iOS pozostaje w testach urządzenia.
