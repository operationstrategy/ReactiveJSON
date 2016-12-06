import ReactiveCocoa
import Result

// MARK: - JSON Service -
//------------------------------------------------------------------------------
extension Singleton where Instance: ServiceHost {
    public static func request<T>(endpoint endpoint: String, method: RequestMethod = .Get, parameters: [String:AnyObject]? = nil, token: AuthToken = .None) -> SignalProducer<(T, NSURLResponse), NetworkError> {
        return Instance.request(endpoint: endpoint, method: method, parameters: parameters, token: token)
            .attemptMap {
                guard let t = $0.0 as? T else {
					if let httpResponse = $0.1 as? NSHTTPURLResponse where httpResponse.statusCode == 401 {
						return .Failure(NetworkError.Unauthorized)
					}
                    return .Failure(NetworkError.IncorrectDataReturned)
                }
				if let httpResponse = $0.1 as? NSHTTPURLResponse where httpResponse.statusCode == 401 {
					return .Failure(NetworkError.Unauthorized)
				}
                return .Success(t, $0.1)
        }
    }
    public static func request<T>(endpoint endpoint: String, method: RequestMethod = .Get, parameters: [String:AnyObject]? = nil, token: AuthToken = .None) -> SignalProducer<T,NetworkError> {
        return request(endpoint: endpoint, method: method, parameters: parameters, token: token).map { $0.0 }
    }
    //--------------------------------------------------------------------------
    public static func request<J: JSONConvertible>(endpoint endpoint: String, method: RequestMethod = .Get, parameters: [String:AnyObject]? = nil, token: AuthToken = .None) -> SignalProducer<([J], NSURLResponse), NetworkError> {
        return Instance.request(endpoint: endpoint, method: method, parameters: parameters, token: token)
            .attemptMap{
				if let httpResponse = $0.1 as? NSHTTPURLResponse where httpResponse.statusCode == 401 {
					return .Failure(NetworkError.Unauthorized)
				}
                switch $0.0 {
                case let json as [[String:AnyObject]]:
                    return .Success(json.map({ J($0) }).flatMap({ $0 }), $0.1)
                case let json as [String:AnyObject]:
                    return .Success([json].map({ J($0) }).flatMap({ $0 }), $0.1)
                default:
                    return .Failure(NetworkError.IncorrectDataReturned)
                }
        }
    }
    public static func request<J: JSONConvertible>(endpoint endpoint: String, method: RequestMethod = .Get, parameters: [String:AnyObject]? = nil, token: AuthToken = .None) -> SignalProducer<J, NetworkError> {
        return request(endpoint: endpoint, method: method, parameters: parameters, token: token)
            .flatMap(.Merge) { (values: [J], response: NSURLResponse) in
                SignalProducer<J, NetworkError>(values:values)
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
        return "\(baseURLString)/" + ("\(endpoint.stringByReplacingOccurrencesOfString("//", withString: "/"))")
    }

    static func URLRequest(endpoint: String, method: RequestMethod = .Get, parameters: [String:AnyObject]? = nil, token: AuthToken = .None) -> NSURLRequest? {
        guard let components = NSURLComponents(string: URLString(with: endpoint)) else {
            return nil
        }

        var request: NSMutableURLRequest!
        
        switch method {
        case .Put: fallthrough
        case .Post:
            request = NSMutableURLRequest(URL: components.URL!)
            request.setValue(
                "application/x-www-form-urlencoded; charset=utf-8",
                forHTTPHeaderField: "Content-Type"
            )
            request.HTTPBody = parameters?.percentEncodedQuery?.dataUsingEncoding(NSUTF8StringEncoding)
        default:
            components.percentEncodedQuery = parameters?.percentEncodedQuery
            request = NSMutableURLRequest(URL: components.URL!)
        }

        //----------------------------------------------------------------------
        request.HTTPMethod = method.rawValue
        token.apply(to: request)

        //----------------------------------------------------------------------
        return request
    }
    
    //--------------------------------------------------------------------------
    static func request(session: NSURLSession = NSURLSession.sharedSession(), endpoint: String, method: RequestMethod = .Get, parameters: [String:AnyObject]? = nil, token: AuthToken = .None) -> SignalProducer<(AnyObject, NSURLResponse), NetworkError> {
        guard let request = URLRequest(endpoint, method: method, parameters: parameters, token: token) else {
            return SignalProducer(error: NetworkError.Unknown)
        }

        return session
            .rac_dataWithRequest(request)
            .mapNetworkError()
            .mapJSONResponse()
    }

    static func request<C: CollectionType>(session: NSURLSession = NSURLSession.sharedSession(), endpoint: String, method: RequestMethod = .Get, parameters: [String:AnyObject]? = nil, token: AuthToken = .None) -> SignalProducer<(C, NSURLResponse), NetworkError> {
        return request(session, endpoint: endpoint, method: method, parameters: parameters, token: token)
            .attemptMap { (json, response) -> Result<(C, NSURLResponse), NetworkError> in
                switch (Mirror(reflecting: json).displayStyle, json) {
                case (.Some(.Collection), let json as C):
                    return .Success(json, response)
                default:
                    let error = NetworkError.IncorrectDataReturned
                    return .Failure(error)
                }
        }
    }
}