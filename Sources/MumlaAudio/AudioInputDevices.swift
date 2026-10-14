#if os(macOS)
import CoreAudio
import Foundation
import MumlaCore

public struct AudioInputDevice: Equatable, Hashable, Sendable, Identifiable {
    public let uid: String
    public let name: String
    public var id: String { uid }

    public init(uid: String, name: String) {
        self.uid = uid
        self.name = name
    }
}

public enum AudioInputDevices {
    /// Devices that currently expose at least one input channel.
    public static func available() -> [AudioInputDevice] {
        deviceIDs().compactMap { id in
            guard inputChannelCount(id) > 0, let uid = uid(of: id) else { return nil }
            return AudioInputDevice(uid: uid, name: name(of: id) ?? uid)
        }
    }

    /// The connected input device with this UID, if any.
    public static func deviceID(forUID uid: String) -> AudioDeviceID? {
        deviceIDs().first { self.uid(of: $0) == uid && inputChannelCount($0) > 0 }
    }

    /// The connected device matching a remembered choice: by UID, or by name when the
    /// device came back with a new UID (other USB port, re-paired Bluetooth).
    public static func match(_ pinned: PinnedInputDevice, in devices: [AudioInputDevice]) -> AudioInputDevice? {
        if let exact = devices.first(where: { $0.uid == pinned.uid }) { return exact }
        let sameName = devices.filter { $0.name == pinned.name }
        return sameName.count == 1 ? sameName[0] : nil
    }

    /// Calls `onChange` on the main queue whenever devices are added or removed.
    /// Keep the returned token alive for as long as updates are wanted.
    public static func observeChanges(_ onChange: @escaping @Sendable () -> Void) -> AnyObject {
        DeviceListObserver(onChange: onChange)
    }

    private static let system = AudioObjectID(kAudioObjectSystemObject)

    private static func deviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private static func inputChannelCount(_ id: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, raw) == noErr else { return 0 }
        let buffers = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func uid(of id: AudioDeviceID) -> String? {
        stringProperty(kAudioDevicePropertyDeviceUID, of: id)
    }

    private static func name(of id: AudioDeviceID) -> String? {
        stringProperty(kAudioObjectPropertyName, of: id)
    }

    private static func stringProperty(_ selector: AudioObjectPropertySelector, of id: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr,
              let value else { return nil }
        return value.takeRetainedValue() as String
    }
}

private final class DeviceListObserver {
    private var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private let block: AudioObjectPropertyListenerBlock

    init(onChange: @escaping @Sendable () -> Void) {
        block = { _, _ in onChange() }
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, block)
    }

    deinit {
        AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, block)
    }
}
#endif
