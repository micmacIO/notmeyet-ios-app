import Foundation
import Testing
import UIKit
@testable import notmeyet

@Suite("Live Looks HTTP transport", .serialized)
@MainActor
struct LiveLooksServiceTests {
    private let selfieID = "9007199254740993"
    private let oversizedSelfieID = "9223372036854775809"
    private let acknowledgedSelfieID = "9007199254740994"
    private let transformationID = "9007199254740995"
    private let otherTransformationID = "9007199254740996"
    private let generationID = "9223372036854775808"
    private let unusableResponseFailure = ServiceFailure.transport(
        "The Looks service returned an unusable response. Try again."
    )

    @Test("Happy path preserves IDs and sends the approved request sequence")
    func happyPathRequestSequence() async throws {
        let meshData = try makeImageData(color: .systemPink)
        let generatedData = try makeImageData(color: .systemBlue)
        let script = LooksTransportScript([
            .json(statusCode: 201, uploadResponse()),
            .json(statusCode: 202, analysisAcknowledgement()),
            .json(statusCode: 200, incompleteSelfieResponse()),
            .json(statusCode: 200, completeSelfieResponse()),
            .image(meshData),
            .json(statusCode: 200, transformationSearchResponse()),
            .json(statusCode: 201, generationCreatedResponse()),
            .json(statusCode: 200, generationPendingResponse()),
            .json(statusCode: 200, generationCompletedResponse()),
            .image(generatedData)
        ])
        ScriptedLooksURLProtocol.script = script
        defer { ScriptedLooksURLProtocol.reset() }
        let tokens = LockedCounter()
        let sleeps = SleepRecorder()
        let photo = makePhoto(uploadData: Data("jpeg-upload-payload".utf8))
        let service = makeService(tokens: tokens, sleeps: sleeps)

        let harmony = try await service.analyze(photo: photo)
        let look = try await service.generateLook(photo: photo, result: harmony)

        #expect(harmony.annotatedImageData == meshData)
        #expect(harmony.faceShape == "Oval")
        #expect(harmony.harmonyScore == 87.25)
        #expect(look.imageData == generatedData)
        #expect(look.styleName == "Textured Crop")
        #expect(look.styleDescription == "Static style guidance.")
        #expect(sleeps.values == [.seconds(3), .seconds(3)])

        let requests = script.requests
        #expect(requests.count == 10)
        #expect(requests.map(\.url?.path) == [
            "/api/v1/selfies",
            "/api/v1/selfies/\(selfieID)/analysis",
            "/api/v1/selfies/\(selfieID)",
            "/api/v1/selfies/\(selfieID)",
            "/mesh.png",
            "/api/v1/transformations/search",
            "/api/v1/generations",
            "/api/v1/generations/\(generationID)",
            "/api/v1/generations/\(generationID)",
            "/generated.png"
        ])
        #expect(requests.contains { $0.url?.path.contains("users/me") == true } == false)

        let apiRequests = requests.filter { $0.url?.path.hasPrefix("/api/v1/") == true }
        #expect(apiRequests.count == 8)
        #expect(apiRequests.map { $0.value(forHTTPHeaderField: "Authorization") } ==
            (1...apiRequests.count).map { "Bearer firebase-token-\($0)" })
        #expect(tokens.value == apiRequests.count)
        #expect(requests[4].value(forHTTPHeaderField: "Authorization") == nil)
        #expect(requests[9].value(forHTTPHeaderField: "Authorization") == nil)

        let upload = requests[0]
        #expect(upload.httpMethod == "POST")
        let uploadContentType = try #require(upload.value(forHTTPHeaderField: "Content-Type"))
        #expect(uploadContentType.hasPrefix("multipart/form-data; boundary=LooksBoundary-"))
        let uploadBody = try #require(upload.httpBody)
        let uploadBodyText = try #require(String(data: uploadBody, encoding: .utf8))
        #expect(uploadBodyText.contains("name=\"file\"; filename=\"selfie.jpg\""))
        #expect(uploadBodyText.contains("Content-Type: image/jpeg"))
        #expect(uploadBody.range(of: photo.uploadData) != nil)
        #expect(uploadBodyText.components(separatedBy: "name=\"file\"").count == 2)

        let searchComponents = try #require(URLComponents(url: requests[5].url!, resolvingAgainstBaseURL: false))
        let searchQuery = Dictionary(uniqueKeysWithValues: (searchComponents.queryItems ?? []).map {
            ($0.name, $0.value)
        })
        #expect(searchQuery["selfieId"] == selfieID)
        #expect(searchQuery["categories"] == "HAIRSTYLE")

        let generationBodyData = try #require(requests[6].httpBody)
        let generationBody = try JSONDecoder().decode(CapturedGenerationRequest.self, from: generationBodyData)
        #expect(generationBody.selfieId == 9_007_199_254_740_993)
        #expect(generationBody.transformationIds == [9_007_199_254_740_995])
        #expect(Int64(generationID) == nil)
        #expect(requests[7].url?.lastPathComponent == generationID)
        #expect(requests[8].url?.lastPathComponent == generationID)
        let generationObject = try #require(
            JSONSerialization.jsonObject(with: generationBodyData) as? [String: Any]
        )
        #expect(Set(generationObject.keys) == ["selfieId", "transformationIds"])

        let allBodies = requests.compactMap(\.httpBody).reduce(into: Data()) { $0.append($1) }
        let serializedBodies = String(decoding: allBodies, as: UTF8.self).lowercased()
        #expect(serializedBodies.contains("questionnaire") == false)
        #expect(serializedBodies.contains("primarygoal") == false)
        #expect(serializedBodies.contains("painpoint") == false)
        #expect(serializedBodies.contains("direction") == false)
        #expect(serializedBodies.contains("ignore this personalized copy") == false)
    }

    @Test("An oversized selfie ID stays exact until generation needs a numeric field")
    func oversizedSelfieIDIsPreservedUntilGenerationEncoding() async throws {
        let imageData = try makeImageData(color: .systemPink)
        let script = LooksTransportScript([
            .json(statusCode: 201, uploadResponse(id: oversizedSelfieID)),
            .json(statusCode: 202, analysisAcknowledgement()),
            .json(statusCode: 200, incompleteSelfieResponse(id: oversizedSelfieID)),
            .json(statusCode: 200, completeSelfieResponse(id: oversizedSelfieID)),
            .image(imageData),
            .json(statusCode: 200, transformationSearchResponse())
        ])
        ScriptedLooksURLProtocol.script = script
        defer { ScriptedLooksURLProtocol.reset() }
        let sleeps = SleepRecorder()
        let service = makeService(sleeps: sleeps)
        let photo = makePhoto()

        #expect(Int64(oversizedSelfieID) == nil)
        #expect(try await service.analyze(photo: photo).annotatedImageData == imageData)
        await #expect(throws: unusableResponseFailure) {
            try await service.generateLook(photo: photo, result: nil)
        }

        let requests = script.requests
        #expect(requests.map(\.url?.path) == [
            "/api/v1/selfies",
            "/api/v1/selfies/\(oversizedSelfieID)/analysis",
            "/api/v1/selfies/\(oversizedSelfieID)",
            "/api/v1/selfies/\(oversizedSelfieID)",
            "/mesh.png",
            "/api/v1/transformations/search"
        ])
        #expect(sleeps.values == [.seconds(3)])
        let searchURL = try #require(requests.last?.url)
        let components = try #require(URLComponents(url: searchURL, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.first(where: { $0.name == "selfieId" })?.value == oversizedSelfieID)
        #expect(requests.contains { $0.url?.path == "/api/v1/generations" } == false)
        #expect(requests.contains { $0.url?.path.contains("users/me") == true } == false)
    }

    @Test(
        "Malformed, zero, and nondecimal upload IDs fail safely",
        arguments: InvalidUploadIDCase.allCases
    )
    func invalidUploadIDsFailSafely(invalidCase: InvalidUploadIDCase) async {
        let script = LooksTransportScript([
            .json(statusCode: 201, uploadResponse(id: invalidCase.rawValue))
        ])
        ScriptedLooksURLProtocol.script = script
        defer { ScriptedLooksURLProtocol.reset() }

        await #expect(throws: ServiceFailure.nonRetryable(
            "The photo upload could not be confirmed. Please retake your photo before trying again."
        )) {
            try await makeService().analyze(photo: makePhoto())
        }
        #expect(RemoteID(rawValue: invalidCase.rawValue) == nil)
        #expect(script.requests.map(\.url?.path) == ["/api/v1/selfies"])
    }

    @Test(
        "Omitted and explicit-null analysis blocks continue polling",
        arguments: IncompleteAnalysisCase.allCases
    )
    func incompleteAnalysisBlocksContinuePolling(incompleteCase: IncompleteAnalysisCase) async throws {
        let imageData = try makeImageData(color: .systemPink)
        let script = LooksTransportScript([
            .json(statusCode: 201, uploadResponse()),
            .json(statusCode: 202, analysisAcknowledgement()),
            .json(statusCode: 200, incompleteSelfieResponse(representation: incompleteCase)),
            .json(statusCode: 200, completeSelfieResponse()),
            .image(imageData)
        ])
        ScriptedLooksURLProtocol.script = script
        defer { ScriptedLooksURLProtocol.reset() }
        let sleeps = SleepRecorder()

        let result = try await makeService(sleeps: sleeps).analyze(photo: makePhoto())

        #expect(result.annotatedImageData == imageData)
        #expect(sleeps.values == [.seconds(3)])
        #expect(script.requests.filter {
            $0.url?.path == "/api/v1/selfies/\(selfieID)"
        }.count == 2)
    }

    @Test("Analysis times out after 40 attempts and 39 polling pauses")
    func analysisPollingTimeoutHasExactAttemptAndSleepCounts() async {
        let pending = LooksStub.json(statusCode: 200, incompleteSelfieResponse())
        let script = LooksTransportScript([
            .json(statusCode: 201, uploadResponse()),
            .json(statusCode: 202, analysisAcknowledgement())
        ] + [LooksStub](repeating: pending, count: 40))
        ScriptedLooksURLProtocol.script = script
        defer { ScriptedLooksURLProtocol.reset() }
        let sleeps = SleepRecorder()

        await #expect(throws: ServiceFailure.transport(
            "Analysis is taking longer than expected. Try again."
        )) {
            try await makeService(sleeps: sleeps).analyze(photo: makePhoto())
        }

        #expect(script.requests.filter {
            $0.url?.path == "/api/v1/selfies/\(selfieID)"
        }.count == 40)
        #expect(sleeps.values == [Duration](repeating: .seconds(3), count: 39))
    }

    @Test("Analysis polling cancellation stops subsequent work")
    func analysisPollingCancellationStopsWork() async {
        let script = LooksTransportScript([
            .json(statusCode: 201, uploadResponse()),
            .json(statusCode: 202, analysisAcknowledgement()),
            .json(statusCode: 200, incompleteSelfieResponse())
        ])
        ScriptedLooksURLProtocol.script = script
        defer { ScriptedLooksURLProtocol.reset() }
        let sleeps = SleepRecorder()
        let service = makeService(
            sleeps: sleeps,
            sleeper: { duration in
                sleeps.record(duration)
                throw CancellationError()
            }
        )

        await #expect(throws: CancellationError.self) {
            try await service.analyze(photo: makePhoto())
        }
        #expect(sleeps.values == [.seconds(3)])
        #expect(script.requests.filter {
            $0.url?.path == "/api/v1/selfies/\(selfieID)"
        }.count == 1)
    }

    @Test("Invalid completed analysis fields fail safely", arguments: InvalidAnalysisCase.allCases)
    func invalidCompletedAnalysisFailsSafely(invalidCase: InvalidAnalysisCase) async {
        let script = LooksTransportScript([
            .json(statusCode: 201, uploadResponse()),
            .json(statusCode: 202, analysisAcknowledgement()),
            .json(statusCode: 200, invalidAnalysisResponse(for: invalidCase))
        ])
        ScriptedLooksURLProtocol.script = script
        defer { ScriptedLooksURLProtocol.reset() }
        let sleeps = SleepRecorder()

        await #expect(throws: unusableResponseFailure) {
            try await makeService(sleeps: sleeps).analyze(photo: makePhoto())
        }

        #expect(script.requests.count == 3)
        #expect(script.requests.contains { $0.url?.path == "/mesh.png" } == false)
        #expect(sleeps.values.isEmpty)
    }

    @Test(
        "An empty search or malformed first-ranked result never skips or creates a generation",
        arguments: InvalidSearchCase.allCases
    )
    func invalidFirstSearchResultStopsGeneration(invalidCase: InvalidSearchCase) async throws {
        let imageData = try makeImageData(color: .systemPink)
        let script = LooksTransportScript([
            .json(statusCode: 201, uploadResponse()),
            .json(statusCode: 202, analysisAcknowledgement()),
            .json(statusCode: 200, completeSelfieResponse()),
            .image(imageData),
            .json(statusCode: 200, invalidTransformationSearchResponse(for: invalidCase))
        ])
        ScriptedLooksURLProtocol.script = script
        defer { ScriptedLooksURLProtocol.reset() }
        let service = makeService()
        let photo = makePhoto()
        let harmony = try await service.analyze(photo: photo)

        await #expect(throws: unusableResponseFailure) {
            try await service.generateLook(photo: photo, result: harmony)
        }

        #expect(script.requests.last?.url?.path == "/api/v1/transformations/search")
        #expect(script.requests.contains { $0.url?.path == "/api/v1/generations" } == false)
        #expect(script.requests.contains { $0.url?.path.contains("users/me") == true } == false)
    }

    @Test(
        "Every continuing generation status polls again",
        arguments: ["PENDING", "SUBMITTING", "AWAITING_RESULT", "PROCESSING"]
    )
    func continuingGenerationStatusesPollAgain(status: String) async throws {
        let meshData = try makeImageData(color: .systemPink)
        let generatedData = try makeImageData(color: .systemBlue)
        let script = LooksTransportScript([
            .json(statusCode: 201, uploadResponse()),
            .json(statusCode: 202, analysisAcknowledgement()),
            .json(statusCode: 200, completeSelfieResponse()),
            .image(meshData),
            .json(statusCode: 200, transformationSearchResponse()),
            .json(statusCode: 201, generationCreatedResponse()),
            .json(statusCode: 200, generationPollingResponse(status: status)),
            .json(statusCode: 200, generationCompletedResponse()),
            .image(generatedData)
        ])
        ScriptedLooksURLProtocol.script = script
        defer { ScriptedLooksURLProtocol.reset() }
        let sleeps = SleepRecorder()
        let service = makeService(sleeps: sleeps)
        let photo = makePhoto()
        let harmony = try await service.analyze(photo: photo)

        let look = try await service.generateLook(photo: photo, result: harmony)

        #expect(look.imageData == generatedData)
        #expect(sleeps.values == [.seconds(3)])
        #expect(script.requests.filter {
            $0.url?.path == "/api/v1/generations/\(generationID)"
        }.count == 2)
    }

    @Test("Generation times out after 40 attempts and 39 polling pauses")
    func generationPollingTimeoutHasExactAttemptAndSleepCounts() async throws {
        let meshData = try makeImageData(color: .systemPink)
        let pending = LooksStub.json(
            statusCode: 200,
            generationPollingResponse(status: "PROCESSING")
        )
        let script = LooksTransportScript([
            .json(statusCode: 201, uploadResponse()),
            .json(statusCode: 202, analysisAcknowledgement()),
            .json(statusCode: 200, completeSelfieResponse()),
            .image(meshData),
            .json(statusCode: 200, transformationSearchResponse()),
            .json(statusCode: 201, generationCreatedResponse())
        ] + [LooksStub](repeating: pending, count: 40))
        ScriptedLooksURLProtocol.script = script
        defer { ScriptedLooksURLProtocol.reset() }
        let sleeps = SleepRecorder()
        let service = makeService(sleeps: sleeps)
        let photo = makePhoto()
        let harmony = try await service.analyze(photo: photo)

        await #expect(throws: ServiceFailure.transport(
            "Your look is taking longer than expected. Try again."
        )) {
            try await service.generateLook(photo: photo, result: harmony)
        }

        #expect(script.requests.filter {
            $0.url?.path == "/api/v1/generations/\(generationID)"
        }.count == 40)
        #expect(sleeps.values == [Duration](repeating: .seconds(3), count: 39))
        #expect(script.requests.filter { $0.url?.path == "/api/v1/generations" }.count == 1)
    }

    @Test(
        "Completed orders require the selected completed item and a secure image URL",
        arguments: InvalidCompletedGenerationCase.allCases
    )
    func invalidCompletedGenerationFailsSafely(invalidCase: InvalidCompletedGenerationCase) async throws {
        let meshData = try makeImageData(color: .systemPink)
        let script = LooksTransportScript([
            .json(statusCode: 201, uploadResponse()),
            .json(statusCode: 202, analysisAcknowledgement()),
            .json(statusCode: 200, completeSelfieResponse()),
            .image(meshData),
            .json(statusCode: 200, transformationSearchResponse()),
            .json(statusCode: 201, generationCreatedResponse()),
            .json(statusCode: 200, invalidCompletedGenerationResponse(for: invalidCase))
        ])
        ScriptedLooksURLProtocol.script = script
        defer { ScriptedLooksURLProtocol.reset() }
        let service = makeService()
        let photo = makePhoto()
        let harmony = try await service.analyze(photo: photo)

        await #expect(throws: unusableResponseFailure) {
            try await service.generateLook(photo: photo, result: harmony)
        }
        #expect(script.requests.contains { $0.url?.path == "/generated.png" } == false)
    }

    @Test(
        "Unknown and malformed generation statuses fail safely",
        arguments: InvalidGenerationStatusCase.allCases
    )
    func invalidGenerationStatusesFailSafely(invalidCase: InvalidGenerationStatusCase) async throws {
        let meshData = try makeImageData(color: .systemPink)
        let script = LooksTransportScript([
            .json(statusCode: 201, uploadResponse()),
            .json(statusCode: 202, analysisAcknowledgement()),
            .json(statusCode: 200, completeSelfieResponse()),
            .image(meshData),
            .json(statusCode: 200, transformationSearchResponse()),
            .json(statusCode: 201, generationCreatedResponse()),
            .json(
                statusCode: 200,
                generationPollingResponse(statusJSON: invalidCase.statusJSON)
            )
        ])
        ScriptedLooksURLProtocol.script = script
        defer { ScriptedLooksURLProtocol.reset() }
        let sleeps = SleepRecorder()
        let service = makeService(sleeps: sleeps)
        let photo = makePhoto()
        let harmony = try await service.analyze(photo: photo)

        await #expect(throws: unusableResponseFailure) {
            try await service.generateLook(photo: photo, result: harmony)
        }

        #expect(sleeps.values.isEmpty)
        #expect(script.requests.filter { $0.url?.path == "/api/v1/generations" }.count == 1)
        #expect(script.requests.filter {
            $0.url?.path == "/api/v1/generations/\(generationID)"
        }.count == 1)
    }

    @Test("Configuration, disclosure, byte, and token gates send no request")
    func failClosedBeforeTransport() async {
        let script = LooksTransportScript([])
        ScriptedLooksURLProtocol.script = script
        defer { ScriptedLooksURLProtocol.reset() }

        let missingBase = makeService(configuration: makeConfiguration(baseURL: nil))
        await #expect(throws: ServiceFailure.configuration(
            "Looks service configuration and facial-data disclosures are incomplete."
        )) {
            try await missingBase.analyze(photo: makePhoto())
        }

        let unapproved = makeService(configuration: makeConfiguration(disclosuresApproved: false))
        await #expect(throws: ServiceFailure.configuration(
            "Looks service configuration and facial-data disclosures are incomplete."
        )) {
            try await unapproved.analyze(photo: makePhoto())
        }

        let oversized = makeService()
        await #expect(throws: ServiceFailure.invalidImage(
            "This photo is too large to upload. Please choose another photo."
        )) {
            try await oversized.analyze(
                photo: makePhoto(uploadData: Data(repeating: 0x01, count: 10_485_761))
            )
        }

        let tokenFailure = LiveLooksService(
            configuration: makeConfiguration(),
            idTokenProvider: { throw TokenProviderError.unavailable },
            protocolClasses: [ScriptedLooksURLProtocol.self],
            sleep: { _ in }
        )
        await #expect(throws: ServiceFailure.authentication(
            "Your session could not be verified. Please sign in again."
        )) {
            try await tokenFailure.analyze(photo: makePhoto())
        }
        #expect(script.requests.isEmpty)
    }

    @Test("Ambiguous upload is nonretryable and is never replayed")
    func ambiguousUploadIsNotReplayed() async {
        let script = LooksTransportScript([.failure(.networkConnectionLost)])
        ScriptedLooksURLProtocol.script = script
        defer { ScriptedLooksURLProtocol.reset() }
        let service = makeService()
        let photo = makePhoto()
        let expected = ServiceFailure.nonRetryable(
            "The photo upload could not be confirmed. Please retake your photo before trying again."
        )
        #expect(expected.isRetryable == false)

        await #expect(throws: expected) {
            try await service.analyze(photo: photo)
        }
        await #expect(throws: expected) {
            try await service.analyze(photo: photo)
        }
        #expect(script.requests.count == 1)
        #expect(script.requests.first?.url?.path == "/api/v1/selfies")
    }

    @Test("Ambiguous analysis trigger polls its known selfie without replay")
    func ambiguousTriggerPollsKnownSelfie() async throws {
        let imageData = try makeImageData(color: .systemPink)
        let script = LooksTransportScript([
            .json(statusCode: 201, uploadResponse()),
            .failure(.networkConnectionLost),
            .json(statusCode: 200, completeSelfieResponse()),
            .image(imageData)
        ])
        ScriptedLooksURLProtocol.script = script
        defer { ScriptedLooksURLProtocol.reset() }
        let service = makeService()

        let result = try await service.analyze(photo: makePhoto())

        #expect(result.annotatedImageData == imageData)
        #expect(script.requests.map(\.url?.path) == [
            "/api/v1/selfies",
            "/api/v1/selfies/\(selfieID)/analysis",
            "/api/v1/selfies/\(selfieID)",
            "/mesh.png"
        ])
    }

    @Test("Retry resumes polling a known selfie without upload or trigger replay")
    func retryResumesKnownSelfie() async throws {
        let imageData = try makeImageData(color: .systemPink)
        let script = LooksTransportScript([
            .json(statusCode: 201, uploadResponse()),
            .json(statusCode: 202, analysisAcknowledgement()),
            .failure(.networkConnectionLost),
            .json(statusCode: 200, completeSelfieResponse()),
            .image(imageData)
        ])
        ScriptedLooksURLProtocol.script = script
        defer { ScriptedLooksURLProtocol.reset() }
        let service = makeService()
        let photo = makePhoto()

        await #expect(throws: ServiceFailure.transport(
            "The Looks service is unavailable. Try again."
        )) {
            try await service.analyze(photo: photo)
        }
        #expect(try await service.analyze(photo: photo).annotatedImageData == imageData)
        #expect(script.requests.filter { $0.httpMethod == "POST" }.count == 2)
        #expect(script.requests.filter { $0.url?.path == "/api/v1/selfies" }.count == 1)
        #expect(script.requests.filter {
            $0.url?.path == "/api/v1/selfies/\(selfieID)/analysis"
        }.count == 1)
    }

    @Test("Annotated-image retry reuses completed analysis without another API request")
    func meshRetryResumesCompletedAnalysis() async throws {
        let imageData = try makeImageData(color: .systemPink)
        let script = LooksTransportScript([
            .json(statusCode: 201, uploadResponse()),
            .json(statusCode: 202, analysisAcknowledgement()),
            .json(statusCode: 200, completeSelfieResponse()),
            .response(
                statusCode: 503,
                headers: ["Content-Type": "image/png"],
                data: Data(),
                finalURL: nil
            ),
            .image(imageData)
        ])
        ScriptedLooksURLProtocol.script = script
        defer { ScriptedLooksURLProtocol.reset() }
        let service = makeService()
        let photo = makePhoto()

        await #expect(throws: ServiceFailure.transport(
            "The generated image is unavailable. Try again."
        )) {
            try await service.analyze(photo: photo)
        }
        #expect(try await service.analyze(photo: photo).annotatedImageData == imageData)

        #expect(script.requests.filter { $0.url?.path.hasPrefix("/api/v1/") == true }.count == 3)
        #expect(script.requests.filter { $0.url?.path == "/mesh.png" }.count == 2)
    }

    @Test("Ambiguous generation creation is nonretryable and never charges twice")
    func ambiguousGenerationIsNotReplayed() async throws {
        let imageData = try makeImageData(color: .systemPink)
        let script = LooksTransportScript([
            .json(statusCode: 201, uploadResponse()),
            .json(statusCode: 202, analysisAcknowledgement()),
            .json(statusCode: 200, completeSelfieResponse()),
            .image(imageData),
            .json(statusCode: 200, transformationSearchResponse()),
            .failure(.networkConnectionLost)
        ])
        ScriptedLooksURLProtocol.script = script
        defer { ScriptedLooksURLProtocol.reset() }
        let service = makeService()
        let photo = makePhoto()
        let harmony = try await service.analyze(photo: photo)
        let expected = ServiceFailure.nonRetryable(
            "The look request could not be confirmed and will not be retried to avoid another charge."
        )
        #expect(expected.isRetryable == false)

        await #expect(throws: expected) {
            try await service.generateLook(photo: photo, result: harmony)
        }
        await #expect(throws: expected) {
            try await service.generateLook(photo: photo, result: harmony)
        }
        #expect(script.requests.filter {
            $0.httpMethod == "POST" && $0.url?.path == "/api/v1/generations"
        }.count == 1)
        #expect(script.requests.contains { $0.url?.path.contains("users/me") == true } == false)
    }

    @Test("Generated-image retry resumes a known order without another charge")
    func imageRetryResumesKnownGeneration() async throws {
        let meshData = try makeImageData(color: .systemPink)
        let generatedData = try makeImageData(color: .systemBlue)
        let script = LooksTransportScript([
            .json(statusCode: 201, uploadResponse()),
            .json(statusCode: 202, analysisAcknowledgement()),
            .json(statusCode: 200, completeSelfieResponse()),
            .image(meshData),
            .json(statusCode: 200, transformationSearchResponse()),
            .json(statusCode: 201, generationCreatedResponse()),
            .json(statusCode: 200, generationCompletedResponse()),
            .response(
                statusCode: 503,
                headers: ["Content-Type": "image/png"],
                data: Data(),
                finalURL: nil
            ),
            .image(generatedData)
        ])
        ScriptedLooksURLProtocol.script = script
        defer { ScriptedLooksURLProtocol.reset() }
        let service = makeService()
        let photo = makePhoto()
        let harmony = try await service.analyze(photo: photo)

        await #expect(throws: ServiceFailure.transport(
            "The generated image is unavailable. Try again."
        )) {
            try await service.generateLook(photo: photo, result: harmony)
        }
        let look = try await service.generateLook(photo: photo, result: harmony)

        #expect(look.imageData == generatedData)
        #expect(script.requests.filter {
            $0.httpMethod == "POST" && $0.url?.path == "/api/v1/generations"
        }.count == 1)
        #expect(script.requests.filter {
            $0.url?.path == "/api/v1/generations/\(generationID)"
        }.count == 1)
        #expect(script.requests.filter { $0.url?.path == "/generated.png" }.count == 2)
    }

    @Test(
        "Terminal generation failures are nonretryable and raw backend details stay private",
        arguments: ["FAILED", "PARTIALLY_COMPLETED"]
    )
    func terminalGenerationFailureIsSafe(status: String) async throws {
        let imageData = try makeImageData(color: .systemPink)
        let script = LooksTransportScript([
            .json(statusCode: 201, uploadResponse()),
            .json(statusCode: 202, analysisAcknowledgement()),
            .json(statusCode: 200, completeSelfieResponse()),
            .image(imageData),
            .json(statusCode: 200, transformationSearchResponse()),
            .json(statusCode: 201, generationCreatedResponse()),
            .json(statusCode: 200, generationFailedResponse(status: status)),
            .json(statusCode: 200, generationFailedResponse(status: status))
        ])
        ScriptedLooksURLProtocol.script = script
        defer { ScriptedLooksURLProtocol.reset() }
        let service = makeService()
        let photo = makePhoto()
        let harmony = try await service.analyze(photo: photo)
        let expected = ServiceFailure.nonRetryable(
            "This look could not be generated. Please continue without it."
        )
        #expect(expected.isRetryable == false)

        await #expect(throws: expected) {
            try await service.generateLook(photo: photo, result: harmony)
        }
        await #expect(throws: expected) {
            try await service.generateLook(photo: photo, result: harmony)
        }
        #expect(expected.errorDescription?.contains("secret backend failure") == false)
        #expect(script.requests.filter { $0.url?.path == "/api/v1/generations" }.count == 1)
        #expect(script.requests.filter {
            $0.url?.path == "/api/v1/generations/\(generationID)"
        }.count == 2)
    }

    @Test("Problem details are replaced with safe user feedback")
    func problemDetailsAreNotExposed() async {
        let secret = "raw-secret-problem-detail"
        let script = LooksTransportScript([
            .json(statusCode: 400, """
                {"type":null,"title":"Bad request","status":400,"detail":"\(secret)","instance":null,"properties":null}
                """)
        ])
        ScriptedLooksURLProtocol.script = script
        defer { ScriptedLooksURLProtocol.reset() }

        do {
            _ = try await makeService().analyze(photo: makePhoto())
            Issue.record("Expected upload rejection")
        } catch let failure as ServiceFailure {
            #expect(failure == .transport("The Looks service could not complete the request. Try again."))
            #expect(failure.errorDescription?.contains(secret) == false)
        } catch {
            Issue.record("Expected ServiceFailure, received \(error)")
        }
    }

    private func makeService(
        configuration: AppConfiguration? = nil,
        tokens: LockedCounter = LockedCounter(),
        sleeps: SleepRecorder = SleepRecorder(),
        sleeper: (@Sendable (Duration) async throws -> Void)? = nil
    ) -> LiveLooksService {
        LiveLooksService(
            configuration: configuration ?? makeConfiguration(),
            idTokenProvider: {
                "firebase-token-\(tokens.increment())"
            },
            protocolClasses: [ScriptedLooksURLProtocol.self],
            sleep: sleeper ?? { duration in sleeps.record(duration) }
        )
    }

    private func makeConfiguration(
        baseURL: URL? = URL(string: "https://api.example.com"),
        disclosuresApproved: Bool = true
    ) -> AppConfiguration {
        AppConfiguration(
            mode: .live,
            googleClientID: "google-client",
            revenueCatAPIKey: "revenuecat-key",
            revenueCatEntitlementID: "pro",
            looksAPIBaseURL: baseURL,
            termsURL: URL(string: "https://example.com/terms"),
            privacyURL: URL(string: "https://example.com/privacy"),
            facialDataDisclosuresApproved: disclosuresApproved
        )
    }

    private func makePhoto(uploadData: Data = Data("jpeg".utf8)) -> PreparedPhoto {
        PreparedPhoto(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            displayData: Data([0x01]),
            uploadData: uploadData,
            pixelWidth: 2,
            pixelHeight: 2
        )
    }

    private func makeImageData(color: UIColor) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2), format: format)
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        return try #require(image.pngData())
    }

    private func uploadResponse(id: String? = nil) -> String {
        let id = id ?? selfieID
        return """
        {"id":"\(id)","userId":null,"url":null,"createdAt":null,"deepface":null,"symmetry":null,"shape":null,"mesh":null,"ratio":null}
        """
    }

    private func analysisAcknowledgement() -> String {
        """
        {"selfieId":"\(acknowledgedSelfieID)"}
        """
    }

    private func incompleteSelfieResponse(
        id: String? = nil,
        representation: IncompleteAnalysisCase = .explicitNull
    ) -> String {
        let id = id ?? selfieID
        switch representation {
        case .omitted:
            return """
            {"id":"\(id)"}
            """
        case .explicitNull:
            return """
            {"id":"\(id)","userId":null,"url":null,"createdAt":null,"deepface":null,"symmetry":null,"shape":null,"mesh":null,"ratio":null}
            """
        }
    }

    private func completeSelfieResponse(
        id: String? = nil,
        faceShape: String = " Oval ",
        harmonyScoreJSON: String = "87.25",
        meshURL: String = "https://images.example.com/mesh.png"
    ) -> String {
        let id = id ?? selfieID
        return """
        {
          "id":"\(id)","userId":null,"url":null,"createdAt":null,
          "deepface":{},
          "symmetry":{"overallScore":\(harmonyScoreJSON),"regionScores":null},
          "shape":{"primaryShape":"\(faceShape)","hairlineMethod":null,"measurements":null,"ratios":null,"shapeScores":null},
          "mesh":{"imageUrl":"\(meshURL)","imageWidth":null,"imageHeight":null},
          "ratio":{"phi":null,"facialRatios":null}
        }
        """
    }

    private func invalidAnalysisResponse(for invalidCase: InvalidAnalysisCase) -> String {
        switch invalidCase {
        case .blankShape:
            completeSelfieResponse(faceShape: "   ")
        case .nonfiniteScore:
            completeSelfieResponse(harmonyScoreJSON: "1e400")
        case .scoreBelowRange:
            completeSelfieResponse(harmonyScoreJSON: "-0.01")
        case .scoreAboveRange:
            completeSelfieResponse(harmonyScoreJSON: "100.01")
        case .insecureMeshURL:
            completeSelfieResponse(meshURL: "http://images.example.com/mesh.png")
        }
    }

    private func transformationSearchResponse() -> String {
        "[\(transformationEntry(id: transformationID))]"
    }

    private func invalidTransformationSearchResponse(for invalidCase: InvalidSearchCase) -> String {
        var id = transformationID
        var creditPrice = 1
        var category = "HAIRSTYLE"
        var displayName = " Textured Crop "
        var description = " Static style guidance. "

        switch invalidCase {
        case .empty:
            return "[]"
        case .wrongCategory:
            category = "BEARD"
        case .wrongCredit:
            creditPrice = 2
        case .blankDisplayName:
            displayName = "   "
        case .blankDescription:
            description = "   "
        case .invalidID:
            id = "not-a-decimal-id"
        }

        let first = transformationEntry(
            id: id,
            creditPrice: creditPrice,
            category: category,
            displayName: displayName,
            description: description
        )
        let validSecond = transformationEntry(
            id: otherTransformationID,
            displayName: " Valid second result ",
            description: " Must not be selected. "
        )
        return "[\(first),\(validSecond)]"
    }

    private func transformationEntry(
        id: String,
        creditPrice: Int = 1,
        category: String = "HAIRSTYLE",
        displayName: String = " Textured Crop ",
        description: String = " Static style guidance. "
    ) -> String {
        """
        {
          "id":"\(id)","referenceImageUrl":null,"creditPrice":\(creditPrice),
          "genders":null,"races":null,"category":"\(category)",
          "displayName":"\(displayName)","description":"\(description)",
          "personalizedReason":"ignore this personalized copy"
        }
        """
    }

    private func generationCreatedResponse() -> String {
        """
        {"id":"\(generationID)","selfieId":"\(selfieID)","status":"PENDING","creditsCharged":1,"items":null,"createdAt":null}
        """
    }

    private func generationPendingResponse() -> String {
        generationPollingResponse(status: "awaiting_result")
    }

    private func generationPollingResponse(status: String) -> String {
        generationPollingResponse(statusJSON: "\"\(status)\"")
    }

    private func generationPollingResponse(statusJSON: String) -> String {
        """
        {"id":"\(generationID)","selfieId":"\(selfieID)","status":\(statusJSON),"creditsCharged":1,"items":null,"createdAt":null}
        """
    }

    private func generationCompletedResponse() -> String {
        """
        {
          "id":"\(generationID)","selfieId":"\(selfieID)","status":"completed","creditsCharged":1,"createdAt":null,
          "items":[
            {"id":"11","transformationId":"\(otherTransformationID)","status":"COMPLETED","aiProvider":null,"resultImageUrl":"https://images.example.com/wrong.png","errorMessage":null,"completedAt":null},
            {"id":"12","transformationId":"\(transformationID)","status":"completed","aiProvider":null,"resultImageUrl":"https://images.example.com/generated.png","errorMessage":null,"completedAt":null}
          ]
        }
        """
    }

    private func invalidCompletedGenerationResponse(
        for invalidCase: InvalidCompletedGenerationCase
    ) -> String {
        let item: String
        switch invalidCase {
        case .missingSelectedItem:
            item = """
            {"id":"11","transformationId":"\(otherTransformationID)","status":"COMPLETED","resultImageUrl":"https://images.example.com/wrong.png"}
            """
        case .selectedItemIncomplete:
            item = """
            {"id":"12","transformationId":"\(transformationID)","status":"PROCESSING","resultImageUrl":"https://images.example.com/generated.png"}
            """
        case .insecureImageURL:
            item = """
            {"id":"12","transformationId":"\(transformationID)","status":"COMPLETED","resultImageUrl":"http://images.example.com/generated.png"}
            """
        }
        return """
        {"id":"\(generationID)","selfieId":"\(selfieID)","status":"COMPLETED","items":[\(item)]}
        """
    }

    private func generationFailedResponse(status: String) -> String {
        """
        {
          "id":"\(generationID)","selfieId":"\(selfieID)","status":"\(status)","creditsCharged":1,"createdAt":null,
          "items":[{"id":"12","transformationId":"\(transformationID)","status":"FAILED","aiProvider":null,"resultImageUrl":null,"errorMessage":"secret backend failure","completedAt":null}]
        }
        """
    }
}

