//: A UIKit based Playground for presenting user interface
  
import SwiftUI
import PlaygroundSupport

struct ContentView: View {

    @ObservedObject var presenter: CoinsPresenter

    var body: some View {
        VStack {
            switch presenter.state {
            case .loaded:
                VStack {
                    Image(systemName: "globe")
                        .imageScale(.large)
                        .foregroundColor(.accentColor)
                    Text("\(presenter.coinList.count) coins downloaded.")
                    HStack{
                        Spacer()
                    }
                }
            case .loading:
                ProgressView()
            case .error:
                VStack {
                    Image(systemName: "exclamationmark.shield")
                        .imageScale(.large)
                        .foregroundColor(.accentColor)
                    Text("\(presenter.errorMessage)")
                }
            }
            Spacer()
        }
        .padding()
        .frame(width: 400)
        .task {
            presenter.getData()
        }
    }
}


// MARK: - Example Usage

let baseAPIURL = URL(string: "https://api.coingecko.com/api/v3/")!
let networkLayer = URLSessionNetworkLayer(logger: nil, baseAPIURL: baseAPIURL)
let endpointProvider = ExampleEndpointProvider(baseAPIURL: baseAPIURL)

let presenter = CoinsPresenter(interactor: CoinsInteractorImpl(networkLayer: networkLayer, endpointProvider: endpointProvider))
let view = ContentView(presenter: presenter)
PlaygroundPage.current.setLiveView(view)



enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    // Add more HTTP methods as needed
}

struct Endpoint: EndpointProtocol {
    let path: String
    let method: HTTPMethod
    let parameters: [String: String]?
    let headers: [String: String]?
}

extension Endpoint: Equatable {

    static func ==(lhs: Endpoint, rhs: Endpoint) -> Bool {
        return lhs.path == rhs.path
        && lhs.method == rhs.method
        && lhs.parameters == rhs.parameters
        && lhs.headers == rhs.headers
    }
}

// MARK: - NetworkError

protocol ErrorResponse {
    var error: String { get }
}

struct ServiceError: Error, ErrorResponse, Decodable, Equatable {
    let error: String
}

enum NetworkError: Error {

    case invalidURL
    case requestFailed(statusCode: Int)
    case invalidResponse
    case decodingFailed
    case encodingFailed
    case serviceError(ServiceError)
    case unknownError(String)
}

extension NetworkError: Equatable {
    static func ==(lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL):
            return true
        case let (.requestFailed(lhsCode), .requestFailed(rhsCode)):
            return lhsCode == rhsCode
        case (.invalidResponse, .invalidResponse):
            return true
        case (.decodingFailed, .decodingFailed):
            return true
        case (.encodingFailed, .encodingFailed):
            return true
        case let (.serviceError(lhsError), .serviceError(rhsError)):
            return lhsError == rhsError
        case let (.unknownError(lhsDescription), .unknownError(rhsDescription)):
            return lhsDescription == rhsDescription
        default:
            return false
        }
    }
}


// MARK: - EndpointProtocol

protocol EndpointProtocol {
    var path: String { get }
    var method: HTTPMethod { get }
    var parameters: [String: String]? { get }
    var headers: [String: String]? { get }
}


// MARK: - Logger

protocol Logger {
    func log(_ message: String)
    func log(_ request: URLRequest)
    func log(_ response: URLResponse, data: Data)
}

final class ConsoleLogger: Logger {
    func log(_ message: String) {
        print("[Network Traffic]: \(message)")
    }

    func log(_ request: URLRequest) {
        if let url = request.url?.absoluteString {
            print("Request: \(request.httpMethod ?? "") - \(url)")
        }
    }

    func log(_ response: URLResponse, data: Data) {
        if let httpResponse = response as? HTTPURLResponse {
            let statusCode = httpResponse.statusCode
            print("Response: \(statusCode)")
        }

        if let responseData = String(data: data, encoding: .utf8) {
            print("Response Data: \(responseData)")
        }
    }
}

struct AccessTokenProvider {

    static let shared = AccessTokenProvider()

    var accessToken: String?
}


// MARK: - NetworkLayer

protocol NetworkLayer {
    func request<T: Decodable>(endpoint: Endpoint, accessTokenProvider: AccessTokenProvider ) async throws -> Result<T, NetworkError>
}


// MARK: - URLSessionNetworkLayer

final class URLSessionNetworkLayer: NetworkLayer {
    private let session: URLSession
    private let logger: Logger?
    private let baseAPIURL: URL

    init(session: URLSession = .shared, logger: Logger? = nil, baseAPIURL: URL) {
        self.session = session
        self.logger = logger
        self.baseAPIURL = baseAPIURL
    }

    func request<T: Decodable>(endpoint: Endpoint, accessTokenProvider: AccessTokenProvider = AccessTokenProvider.shared) async throws -> Result<T, NetworkError> {
        do {
            let request = try buildRequest(with: endpoint, accessTokenProvider: accessTokenProvider)
            logger?.log(request)

            let (data, response) = try await session.data(for: request)
            logger?.log(response, data: data)

            try validate(response, data)
            let decodedData = try decode(data, as: T.self)
            return .success(decodedData)
        } catch {
            guard let error = error as? NetworkError else {
                return .failure(.unknownError(error.localizedDescription))
            }
            return .failure(error)
        }
    }

