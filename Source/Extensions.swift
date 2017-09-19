// MARK: - Extension, Query Items -
//------------------------------------------------------------------------------
extension Dictionary where Value: AnyObject {
    func toQueryItems() -> [URLQueryItem] {
        return map { (key: Key, value: AnyObject) in ("\(key)", value.description) }
            .map(URLQueryItem.init)
            .sorted { $0.name < $1.name }
    }

    var percentEncodedQuery: String? {
        return toQueryItems().toPercentEncodedQuery()
    }
}

extension Array where Iterator.Element == URLQueryItem {
    internal func toPercentEncodedQuery() -> String? {
        var components = URLComponents()
        components.queryItems = self
        let percentEncodedQuery = components.percentEncodedQuery
        return percentEncodedQuery
    }
}
