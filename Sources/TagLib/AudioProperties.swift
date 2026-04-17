import Foundation

/// Trade speed vs accuracy when TagLib reads audio properties (duration, bitrate, and similar).
public enum AudioPropertiesReadStyle: Int, Sendable {
    case fast = 0
    case average = 1
    case accurate = 2
}

/// Duration in milliseconds, bitrate in kbps, sample rate in Hz, and channel count.
public struct AudioProperties: Equatable, Sendable {
    public var length: Int
    public var bitrate: Int
    public var sampleRate: Int
    public var channels: Int

    public init(length: Int, bitrate: Int, sampleRate: Int, channels: Int) {
        self.length = length
        self.bitrate = bitrate
        self.sampleRate = sampleRate
        self.channels = channels
    }
}
