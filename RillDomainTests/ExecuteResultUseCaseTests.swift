import Foundation
import Testing

@testable import RillDomain

@Suite("ExecuteResultUseCase")
struct ExecuteResultUseCaseTests {
    @Test func `executes the primary action and records the use`() async throws {
        let performer = RecordingPerformer()
        let usage = RecordingUsageStore()
        let now = Date(timeIntervalSince1970: 1_000)
        let useCase = ExecuteResultUseCase(
            performer: performer,
            usage: usage,
            clock: FixedClock(now: now)
        )
        let url = URL(fileURLWithPath: "/Applications/Safari.app")
        let result = SearchResult.fixture(
            title: "Safari",
            section: .applications,
            kind: .application,
            action: .openFile(url)
        )

        try await useCase(result)

        #expect(await performer.performed == [.openFile(url)])
        #expect(await usage.recorded == [result.id])
    }

    @Test func `a failed action records nothing`() async {
        let usage = RecordingUsageStore()
        let useCase = ExecuteResultUseCase(
            performer: FailingPerformer(),
            usage: usage,
            clock: FixedClock(now: Date(timeIntervalSince1970: 0))
        )

        await #expect(throws: ActionTestError.self) {
            try await useCase(.fixture(title: "Safari"))
        }
        #expect(await usage.recorded.isEmpty)
    }
}

private struct ActionTestError: Error {}

private actor RecordingPerformer: ActionPerforming {
    private(set) var performed: [ActionDescriptor] = []

    func perform(_ action: ActionDescriptor) async throws {
        performed.append(action)
    }
}

private struct FailingPerformer: ActionPerforming {
    func perform(_ action: ActionDescriptor) async throws {
        throw ActionTestError()
    }
}

private actor RecordingUsageStore: UsageStoring {
    private(set) var recorded: [SearchResult.ID] = []

    func snapshot() async -> UsageSnapshot {
        .empty
    }

    func record(_ id: SearchResult.ID, at date: Date) async {
        recorded.append(id)
    }
}

private struct FixedClock: RillDomain.Clock {
    let now: Date
}
