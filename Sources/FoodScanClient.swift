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
    case authenticationRequired
    case httpStatus(Int)
    case serverError(code: String, message: String?)
    case decodingFailed
    case network(String)
    case emptyCandidate

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The scan proxy address isn’t valid. Check the Food Scan proxy URL in Settings (Debug) or reinstall."
        case .invalidImage:
            return "That photo couldn’t be prepared for scanning. Try another still image."
        case .authenticationRequired:
            return "Your scan session is missing or expired. Sign in again to scan; manual logging is still available."
        case .httpStatus(let code):
            return "The scan server returned an unexpected response (\(code))."
        case .serverError(let code, let message):
            return FoodScanClient.userMessage(forServerCode: code, fallback: message)
        case .decodingFailed:
            return "The scan response couldn’t be read. Nothing was saved."
        case .network(let detail):
            return "Couldn’t reach the PandaPlate scan server. \(detail)"
        case .emptyCandidate:
            return "No food was identified in that photo."
        }
    }
}

enum FoodScanClient {
    static let defaultBaseURL = PandaPlateProxyConfiguration.defaultBaseURL
    static let baseURLDefaultsKey = PandaPlateProxyConfiguration.baseURLDefaultsKey

    static var configuredBaseURL: URL {
        (try? PandaPlateProxyConfiguration.baseURL()) ?? URL(string: defaultBaseURL)!
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

    static func scan(image: UIImage, consent: Bool) async throws -> FoodScanResponse {
        guard consent else { throw FoodScanClientError.serverError(code: "explicit_live_consent_required", message: nil) }
        let proxySession: PandaPlateProxySession
        do {
            guard let validSession = try PandaPlateProxyAuthService.shared.validSession() else {
                throw FoodScanClientError.authenticationRequired
            }
            proxySession = validSession
        } catch let error as FoodScanClientError {
            throw error
        } catch {
            throw FoodScanClientError.serverError(code: "proxy_session_unavailable", message: error.localizedDescription)
        }
        guard let base64 = jpegBase64(from: image) else { throw FoodScanClientError.invalidImage }
        let baseURL: URL
        do {
            baseURL = try PandaPlateProxyConfiguration.baseURL()
        } catch {
            throw FoodScanClientError.invalidURL
        }
        let url = baseURL.appending(path: "v1/scan")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("Bearer \(proxySession.sessionToken)", forHTTPHeaderField: "Authorization")
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
            if http.statusCode == 401 || code == "unauthorized" {
                PandaPlateProxyAuthService.shared.clearSession()
                throw FoodScanClientError.authenticationRequired
            }
            let message = payload["message"] as? String
            throw FoodScanClientError.serverError(code: code, message: message)
        }
        if http.statusCode == 401 {
            PandaPlateProxyAuthService.shared.clearSession()
            throw FoodScanClientError.authenticationRequired
        }
        throw FoodScanClientError.httpStatus(http.statusCode)
    }

    static func userMessage(forServerCode code: String, fallback: String?) -> String {
        switch code {
        case "unauthorized", "proxy_session_unavailable":
            return "Your scan session is missing or expired. Sign in again to scan; manual logging is still available."
        case "live_scan_not_enabled":
            return "Live Food Scan isn’t enabled on the proxy right now. Try again later, or log manually."
        case "explicit_live_consent_required":
            return "Confirm consent before sending this photo for recognition."
        case "one_live_test_already_used_or_in_progress":
            return "This proxy’s one-shot live test was already used. Continuous mode is required for more scans."
        case "deepseek_key_missing":
            return "The scan proxy is missing its vision provider configuration."
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
            return "That photo is too large for the scan request."
        case "scan_failed":
            return fallback ?? "The scan didn’t complete. Nothing was saved."
        default:
            return fallback ?? "The scan didn’t complete (\(code)). Nothing was invented."
        }
    }
}
