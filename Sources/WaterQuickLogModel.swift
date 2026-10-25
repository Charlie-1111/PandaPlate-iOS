import Foundation

/// Illustrative container sizes for logging what the person actually drank.
enum WaterServingSize: String, CaseIterable, Identifiable {
    case smallCup
    case glass
    case bottle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smallCup: "Small cup"
        case .glass: "Glass"
        case .bottle: "Bottle"
        }
    }

    var milliliters: Int {
        switch self {
        case .smallCup: 150
        case .glass: 250
        case .bottle: 500
        }
    }

    var example: String { "\(milliliters) ml" }
}

/// Helpers for the ten tappable water slots. This is a log, not a hydration target.
enum WaterQuickLogModel {
    static let maximumCups = 10
    static let allowedServingSizes = Set(WaterServingSize.allCases.map(\.milliliters))
    static let maximumTotalML = maximumCups * WaterServingSize.bottle.milliliters

    static func total(for cups: [Int?]) -> Int {
        cups.prefix(maximumCups).compactMap { $0 }
            .filter { allowedServingSizes.contains($0) }
            .reduce(0, +)
    }

    static func filledCount(for cups: [Int?]) -> Int {
        cups.prefix(maximumCups).compactMap { $0 }.count
    }

    static func canSet(_ servingML: Int, at index: Int, in cups: [Int?]) -> Bool {
        guard (0..<maximumCups).contains(index), allowedServingSizes.contains(servingML), index < cups.count else {
            return false
        }
        if cups[index] != nil { return true }
        return filledCount(for: cups) < maximumCups
            && total(for: cups) + servingML <= maximumTotalML
    }
}
