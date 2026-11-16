import Testing
@testable import Masebha

struct TimerDelayTests {
    @Test func storedValuesBelowTheMinimumMeanOneSecond() {
        #expect(TimerDelay.sanitized(0) == 1000)
        #expect(TimerDelay.sanitized(99) == 1000)
        #expect(TimerDelay.sanitized(100) == 100)
        #expect(TimerDelay.sanitized(2500) == 2500)
    }

    @Test func manualButtonsFollowTheAndroidRules() {
        #expect(TimerDelay.plusSecond(1000) == 2000)
        #expect(TimerDelay.minusSecond(2000) == 1000)
        #expect(TimerDelay.minusSecond(1000) == 1000)   // would reach 0: ignored
        #expect(TimerDelay.minusSecond(500) == 500)
        #expect(TimerDelay.plusTenth(100) == 200)
        #expect(TimerDelay.minusTenth(200) == 100)
        #expect(TimerDelay.minusTenth(100) == 100)      // minimum 0.1 s
    }

    @Test func autoModeAveragesThreeIntervals() {
        #expect(TimerDelay.averageInterval(tapTimes: [0, 0.5, 1.1]) == nil)   // needs 4 taps
        #expect(TimerDelay.averageInterval(tapTimes: [10.0, 10.6, 11.2, 11.8]) == 600)
        #expect(TimerDelay.averageInterval(tapTimes: [0, 0.01, 0.02, 0.03]) == 100)   // minimum
    }

    @Test func displayHasOneDecimalAndAsciiDigits() {
        #expect(TimerDelay.display(1000) == "1.0")
        #expect(TimerDelay.display(400) == "0.4")
        #expect(TimerDelay.display(12345) == "12.3")
    }

    @Test func fixedRateKeepsThePace() {
        // On time: the next tick is planned from the previous plan, not from "now".
        #expect(FixedRate.nextTick(afterPlanned: 10.0, interval: 1.0, now: 10.2) == 11.0)
        // A whole interval behind: restart from now instead of a burst of missed ticks.
        #expect(FixedRate.nextTick(afterPlanned: 10.0, interval: 1.0, now: 12.5) == 13.5)
        #expect(FixedRate.nextTick(afterPlanned: 10.0, interval: 1.0, now: 11.0) == 12.0)
    }
}

struct DhikrFormTests {
    @Test func validAdd() {
        let result = DhikrForm.validate(name: "  سبحان الله \n", loopSize: "33", total: "", isEdit: false)
        #expect(result == .success(.init(name: "سبحان الله", loopSize: 33, total: 0)))
    }

    @Test func previousCountIsOptionalWhenAdding() {
        #expect(DhikrForm.validate(name: "A", loopSize: "1", total: "250", isEdit: false)
                == .success(.init(name: "A", loopSize: 1, total: 250)))
    }

    @Test func totalIsRequiredWhenEditing() {
        #expect(DhikrForm.validate(name: "A", loopSize: "33", total: "", isEdit: true) == .failure(.missingFields))
    }

    @Test func missingFields() {
        #expect(DhikrForm.validate(name: "   ", loopSize: "33", total: "", isEdit: false) == .failure(.missingFields))
        #expect(DhikrForm.validate(name: "A", loopSize: "", total: "", isEdit: false) == .failure(.missingFields))
        #expect(DhikrForm.validate(name: "A", loopSize: "3x", total: "", isEdit: false) == .failure(.missingFields))
    }

    @Test func zeroBeadsIsRefused() {
        #expect(DhikrForm.validate(name: "A", loopSize: "0", total: "", isEdit: false) == .failure(.zeroLoop))
        #expect(DhikrForm.validate(name: "A", loopSize: "00000", total: "", isEdit: false) == .failure(.zeroLoop))
    }

    @Test func lengthLimits() {
        #expect(DhikrForm.validate(name: "A", loopSize: "123456", total: "", isEdit: false) == .failure(.missingFields))
        #expect(DhikrForm.validate(name: "A", loopSize: "99999", total: "9999999", isEdit: false)
                == .success(.init(name: "A", loopSize: 99999, total: 9_999_999)))
    }

    @Test func inputFilterKeepsDigitsAndConvertsArabicIndic() {
        #expect(DhikrForm.digitsOnly("1a2 3", maxDigits: 5) == "123")
        #expect(DhikrForm.digitsOnly("٣٣", maxDigits: 5) == "33")
        #expect(DhikrForm.digitsOnly("۱۰۰", maxDigits: 5) == "100")   // Persian digits
        #expect(DhikrForm.digitsOnly("1234567", maxDigits: 5) == "12345")
        #expect(DhikrForm.digitsOnly("-5", maxDigits: 5) == "5")
    }
}