nonisolated enum InvalidUploadIDCase: String, CaseIterable, Sendable {
    case malformed = ""
    case zero = "0"
    case nondecimal = "12x"
}

nonisolated enum IncompleteAnalysisCase: CaseIterable, Sendable {
    case omitted
    case explicitNull
}

nonisolated enum InvalidAnalysisCase: CaseIterable, Sendable {
    case blankShape
    case nonfiniteScore
    case scoreBelowRange
    case scoreAboveRange
    case insecureMeshURL
}

nonisolated enum InvalidSearchCase: CaseIterable, Sendable {
    case empty
    case wrongCategory
    case wrongCredit
    case blankDisplayName
    case blankDescription
    case invalidID
}

nonisolated enum InvalidGenerationStatusCase: CaseIterable, Sendable {
    case unknown
    case malformed
    case null

    var statusJSON: String {
        switch self {
        case .unknown: "\"UNRECOGNIZED\""
        case .malformed: "17"
        case .null: "null"
        }
    }
}

nonisolated enum InvalidCompletedGenerationCase: CaseIterable, Sendable {
    case missingSelectedItem
    case selectedItemIncomplete
    case insecureImageURL
}

nonisolated private struct CapturedGenerationRequest: Decodable {
    let selfieId: Int64
    let transformationIds: [Int64]
}

