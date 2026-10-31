import Foundation
import UIKit

struct FoodScanFDCMatch: Decodable, Identifiable, Equatable {
    let fdcId: Int
    let description: String
    let dataType: String?
    var id: Int { fdcId }
}

struct FoodScanCandidate: Decodable, Equatable {
    let foodDescription: String
    let portion: String?
    let grams: Int?
    let confidence: Double?
    let notes: String?
    let calories: Int?
    let nutritionSource: String?
    let fdcMatches: [FoodScanFDCMatch]?
}

struct FoodScanResponse: Decodable, Equatable {
    let mode: String?
    let candidate: FoodScanCandidate
    let notice: String?
}

enum FoodScanClientError: LocalizedError, Equatable {
    case invalidURL
    case invalidImage
    case httpStatus(Int)
    case serverError(code: String, message: String?)
    case decodingFailed
    case network(String)
    case emptyCandidate

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The scan server address isn’t valid. Check the local server URL in Settings."
        case .invalidImage:
            return "That photo couldn’t be prepared for scanning. Try another still image."
        case .httpStatus(let code):
            return "The scan server returned an unexpected response (\(code))."
        case .serverError(let code, let message):
            return FoodScanClient.userMessage(forServerCode: code, fallback: message)
        case .decodingFailed:
            return "The scan response couldn’t be read. Nothing was saved."
        case .network(let detail):
            return "Couldn’t reach the local PandaPlate Server. \(detail)"
        case .emptyCandidate:
            return "No food was identified in that photo."
        }
    }
}

enum FoodScanClient {
    static let defaultBaseURL = "http://127.0.0.1:8787"
    static let baseURLDefaultsKey = "pandaplate.scanBaseURL"
    static let scanTokenDefaultsKey = "pandaplate.scanToken"

    static var configuredBaseURL: URL {
        let fallback = URL(string: defaultBaseURL)!
        #if DEBUG
        let raw = UserDefaults.standard.string(forKey: baseURLDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty, isPrivateScanBaseURL(raw), let url = URL(string: raw) else {
            return fallback
        }
        return url
        #else
        return fallback
        #endif
    }

    /// Loopback and private LAN hosts only. Public hosts are rejected so a saved URL cannot upload a meal photo off the device network.
    static func isPrivateScanBaseURL(_ raw: String) -> Bool {
        guard let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.user == nil,
              url.password == nil,
              let host = url.host?.lowercased()
        else { return false }
        if host == "localhost" || host == "127.0.0.1" || host == "::1" { return true }
        let parts = host.split(separator: ".")
        guard parts.count == 4 else { return false }
        let octets = parts.compactMap { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) else { return false }
        if octets[0] == 10 { return true }
        if octets[0] == 192 && octets[1] == 168 { return true }
        if octets[0] == 172 && (16...31).contains(octets[1]) { return true }
        if octets[0] == 169 && octets[1] == 254 { return true }
        return false
    }

    static var configuredScanToken: String? {
        let raw = UserDefaults.standard.string(forKey: scanTokenDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return nil }
        return raw
    }

    static func jpegBase64(from image: UIImage, maxBytes: Int = 900_000) -> String? {
        var quality: CGFloat = 0.82
        var data = image.jpegData(compressionQuality: quality)
        while let current = data, current.count > maxBytes, quality > 0.35 {
            quality -= 0.12
            data = image.jpegData(compressionQuality: quality)
        }
        guard let final = data, !final.isEmpty, final.count <= 1_000_000 else { return nil }
        return final.base64EncodedString()
    }

    static func scan(image: UIImage, consent: Bool = true) async throws -> FoodScanResponse {
        guard consent else { throw FoodScanClientError.serverError(code: "explicit_live_consent_required", message: nil) }
        guard let base64 = jpegBase64(from: image) else { throw FoodScanClientError.invalidImage }
        let url = configuredBaseURL.appendingPathComponent("v1/scan")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = configuredScanToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 60
        let body: [String: Any] = [
            "mode": "live",
            "consent": true,
            "imageBase64": base64,
            "mimeType": "image/jpeg",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FoodScanClientError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw FoodScanClientError.network("No HTTP response.")
        }

        if (200...299).contains(http.statusCode) {
            do {
                let decoded = try JSONDecoder().decode(FoodScanResponse.self, from: data)
                let name = decoded.candidate.foodDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { throw FoodScanClientError.emptyCandidate }
                return decoded
            } catch let error as FoodScanClientError {
                throw error
            } catch {
                throw FoodScanClientError.decodingFailed
            }
        }

        if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let code = payload["error"] as? String {
            let message = payload["message"] as? String
            throw FoodScanClientError.serverError(code: code, message: message)
        }
        throw FoodScanClientError.httpStatus(http.statusCode)
    }

    static func userMessage(forServerCode code: String, fallback: String?) -> String {
        switch code {
        case "unauthorized":
            return "The local scan server rejected this request. Check the scan token in developer settings."
        case "live_scan_not_enabled":
            return "Live food scan isn’t enabled on the local server right now."
        case "explicit_live_consent_required":
            return "Confirm consent before sending this photo for recognition."
        case "one_live_test_already_used_or_in_progress":
            return "The one-shot live test was already used. Restart the server in continuous live mode for more scans."
        case "deepseek_key_missing":
            return "The local server is missing its vision provider configuration."
        case "deepseek_request_failed":
            return "The vision provider couldn’t finish this scan. Try again in a moment."
        case "usda_request_failed":
            return "USDA FoodData Central couldn’t be reached, so calories stay unknown."
        case "no_food_detected":
            return "No clear food item was detected in that photo."
        case "invalid_provider_response":
            return "The recognition response wasn’t usable. Nothing was invented for you."
        case "invalid_image_or_image_too_large":
            return "That image wasn’t accepted. Use a smaller JPEG or PNG under about 1 MB."
        case "request_too_large":
            return "That photo is too large for the local scan request."
        case "scan_failed":
            return fallback ?? "The scan didn’t complete. Nothing was saved."
        default:
            return fallback ?? "The scan didn’t complete (\(code)). Nothing was invented."
        }
    }
}
