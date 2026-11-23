import Foundation
import Network
import UIKit

/// Temporary HTTP delivery to Safari, bound exclusively to IPv4 loopback.
/// No local network access, no remote service, no permanent background daemon.
@MainActor final class ProfileServer: ObservableObject {
    @Published private(set) var active = false
    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]
    private var background: UIBackgroundTaskIdentifier = .invalid
    private var expiration: Timer?
    private var pending: CheckedContinuation<URL, Error>?
    private var responseData = Data()
    private var mimeType = "application/x-apple-aspen-config"
    private var token = ""
    private var filename = "icons.mobileconfig"

    func serve(_ data: Data, filename: String = "icons.mobileconfig", mime: String = "application/x-apple-aspen-config") async throws -> URL {
        stop()
        guard filename.range(of: "^[A-Za-z0-9 ._-]+$", options: .regularExpression) != nil else {
            throw BridgeError.invalid("Nieprawidłowa nazwa pliku.")
        }
        responseData = data; self.filename = filename; mimeType = mime
        token = UUID().uuidString.lowercased()
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        let listener = try NWListener(using: parameters)
        self.listener = listener
        background = UIApplication.shared.beginBackgroundTask(withName: "IconBridge download") { [weak self] in
            Task { @MainActor in self?.stop() }
        }
        return try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    guard let self, self.listener === listener else { return }
                    switch state {
                    case .ready:
                        guard let port = listener.port,
                              let url = URL(string: "http://127.0.0.1:\(port.rawValue)/\(self.token)/\(self.filename)") else {
                            self.stop(); return
                        }
                        self.active = true
                        self.pending?.resume(returning: url); self.pending = nil
                        self.expiration = Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { [weak self] _ in
                            Task { @MainActor in self?.stop() }
                        }
                    case .failed(let error):
                        self.pending?.resume(throwing: error); self.pending = nil; self.stop()
                    case .cancelled: self.stop()
                    default: break
                    }
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    guard let self, self.active else { connection.cancel(); return }
                    let id = UUID(); self.connections[id] = connection
                    connection.start(queue: .main)
                    self.receive(connection, id: id, accumulated: Data())
                    DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self, weak connection] in
                        connection?.cancel(); self?.connections[id] = nil
                    }
                }
            }
            listener.start(queue: .main)
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
                guard let self, self.listener === listener, self.pending != nil else { return }
                self.stop()
            }
        }
    }
    private func receive(_ connection: NWConnection, id: UUID, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] content, _, complete, error in
            Task { @MainActor in
                guard let self, self.connections[id] != nil else { return }
                var data = accumulated; data.append(content ?? Data())
                guard data.count <= 8192, error == nil else { connection.cancel(); self.connections[id] = nil; return }
                if let header = String(data: data, encoding: .utf8), header.contains("\r\n\r\n") {
                    let ok = LocalRequest.accepts(header, token: self.token, filename: self.filename)
                    let body = ok ? self.responseData : Data("Not found".utf8)
                    let status = ok ? "200 OK" : "404 Not Found"
                    let type = ok ? self.mimeType : "text/plain"
                    let disposition = ok ? "Content-Disposition: attachment; filename=\"\(self.filename)\"\r\n" : ""
                    var response = Data("HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\nCache-Control: no-store\r\n\(disposition)Connection: close\r\n\r\n".utf8)
                    response.append(body)
                    connection.send(content: response, completion: .contentProcessed { [weak self] _ in
                        connection.cancel()
                        Task { @MainActor in self?.connections[id] = nil }
                    })
                } else if complete { connection.cancel(); self.connections[id] = nil }
                else { self.receive(connection, id: id, accumulated: data) }
            }
        }
    }
    func stop() {
        pending?.resume(throwing: BridgeError.invalid("Pobieranie wygasło. Wróć do aplikacji i spróbuj ponownie.")); pending = nil
        let old = listener; listener = nil; old?.cancel()
        for connection in connections.values { connection.cancel() }; connections.removeAll()
        expiration?.invalidate(); expiration = nil; active = false
        if background != .invalid { UIApplication.shared.endBackgroundTask(background); background = .invalid }
    }
}
