import Foundation

/// Handles all communication with the Google Gemini API
actor GeminiService {

    static let shared = GeminiService()

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    private let model = "gemini-2.5-flash"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Errors

    enum GeminiError: LocalizedError {
        case noAPIKey
        case invalidResponse
        case httpError(Int, String)
        case decodingError(String)
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "No Gemini API key configured. Add one in Settings."
            case .invalidResponse:
                return "Invalid response from Gemini API."
            case .httpError(let code, let message):
                return "API error (\(code)): \(message)"
            case .decodingError(let detail):
                return "Failed to parse AI response: \(detail)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Generic JSON Generation

    /// Send a prompt and get structured JSON back
    func generateJSON<T: Decodable>(
        prompt: String,
        responseType: T.Type,
        schema: [String: Any]? = nil
    ) async throws -> T {
        guard let apiKey = KeychainService.geminiAPIKey else {
            throw GeminiError.noAPIKey
        }

        let url = URL(string: "\(baseURL)/\(model):generateContent?key=\(apiKey)")!

        var requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.7
            ]
        ]

        // Add JSON schema if provided
        if let schema = schema {
            requestBody["generationConfig"] = [
                "responseMimeType": "application/json",
                "responseSchema": schema,
                "temperature": 0.7
            ] as [String: Any]
        }

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw GeminiError.httpError(httpResponse.statusCode, errorBody)
            }

            // Parse Gemini response structure
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let first = candidates.first,
                  let content = first["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let textPart = parts.first?["text"] as? String else {
                throw GeminiError.invalidResponse
            }

            // Parse the JSON text from Gemini into our model
            guard let textData = textPart.data(using: .utf8) else {
                throw GeminiError.decodingError("Could not encode response text")
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            do {
                return try decoder.decode(T.self, from: textData)
            } catch {
                throw GeminiError.decodingError("\(error.localizedDescription)\nRaw: \(textPart.prefix(500))")
            }

        } catch let error as GeminiError {
            throw error
        } catch {
            throw GeminiError.networkError(error)
        }
    }

    // MARK: - Simple Text Generation

    func generateText(prompt: String) async throws -> String {
        guard let apiKey = KeychainService.geminiAPIKey else {
            throw GeminiError.noAPIKey
        }

        let url = URL(string: "\(baseURL)/\(model):generateContent?key=\(apiKey)")!

        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "temperature": 0.7
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GeminiError.httpError(
                (response as? HTTPURLResponse)?.statusCode ?? -1,
                errorBody
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let textPart = parts.first?["text"] as? String else {
            throw GeminiError.invalidResponse
        }

        return textPart
    }

    // MARK: - Connection Test

    /// Test an API key with a minimal prompt. Returns true on success, throws on failure.
    func testConnection(apiKey: String) async throws -> Bool {
        let url = URL(string: "\(baseURL)/\(model):generateContent?key=\(apiKey)")!

        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": "Reply with just the word OK"]]]
            ],
            "generationConfig": [
                "maxOutputTokens": 10,
                "temperature": 0
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GeminiError.httpError(httpResponse.statusCode, errorBody)
        }

        return true
    }
}