    private func buildRequest(with endpoint: Endpoint, accessTokenProvider: AccessTokenProvider) throws -> URLRequest {
        let url = try makeURL(with: endpoint.path)

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue

        if let headers = endpoint.headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Add access token
        if let accessToken = accessTokenProvider.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func makeURL(with path: String) throws -> URL {
        guard let url = URL(string: path, relativeTo: baseAPIURL) else {
            throw NetworkError.invalidURL
        }

        return url
    }

    private func validate(_ response: URLResponse, _ data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(ServiceError.self, from: data) {
                throw NetworkError.serviceError(errorResponse)
            }
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }

    private func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(type, from: data)
        } catch {
            self.logger?.log("Decoding failed: \(error)")
            throw NetworkError.decodingFailed
        }
    }
}


final class JSONLocalFileNetworkLayer: NetworkLayer {

    func request<T: Decodable>(endpoint: Endpoint, accessTokenProvider: AccessTokenProvider) async throws -> Result<T, NetworkError> {
        guard let fileName = URL(string: endpoint.path)?.lastPathComponent else {
            throw NetworkError.invalidURL
        }

        do {
            let data = try fetchData(from: fileName)
            let decodedData = try decode(data, as: T.self)
            return .success(decodedData) // Assuming successful response
        } catch {
            throw NetworkError.decodingFailed
        }
    }

    private func fetchData(from fileName: String) throws -> Data {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            throw NetworkError.invalidURL
        }

        return try Data(contentsOf: url)
    }

    private func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw NetworkError.decodingFailed
        }
    }
}






// MARK: - EndpointProvider

protocol EndpointProvider {
    func getCryptoCoinPricesEndpoint() -> EndpointProtocol
    func getCryptoCoinDetailEndpoint(coinId: String) -> EndpointProtocol
    // Add more endpoint methods as needed
}

// MARK: - ExampleEndpointProvider

class ExampleEndpointProvider: EndpointProvider {

    private let baseAPIURL: URL

    init(baseAPIURL: URL) {
        self.baseAPIURL = baseAPIURL
    }

    func getCryptoCoinPricesEndpoint() -> EndpointProtocol {
        return Endpoint(path: "coins/list", method: .get, parameters: nil, headers: nil)
    }

    func getCryptoCoinDetailEndpoint(coinId: String) -> EndpointProtocol {
        return Endpoint(path: "coins/\(coinId)", method: .get, parameters: nil, headers: nil)
    }
}



// MARK: - CryptoCoinPrice

struct Coin: Codable {
    let id: String
    let symbol: String
    let name: String
}



protocol GetCoinListService {

    func getCoinList() async throws -> Result<[Coin], NetworkError>
}

extension GetCoinListService where Self: BaseInteractor {

    func getCoinList() async throws -> Result<[Coin], NetworkError> {

        let endpoint = endpointProvider.getCryptoCoinPricesEndpoint() as! Endpoint
        return try await networkLayer.request(endpoint: endpoint, accessTokenProvider: AccessTokenProvider.shared)
    }
}


protocol GetCoinDetailService {

    func getCoinDetail(coinId: String) async throws -> Result<Coin, NetworkError>
}

extension GetCoinDetailService where Self: BaseInteractor {

    func getCoinDetail(coinId: String) async throws -> Result<Coin, NetworkError> {

        let endpoint = endpointProvider.getCryptoCoinDetailEndpoint(coinId: coinId) as! Endpoint
        return try await networkLayer.request(endpoint: endpoint, accessTokenProvider: AccessTokenProvider.shared)
    }
}

//typealias Interactor = GetCoinDetailNetworkProviderProtocol & GetCoinListUseCaseProtocol

protocol BaseInteractor {

    var endpointProvider: EndpointProvider { get set }
    var networkLayer: NetworkLayer { get set }
}

protocol CoinsInteractor: BaseInteractor {

    func downloadCoinList() async throws -> Result<[Coin], NetworkError>
    func fetchDetail(of coinId: String) async throws -> Result<Coin, NetworkError>
}

typealias Interactor = CoinsInteractor & GetCoinListService & GetCoinDetailService

class CoinsInteractorImpl: Interactor {

    var networkLayer: NetworkLayer
    var endpointProvider: EndpointProvider

    init(networkLayer: NetworkLayer, endpointProvider: EndpointProvider) {
        self.networkLayer = networkLayer
        self.endpointProvider = endpointProvider
    }

    func downloadCoinList() async throws -> Result<[Coin], NetworkError> {
        let response = try await getCoinList()
        switch response {
        case .success(let coins):
            return .success(coins.reversed())
        case .failure(_):
            return response
        }
    }

    func fetchDetail(of coinId: String) async throws ->  Result<Coin, NetworkError> {
        return try await getCoinDetail(coinId: coinId)
    }
}



class CoinsPresenter: ObservableObject {

    enum CoinsPresenterState {

        case loading
        case loaded
        case error
    }

    @Published var coinList = [Coin]()
    @Published var state: CoinsPresenterState = .loading
    @Published var errorMessage: String = ""

    let interactor: CoinsInteractor

    init(interactor: CoinsInteractor) {
        self.interactor = interactor
    }

    func getData() {
        Task.init {
            do {
                let coinzResponse = try await interactor.downloadCoinList()
                DispatchQueue.main.async {
                    self.state = .loaded
                }

                switch coinzResponse {
                case .success(let coinz):
                    self.coinList = coinz
                    print("\(coinz.count) coins downloaded.")
                case .failure(let failure):
                    print("\(failure) inside Presenter")
                }

                let btcResponse = try await interactor.fetchDetail(of: "bitcoin")
                switch btcResponse {
                case .success(let coin):
                    print("Downloaded: \(coin)")
                case .failure(let failure):
                    switch failure {
                    case NetworkError.serviceError(let errorResponse):
                        print(errorResponse.error)
                    default:
                        print("\(failure.localizedDescription) inside Presenter")
                    }
                }
            }
            catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.state = .loaded
                }
                print(error.localizedDescription)
            }
        }
    }
}
