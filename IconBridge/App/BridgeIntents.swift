import AppIntents
import UniformTypeIdentifiers

struct AddIconIntent: AppIntent {
    static var title: LocalizedStringResource = "Dodaj ikonę do paczki"
    static var description = IntentDescription("Importuje obraz do paczki IconBridge. Paczka zostanie utworzona, jeśli nie istnieje.")
    static var openAppWhenRun: Bool = true
    @Parameter(title: "Obraz") var image: IntentFile
    @Parameter(title: "Nazwa ikony") var iconName: String
    @Parameter(title: "Nazwa paczki", default: "Moja paczka") var packName: String
    @Parameter(title: "Nazwa skrótu otwierającego aplikację", default: "") var shortcutName: String
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = IconStore.shared
        let id: UUID
        if let existing = store.packs.first(where: { $0.name == packName }) { id = existing.id }
        else { id = try store.addPack(name: packName) }
        try store.addImage(image.data, name: iconName, to: id)
        if !shortcutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, var pack = store.pack(id), !pack.icons.isEmpty {
            let target = LaunchTarget(kind: .shortcut, value: shortcutName); _ = try target.resolvedURL()
            pack.icons[pack.icons.count - 1].target = target; try store.save(pack)
        }
        store.requestedPack = id
        return .result(dialog: "Dodano ikonę do paczki.")
    }
}
struct ExportPackProfileIntent: AppIntent {
    static var title: LocalizedStringResource = "Eksportuj profil paczki"
    static var description = IntentDescription("Zwraca eksperymentalny profil Web Clip. Nie instaluje go automatycznie.")
    static var openAppWhenRun: Bool = true
    @Parameter(title: "Nazwa paczki") var packName: String
    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        guard let pack = IconStore.shared.packs.first(where: { $0.name == packName }) else {
            throw BridgeError.invalid("Nie znaleziono paczki o tej nazwie.")
        }
        let file = IntentFile(data: try ProfileBuilder.build(pack: pack), filename: "IconBridge.mobileconfig", type: .data)
        return .result(value: file)
    }
}
