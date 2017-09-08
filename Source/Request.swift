import ReactiveSwift
import Result

// MARK: - JSON Service -
//------------------------------------------------------------------------------
extension Singleton where Instance: ServiceHost {
    public static func request<T>(endpoint: String,
                                  method: RequestMethod = .GET,
                                  queryItems: [URLQueryItem]? = nil,
                                  token: AuthToken = .none) -> SignalProducer<(T, URLResponse), NetworkError> {
        return Instance.request(endpoint: endpoint,
                                method: method,
                                queryItems: queryItems,
                                token: token)
            .map { x in (x.0 as? T).map { ($0, x.1) } }
            .attemptMap { Result($0, failWith: .incorrectDataReturned) }
    }

    public static func request<T>(endpoint: String,
                                  method: RequestMethod = .GET,
                                  queryItems: [URLQueryItem]? = nil,
                                  token: AuthToken = .none) -> SignalProducer<T, NetworkError> {
        return request(endpoint: endpoint, method: method, queryItems: queryItems, token: token).map { $0.0 }
    }
    //--------------------------------------------------------------------------
    public static func request<J: JSONConvertible>(endpoint: String, method: RequestMethod = .GET, queryItems: [URLQueryItem]? = nil, token: AuthToken = .none) -> SignalProducer<([J], URLResponse), NetworkError> {
        return Instance.request(endpoint: endpoint, method: method, queryItems: queryItems, token: token)
        .attemptMap{
                switch $0.0 {
                case let json as [[String:AnyObject]]:
                    return .success(json.map({ J($0) }).flatMap({ $0 }), $0.1)
                case let json as [String:AnyObject]:
                    return .success([json].map({ J($0) }).flatMap({ $0 }), $0.1)
                default:
                    return .failure(.incorrectDataReturned)
                }
        }
    }
    public static func request<J: JSONConvertible>(endpoint: String, method: RequestMethod = .GET, queryItems: [URLQueryItem]? = nil, token: AuthToken = .none) -> SignalProducer<J, NetworkError> {
        return request(endpoint: endpoint, method: method, queryItems: queryItems, token: token)
            .flatMap(.merge) { (values: [J], response: URLResponse) in
                SignalProducer<J, NetworkError>(values)
        }
    }
}

extension ServiceHost {
    /// - parameter baseURLString: _"(scheme)://(host)/(path?)"_
    static var baseURLString: String {
        var baseURLString = "\(scheme)://\(host)"
        if let path = path {
            baseURLString += "/\(path)"
        }
        return baseURLString
    }
    
    //--------------------------------------------------------------------------
    static func URLString(with endpoint: String) -> String {
        return "\(baseURLString)/" + ("\(endpoint.replacingOccurrences(of: "//", with: "/"))")
    }
    
    static func URLRequest(_ endpoint: String,
                           method: RequestMethod = .GET,
                           queryItems: [URLQueryItem]? = nil,
                           token: AuthToken = .none) -> Foundation.URLRequest? {
        guard var components = URLComponents(string: URLString(with: endpoint)) else {
            return nil
        }
        
        let request: NSMutableURLRequest
        
        switch method {
        case .PUT, .POST:
            request = NSMutableURLRequest(url: components.url!)
            request.setValue(
                "application/x-www-form-urlencoded; charset=utf-8",
                forHTTPHeaderField: "Content-Type"
            )
            request.httpBody = method.payload?.percentEncodedQuery?.data(using: .utf8)
        default:
            components.queryItems = queryItems
            request = NSMutableURLRequest(url: components.url!)
        }
        
        //----------------------------------------------------------------------
        request.httpMethod = method.description
        token.apply(to: request)
        
        //----------------------------------------------------------------------
        return request as URLRequest?
    }
    
    //--------------------------------------------------------------------------
    static func request(_ session: URLSession = .shared,
                        endpoint: String,
                        method: RequestMethod = .GET,
                        queryItems: [URLQueryItem]? = nil,
                        token: AuthToken = .none) -> SignalProducer<(Any, URLResponse), NetworkError> {
        guard let request = URLRequest(endpoint, method: method, queryItems: queryItems, token: token) else {
            return SignalProducer(error: NetworkError.unknown)
        }
        
        return session.reactive
            .data(with: request)
            .mapNetworkError()
            .mapJSONResponse()
            .attemptMap {
                ($0.1 as? HTTPURLResponse)?.statusCode == 401
                    ? .failure(.unauthorized) : .success($0)
        }
    }
    
    static func request<C: Collection>(_ session: URLSession = .shared,
                                       endpoint: String,
                                       method: RequestMethod = .GET,
                                       queryItems: [URLQueryItem]? = nil,
                                       token: AuthToken = .none) -> SignalProducer<(C, URLResponse), NetworkError> {
        return request(session, endpoint: endpoint, method: method, queryItems: queryItems, token: token)
            .attemptMap { (json, response) -> Result<(C, URLResponse), NetworkError> in
                switch (Mirror(reflecting: json).displayStyle, json) {
                case (.some(.collection), let json as C):
                    return .success(json, response)
                default:
                    return .failure(.incorrectDataReturned)
                }
        }
    }
}
