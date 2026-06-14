import Foundation
import Starscream

/// Handles communication with the OpenClaw Gateway for workout generation.
/// Replaces direct Gemini API calls with server-side RAG + Venice AI.
actor GatewayWorkoutService {

    static let shared = GatewayWorkoutService()

    // Default to your production Gateway. Can be overridden for local testing.
    private let gatewayURL = "wss://gateway.hankbot.online"
    private let sessionKey = "chungus:workout" // Dedicated session for workout generation
    
    private var socket: WebSocket?
    private var continuation: CheckedContinuation<String, Error>?
    private var accumulatedText = ""
    private var currentPrompt = ""

    private init() {}

    enum GatewayError: LocalizedError {
        case connectionFailed
        case timeout
        case invalidResponse
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .connectionFailed:
                return "Failed to connect to the fitness server. Please check your internet connection."
            case .timeout:
                return "The server took too long to respond. Please try again."
            case .invalidResponse:
                return "Received an invalid response from the server."
            case .serverError(let msg):
                return "Server error: \(msg)"
            }
        }
    }

    /// Sends a prompt to the Gateway and returns the raw text response
    func generateWorkoutJSON(prompt: String, timeout: TimeInterval = 45.0) async throws -> String {
        currentPrompt = "You are an expert fitness coach. Return ONLY valid JSON, no markdown, no explanations outside the JSON. " + prompt
        accumulatedText = ""
        
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            var request = URLRequest(url: URL(string: gatewayURL)!)
            request.timeoutInterval = 5
            
            let socket = WebSocket(request: request)
            socket.delegate = self
            self.socket = socket
            
            socket.connect()
            
            // Timeout handler
            Task {
                try? await Task.sleep(for: .seconds(timeout))
                await self.handleTimeout()
            }
        }
    }

    private func handleTimeout() {
        guard let cont = continuation else { return }
        self.continuation = nil
        socket?.disconnect()
        socket = nil
        cont.resume(throwing: GatewayError.timeout)
    }

    private func handleResponse() {
        guard let cont = continuation else { return }
        
        var cleaned = accumulatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            if let firstNewline = cleaned.firstIndex(of: "\n") {
                cleaned = String(cleaned[cleaned.index(after: firstNewline)...])
            }
            if cleaned.hasSuffix("```") {
                cleaned = String(cleaned.dropLast(3))
            }
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        self.continuation = nil
        socket?.disconnect()
        socket = nil
        cont.resume(returning: cleaned)
    }

    private func handleError(_ error: Error) {
        guard let cont = continuation else { return }
        self.continuation = nil
        socket?.disconnect()
        socket = nil
        cont.resume(throwing: error)
    }
}

// MARK: - WebSocketDelegate

extension GatewayWorkoutService: WebSocketDelegate {
    nonisolated func didConnect(socket: WebSocketClient) {
        Task { @MainActor in
            let prompt = await self.currentPrompt
            let rpcPayload: [String: Any] = [
                "jsonrpc": "2.0",
                "method": "chat.send",
                "params": [
                    "sessionKey": await self.sessionKey,
                    "message": prompt,
                    "idempotencyKey": UUID().uuidString
                ],
                "id": 1
            ]
            
            if let data = try? JSONSerialization.data(withJSONObject: rpcPayload) {
                socket.write(data: data)
            }
        }
    }

    nonisolated func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        Task { @MainActor in
            switch event {
            case .connected:
                break // Handled in didConnect
            case .text(let text):
                await self.appendText(text)
                
                // Heuristic: if we have a valid-looking JSON ending, resolve
                let currentText = await self.getAccumulatedText()
                if currentText.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("}") {
                    await self.handleResponse()
                }
            case .disconnected(let reason, let code):
                print("[GatewayWorkout] Disconnected: \(reason), code: \(code)")
                if await self.continuation != nil {
                    let finalText = await self.getAccumulatedText()
                    if !finalText.isEmpty {
                        await self.setAccumulatedText(finalText)
                        await self.handleResponse()
                    } else {
                        await self.handleError(GatewayError.connectionFailed)
                    }
                }
            case .error(let error):
                print("[GatewayWorkout] Error: \(error?.localizedDescription ?? "Unknown")")
                await self.handleError(GatewayError.connectionFailed)
            case .pong, .ping, .viabilityChanged, .reconnectSuggested, .cancelled, .peerClosed:
                break
            @unknown default:
                break
            }
        }
    }
    
    private func appendText(_ text: String) {
        accumulatedText += text
    }
    
    private func getAccumulatedText() -> String {
        return accumulatedText
    }
    
    private func setAccumulatedText(_ text: String) {
        accumulatedText = text
    }
}