import Foundation

/// Represents possible network-related errors
public enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case unauthorized
    case serverError(String)
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .noData:
            return "No data received from the server"
        case .decodingError:
            return "Failed to decode the response"
        case .unauthorized:
            return "Unauthorized request. Please check your API key"
        case .serverError(let message):
            return "Server error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

/// Handles network requests for the SDK
final class NetworkManager {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = ConfigurationManager.shared.timeoutInterval
        configuration.timeoutIntervalForResource = ConfigurationManager.shared.timeoutInterval
        
        self.session = URLSession(configuration: configuration)
        
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601
        
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    /// Performs a network request and decodes the response
    /// - Parameters:
    ///   - endpoint: The API endpoint
    ///   - method: HTTP method
    ///   - body: Optional request body
    ///   - headers: Additional headers
    func request<T: Decodable, U: Encodable>(
        endpoint: String,
        method: String,
        body: U? = nil,
        headers: [String: String] = [:]
    ) async throws -> T {
        guard let baseURL = URL(string: endpoint, relativeTo: ConfigurationManager.shared.getBaseURL()) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = method
        
        // Add authorization header
        if let authHeader = ConfigurationManager.shared.getAuthorizationHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        
        // Add content type for requests with body
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        // Add custom headers
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        // Encode body if present
        if let body = body {
            request.httpBody = try encoder.encode(body)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.networkError(NSError(domain: "", code: -1))
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    throw NetworkError.decodingError
                }
            case 401:
                throw NetworkError.unauthorized
            case 400...599:
                let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)
                throw NetworkError.serverError(errorMessage?["message"] ?? "Unknown server error")
            default:
                throw NetworkError.networkError(NSError(domain: "", code: httpResponse.statusCode))
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkError(error)
        }
    }
    
    /// Performs a network request without expecting a response body
    /// - Parameters:
    ///   - endpoint: The API endpoint
    ///   - method: HTTP method
    ///   - body: Optional request body
    ///   - headers: Additional headers
    func requestWithoutResponse<U: Encodable>(
        endpoint: String,
        method: String,
        body: U? = nil,
        headers: [String: String] = [:]
    ) async throws {
        guard let baseURL = URL(string: endpoint, relativeTo: ConfigurationManager.shared.getBaseURL()) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = method
        
        if let authHeader = ConfigurationManager.shared.getAuthorizationHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        if let body = body {
            request.httpBody = try encoder.encode(body)
        }
        
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.networkError(NSError(domain: "", code: -1))
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                return
            case 401:
                throw NetworkError.unauthorized
            case 400...599:
                throw NetworkError.serverError("Request failed with status code: \(httpResponse.statusCode)")
            default:
                throw NetworkError.networkError(NSError(domain: "", code: httpResponse.statusCode))
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkError(error)
        }
    }
} 