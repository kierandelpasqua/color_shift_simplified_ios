import Testing
@testable import ColorShift

struct SliderMathTests {
    @Test func mapsEndsAndMiddle() {
        #expect(SliderMath.value(at: 0, maximum: 360, width: 200) == 0)
        #expect(SliderMath.value(at: 200, maximum: 360, width: 200) == 360)
        #expect(SliderMath.value(at: 100, maximum: 100, width: 200) == 50)
    }

    @Test func clampsOutsideTheTrack() {
        #expect(SliderMath.value(at: -40, maximum: 100, width: 200) == 0)
        #expect(SliderMath.value(at: 400, maximum: 100, width: 200) == 100)
    }

    @Test func stepsAreIntegersAndRoundTrip() {
        for v in 0...100 {
            let x = SliderMath.x(for: v, maximum: 100, width: 317)
            #expect(SliderMath.value(at: x, maximum: 100, width: 317) == v)
        }
    }
}
