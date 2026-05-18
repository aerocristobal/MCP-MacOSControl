import Foundation

/// STORY-009 — terminal outcome of a poll run. `last` is the probe result from
/// the final cycle, so the tool can surface fresh state in both the success
/// payload and the `state_condition_not_met` error.
public enum PollOutcome {
    case satisfied(last: ElementProbeResult, elapsed: TimeInterval, polls: Int)
    case timedOut(last: ElementProbeResult, elapsed: TimeInterval, polls: Int)
}

/// Fixed-cadence poll loop. One in-flight probe per cycle (the `await` is
/// sequential — no concurrent over-fetching). Halts the instant the predicate
/// is satisfied; the remaining timeout budget is not consumed and no trailing
/// sleep is issued, so the matched state is captured at the moment of match.
public final class ElementStatePollLoop {

    public init() {}

    public func poll(
        predicate: ConditionPredicate,
        probe: ElementStateProbe,
        timeout: TimeInterval,
        pollIntervalMs: Int,
        clock: Clock
    ) async -> PollOutcome {
        let start = clock.now()
        var polls = 0

        while true {
            let result = await probe.probe()
            polls += 1

            if predicate.evaluate(result) {
                let elapsed = clock.now().timeIntervalSince(start)
                return .satisfied(last: result, elapsed: elapsed, polls: polls)
            }

            let elapsed = clock.now().timeIntervalSince(start)
            if elapsed >= timeout {
                return .timedOut(last: result, elapsed: elapsed, polls: polls)
            }

            await clock.sleep(forMilliseconds: pollIntervalMs)
        }
    }
}
