import Foundation
import Translation
import SwiftUI
import Synchronization

@MainActor
@available(iOS 18.0, *)
final class TranslationBridge: ObservableObject {
    struct Job {
        let text: String
        let configuration: TranslationSession.Configuration
        let continuation: CheckedContinuation<String?, Error>
    }

    // “Kick” signal to (re)start .translationTask with a specific language pair
    @Published fileprivate var activeJob: Job? = nil

    func translate(_ text: String,
                   source: Locale.Language? = nil,
                   target: Locale.Language? = nil) async throws -> String?
    {
        var nextConfig = TranslationSession.Configuration(source: source, target: target)
        if var oldConfig = activeJob?.configuration, oldConfig == nextConfig {
            oldConfig.invalidate()
            nextConfig = oldConfig
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            activeJob = Job(text: text, configuration: nextConfig, continuation: continuation)
        }
    }
}

@available(iOS 18.0, *)
struct TranslationTaskHost: View {
    @ObservedObject var bridge: TranslationBridge

    var body: some View {
        let job = bridge.activeJob
        Color.clear
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
            .opacity(0.01)

            .translationTask(job?.configuration) { session in
                guard let job else {
                    return
                }
                do {
                    let response = try await session.translate(job.text)
                    job.continuation.resume(returning: response.targetText)
                } catch {
                    job.continuation.resume(throwing: error)
                }
            }
    }
}

protocol TranslationHelper: Actor {
    @available(iOS 16.0, *)
    func translate(
        text: String,
        source: Locale.Language,
        target: Locale.Language
    ) async -> Result<String?, Error>
}

actor DummyTranslationHelper : TranslationHelper {
    @available(iOS 16.0, *)
    func translate(
        text: String,
        source: Locale.Language,
        target: Locale.Language
    ) async -> Result<String?, Error> {
        return .success(nil)
    }
}

@available(iOS 18.0, *)
actor RealTranslationHelper : TranslationHelper {
    let bridgeMutex: AsyncMutex<TranslationBridge>
    init(bridge: TranslationBridge) {
        self.bridgeMutex = AsyncMutex(bridge)
    }

    func translate(
        text: String,
        source: Locale.Language,
        target: Locale.Language
    ) async -> Result<String?, Error> {
        return await self.bridgeMutex.withResource { bridge in
            do {
                let result = try await bridge.translate(text, source: source, target: target)
                return .success(result)
            } catch {
                return .failure(error)
            }
        }
    }
}