nonisolated private enum TokenProviderError: Error {
    case unavailable
}

nonisolated private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var value: Int {
        lock.withLock { storage }
    }

    @discardableResult
    func increment() -> Int {
        lock.withLock {
            storage += 1
            return storage
        }
    }
}

nonisolated private final class SleepRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Duration] = []

    var values: [Duration] {
        lock.withLock { storage }
    }

    func record(_ duration: Duration) {
        lock.withLock { storage.append(duration) }
    }
}

nonisolated private enum LooksStub: Sendable {
    case response(statusCode: Int, headers: [String: String], data: Data, finalURL: URL?)
    case failure(URLError.Code)

    static func json(statusCode: Int, _ body: String) -> LooksStub {
        .response(
            statusCode: statusCode,
            headers: ["Content-Type": "application/json"],
            data: Data(body.utf8),
            finalURL: nil
        )
    }

    static func image(_ data: Data) -> LooksStub {
        .response(
            statusCode: 200,
            headers: ["Content-Type": "image/png"],
            data: data,
            finalURL: nil
        )
    }
}

nonisolated private final class LooksTransportScript: @unchecked Sendable {
    private let lock = NSLock()
    private var stubs: [LooksStub]
    private var recordedRequests: [URLRequest] = []

    init(_ stubs: [LooksStub]) {
        self.stubs = stubs
    }

    var requests: [URLRequest] {
        lock.withLock { recordedRequests }
    }

    func next(for request: URLRequest) throws -> LooksStub {
        try lock.withLock {
            recordedRequests.append(request)
            guard stubs.isEmpty == false else { throw URLError(.badServerResponse) }
            return stubs.removeFirst()
        }
    }
}

nonisolated private final class ScriptedLooksURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var script: LooksTransportScript?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let script = Self.script else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            switch try script.next(for: requestWithCapturedBody(request)) {
            case .failure(let code):
                client?.urlProtocol(self, didFailWithError: URLError(code))
            case .response(let statusCode, let headers, let data, let finalURL):
                guard
                    let responseURL = finalURL ?? request.url,
                    let response = HTTPURLResponse(
                        url: responseURL,
                        statusCode: statusCode,
                        httpVersion: "HTTP/1.1",
                        headerFields: headers
                    )
                else {
                    client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                    return
                }
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            }
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func reset() {
        script = nil
    }

    private func requestWithCapturedBody(_ request: URLRequest) -> URLRequest {
        guard request.httpBody == nil, let stream = request.httpBodyStream else { return request }
        stream.open()
        defer { stream.close() }

        var body = Data()
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            body.append(buffer, count: count)
        }

        var capturedRequest = request
        capturedRequest.httpBodyStream = nil
        capturedRequest.httpBody = body
        return capturedRequest
    }
}
