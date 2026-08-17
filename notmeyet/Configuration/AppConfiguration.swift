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
    let termsURL: URL?
    let privacyURL: URL?
    let facialDataDisclosuresApproved: Bool
    let backendUserLifecycleContractConfirmed: Bool

    init(
        mode: ServiceMode,
        googleClientID: String,
        revenueCatAPIKey: String,
        revenueCatEntitlementID: String,
        looksAPIBaseURL: URL?,
        termsURL: URL?,
        privacyURL: URL?,
        facialDataDisclosuresApproved: Bool,
        backendUserLifecycleContractConfirmed: Bool
    ) {
        self.mode = mode
        self.googleClientID = googleClientID
        self.revenueCatAPIKey = revenueCatAPIKey
        self.revenueCatEntitlementID = revenueCatEntitlementID
        self.looksAPIBaseURL = looksAPIBaseURL
        self.termsURL = termsURL
        self.privacyURL = privacyURL
        self.facialDataDisclosuresApproved = facialDataDisclosuresApproved
        self.backendUserLifecycleContractConfirmed = backendUserLifecycleContractConfirmed
    }

    var isMock: Bool {
        mode == .mock
    }

    var hasConfirmedBackendUserLifecycleConfiguration: Bool {
        mode == .live
            && backendUserLifecycleContractConfirmed
            && looksAPIBaseURL?.isProductionHTTPSURL == true
    }

    static func load(
        bundle: Bundle = .main,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> AppConfiguration {
        let values = bundle.infoDictionary ?? [:]
        let requestedMode = values["NMYServiceMode"] as? String ?? "live"
        let googleClientID = values["NMYGoogleClientID"] as? String ?? ""
        let googleCallbackSchemes = Self.callbackSchemes(from: values)
        let revenueCatAPIKey = values["NMYRevenueCatAPIKey"] as? String ?? ""
        let entitlementID = values["NMYRevenueCatEntitlementID"] as? String ?? ""
        let looksURL = Self.validURL(from: values["NMYLooksAPIBaseURL"] as? String)
        let termsURL = Self.validURL(from: values["NMYTermsURL"] as? String)
        let privacyURL = Self.validURL(from: values["NMYPrivacyURL"] as? String)
        let disclosuresApproved = (values["NMYFacialDataDisclosuresApproved"] as? NSNumber)?.boolValue
            ?? (values["NMYFacialDataDisclosuresApproved"] as? NSString)?.boolValue
            ?? false
        let lifecycleContractConfirmed = (values["NMYBackendUserLifecycleContractConfirmed"] as? NSNumber)?.boolValue
            ?? (values["NMYBackendUserLifecycleContractConfirmed"] as? NSString)?.boolValue
            ?? false

        let mode = Self.resolveMode(
            requestedMode: requestedMode,
            arguments: arguments,
            googleClientID: googleClientID,
            googleCallbackSchemes: googleCallbackSchemes,
            revenueCatAPIKey: revenueCatAPIKey,
            entitlementID: entitlementID,
            looksURL: looksURL,
            termsURL: termsURL,
            privacyURL: privacyURL,
            disclosuresApproved: disclosuresApproved,
            lifecycleContractConfirmed: lifecycleContractConfirmed,
            hasFirebaseConfiguration: bundle.path(forResource: "GoogleService-Info", ofType: "plist") != nil
        )

        return AppConfiguration(
            mode: mode,
            googleClientID: googleClientID,
            revenueCatAPIKey: revenueCatAPIKey,
            revenueCatEntitlementID: entitlementID,
            looksAPIBaseURL: looksURL,
            termsURL: termsURL,
            privacyURL: privacyURL,
            facialDataDisclosuresApproved: disclosuresApproved,
            backendUserLifecycleContractConfirmed: lifecycleContractConfirmed
        )
    }

    static func resolveMode(
        requestedMode: String,
        arguments: [String],
        googleClientID: String,
        googleCallbackSchemes: [String],
        revenueCatAPIKey: String,
        entitlementID: String,
        looksURL: URL?,
        termsURL: URL?,
        privacyURL: URL?,
        disclosuresApproved: Bool,
        lifecycleContractConfirmed: Bool,
        hasFirebaseConfiguration: Bool,
        isDebugBuild: Bool = Self.isDebugBuild
    ) -> ServiceMode {
        let normalizedMode = requestedMode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard normalizedMode == "mock" || normalizedMode == "live" else {
            return .invalid("Unsupported service mode: \(requestedMode).")
        }

        let requestsDebugOnlyBehavior = arguments.contains { argument in
            argument.hasPrefix("--mock-")
                || argument == "--reset-onboarding"
                || argument.hasPrefix("--ui-test-presentation=")
        }
        if !isDebugBuild && requestsDebugOnlyBehavior {
            return .invalid("Mock and UI-test selectors are unavailable in Release builds.")
        }

        let requestsMock = normalizedMode == "mock" || arguments.contains("--mock-services")

        if requestsMock {
            return isDebugBuild
                ? .mock
                : .invalid("Mock services are unavailable in Release builds.")
        }

        let missingLiveConfiguration = [
            googleClientID.isGoogleClientID ? nil : "Google client ID",
            googleClientID.hasMatchingCallbackScheme(in: googleCallbackSchemes) ? nil : "Google callback scheme",
            revenueCatAPIKey.isPlaceholder ? "RevenueCat API key" : nil,
            entitlementID.isPlaceholder ? "RevenueCat entitlement" : nil,
            looksURL?.isProductionHTTPSURL == true ? nil : "Looks API URL",
            termsURL?.isProductionHTTPSURL == true ? nil : "Terms URL",
            privacyURL?.isProductionHTTPSURL == true ? nil : "Privacy URL",
            disclosuresApproved ? nil : "facial-data disclosures",
            lifecycleContractConfirmed ? nil : "backend-user lifecycle contract",
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
        guard let url = URL(string: trimmedValue), url.isProductionHTTPSURL else { return nil }
        return url
    }

    private static func callbackSchemes(from values: [String: Any]) -> [String] {
        guard let URLTypes = values["CFBundleURLTypes"] as? [[String: Any]] else { return [] }
        return URLTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
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

    var isGoogleClientID: Bool {
        let normalized = trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let suffix = ".apps.googleusercontent.com"
        return !isPlaceholder && normalized.hasSuffix(suffix) && normalized.count > suffix.count
    }

    func hasMatchingCallbackScheme(in schemes: [String]) -> Bool {
        guard isGoogleClientID else { return false }
        let expectedScheme = trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ".")
            .reversed()
            .joined(separator: ".")
        return schemes.contains { scheme in
            !scheme.isPlaceholder && scheme.caseInsensitiveCompare(expectedScheme) == .orderedSame
        }
    }
}

private extension URL {
    var isProductionHTTPSURL: Bool {
        guard
            scheme?.lowercased() == "https",
            let host = host?.lowercased(),
            !host.isEmpty,
            !absoluteString.isPlaceholder
        else {
            return false
        }

        let reservedHosts = ["example.com", "example.net", "example.org", "localhost"]
        guard !reservedHosts.contains(where: { host == $0 || host.hasSuffix(".\($0)") }) else {
            return false
        }

        let reservedTopLevelDomains = ["example", "invalid", "localhost", "test"]
        guard let topLevelDomain = host.split(separator: ".").last else { return false }
        return !reservedTopLevelDomains.contains(String(topLevelDomain))
            && host != "127.0.0.1"
            && host != "::1"
            && host != "[::1]"
    }
}
