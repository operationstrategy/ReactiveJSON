// MARK: - Request Method -
//------------------------------------------------------------------------------
public enum RequestMethod: CustomStringConvertible {
    case GET
    case POST(payload: [String: AnyObject])
    case PUT(payload: [String: AnyObject])
    case DELETE

    public var description: String {
        switch self {
        case .GET: return "GET"
        case .POST: return "POST"
        case .DELETE: return "DELETE"
        case .PUT: return "PUT"
        }
    }

    internal var payload: [String: AnyObject]? {
        switch self {
        case let .POST(payload: pl): return pl
        case let .PUT(payload: pl): return pl
        default: return nil
        }
    }
}
