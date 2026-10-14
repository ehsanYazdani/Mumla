import MumlaAudio
import MumlaCore
import XCTest

final class PinnedInputDeviceTests: XCTestCase {
    private let builtIn = AudioInputDevice(uid: "BuiltInMicrophoneDevice", name: "MacBook Pro Microphone")
    private let usb = AudioInputDevice(uid: "usb-port-1", name: "USBAudio1.0")

    func testMatchesRememberedDeviceByUID() {
        let pinned = PinnedInputDevice(uid: "usb-port-1", name: "Renamed")
        XCTAssertEqual(AudioInputDevices.match(pinned, in: [builtIn, usb]), usb)
    }

    func testFollowsRememberedDeviceToNewUIDByName() {
        let pinned = PinnedInputDevice(uid: "usb-port-2", name: "USBAudio1.0")
        XCTAssertEqual(AudioInputDevices.match(pinned, in: [builtIn, usb]), usb)
    }

    func testNoMatchWhileRememberedDeviceIsDisconnected() {
        let pinned = PinnedInputDevice(uid: "usb-port-1", name: "USBAudio1.0")
        XCTAssertNil(AudioInputDevices.match(pinned, in: [builtIn]))
    }

    func testAmbiguousNameDoesNotMatch() {
        let pinned = PinnedInputDevice(uid: "usb-port-3", name: "USBAudio1.0")
        let other = AudioInputDevice(uid: "usb-port-4", name: "USBAudio1.0")
        XCTAssertNil(AudioInputDevices.match(pinned, in: [usb, other]))
    }
}
