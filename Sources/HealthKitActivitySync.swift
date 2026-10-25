import Foundation
import HealthKit

/// Read-first Apple Health sync. Preference-only for calorie mode — no BMR/TDEE theater.
/// Simulator: HealthKit may be unavailable; authorization and fetches fail gracefully.
@MainActor
final class HealthKitActivitySync: ObservableObject {
    static let shared = HealthKitActivitySync()

    enum ConnectionState: String {
        case notAsked
        case connected
        case denied
    }

    private static let stateKey = "pandaplate.healthKit.connectionState"
    private static let stepsKey = "pandaplate.healthKit.todaySteps"
    private static let energyKey = "pandaplate.healthKit.todayActiveEnergy"
    private static let exerciseKey = "pandaplate.healthKit.todayExerciseMinutes"
    private static let fetchedAtKey = "pandaplate.healthKit.fetchedAt"

    private let store = HKHealthStore()

    @Published private(set) var connectionState: ConnectionState
    @Published private(set) var todaySteps: Int?
    @Published private(set) var todayActiveEnergyKcal: Double?
    @Published private(set) var todayExerciseMinutes: Int?
    @Published private(set) var lastFetchDate: Date?
    @Published private(set) var lastErrorMessage: String?

    var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    var isConnected: Bool { connectionState == .connected }

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(energy) }
        if let exercise = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) { types.insert(exercise) }
        types.insert(HKObjectType.workoutType())
        return types
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.stateKey) ?? ConnectionState.notAsked.rawValue
        connectionState = ConnectionState(rawValue: raw) ?? .notAsked
        let steps = UserDefaults.standard.object(forKey: Self.stepsKey) as? Int
        todaySteps = steps
        if UserDefaults.standard.object(forKey: Self.energyKey) != nil {
            todayActiveEnergyKcal = UserDefaults.standard.double(forKey: Self.energyKey)
        }
        if UserDefaults.standard.object(forKey: Self.exerciseKey) != nil {
            todayExerciseMinutes = UserDefaults.standard.integer(forKey: Self.exerciseKey)
        }
        lastFetchDate = UserDefaults.standard.object(forKey: Self.fetchedAtKey) as? Date
    }

    func persistState(_ state: ConnectionState) {
        connectionState = state
        UserDefaults.standard.set(state.rawValue, forKey: Self.stateKey)
    }

    /// Requests read authorization. Never writes to HealthKit in this build.
    func requestAuthorization() async -> ConnectionState {
        guard isHealthDataAvailable else {
            lastErrorMessage = "Apple Health isn’t available on this device."
            persistState(.denied)
            return .denied
        }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            // HealthKit does not reveal deny vs grant per type; treat successful prompt as connected
            // and let empty fetches stay honest (“No steps synced yet”).
            persistState(.connected)
            lastErrorMessage = nil
            await refreshTodaySummary()
            return .connected
        } catch {
            lastErrorMessage = "Couldn’t connect to Apple Health. You can try again later."
            persistState(.denied)
            return .denied
        }
    }

    func refreshTodaySummary() async {
        guard isHealthDataAvailable, connectionState == .connected else { return }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        async let steps = sumQuantity(.stepCount, unit: HKUnit.count(), predicate: predicate)
        async let energy = sumQuantity(.activeEnergyBurned, unit: HKUnit.kilocalorie(), predicate: predicate)
        async let exercise = sumQuantity(.appleExerciseTime, unit: HKUnit.minute(), predicate: predicate)

        let stepValue = await steps
        let energyValue = await energy
        let exerciseValue = await exercise

        todaySteps = stepValue.map { Int($0.rounded()) }
        todayActiveEnergyKcal = energyValue
        todayExerciseMinutes = exerciseValue.map { Int($0.rounded()) }
        lastFetchDate = Date()

        if let todaySteps {
            UserDefaults.standard.set(todaySteps, forKey: Self.stepsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.stepsKey)
        }
        if let todayActiveEnergyKcal {
            UserDefaults.standard.set(todayActiveEnergyKcal, forKey: Self.energyKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.energyKey)
        }
        if let todayExerciseMinutes {
            UserDefaults.standard.set(todayExerciseMinutes, forKey: Self.exerciseKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.exerciseKey)
        }
        UserDefaults.standard.set(lastFetchDate, forKey: Self.fetchedAtKey)
    }

    /// Maps recent HealthKit workouts into AppStore session logs. Kcal only when HK provides totalEnergyBurned.
    func importRecentWorkouts(into appStore: AppStore, limit: Int = 10) async {
        guard isHealthDataAvailable, connectionState == .connected else { return }
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        do {
            let samples: [HKSample] = try await withCheckedThrowingContinuation { cont in
                let query = HKSampleQuery(
                    sampleType: HKObjectType.workoutType(),
                    predicate: predicate,
                    limit: limit,
                    sortDescriptors: [sort]
                ) { _, results, error in
                    if let error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume(returning: results ?? [])
                    }
                }
                store.execute(query)
            }
            for sample in samples {
                guard let workout = sample as? HKWorkout else { continue }
                let minutes = max(1, Int((workout.duration / 60.0).rounded()))
                let name = Self.activityName(for: workout.workoutActivityType)
                // Real HK energy only — never invent. Missing energy stays Unknown (nil).
                let hkKcal: Int? = {
                    guard let qty = workout.totalEnergyBurned else { return nil }
                    let v = Int(qty.doubleValue(for: HKUnit.kilocalorie()).rounded())
                    return (1...20_000).contains(v) ? v : nil
                }()
                _ = appStore.addWorkout(
                    activity: "Health · \(name)",
                    durationMinutes: min(minutes, WorkoutFeatureRules.maximumCustomDuration),
                    time: workout.endDate,
                    activeEnergyKcal: hkKcal
                )
            }
        } catch {
            lastErrorMessage = "Workouts couldn’t be read right now."
        }
    }

    private func sumQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit, predicate: NSPredicate) async -> Double? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        return await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: unit)
                cont.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private static func activityName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .walking: return "Walking"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength"
        case .yoga: return "Yoga"
        case .swimming: return "Swimming"
        case .hiking: return "Hiking"
        case .dance: return "Dance"
        case .elliptical: return "Elliptical"
        case .coreTraining: return "Core training"
        default: return "Workout"
        }
    }

    func resetDemoState() {
        persistState(.notAsked)
        todaySteps = nil
        todayActiveEnergyKcal = nil
        todayExerciseMinutes = nil
        lastFetchDate = nil
        lastErrorMessage = nil
        UserDefaults.standard.removeObject(forKey: Self.stepsKey)
        UserDefaults.standard.removeObject(forKey: Self.energyKey)
        UserDefaults.standard.removeObject(forKey: Self.exerciseKey)
        UserDefaults.standard.removeObject(forKey: Self.fetchedAtKey)
    }
}
