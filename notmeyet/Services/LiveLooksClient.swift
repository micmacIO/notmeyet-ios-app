import Foundation

actor LiveLooksService {
    private static let maximumUploadBytes = 10_485_760
    private static let pollingAttempts = 40
    private static let pollingInterval = Duration.seconds(3)

    private let configuration: AppConfiguration
    private let idTokenProvider: @Sendable () async throws -> String
    private let sleep: @Sendable (Duration) async throws -> Void
    private let session: URLSession
    private let imageLoader: GeneratedImageLoader
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var remoteSession: RemoteSession?

    init(
        configuration: AppConfiguration,
        idTokenProvider: @escaping @Sendable () async throws -> String,
        protocolClasses: [AnyClass]? = nil,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { duration in
            try await Task.sleep(for: duration)
        },
        imageLoader: GeneratedImageLoader? = nil
    ) {
        self.configuration = configuration
        self.idTokenProvider = idTokenProvider
        self.sleep = sleep

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.urlCache = nil
        sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        sessionConfiguration.httpCookieStorage = nil
        sessionConfiguration.httpCookieAcceptPolicy = .never
        sessionConfiguration.httpShouldSetCookies = false
        sessionConfiguration.urlCredentialStorage = nil
        if let protocolClasses {
            sessionConfiguration.protocolClasses = protocolClasses
        }
        self.session = URLSession(configuration: sessionConfiguration)
        self.imageLoader = imageLoader ?? GeneratedImageLoader(protocolClasses: protocolClasses)
    }

    func analyze(photo: PreparedPhoto) async throws -> HarmonyResult {
        try Task.checkCancellation()
        let baseURL = try validatedBaseURL(for: photo)
        startSessionIfNeeded(for: photo.id)

        let selfieID = try await selfieID(for: photo, baseURL: baseURL)
        try await triggerAnalysisIfNeeded(for: photo.id, selfieID: selfieID, baseURL: baseURL)
        let analysis = try await completedAnalysis(for: photo.id, selfieID: selfieID, baseURL: baseURL)
        let imageData = try await imageLoader.load(url: analysis.imageURL)
        try requireCurrentSession(for: photo.id)

        return HarmonyResult(
            annotatedImageData: imageData,
            faceShape: analysis.faceShape,
            harmonyScore: analysis.harmonyScore
        )
    }

    func generateLook(photo: PreparedPhoto, result: HarmonyResult?) async throws -> GeneratedLook {
        try Task.checkCancellation()
        _ = result
        let baseURL = try validatedBaseURL(for: photo)
        guard let current = remoteSession, current.photoID == photo.id else {
            throw missingAnalysisFailure
        }
        guard case .known(let selfieID) = current.upload else {
            throw missingAnalysisFailure
        }

        let transformation = try await selectedTransformation(
            for: photo.id,
            selfieID: selfieID,
            baseURL: baseURL
        )
        let generationID = try await generationID(
            for: photo.id,
            selfieID: selfieID,
            transformation: transformation,
            baseURL: baseURL
        )
        let imageURL = try await completedGenerationImageURL(
            for: photo.id,
            selfieID: selfieID,
            generationID: generationID,
            transformationID: transformation.id,
            baseURL: baseURL
        )
        let imageData = try await imageLoader.load(url: imageURL)
        try requireCurrentSession(for: photo.id)

        return GeneratedLook(
            imageData: imageData,
            styleName: transformation.displayName,
            styleDescription: transformation.description
        )
    }

    func clearSession(photoID: UUID) {
        guard remoteSession?.photoID == photoID else { return }
        remoteSession = nil
    }

    nonisolated func client() -> LooksClient {
        LooksClient(
            analyze: { [self] photo in
                try await analyze(photo: photo)
            },
            generateLook: { [self] photo, result in
                try await generateLook(photo: photo, result: result)
            },
            clearSession: { [self] photoID in
                await clearSession(photoID: photoID)
            }
        )
    }

    private func validatedBaseURL(for photo: PreparedPhoto) throws -> URL {
        guard
            configuration.facialDataDisclosuresApproved,
            let baseURL = configuration.looksAPIBaseURL,
            baseURL.scheme?.lowercased() == "https",
            baseURL.host?.isEmpty == false
        else {
            throw ServiceFailure.configuration(
                "Looks service configuration and facial-data disclosures are incomplete."
            )
        }
        guard photo.uploadData.count <= Self.maximumUploadBytes else {
            throw ServiceFailure.invalidImage(
                "This photo is too large to upload. Please choose another photo."
            )
        }
        return baseURL
    }

    private func startSessionIfNeeded(for photoID: UUID) {
        guard remoteSession?.photoID != photoID else { return }
        remoteSession = RemoteSession(photoID: photoID)
    }

    private func selfieID(for photo: PreparedPhoto, baseURL: URL) async throws -> RemoteID {
        let state = try currentSession(for: photo.id).upload
        switch state {
        case .known(let selfieID):
            return selfieID
        case .ambiguous:
            throw ambiguousUploadFailure
        case .notStarted:
            break
        }

        var request = URLRequest(url: endpoint(["api", "v1", "selfies"], relativeTo: baseURL))
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let boundary = "LooksBoundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(photo.uploadData, boundary: boundary)
        request = try await authorized(request)
        try requireCurrentSession(for: photo.id)

        switch try currentSession(for: photo.id).upload {
        case .known(let selfieID):
            return selfieID
        case .ambiguous:
            throw ambiguousUploadFailure
        case .notStarted:
            updateSession(for: photo.id) { $0.upload = .ambiguous }
        }

        let response: APIResponse
        do {
            response = try await execute(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try requireCurrentSession(for: photo.id)
            throw ambiguousUploadFailure
        }
        try requireCurrentSession(for: photo.id)

        guard response.http.statusCode == 201 else {
            if (400..<500).contains(response.http.statusCode) {
                updateSession(for: photo.id) { $0.upload = .notStarted }
                throw safeHTTPFailure(for: response.http.statusCode)
            }
            throw ambiguousUploadFailure
        }

        guard
            let decoded = try? decoder.decode(SelfieResponse.self, from: response.data),
            let rawID = decoded.id,
            let selfieID = RemoteID(rawValue: rawID)
        else {
            throw ambiguousUploadFailure
        }
        updateSession(for: photo.id) { $0.upload = .known(selfieID) }
        return selfieID
    }

    private func triggerAnalysisIfNeeded(
        for photoID: UUID,
        selfieID: RemoteID,
        baseURL: URL
    ) async throws {
        guard try currentSession(for: photoID).analysisTriggerAttempted == false else { return }

        var request = URLRequest(
            url: endpoint(["api", "v1", "selfies", selfieID.rawValue, "analysis"], relativeTo: baseURL)
        )
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request = try await authorized(request)
        try requireCurrentSession(for: photoID)
        guard try currentSession(for: photoID).analysisTriggerAttempted == false else { return }
        updateSession(for: photoID) { $0.analysisTriggerAttempted = true }

        let response: APIResponse
        do {
            response = try await execute(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try requireCurrentSession(for: photoID)
            return
        }
        try requireCurrentSession(for: photoID)

        if response.http.statusCode == 202 {
            // The acknowledgement is intentionally advisory; upload owns the exact selfie ID.
            _ = try? decoder.decode(AnalyzeSelfieResponse.self, from: response.data)
            return
        }
        guard (400..<500).contains(response.http.statusCode) else {
            return
        }
        updateSession(for: photoID) { $0.analysisTriggerAttempted = false }
        throw safeHTTPFailure(for: response.http.statusCode)
    }

    private func completedAnalysis(
        for photoID: UUID,
        selfieID: RemoteID,
        baseURL: URL
    ) async throws -> CompletedAnalysis {
        if let completed = try currentSession(for: photoID).completedAnalysis {
            return completed
        }

        let url = endpoint(["api", "v1", "selfies", selfieID.rawValue], relativeTo: baseURL)
        for attempt in 0..<Self.pollingAttempts {
            let response: SelfieResponse = try await get(url, as: SelfieResponse.self)
            try requireCurrentSession(for: photoID)

            if let responseID = response.id {
                guard RemoteID(rawValue: responseID) == selfieID else {
                    throw invalidResponseFailure
                }
            }

            guard
                response.deepface != nil,
                let symmetry = response.symmetry,
                let shape = response.shape,
                let mesh = response.mesh,
                response.ratio != nil
            else {
                if attempt < Self.pollingAttempts - 1 {
                    try await pauseBeforeNextPoll()
                    try requireCurrentSession(for: photoID)
                }
                continue
            }

            guard
                let rawFaceShape = shape.primaryShape,
                rawFaceShape.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                let harmonyScore = symmetry.overallScore,
                harmonyScore.isFinite,
                (0...100).contains(harmonyScore),
                let imageURL = secureURL(from: mesh.imageUrl)
            else {
                throw invalidResponseFailure
            }

            let completed = CompletedAnalysis(
                imageURL: imageURL,
                faceShape: rawFaceShape.trimmingCharacters(in: .whitespacesAndNewlines),
                harmonyScore: harmonyScore
            )
            updateSession(for: photoID) { $0.completedAnalysis = completed }
            return completed
        }

        throw ServiceFailure.transport("Analysis is taking longer than expected. Try again.")
    }

    private func selectedTransformation(
        for photoID: UUID,
        selfieID: RemoteID,
        baseURL: URL
    ) async throws -> SelectedTransformation {
        if let selected = try currentSession(for: photoID).transformation {
            return selected
        }
        let searchURL = endpoint(["api", "v1", "transformations", "search"], relativeTo: baseURL)
        guard var components = URLComponents(url: searchURL, resolvingAgainstBaseURL: false) else {
            throw invalidResponseFailure
        }
        components.queryItems = [
            URLQueryItem(name: "selfieId", value: selfieID.rawValue),
            URLQueryItem(name: "categories", value: "HAIRSTYLE")
        ]
        guard let url = components.url else { throw invalidResponseFailure }

        let transformations: [TransformationResponse] = try await get(
            url,
            as: [TransformationResponse].self
        )
        try requireCurrentSession(for: photoID)
        if let selected = try currentSession(for: photoID).transformation {
            return selected
        }

        guard
            let first = transformations.first,
            let rawID = first.id,
            let id = RemoteID(rawValue: rawID),
            first.category == "HAIRSTYLE",
            first.creditPrice == 1,
            let rawDisplayName = first.displayName,
            let rawDescription = first.description,
            rawDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
            rawDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        else {
            throw invalidResponseFailure
        }

        let selected = SelectedTransformation(
            id: id,
            displayName: rawDisplayName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: rawDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        updateSession(for: photoID) { $0.transformation = selected }
        return selected
    }

    private func generationID(
        for photoID: UUID,
        selfieID: RemoteID,
        transformation: SelectedTransformation,
        baseURL: URL
    ) async throws -> RemoteID {
        let current = try currentSession(for: photoID)
        if let generationID = current.generationID { return generationID }
        guard current.generationCreationIsAmbiguous == false else {
            throw ambiguousGenerationFailure
        }
        guard
            let selfieInt64 = selfieID.positiveInt64,
            let transformationInt64 = transformation.id.positiveInt64
        else {
            throw invalidResponseFailure
        }

        var request = URLRequest(url: endpoint(["api", "v1", "generations"], relativeTo: baseURL))
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try encoder.encode(
                GenerationRequest(
                    selfieId: selfieInt64,
                    transformationIds: [transformationInt64]
                )
            )
        } catch {
            throw invalidResponseFailure
        }
        request = try await authorized(request)
        try requireCurrentSession(for: photoID)

        let refreshed = try currentSession(for: photoID)
        if let generationID = refreshed.generationID { return generationID }
        guard refreshed.generationCreationIsAmbiguous == false else {
            throw ambiguousGenerationFailure
        }
        updateSession(for: photoID) { $0.generationCreationIsAmbiguous = true }

        let response: APIResponse
        do {
            response = try await execute(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try requireCurrentSession(for: photoID)
            throw ambiguousGenerationFailure
        }
        try requireCurrentSession(for: photoID)

        guard response.http.statusCode == 201 else {
            if (400..<500).contains(response.http.statusCode) {
                updateSession(for: photoID) { $0.generationCreationIsAmbiguous = false }
                throw safeHTTPFailure(for: response.http.statusCode)
            }
            throw ambiguousGenerationFailure
        }

        guard
            let decoded = try? decoder.decode(GenerationResponse.self, from: response.data),
            let rawID = decoded.id,
            let generationID = RemoteID(rawValue: rawID)
        else {
            throw ambiguousGenerationFailure
        }
        updateSession(for: photoID) {
            $0.generationID = generationID
            $0.generationCreationIsAmbiguous = false
        }
        return generationID
    }

    private func completedGenerationImageURL(
        for photoID: UUID,
        selfieID: RemoteID,
        generationID: RemoteID,
        transformationID: RemoteID,
        baseURL: URL
    ) async throws -> URL {
        if let imageURL = try currentSession(for: photoID).completedGenerationImageURL {
            return imageURL
        }

        let url = endpoint(["api", "v1", "generations", generationID.rawValue], relativeTo: baseURL)
        for attempt in 0..<Self.pollingAttempts {
            let response: GenerationResponse = try await get(url, as: GenerationResponse.self)
            try requireCurrentSession(for: photoID)

            if let responseID = response.id {
                guard RemoteID(rawValue: responseID) == generationID else {
                    throw invalidResponseFailure
                }
            }
            if let responseSelfieID = response.selfieId {
                guard RemoteID(rawValue: responseSelfieID) == selfieID else {
                    throw invalidResponseFailure
                }
            }

            switch response.status {
            case .pending, .submitting, .awaitingResult, .processing:
                if attempt < Self.pollingAttempts - 1 {
                    try await pauseBeforeNextPoll()
                    try requireCurrentSession(for: photoID)
                }
            case .completed:
                guard
                    let item = response.items?.first(where: {
                        guard let rawID = $0.transformationId else { return false }
                        return RemoteID(rawValue: rawID) == transformationID
                    }),
                    item.status == .completed,
                    let imageURL = secureURL(from: item.resultImageUrl)
                else {
                    throw invalidResponseFailure
                }
                updateSession(for: photoID) { $0.completedGenerationImageURL = imageURL }
                return imageURL
            case .failed, .partiallyCompleted:
                throw ServiceFailure.nonRetryable(
                    "This look could not be generated. Please continue without it."
                )
            case .unknown, .none:
                throw invalidResponseFailure
            }
        }

        throw ServiceFailure.transport("Your look is taking longer than expected. Try again.")
    }

    private func get<Response: Decodable & Sendable>(
        _ url: URL,
        as type: Response.Type
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request = try await authorized(request)

        let response: APIResponse
        do {
            response = try await execute(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ServiceFailure.transport("The Looks service is unavailable. Try again.")
        }
        guard response.http.statusCode == 200 else {
            throw safeHTTPFailure(for: response.http.statusCode)
        }
        do {
            return try decoder.decode(type, from: response.data)
        } catch {
            throw invalidResponseFailure
        }
    }

    private func authorized(_ request: URLRequest) async throws -> URLRequest {
        try Task.checkCancellation()
        let token: String
        do {
            token = try await idTokenProvider()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            throw ServiceFailure.authentication(
                "Your session could not be verified. Please sign in again."
            )
        }
        try Task.checkCancellation()

        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            trimmedToken.isEmpty == false,
            trimmedToken == token,
            token.contains("\r") == false,
            token.contains("\n") == false
        else {
            throw ServiceFailure.authentication(
                "Your session could not be verified. Please sign in again."
            )
        }

        var authorizedRequest = request
        authorizedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        authorizedRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        return authorizedRequest
    }

    private func execute(_ request: URLRequest) async throws -> APIResponse {
        try Task.checkCancellation()
        do {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse else {
                throw APIRequestError.noResponse
            }
            return APIResponse(data: data, http: http)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            throw APIRequestError.noResponse
        }
    }

    private func pauseBeforeNextPoll() async throws {
        try Task.checkCancellation()
        do {
            try await sleep(Self.pollingInterval)
            try Task.checkCancellation()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            throw ServiceFailure.transport("The Looks service is unavailable. Try again.")
        }
    }

    private func endpoint(_ pathComponents: [String], relativeTo baseURL: URL) -> URL {
        pathComponents.reduce(baseURL) { url, component in
            url.appendingPathComponent(component, isDirectory: false)
        }
    }

    private func multipartBody(_ imageData: Data, boundary: String) -> Data {
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"selfie.jpg\"\r\n".utf8))
        body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
        body.append(imageData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
    }

    private func secureURL(from rawValue: String?) -> URL? {
        guard
            let rawValue,
            let url = URL(string: rawValue),
            url.scheme?.lowercased() == "https",
            url.host?.isEmpty == false
        else {
            return nil
        }
        return url
    }

    private func currentSession(for photoID: UUID) throws -> RemoteSession {
        guard let remoteSession, remoteSession.photoID == photoID else {
            throw CancellationError()
        }
        return remoteSession
    }

    private func requireCurrentSession(for photoID: UUID) throws {
        try Task.checkCancellation()
        _ = try currentSession(for: photoID)
    }

    private func updateSession(
        for photoID: UUID,
        _ update: (inout RemoteSession) -> Void
    ) {
        guard var remoteSession, remoteSession.photoID == photoID else { return }
        update(&remoteSession)
        self.remoteSession = remoteSession
    }

    private func safeHTTPFailure(for statusCode: Int) -> ServiceFailure {
        if statusCode == 401 || statusCode == 403 {
            return .authentication("Your session could not be verified. Please sign in again.")
        }
        return .transport("The Looks service could not complete the request. Try again.")
    }

    private var invalidResponseFailure: ServiceFailure {
        .transport("The Looks service returned an unusable response. Try again.")
    }

    private var ambiguousUploadFailure: ServiceFailure {
        .nonRetryable(
            "The photo upload could not be confirmed. Please retake your photo before trying again."
        )
    }

    private var ambiguousGenerationFailure: ServiceFailure {
        .nonRetryable(
            "The look request could not be confirmed and will not be retried to avoid another charge."
        )
    }

    private var missingAnalysisFailure: ServiceFailure {
        .nonRetryable(
            "This photo's analysis session is no longer available. Please retake your photo."
        )
    }
}

private extension LiveLooksService {
    struct APIResponse: Sendable {
        let data: Data
        let http: HTTPURLResponse
    }

    enum APIRequestError: Error {
        case noResponse
    }

    enum UploadState: Sendable {
        case notStarted
        case ambiguous
        case known(RemoteID)
    }

    struct CompletedAnalysis: Sendable {
        let imageURL: URL
        let faceShape: String
        let harmonyScore: Double
    }

    struct SelectedTransformation: Sendable {
        let id: RemoteID
        let displayName: String
        let description: String
    }

    struct RemoteSession: Sendable {
        let photoID: UUID
        var upload = UploadState.notStarted
        var analysisTriggerAttempted = false
        var completedAnalysis: CompletedAnalysis?
        var transformation: SelectedTransformation?
        var generationCreationIsAmbiguous = false
        var generationID: RemoteID?
        var completedGenerationImageURL: URL?
    }
}
