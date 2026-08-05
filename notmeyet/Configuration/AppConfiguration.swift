import Foundation

enum ServiceMode: Equatable, Sendable {
    case mock
    case live
    case invalid(String)
}

struct AppConfiguration: Equatable, Sendable {
    let mode: ServiceMode
    let googleClientID: String
    let revenueCatAPIKey: String
    let revenueCatEntitlementID: String
    let looksAPIBaseURL: URL?
    let looksAuthToken: String
    let termsURL: URL?
    let privacyURL: URL?
    let facialDataDisclosuresApproved: Bool

    var isMock: Bool {
        mode == .mock
    }

    static func load(
        bundle: Bundle = .main,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> AppConfiguration {
        let values = bundle.infoDictionary ?? [:]
        let requestedMode = values["NMYServiceMode"] as? String ?? "live"
        let googleClientID = values["NMYGoogleClientID"] as? String ?? ""
        let revenueCatAPIKey = values["NMYRevenueCatAPIKey"] as? String ?? ""
        let entitlementID = values["NMYRevenueCatEntitlementID"] as? String ?? ""
        let looksAuthToken = values["NMYLooksAuthToken"] as? String ?? ""
        let looksURL = Self.validURL(from: values["NMYLooksAPIBaseURL"] as? String)
        let termsURL = Self.validURL(from: values["NMYTermsURL"] as? String)
        let privacyURL = Self.validURL(from: values["NMYPrivacyURL"] as? String)
        let disclosuresApproved = (values["NMYFacialDataDisclosuresApproved"] as? NSNumber)?.boolValue
            ?? (values["NMYFacialDataDisclosuresApproved"] as? NSString)?.boolValue
            ?? false

        let mode = Self.resolveMode(
            requestedMode: requestedMode,
            arguments: arguments,
            googleClientID: googleClientID,
            revenueCatAPIKey: revenueCatAPIKey,
            entitlementID: entitlementID,
            looksURL: looksURL,
            looksAuthToken: looksAuthToken,
            termsURL: termsURL,
            privacyURL: privacyURL,
            disclosuresApproved: disclosuresApproved,
            hasFirebaseConfiguration: bundle.path(forResource: "GoogleService-Info", ofType: "plist") != nil
        )

        return AppConfiguration(
            mode: mode,
            googleClientID: googleClientID,
            revenueCatAPIKey: revenueCatAPIKey,
            revenueCatEntitlementID: entitlementID,
            looksAPIBaseURL: looksURL,
            looksAuthToken: looksAuthToken,
            termsURL: termsURL,
            privacyURL: privacyURL,
            facialDataDisclosuresApproved: disclosuresApproved
        )
    }

    static func resolveMode(
        requestedMode: String,
        arguments: [String],
        googleClientID: String,
        revenueCatAPIKey: String,
        entitlementID: String,
        looksURL: URL?,
        looksAuthToken: String,
        termsURL: URL?,
        privacyURL: URL?,
        disclosuresApproved: Bool,
        hasFirebaseConfiguration: Bool,
        isDebugBuild: Bool = Self.isDebugBuild
    ) -> ServiceMode {
        let normalizedMode = requestedMode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard normalizedMode == "mock" || normalizedMode == "live" else {
            return .invalid("Unsupported service mode: \(requestedMode).")
        }

        let requestsMock = normalizedMode == "mock" || arguments.contains("--mock-services")

        if requestsMock {
            return isDebugBuild
                ? .mock
                : .invalid("Mock services are unavailable in Release builds.")
        }

        let missingLiveConfiguration = [
            googleClientID.isPlaceholder ? "Google client ID" : nil,
            revenueCatAPIKey.isPlaceholder ? "RevenueCat API key" : nil,
            entitlementID.isPlaceholder ? "RevenueCat entitlement" : nil,
            looksURL == nil ? "Looks API URL" : nil,
            looksAuthToken.isPlaceholder ? "Looks API authentication" : nil,
            termsURL == nil ? "Terms URL" : nil,
            privacyURL == nil ? "Privacy URL" : nil,
            disclosuresApproved ? nil : "facial-data disclosures",
            hasFirebaseConfiguration ? nil : "Firebase configuration"
        ].compactMap { $0 }

        guard missingLiveConfiguration.isEmpty else {
            return .invalid("Live configuration is incomplete: \(missingLiveConfiguration.joined(separator: ", ")).")
        }

        return .live
    }

    private static func validURL(from value: String?) -> URL? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedValue), url.scheme == "https", url.host != nil else { return nil }
        return url
    }

    private static var isDebugBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}

private extension String {
    var isPlaceholder: Bool {
        let normalized = trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty || normalized.uppercased().contains("PLACEHOLDER")
    }
}
