import Foundation

/// Embedded cover art or other image from a tag (for example ID3 `APIC` or FLAC pictures).
public struct Picture: Equatable, Sendable {
    public var data: Data
    public var description: String
    public var pictureType: String
    public var mimeType: String

    public init(data: Data, description: String, pictureType: String, mimeType: String) {
        self.data = data
        self.description = description
        self.pictureType = pictureType
        self.mimeType = mimeType
    }
}
