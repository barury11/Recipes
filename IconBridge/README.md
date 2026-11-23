# IconBridge

Osobna aplikacja iOS 17+ do importowania własnych ikon, organizowania ich w paczki i przypisywania do aplikacji przez Skróty. Projekt jest w gałęzi `iconbridge` repozytorium Recipes, ponieważ dostępna integracja nie oferuje tworzenia repozytoriów. Projekt i identyfikator aplikacji są niezależne od Recipes.

## Pobieranie

Otwórz **Actions → Build IconBridge unsigned IPA**, a po ukończeniu buildu pobierz artefakt **IconBridge-unsigned-IPA-and-Shortcuts**. Workflow tworzy także prerelease `iconbridge-0.1.0-N` z niepodpisanym IPA, podpisanym skrótem importu i archiwum wszystkich skrótów. IPA wymaga własnego podpisania; skróty podpisuje osobno oficjalne narzędzie Apple `shortcuts sign --mode anyone`. Nie potrzebujesz sekretów w repozytorium.

## Użycie

1. Zainstaluj podpisane przez siebie IPA. Otwórz IconBridge, utwórz paczkę i dodaj obrazy ze Zdjęć albo Plików. Można wybrać wiele plików lub folder z obrazami; podfoldery są pomijane. Obrazy są przycinane centralnie do kwadratu i zapisywane jako PNG 400 × 400.
2. Dotknij ikony. Wybierz aplikację z katalogu i dodaj jej podpisany skrót przyciskiem **Dodaj skrót przez Safari**. Zachowaj nazwę `IconBridge - Safari` itp. Alternatywnie udostępnij plik do Plików, otwórz go i zatwierdź import w Skrótach. Katalog nie wykrywa instalacji aplikacji.
3. Dla aplikacji spoza katalogu utwórz w Skrótach nowy skrót z jedną czynnością **Otwórz aplikację**, wybierz aplikację i wpisz dokładną nazwę skrótu w IconBridge. Nie potrzeba identyfikatora bundle ani URL scheme. Można też podać znany adres aplikacji i przetestować go.
4. Sprawdź otwieranie. Zapisz obraz ikony do Plików lub Zdjęć. W Skrótach otwórz szczegóły przypisanego skrótu → **Do ekranu początkowego** → miniatura → własny plik/zdjęcie → **Dodaj**. To standardowa metoda Apple.
5. Opcjonalnie w paczce wybierz **Przygotuj ekran początkowy → Pobierz profil ikon w Safari**. Wszystkie ikony muszą być przypisane. To eksperymentalna metoda masowa: profil dodaje Web Clips z obrazami, kierujące na `shortcuts://run-shortcut?name=...` albo własne URL. Instalację zatwierdzasz w Ustawieniach. Może pojawić się Safari, Skróty lub dodatkowy komunikat. Jeżeli dany iOS odrzuci URL albo aplikacja się nie otworzy, wróć do kroku 4.
6. Oryginalne aplikacje zachowaj w Bibliotece aplikacji: menu ikony → Usuń aplikację → **Usuń z ekranu początkowego**. Przeciągnij nowe przyciski na ich miejsca. Lista w paczce zapisuje Twoje ręczne oznaczenia; nie odczytuje stanu ekranu.

## Skrót towarzyszący i App Intents

`IconBridge - Importuj.shortcut`: wybór jednego zdjęcia → skopiowanie obrazu do lokalnego schowka → `iconbridge://import-clipboard` → wybór paczki w aplikacji. Pierwsze uruchomienie może wymagać zgody iOS na wklejenie. Skrót nie pobiera niczego z internetu. Własne automatyzacje mogą używać czynności **Dodaj ikonę do paczki** (IntentFile, nazwa ikony, paczka, opcjonalnie nazwa skrótu) i **Eksportuj profil paczki** (zwraca IntentFile `.mobileconfig`, nie instaluje go).

