import Foundation

@MainActor
final class OnboardingGateStore {
    private struct StoredGate: Codable {
        let version: Int
        let gate: RoutingGate
    }

    private let defaults: UserDefaults
    private let keyPrefix = "notmeyet.onboarding.gate"
    private let currentVersion = 1

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func gate(for userID: String) -> RoutingGate {
        let key = key(for: userID)
        guard
            let data = defaults.data(forKey: key),
            let stored = try? JSONDecoder().decode(StoredGate.self, from: data),
            stored.version == currentVersion
        else {
            defaults.removeObject(forKey: key)
            return .start
        }
        return stored.gate
    }

    func setGate(_ gate: RoutingGate, for userID: String) {
        let stored = StoredGate(version: currentVersion, gate: gate)
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: key(for: userID))
    }

    func clearAll() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(keyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    func client() -> RoutingGateClient {
        RoutingGateClient(
            gate: { [self] userID in gate(for: userID) },
            setGate: { [self] gate, userID in setGate(gate, for: userID) },
            clearAll: { [self] in clearAll() }
        )
    }

    private func key(for userID: String) -> String {
        "\(keyPrefix).\(Data(userID.utf8).base64EncodedString())"
    }
}
