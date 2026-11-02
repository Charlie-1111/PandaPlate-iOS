import XCTest
import UIKit
@testable import PandaPlate

private final class PandaPlateStubURLProtocol: URLProtocol {
    static var handler: ((URLRequest, Data?) throws -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (status, data) = try handler(request, Self.bodyData(for: request))
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func bodyData(for request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while true {
            let count = buffer.withUnsafeMutableBufferPointer { bytes in
                stream.read(bytes.baseAddress!, maxLength: bytes.count)
            }
            if count < 0 { return nil }
            if count == 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
}

final class PandaPlateProxyAuthTests: XCTestCase {
    override func tearDown() {
        PandaPlateStubURLProtocol.handler = nil
        super.tearDown()
    }

    func testAppleNonceUsesLowercaseSHA256Hex() {
        XCTAssertEqual(
            PandaPlateProxyConfiguration.appleRequestNonce(for: "abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    func testEndpointRequiresHTTPSExceptForLoopbackHTTP() {
        XCTAssertTrue(PandaPlateProxyConfiguration.isAllowedBaseURL(URL(string: "http://127.0.0.1:8787")!))
        XCTAssertTrue(PandaPlateProxyConfiguration.isAllowedBaseURL(URL(string: "http://localhost:8787")!))
        XCTAssertTrue(PandaPlateProxyConfiguration.isAllowedBaseURL(URL(string: "https://proxy.example.workers.dev")!))
        XCTAssertFalse(PandaPlateProxyConfiguration.isAllowedBaseURL(URL(string: "http://proxy.example.workers.dev")!))
        XCTAssertFalse(PandaPlateProxyConfiguration.isAllowedBaseURL(URL(string: "http://0.0.0.0:8787")!))
        XCTAssertFalse(PandaPlateProxyConfiguration.isAllowedBaseURL(URL(string: "https://user:pass@proxy.example.workers.dev")!))
        XCTAssertFalse(PandaPlateProxyConfiguration.isAllowedBaseURL(URL(string: "file:///tmp/proxy")!))
    }

    func testSessionExpiryUsesDeterministicUnixTimeBoundary() {
        let session = PandaPlateProxySession(sessionToken: "test-session", expiresAt: 2_001)
        XCTAssertTrue(session.isValid(at: Date(timeIntervalSince1970: 2_000)))
        XCTAssertFalse(session.isValid(at: Date(timeIntervalSince1970: 2_001)))
        XCTAssertFalse(PandaPlateProxySession(sessionToken: "", expiresAt: 2_100).isValid(at: Date(timeIntervalSince1970: 2_000)))
    }

    func testPhotoScanRejectsMissingConsentBeforeSessionOrNetwork() async {
        do {
            _ = try await FoodScanClient.scan(image: UIImage(), consent: false)
            XCTFail("A scan without explicit consent must not proceed.")
        } catch let error as FoodScanClientError {
            XCTAssertEqual(error, .serverError(code: "explicit_live_consent_required", message: nil))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAppleExchangeFetchesNonceAndSendsRawNonceWithBearerIdentityToken() async throws {
        var requests: [(URLRequest, Data?)] = []
        PandaPlateStubURLProtocol.handler = { request, body in
            requests.append((request, body))
            if request.url?.path == "/v1/auth/nonce" {
                return (200, Data(#"{"nonce":"raw-server-nonce-value-12345678901234567890","expiresInSeconds":300}"#.utf8))
            }
            return (200, Data(#"{"sessionToken":"signed-app-session","expiresAt":9000}"#.utf8))
        }
        let client = makeClient()

        let nonce = try await client.fetchNonce(for: .apple)
        let appSession = try await client.exchangeAppleIdentityToken("apple.id.token", rawNonce: nonce)

        XCTAssertEqual(nonce, "raw-server-nonce-value-12345678901234567890")
        XCTAssertEqual(appSession.sessionToken, "signed-app-session")
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[0].0.url?.path, "/v1/auth/nonce")
        XCTAssertEqual(requests[0].0.httpMethod, "POST")
        XCTAssertEqual(requests[0].0.value(forHTTPHeaderField: "Cache-Control"), "no-store")
        let nonceData = try XCTUnwrap(requests[0].1)
        let nonceBody = try XCTUnwrap(JSONSerialization.jsonObject(with: nonceData) as? [String: String])
        XCTAssertEqual(nonceBody["provider"], "apple")
        XCTAssertEqual(requests[1].0.url?.path, "/v1/auth/session")
        XCTAssertEqual(requests[1].0.value(forHTTPHeaderField: "Authorization"), "Bearer apple.id.token")
        let appleData = try XCTUnwrap(requests[1].1)
        let appleBody = try XCTUnwrap(JSONSerialization.jsonObject(with: appleData) as? [String: String])
        XCTAssertEqual(appleBody["provider"], "apple")
        XCTAssertEqual(appleBody["nonce"], nonce)
    }


    private func makeClient() -> PandaPlateProxyAuthClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PandaPlateStubURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)
        return PandaPlateProxyAuthClient(baseURL: URL(string: "https://proxy.test")!, session: urlSession)
    }
}
