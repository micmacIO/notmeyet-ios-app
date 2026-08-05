import Foundation

actor LiveLooksService {
    private let configuration: AppConfiguration
    private let session: URLSession

    init(
        configuration: AppConfiguration,
        protocolClasses: [AnyClass]? = nil
    ) {
        self.configuration = configuration
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.urlCache = nil
        sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        sessionConfiguration.httpCookieStorage = nil
        if let protocolClasses {
            sessionConfiguration.protocolClasses = protocolClasses
        }
        self.session = URLSession(configuration: sessionConfiguration)
    }

    func analyze(photo: PreparedPhoto) async throws -> HarmonyResult {
        _ = session
        _ = photo.uploadData.count
        throw unavailableContract
    }

    func generateLook(photo: PreparedPhoto, result: HarmonyResult?) async throws -> GeneratedLook {
        _ = session
        _ = photo.uploadData.count
        _ = result
        throw unavailableContract
    }

    nonisolated func client() -> LooksClient {
        LooksClient(
            analyze: { [self] photo in
                try await analyze(photo: photo)
            },
            generateLook: { [self] photo, result in
                try await generateLook(photo: photo, result: result)
            }
        )
    }

    private var unavailableContract: ServiceFailure {
        guard
            configuration.looksAPIBaseURL != nil,
            configuration.looksAuthToken.isEmpty == false,
            configuration.facialDataDisclosuresApproved
        else {
            return .configuration("Looksmaxxing configuration and facial-data disclosures are incomplete.")
        }
        return .configuration("Looksmaxxing OpenAPI request and response contracts have not been supplied.")
    }
}
