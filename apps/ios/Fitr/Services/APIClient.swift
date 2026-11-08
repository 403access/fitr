import Foundation

enum FitrAPIError: LocalizedError {
    case invalidURL
    case transport(String)
    case server(status: Int, message: String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "That server address doesn’t look right."
        case .transport:
            return "Can’t reach your training server."
        case let .server(_, message):
            return message
        case .decoding:
            return "The server sent an unexpected response."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .transport:
            return "Check that the Bun server is running and that the URL is reachable from this device."
        case .server:
            return nil
        case .decoding:
            return "Make sure the app and server are on the same version."
        case .invalidURL:
            return "Use a full URL such as http://localhost:8787."
        }
    }
}

private struct APIErrorEnvelope: Decodable {
    struct Detail: Decodable {
        let code: String
        let message: String
    }
    let error: Detail
}

actor APIClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private(set) var baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 20
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

    func setBaseURL(_ url: URL) {
        baseURL = url
    }

    func bootstrap(date: String?) async throws -> Bootstrap {
        try await request(
            "api/bootstrap",
            query: date.map { [URLQueryItem(name: "date", value: $0)] } ?? []
        )
    }

    func progress(period: TrainingPeriod, anchor: String) async throws -> ProgressSummary {
        try await request(
            "api/progress",
            query: [
                URLQueryItem(name: "period", value: period.rawValue),
                URLQueryItem(name: "anchor", value: anchor),
            ]
        )
    }

    func complete(taskID: String, body: CompletionRequest) async throws -> MutationResponse {
        try await request("api/tasks/\(taskID)/complete", method: "POST", body: body)
    }

    func skip(taskID: String) async throws -> MutationResponse {
        try await emptyRequest("api/tasks/\(taskID)/skip", method: "POST")
    }

    func reset(taskID: String) async throws -> MutationResponse {
        try await emptyRequest("api/tasks/\(taskID)/reset", method: "POST")
    }

    func updateProfile(_ patch: ProfilePatch) async throws -> UserProfile {
        try await request("api/profile", method: "PATCH", body: patch)
    }

    func exerciseProgress(exerciseID: String) async throws -> ExerciseProgress {
        try await request("api/progress/exercises/\(exerciseID)")
    }

    func health() async -> Bool {
        do {
            let _: HealthResponse = try await request("api/health")
            return true
        } catch {
            return false
        }
    }

    private struct HealthResponse: Decodable {
        let status: String
    }

    private func request<Response: Decodable>(
        _ path: String,
        method: String = "GET",
        query: [URLQueryItem] = []
    ) async throws -> Response {
        try await perform(path, method: method, query: query, body: nil)
    }

    private func emptyRequest<Response: Decodable>(
        _ path: String,
        method: String
    ) async throws -> Response {
        try await perform(path, method: method, query: [], body: nil)
    }

    private func request<Response: Decodable, Body: Encodable>(
        _ path: String,
        method: String = "GET",
        query: [URLQueryItem] = [],
        body: Body?
    ) async throws -> Response {
        let data = body.flatMap { try? encoder.encode($0) }
        return try await perform(path, method: method, query: query, body: data)
    }

    private func perform<Response: Decodable>(
        _ path: String,
        method: String,
        query: [URLQueryItem],
        body: Data?
    ) async throws -> Response {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw FitrAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw FitrAPIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw FitrAPIError.decoding("Missing HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? decoder.decode(APIErrorEnvelope.self, from: data))?.error.message
                ?? "Server returned \(http.statusCode)."
            throw FitrAPIError.server(status: http.statusCode, message: message)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw FitrAPIError.decoding(error.localizedDescription)
        }
    }
}
