import AppKit
import MumlaAudio
import MumlaCore
import XCTest
@testable import MumlaMac

final class TranscriptPillTests: XCTestCase {
    @MainActor
    func testHistoryPasteWithoutATargetCopiesSilentlyAfterTranscribingBar() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        let record = DictationRecord(text: "Hej Mumla", language: .swedish)
        coordinator.history = try DictationHistoryStore(directory: directory).append(record)
        coordinator.setShowPasteDialog(false)
        var presentations: [PillState] = []
        coordinator.showPill = { [weak coordinator] in
            if let state = coordinator?.pillState { presentations.append(state) }
        }
        coordinator.pasteRecord(record, target: nil)
        for _ in 0..<100 {
            if coordinator.pillState == .hidden { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(presentations, [.transcribing])
        XCTAssertEqual(coordinator.pillState, .hidden)
        XCTAssertEqual(board.string(forType: .string), record.text)
        XCTAssertEqual(coordinator.history, [record])
    }

    @MainActor
    func testFailedSettingsSaveDoesNotEnableSilentCopyOrDismissFallback() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("settings.json"), withIntermediateDirectories: true)
        board.setString("Previous clipboard", forType: .string)
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        let record = DictationRecord(text: "My dictation", language: .english)
        coordinator.presentInsertion(.needsCopy(copied: false), record: record)
        coordinator.setShowPasteDialog(false)
        XCTAssertTrue(coordinator.settings.showPasteDialog)
        XCTAssertEqual(coordinator.pillState, .transcript(record, copied: false))
        XCTAssertEqual(board.string(forType: .string), "Previous clipboard")
    }

    @MainActor
    func testSilentFallbackCopiesAndHidesWithoutLosingHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        let record = DictationRecord(text: "Hej Mumla", language: .swedish)
        coordinator.history = try DictationHistoryStore(directory: directory).append(record)
        coordinator.setShowPasteDialog(false)
        XCTAssertFalse(try AppSettingsStore(directory: directory).load().showPasteDialog)
        var presentations = 0
        var dismissals = 0
        coordinator.showPill = { presentations += 1 }
        coordinator.hidePill = { dismissals += 1 }
        coordinator.pillState = .transcribing
        coordinator.presentInsertion(.needsCopy(copied: false), record: record)
        XCTAssertEqual(board.string(forType: .string), record.text)
        XCTAssertEqual(coordinator.pillState, .hidden)
        XCTAssertEqual(presentations, 0)
        XCTAssertEqual(dismissals, 1)
        XCTAssertEqual(coordinator.history, [record])
        XCTAssertEqual(try DictationHistoryStore(directory: directory).load(), [record])
        coordinator.setShowPasteDialog(true)
        XCTAssertTrue(try AppSettingsStore(directory: directory).load().showPasteDialog)
        coordinator.presentInsertion(.needsCopy(copied: false), record: record)
        XCTAssertEqual(coordinator.pillState, .transcript(record, copied: false))
        XCTAssertEqual(presentations, 1)
    }

    @MainActor
    func testTurningDialogOffCopiesAndDismissesExistingFallback() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        let record = DictationRecord(text: "My dictation", language: .english)
        coordinator.presentInsertion(.blockedSecureField, record: record)
        coordinator.setShowPasteDialog(false)
        XCTAssertEqual(coordinator.pillState, .hidden)
        XCTAssertEqual(board.string(forType: .string), record.text)
    }

    @MainActor
    func testSilentModeNeverShowsFallbackForSecureOrEmptyTranscriptAndLeavesConfirmedClipboardAlone() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        coordinator.setShowPasteDialog(false)
        var presentations = 0
        coordinator.showPill = { presentations += 1 }
        let record = DictationRecord(text: "My dictation", language: .english)
        coordinator.presentInsertion(.blockedSecureField, record: record)
        XCTAssertEqual(coordinator.pillState, .hidden)
        XCTAssertEqual(board.string(forType: .string), record.text)
        board.clearContents()
        board.setString("Clipboard after success", forType: .string)
        coordinator.presentInsertion(.inserted, record: record)
        XCTAssertEqual(board.string(forType: .string), "Clipboard after success")
        coordinator.presentInsertion(.needsCopy(copied: false), record: DictationRecord(text: "", language: .english))
        XCTAssertEqual(coordinator.pillState, .hidden)
        XCTAssertEqual(board.string(forType: .string), "Clipboard after success")
        XCTAssertEqual(presentations, 0)
    }

    @MainActor
    func testAlreadyCopiedSilentFallbackDoesNotReplaceNewerClipboard() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        coordinator.setShowPasteDialog(false)
        board.setString("Newer user copy", forType: .string)
        coordinator.presentInsertion(.needsCopy(copied: true), record: DictationRecord(text: "Old dictation", language: .english))
        XCTAssertEqual(coordinator.pillState, .hidden)
        XCTAssertEqual(board.string(forType: .string), "Newer user copy")
    }

    @MainActor
    func testSettingsActionRequestsSettingsInsteadOfOnlyOpeningWindow() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        var opened = 0
        coordinator.showMainWindow = { opened += 1 }
        coordinator.openMainWindow()
        XCTAssertNil(coordinator.settingsOpenRequest)
        coordinator.isOnboardingVisible = true
        coordinator.openSettings()
        let request = coordinator.settingsOpenRequest
        XCTAssertNotNil(request)
        XCTAssertFalse(coordinator.isOnboardingVisible)
        coordinator.openSettings()
        XCTAssertNotEqual(request, coordinator.settingsOpenRequest)
        XCTAssertEqual(opened, 3)
    }

    @MainActor
    func testHotkeyDiagnosticsExcludeTranscriptAndDictionaryText() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        coordinator.history = [DictationRecord(text: "private transcript", language: .swedish)]
        coordinator.hotkeyGestureStage = .holdStarted
        coordinator.copyHotkeyDiagnostics()
        let copied = board.string(forType: .string) ?? ""
        XCTAssertTrue(copied.contains("Gesture: holdStarted"))
        XCTAssertTrue(copied.contains("Input Monitoring:"))
        XCTAssertTrue(copied.contains("Paste: notAttempted"))
        XCTAssertFalse(copied.contains("private transcript"))
        XCTAssertFalse(copied.contains(directory.path))
    }

    @MainActor
    func testSuccessfulInsertionHidesPillWithoutPresentingCopyDialog() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        var presentations = 0
        var dismissals = 0
        coordinator.showPill = { presentations += 1 }
        coordinator.hidePill = { dismissals += 1 }
        coordinator.pillState = .transcribing
        coordinator.presentInsertion(.inserted, record: DictationRecord(text: "Hej Mumla", language: .swedish))
        XCTAssertEqual(coordinator.pillState, .hidden)
        XCTAssertEqual(presentations, 0)
        XCTAssertEqual(dismissals, 1)
    }

    @MainActor
    func testFallbackPersistsPastOldHideDeadlineAndCopiesEntireTranscript() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        let record = DictationRecord(text: String(repeating: "A full transcript. ", count: 100), language: .english)
        coordinator.showPracticePill()
        coordinator.presentInsertion(.needsCopy(copied: false), record: record)
        try await Task.sleep(for: .milliseconds(1600))
        XCTAssertEqual(coordinator.pillState, .transcript(record, copied: false))
        coordinator.copyPillTranscript()
        XCTAssertEqual(board.string(forType: .string), record.text)
        XCTAssertEqual(coordinator.pillState, .transcript(record, copied: true))
        coordinator.dismissPill()
        XCTAssertEqual(coordinator.pillState, .hidden)
    }

    @MainActor
    func testSecureFallbackDoesNotAutoCopyAndEscapeDismisses() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        board.setString("Existing clipboard", forType: .string)
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        let record = DictationRecord(text: "My dictation", language: .english)
        coordinator.presentInsertion(.blockedSecureField, record: record)
        XCTAssertEqual(board.string(forType: .string), "Existing clipboard")
        XCTAssertEqual(coordinator.pillState, .transcript(record, copied: false))
        coordinator.cancelDictation()
        XCTAssertEqual(coordinator.pillState, .hidden)
    }

    @MainActor
    func testTriggerSelectionPersistsAndNotifiesMonitor() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        var updated: DictationTriggerKey?
        coordinator.triggerKeyChanged = { updated = $0 }
        coordinator.setTriggerKey(.function)
        XCTAssertEqual(updated, .function)
        XCTAssertEqual(try AppSettingsStore(directory: directory).load().triggerKey, .function)
    }

    @MainActor
    func testHotkeyPermissionActionReachesMonitorWithoutChangingTriggerSetting() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        var requests = 0
        coordinator.requestHotkeyAccess = { requests += 1 }
        coordinator.requestHotkeyPermission()
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(coordinator.settings.triggerKey, .control)
    }

    @MainActor
    func testHotkeyFailureIsVisibleWithoutOverwritingRecordingStatus() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        coordinator.statusText = "Downloading model"
        coordinator.updateHotkeyStatus(.inputMonitoringRequired)
        XCTAssertEqual(coordinator.hotkeyMonitorStatus, .inputMonitoringRequired)
        XCTAssertFalse(coordinator.hotkeyStatusText.isEmpty)
        XCTAssertEqual(coordinator.statusText, "Downloading model")
        coordinator.updateHotkeyStatus(.active)
        XCTAssertTrue(coordinator.hotkeyStatusText.contains("Ctrl"))
    }

    @MainActor
    func testSecureInputWarningExplainsWhyTheHotkeyIsBlocked() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        var presentations = 0
        coordinator.showPill = { presentations += 1 }
        coordinator.showSecureInputWarning()
        XCTAssertEqual(coordinator.pillState, .message(AppCoordinator.secureInputWarning))
        XCTAssertEqual(presentations, 1)
    }

    @MainActor
    func testSecureInputWarningDoesNotReplaceTranscriptOrProgress() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        var presentations = 0
        coordinator.showPill = { presentations += 1 }
        for state in [PillState.transcribing, .transcript(DictationRecord(text: "Hej", language: .swedish), copied: false)] {
            coordinator.pillState = state
            coordinator.showSecureInputWarning()
            XCTAssertEqual(coordinator.pillState, state)
        }
        XCTAssertEqual(presentations, 0)
    }

    @MainActor
    private func makeCoordinator(directory: URL, pasteboard: NSPasteboard) -> AppCoordinator {
        AppCoordinator(recorder: MicrophoneRecorder(), transcriber: nil,
                       historyStore: DictationHistoryStore(directory: directory),
                       dictionaryStore: DictionaryStore(directory: directory),
                       settingsStore: AppSettingsStore(directory: directory), modelDirectory: nil, pasteboard: pasteboard)
    }
}
