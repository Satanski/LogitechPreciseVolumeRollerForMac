import Foundation

// Prosty mini-framework do testowania, aby pominąć problem z brakiem XCTest w samym Command Line Tools na tym macOS

@MainActor
class TestRunner {
    var totalTests = 0
    var passedTests = 0

    func assert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
        totalTests += 1
        if condition {
            passedTests += 1
            print("✅ PASS: \(message)")
        } else {
            print("❌ FAIL: \(message) at \(file):\(line)")
        }
    }

    func runTests() {
        print("Running VolumeEventProcessor tests...\n")

        let sut = VolumeEventProcessor()

        // MARK: - Normal Scrolling Tests

        let time1: TimeInterval = 1000.0
        let result1 = sut.processVolumeEvent(isUp: true, currentTime: time1)
        assert(result1 == true, "First event should be accepted")


        let sut2 = VolumeEventProcessor()
        var time2: TimeInterval = 1000.0
        _ = sut2.processVolumeEvent(isUp: true, currentTime: time2)
        time2 += 0.05 // > 0.03 debounce interval
        let result2 = sut2.processVolumeEvent(isUp: true, currentTime: time2)
        assert(result2 == true, "Event after debounce interval should be accepted")

        // MARK: - Debounce Tests

        let sut3 = VolumeEventProcessor()
        var time3: TimeInterval = 1000.0
        _ = sut3.processVolumeEvent(isUp: true, currentTime: time3)
        time3 += 0.01 // < 0.03 debounce interval
        let result3 = sut3.processVolumeEvent(isUp: true, currentTime: time3)
        assert(result3 == false, "Event arriving too quickly should be debounced/ignored")

        // MARK: - Direction Lock Tests

        let sut4 = VolumeEventProcessor()
        var time4: TimeInterval = 1000.0
        _ = sut4.processVolumeEvent(isUp: true, currentTime: time4)
        time4 += 0.10 // > 0.03 debounce, but < 0.30 direction lock
        let result4 = sut4.processVolumeEvent(isUp: false, currentTime: time4) // First contrary event
        assert(result4 == false, "First opposite event within lock window should be ignored (needs 2 confirmations)")

        let sut5 = VolumeEventProcessor()
        var time5: TimeInterval = 1000.0
        _ = sut5.processVolumeEvent(isUp: true, currentTime: time5)
        // 1. Initial opposite event (ignored)
        time5 += 0.10
        let result5_1 = sut5.processVolumeEvent(isUp: false, currentTime: time5)
        assert(result5_1 == false, "First opposite event within lock should be ignored")

        // 2. First confirmation (ignored, because directionConfirmCount = 2)
        time5 += 0.10
        let result5_2 = sut5.processVolumeEvent(isUp: false, currentTime: time5)
        assert(result5_2 == false, "Second opposite event should still be ignored")

        // 3. Second confirmation (accepted!)
        time5 += 0.10
        let result5_3 = sut5.processVolumeEvent(isUp: false, currentTime: time5)
        assert(result5_3 == true, "Third opposite event should be accepted as new direction is confirmed")

        let sut6 = VolumeEventProcessor()
        var time6: TimeInterval = 1000.0
        _ = sut6.processVolumeEvent(isUp: true, currentTime: time6)
        time6 += 0.40 // > 0.30 direction lock window
        let result6 = sut6.processVolumeEvent(isUp: false, currentTime: time6)
        assert(result6 == true, "Opposite event far in the future should be accepted immediately")


        let sut7 = VolumeEventProcessor()
        var time7: TimeInterval = 1000.0
        _ = sut7.processVolumeEvent(isUp: true, currentTime: time7)
        // Let's scroll opposite once (ignored)
        time7 += 0.10
        let result7_1 = sut7.processVolumeEvent(isUp: false, currentTime: time7)
        assert(result7_1 == false, "Opposite event correctly ignored")
        // Let's scroll in the ORIGINAL direction again
        time7 += 0.10
        let result7_2 = sut7.processVolumeEvent(isUp: true, currentTime: time7)
        assert(result7_2 == true, "Same direction should be accepted")
        // Let's scroll opposite AGAIN (should be ignored again, not accepted as confirmation!)
        time7 += 0.10
        let result7_3 = sut7.processVolumeEvent(isUp: false, currentTime: time7)
        assert(result7_3 == false, "The confirmation count should have been reset")

        print("\nResults: \(passedTests)/\(totalTests) tests passed.")

        if passedTests != totalTests {
            exit(1)
        } else {
            exit(0)
        }
    }
}

Task { @MainActor in
    let runner = TestRunner()
    runner.runTests()
}
RunLoop.main.run()
