import Foundation

/// TagLib property map: each key maps to one or more string values (UTF-8).
public typealias PropertyMap = [String: [String]]

/// Combined metadata: generic string properties and embedded pictures.
public struct Metadata: Equatable, Sendable {
    public var propertyMap: PropertyMap
    public var pictures: [Picture]

    public init(propertyMap: PropertyMap, pictures: [Picture]) {
        self.propertyMap = propertyMap
        self.pictures = pictures
    }
}