Katalog zawiera 24 launchery, każdy z jedną czynnością „Otwórz aplikację”: Safari, Wiadomości, Telefon, Zdjęcia, Aparat, Apple Music, Ustawienia, Pliki, Notatki, Mail, Kalendarz, Zegar, App Store, Skróty, YouTube, Spotify, Instagram, TikTok, Discord, Roblox, ChatGPT, WhatsApp, Messenger, Snapchat. Działanie konkretnej aplikacji wymaga jej instalacji na urządzeniu. W razie niedopasowania identyfikatora użyj własnego skrótu z natywnym wyborem aplikacji.

## Paczki

`.iconpack` to JSON wersji 1 z nazwą, obrazami PNG w base64 i przypisaniami. Import tworzy nową kopię z nowymi UUID, sprawdza typy URL, limit 200 ikon i 32 MB oraz dekoduje i ponownie skaluje obrazy. Paczki można eksportować, zmieniać ich nazwy, usuwać, porządkować i przenosić między nimi ikony. Nie uruchamiamy adresów przy imporcie. Nazwa pliku obrazu może automatycznie przypisać znaną aplikację z katalogu.

## Ograniczenia i usuwanie

- Brak publicznego API do zamiany cudzych ikon, odczytu lub przestawiania istniejącego układu SpringBoard. Obecny układ jest przenoszony ręcznie.
- Nowe przyciski nie dziedziczą liczników powiadomień ani menu kontekstowego aplikacji. Nie obiecujemy braku animacji, banerów lub dodatkowego przejścia przez Skróty.
- `TargetApplicationBundleIdentifier` profilu jest ignorowany przy ręcznej instalacji od iOS 14.3. Nie używamy go ani nie wprowadzamy MDM.
- Masowa instalacja Web Clips z URL aplikacji jest eksperymentalna. Dokumentacja payloadu nie gwarantuje uruchamiania wszystkich niestandardowych schematów. Standardowe dodawanie ikony ze Skrótów jest ścieżką podstawową.
- Usunięcie profilu usuwa jego przyciski; nie usuwa aplikacji. Ikony dodane przez Skróty usuwa się ręcznie. Oryginały można ponownie przeciągnąć z Biblioteki aplikacji.
- Eksport tej samej paczki zachowuje identyfikatory profilu. iOS może zaproponować aktualizację, lecz zachowanie położenia ikon nie jest gwarantowane.
- Pobranie pliku odbywa się przez losowy adres `127.0.0.1` związany wyłącznie z loopback. Serwer wygasa po maks. 120 sekundach lub wcześniej po zakończeniu czasu w tle. Gdy pobieranie się nie uda, wróć do aplikacji i ponów je albo zapisz plik do Plików.

## Budowanie i testowanie

Otwórz `IconBridge.xcodeproj` w Xcode. Przed budowaniem dystrybucji na Macu uruchom `python3 Tools/sign_shortcuts.py`; spowoduje wysłanie stałych, niespersonalizowanych definicji skrótów do Apple w celu ich podpisania. Lokalne buildy bez tego kroku mają jawny komunikat o brakujących skrótach. Przy buildzie CI niepodpisane skróty są błędem blokującym wydanie.

- `python3 Tools/generate_project.py` odtwarza projekt Xcode i ikonę aplikacji bez zależności.
- `python3 Tools/generate_shortcuts.py` odtwarza deterministyczne źródła `.shortcut`.
- `python3 Tools/validate.py` sprawdza katalog, źródła skrótów, referencje zmiennych i kompletność projektu.
- `swift test` sprawdza kodowanie nazw i URL, eksport profili, walidację paczek i parser HTTP.
- Actions buduje IPA dla arm64, sprawdza ZIP, bundle ID, brak podpisu aplikacji oraz 25 podpisanych skrótów, a także buduje i uruchamia aplikację w symulatorze iPhone'a.

Podpisanie skrótu nie jest testem jego uruchomienia na iOS. Testy rdzenia i uruchomienie w symulatorze nie zastępują testu na fizycznym iPhonie. Lista sprawdzeń: [Docs/DEVICE-TESTS.md](Docs/DEVICE-TESTS.md). Historia prób i odrzuconych metod: [Docs/EXPERIMENTS.md](Docs/EXPERIMENTS.md).
