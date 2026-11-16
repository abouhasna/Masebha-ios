import Testing
@testable import Masebha

/// The counting rules of the counter screen, checked against the Android behavior.
struct CounterStateTests {
    @Test func opensAtZeroWithoutResumeLoop() {
        let state = CounterState.opening(total: 50, loopSize: 33, today: 7, resumeLoop: false)
        #expect(state.total == 50)
        #expect(state.current == 0)
        #expect(state.session == 0)
        #expect(state.loops == 0)
        #expect(state.today == 7)
    }

    @Test func resumeLoopContinuesTheUnfinishedLoop() {
        // Android D1: total 50, loop 33 -> opens at 17, session 17.
        let state = CounterState.opening(total: 50, loopSize: 33, today: 0, resumeLoop: true)
        #expect(state.current == 17)
        #expect(state.session == 17)
    }

    @Test func resumeLoopExampleFromTheAndroidDocs() {
        // "Three taps and reset session give total 33."
        var state = CounterState.opening(total: 50, loopSize: 33, today: 0, resumeLoop: true)
        for _ in 0..<3 { _ = state.tap() }
        #expect(state.total == 53)
        let removed = state.resetSession()
        #expect(removed == 20)
        #expect(state.total == 33)
    }

    @Test func tapCountsAndWrapsTheLoop() {
        var state = CounterState.opening(total: 0, loopSize: 3, today: 0, resumeLoop: false)
        #expect(state.tap() == false)
        #expect(state.tap() == false)
        #expect(state.tap() == true)   // third tap completes the loop
        #expect(state.current == 0)
        #expect(state.loops == 1)
        #expect(state.total == 3)
        #expect(state.session == 3)
        #expect(state.today == 3)
    }

    @Test func loopOfOneCompletesOnEveryTap() {
        var state = CounterState.opening(total: 10, loopSize: 1, today: 0, resumeLoop: true)
        #expect(state.current == 0)
        #expect(state.tap() == true)
        #expect(state.tap() == true)
        #expect(state.loops == 2)
        #expect(state.total == 12)
    }

    @Test func thirtyFiveTapsOnALoopOf33() {
        var state = CounterState.opening(total: 0, loopSize: 33, today: 0, resumeLoop: false)
        var completed = 0
        for _ in 0..<35 {
            if state.tap() { completed += 1 }
        }
        #expect(completed == 1)
        #expect(state.current == 2)
        #expect(state.loops == 1)
        #expect(state.total == 35)
        #expect(state.session == 35)
    }

    @Test func undoWithNothingToUndoChangesNothing() {
        var state = CounterState.opening(total: 40, loopSize: 33, today: 2, resumeLoop: false)
        let before = state
        #expect(state.undo() == nil)
        #expect(state == before)
    }

    @Test func undoStepsBackOneCount() {
        var state = CounterState.opening(total: 0, loopSize: 33, today: 0, resumeLoop: false)
        _ = state.tap()
        _ = state.tap()
        #expect(state.undo() == -1)
        #expect(state.current == 1)
        #expect(state.total == 1)
        #expect(state.session == 1)
        #expect(state.today == 1)
    }

    @Test func undoRollsBackACompletedLoop() {
        var state = CounterState.opening(total: 0, loopSize: 3, today: 0, resumeLoop: false)
        for _ in 0..<3 { _ = state.tap() }
        #expect(state.current == 0 && state.loops == 1)
        #expect(state.undo() == -1)
        #expect(state.loops == 0)
        #expect(state.current == 2)
        #expect(state.total == 2)
    }

    @Test func undoCanRemoveTheResumedTaps() {
        // With resume loop the session includes the taps from before (by design).
        var state = CounterState.opening(total: 5, loopSize: 33, today: 0, resumeLoop: true)
        for _ in 0..<5 { #expect(state.undo() == -1) }
        #expect(state.total == 0)
        #expect(state.undo() == nil)
    }

    @Test func todayNeverGoesNegative() {
        var state = CounterState.opening(total: 10, loopSize: 33, today: 0, resumeLoop: true)
        _ = state.undo()
        #expect(state.today == 0)
        _ = state.resetSession()
        #expect(state.today == 0)
    }

    @Test func resetSessionRemovesOnlyThisVisit() {
        var state = CounterState.opening(total: 100, loopSize: 33, today: 4, resumeLoop: false)
        for _ in 0..<40 { _ = state.tap() }
        #expect(state.resetSession() == 40)
        #expect(state.total == 100)
        #expect(state.today == 4)
        #expect(state.current == 0 && state.loops == 0 && state.session == 0)
    }

    @Test func resetAllClearsEverything() {
        var state = CounterState.opening(total: 100, loopSize: 33, today: 4, resumeLoop: false)
        _ = state.tap()
        state.resetAll()
        #expect(state.total == 0 && state.today == 0 && state.session == 0 && state.current == 0 && state.loops == 0)
    }

    @Test func invariantHoldsThroughAMixOfActions() {
        var state = CounterState.opening(total: 1000, loopSize: 7, today: 0, resumeLoop: true)
        let actions = [0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
        for action in actions {
            if action == 0 { _ = state.tap() } else { _ = state.undo() }
            #expect(state.session == state.current + state.loops * state.loopSize)
            #expect(state.current >= 0 && state.current < state.loopSize)
        }
    }

    @Test func zeroOrNegativeLoopSizeIsTreatedAsOne() {
        let state = CounterState.opening(total: 5, loopSize: 0, today: 0, resumeLoop: true)
        #expect(state.loopSize == 1)
        #expect(state.current == 0)
    }

    @Test func syncTakesTheStoredValues() {
        var state = CounterState.opening(total: 5, loopSize: 33, today: 1, resumeLoop: false)
        state.sync(with: CountSnapshot(total: 99, today: 12))
        #expect(state.total == 99)
        #expect(state.today == 12)
    }
}
