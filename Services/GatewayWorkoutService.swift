import Foundation
import Starscream

/// Handles communication with the OpenClaw Gateway for workout generation.
/// Replaces direct Gemini API calls with server-side RAG + Venice AI.
final class GatewayWorkoutService: @unchecked Sendable {

    static let shared = GatewayWorkoutService()

    private let gatewayURL = "wss://gateway.hankbot.online"
    private let sessionKey = "chungus:workout"

    // Lock-protected mutable state for Swift 6 strict concurrency
    private let lock = NSLock()
    private var socket: WebSocket?
    private var continuation: CheckedContinuation<String, Error>?
    private var accumulatedText = ""
    private var pendingPrompt = ""

    private init() {}

    enum GatewayError: LocalizedError {
        case connectionFailed(String)
        case timeout
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .connectionFailed(let msg):
                return "Failed to connect to the fitness server: \(msg). Check your internet connection."
            case .timeout:
                return "The server took too long to respond. Please try again."
            case .invalidResponse:
                return "Received an invalid response from the server."
            }
        }
    }

    /// Sends a prompt to the Gateway and returns the raw text response
    func generateWorkoutJSON(prompt: String, timeout: TimeInterval = 45.0) async throws -> String {
        let systemPrompt = "You are an expert fitness coach. Return ONLY valid JSON, no markdown, no explanations outside the JSON. " + prompt

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            self.lock.lock()
            self.accumulatedText = ""
            self.pendingPrompt = systemPrompt
            self.continuation = cont
            self.lock.unlock()

            var request = URLRequest(url: URL(string: self.gatewayURL)!)
            request.timeoutInterval = 10

            let ws = WebSocket(request: request)
            ws.delegate = self

            self.lock.lock()
            self.socket = ws
            self.lock.unlock()

            ws.connect()

            // Timeout handler
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                self?.handleTimeout()
            }
        }
    }

    // MARK: - Internal State Management (lock-protected)

    private func handleTimeout() {
        lock.lock()
        let cont = continuation
        continuation = nil
        let ws = socket
        socket = nil
        lock.unlock()

        cont?.resume(throwing: GatewayError.timeout)
        ws?.disconnect()
    }

    private func handleResponse() {
        lock.lock()
        let cont = continuation
        continuation = nil
        var cleaned = accumulatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let ws = socket
        socket = nil
        lock.unlock()

        // Strip markdown code fences
        if cleaned.hasPrefix("```") {
            if let firstNewline = cleaned.firstIndex(of: "\n") {
                cleaned = String(cleaned[cleaned.index(after: firstNewline)...])
            }
            if cleaned.hasSuffix("```") {
                cleaned = String(cleaned.dropLast(3))
            }
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        cont?.resume(returning: cleaned)
        ws?.disconnect()
    }

    private func handleError(_ error: Error) {
        lock.lock()
        let cont = continuation
        continuation = nil
        let ws = socket
        socket = nil
        lock.unlock()

        cont?.resume(throwing: GatewayError.connectionFailed(error.localizedDescription))
        ws?.disconnect()
    }
}

// MARK: - WebSocketDelegate

extension GatewayWorkoutService: WebSocketDelegate {
    nonisolated func didConnect(socket: WebSocketClient) {
        lock.lock()
        let prompt = pendingPrompt
        let key = sessionKey
        lock.unlock()

        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "chat.send",
            "params": [
                "sessionKey": key,
                "message": prompt,
                "idempotencyKey": UUID().uuidString
            ] as [String: Any],
            "id": 1
        ]

        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            socket.write(data: data)
        }
    }

    nonisolated func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected:
            break // Handled in didConnect
        case .text(let text):
            lock.lock()
            accumulatedText += text
            let current = accumulatedText
            lock.unlock()

            // Heuristic: valid JSON ending
            if current.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("}") {
                handleResponse()
            }
        case .binary:
            break
        case .disconnected(let reason, let code):
            print("[GatewayWorkout] Disconnected: \(reason), code: \(code)")
            lock.lock()
            let hasCont = continuation != nil
            let finalText = accumulatedText
            lock.unlock()

            if hasCont && !finalText.isEmpty {
                handleResponse()
            } else if hasCont {
                handleError(GatewayError.connectionFailed("Disconnected: \(reason)"))
            }
        case .error(let error):
            print("[GatewayWorkout] Error: \(error?.localizedDescription ?? "Unknown")")
            handleError(error ?? GatewayError.connectionFailed("Unknown WebSocket error"))
        case .ping, .pong, .viabilityChanged, .reconnectSuggested, .cancelled, .peerClosed:
            break
        @unknown default:
            break
        }
    }
}
