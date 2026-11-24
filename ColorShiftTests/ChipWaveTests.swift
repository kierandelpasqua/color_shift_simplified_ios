import Testing
@testable import ColorShift

/// The wave's keyframes (web `@keyframes chip-wave`, PM §12 M3), on a 100pt chip.
struct ChipWaveTests {
    @Test func startsHiddenLeftOfTheChip() {
        let s = ChipWave.state(at: 0, width: 100)
        #expect(s.x == -36 && s.opacity == 0)
    }

    @Test func isFullyVisibleFromFadeInToHold() {
        #expect(ChipWave.state(at: 0.028, width: 100).opacity == 1)
        #expect(ChipWave.state(at: 0.10, width: 100).opacity == 1)
        #expect(ChipWave.state(at: 0.149, width: 100).opacity == 1)
    }

    @Test func endsAtTheTrailingEdgeAndRestsInvisible() {
        let end = ChipWave.state(at: 0.19, width: 100)
        #expect(end.x == 100 && end.opacity == 0)
        let rest = ChipWave.state(at: 0.6, width: 100)
        #expect(rest.x == 100 && rest.opacity == 0)
    }

    @Test func sweepIsEasedAndMonotonic() {
        let xs = stride(from: 0.0, through: 0.19, by: 0.01).map { ChipWave.state(at: $0, width: 100).x }
        #expect(zip(xs, xs.dropFirst()).allSatisfy { $0 <= $1 })
        // Ease-in-out: the midpoint of the sweep is at the midpoint of the distance.
        #expect(abs(ChipWave.state(at: 0.095, width: 100).x - 32) < 0.5)
    }
}
