import Quick
import Nimble
import ReactiveJSON
import ReactiveSwift
import Result

struct GW2API: Singleton, ServiceHost {
    fileprivate(set) static var shared = Instance()
    typealias Instance = GW2API

    static var scheme: String { return "https" }
    static var host: String { return "api.guildwars2.com" }
    static var path: String? { return "v2" }
}

class JSONRequestTests: QuickSpec {
    override func spec() {
        describe("json request") {
            it("returns 'nil' with bad endpoint path") {
                let request: SignalProducer<Any, NetworkError> = GW2API.request(endpoint: "").map { $0.0 }
                var error: NetworkError? = nil
                request.startWithFailed {
                    error = $0
                }
                expect(error).toNotEventually(beNil(), timeout: 5)
            }

            it("handles request as 'dictionary'") {
                var colors: [String:AnyObject] = [:]
                GW2API.request(endpoint: "colors", queryItems: [URLQueryItem(name: "id", value: "4")])
                    .startWithResult {
                        colors = $0.value!
                }

                expect(colors["name"] as? String).toEventually(equal("Gray"), timeout: 5)
            }

            it("handles request as 'int' collection") {
                var colors: [Int]? 
                GW2API.request(endpoint: "colors")
                    .startWithResult { (result: Result<[Int], NetworkError>) in
                        colors = result.value 
                }
                expect(colors?.count).toEventually(beGreaterThanOrEqualTo(531), timeout: 5)
            }
        }
    }
}
