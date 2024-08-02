import Foundation

/// Makes URL requests.
public final class Provider {
    public let baseURL: String
    public let http: HTTPService
    public var interceptors: [Interceptor]
    public var modifiers: [RequestModifier]

    public init(baseURL: String, http: HTTPService, modifiers: [RequestModifier] = [], interceptors: [Interceptor] = []) {
        self.baseURL = baseURL
        self.http = http
        self.interceptors = interceptors
        self.modifiers = modifiers
    }

    public func newBuilder(method: String, path: String) -> RequestBuilder {
        RequestBuilder(baseURL: baseURL, method: method, path: path)
    }

    public func modifyRequests(action: @escaping (inout RequestBuilder) throws -> Void) -> Self {
        struct AnonymousModifier: RequestModifier {
            let action: (inout RequestBuilder) throws -> Void

            func modify(req: inout RequestBuilder) throws {
                try action(&req)
            }
        }

        modifiers.append(AnonymousModifier(action: action))
        return self
    }

    @discardableResult
	public func intercept(action: @Sendable @escaping (Request, (Request) async throws -> Response) async throws -> Response) -> Self {
        struct AnonymousInterceptor: Interceptor {
            let action: @Sendable (Request, Interceptor.Next) async throws -> Response

            func intercept(req: Request, next: Interceptor.Next) async throws -> Response {
                try await action(req, next)
            }
        }

        interceptors.append(AnonymousInterceptor(action: action))
        return self
    }

    @discardableResult
    public func request(_ builder: inout RequestBuilder) async throws -> Response {
        let request = try createRequest(&builder)
        var next: (Request) async throws -> Response = http.request
        for interceptor in interceptors.reversed() {
            let _next = next
            next = { try await interceptor.intercept(req: $0, next: _next) }
        }

        return try await next(request)
    }

    private func createRequest(_ builder: inout RequestBuilder) throws -> Request {
        for modifier in modifiers {
            try modifier.modify(req: &builder)
        }

        let url = try builder.fullURL()
        let (body, headers) = try builder.bodyAndHeaders()
        return http.build(method: builder.method, url: url, headers: headers, body: body)
    }
}

public protocol Interceptor: Sendable {
    typealias Next = (Request) async throws -> Response
    func intercept(req: Request, next: Next) async throws -> Response
}

public protocol RequestModifier {
    func modify(req: inout RequestBuilder) throws
}

// MARK: Closure Based APIs

extension Provider {
    public func request(_ builder: inout RequestBuilder, completionHandler: @Sendable @escaping (Response) -> Void) {
        do {
            let request = try createRequest(&builder)
            var next = http.request
            for interceptor in interceptors.reversed() {
                let _next = next
                next = {
                    interceptor.intercept(req: $0, completionHandler: $1, next: _next)
                }
            }

            return next(request, completionHandler)
        } catch {
            completionHandler(.error(error))
        }
    }
}

extension Interceptor {
    fileprivate func intercept(req: Request,
                               completionHandler: @Sendable @escaping (Response) -> Void,
                               next: @Sendable @escaping (Request, @Sendable @escaping (Response) -> Void) -> Void) {
        Task {
            do {
                completionHandler(
                    try await intercept(req: req) { req in
                        return try await withCheckedThrowingContinuation { c in
							next(req, { x in c.resume(returning: x) })
                        }
                    }
                )
            } catch {
                completionHandler(.error(error))
            }
        }
    }
}
