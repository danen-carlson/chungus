import Foundation

/// Handles communication with the Chungus fitness API server.
/// The server holds the Venice AI key and RAG knowledge server-side,
/// so the app just sends a prompt and gets back structured JSON.
final class GatewayWorkoutService: Sendable {

    static let shared = GatewayWorkoutService()

    private let baseURL = "https://fitness.hankbot.online"

    private init() {}

    enum GatewayError: LocalizedError {
        case connectionFailed(String)
        case timeout
        case invalidResponse
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .connectionFailed(let msg):
                return "Failed to connect to the fitness server: \(msg). Check your internet connection."
            case .timeout:
                return "The server took too long to respond. Please try again."
            case .invalidResponse:
                return "Received an invalid response from the server."
            case .serverError(let msg):
                return "Server error: \(msg)"
            }
        }
    }

    /// Sends a prompt to the fitness API and returns the raw text response
    func generateWorkoutJSON(prompt: String, timeout: TimeInterval = 60.0) async throws -> String {
        let url = URL(string: "\(baseURL)/generate")!

        let body: [String: Any] = ["prompt": prompt]
        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = timeout

        let (data, response): (Data, URLResponse)
        do {
            let session = URLSession(configuration: .default)
            (data, response) = try await session.data(for: request)
        } catch {
            if (error as NSError).code == NSURLErrorTimedOut {
                throw GatewayError.timeout
            }
            throw GatewayError.connectionFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GatewayError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GatewayError.serverError("HTTP \(httpResponse.statusCode): \(errorBody.prefix(200))")
        }

        // Parse the wrapper response: {"result": "..."}
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? String else {
            throw GatewayError.invalidResponse
        }

        return result
    }

    /// Quick health check — returns true if the server is reachable
    func healthCheck() async throws -> Bool {
        let url = URL(string: "\(baseURL)/health")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GatewayError.connectionFailed("Server returned non-200 status")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["status"] as? String == "ok" else {
            throw GatewayError.invalidResponse
        }

        return true
    }
}
