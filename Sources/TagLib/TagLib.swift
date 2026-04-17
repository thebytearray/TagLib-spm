import CTagLib
import Darwin
import Foundation

/// Namespace for reading and writing audio file metadata via TagLib on local file URLs.
///
/// All methods require `URL` values with `isFileURL == true`. TagLib performs blocking I/O;
/// call from a background queue in UI applications.
public enum TagLib {
    /// Reads duration, bitrate, sample rate, and channel count for a local audio file.
    public static func getAudioProperties(
        from url: URL,
        readStyle: AudioPropertiesReadStyle = .average
    ) -> AudioProperties? {
        guard url.isFileURL else { return nil }
        let path = filePath(from: url)
        var ap = taglib_swift_audio_properties_t()
        guard taglib_swift_get_audio_properties(path, Int32(readStyle.rawValue), &ap) else {
            return nil
        }
        return AudioProperties(
            length: Int(ap.length_ms),
            bitrate: Int(ap.bitrate),
            sampleRate: Int(ap.sample_rate),
            channels: Int(ap.channels)
        )
    }

    /// Reads the property map and, if requested, embedded pictures.
    public static func getMetadata(from url: URL, readPictures: Bool = true) -> Metadata? {
        guard url.isFileURL else { return nil }
        let path = filePath(from: url)
        var ptr: UnsafeMutablePointer<taglib_swift_metadata_t>?
        guard taglib_swift_get_metadata(path, readPictures, &ptr), let raw = ptr else {
            return nil
        }
        defer { taglib_swift_free_metadata(raw) }
        let meta = raw.pointee
        var map: PropertyMap = [:]
        if let entries = meta.entries, meta.entry_count > 0 {
            for i in 0 ..< meta.entry_count {
                let e = entries[Int(i)]
                guard let keyPtr = e.key else { continue }
                let key = String(cString: keyPtr)
                var values: [String] = []
                if let vals = e.values, e.value_count > 0 {
                    for j in 0 ..< e.value_count {
                        if let vp = vals[Int(j)] {
                            values.append(String(cString: vp))
                        }
                    }
                }
                map[key] = values
            }
        }
        var pictures: [Picture] = []
        if let pics = meta.pictures, meta.picture_count > 0 {
            for i in 0 ..< meta.picture_count {
                let p = pics[Int(i)]
                let data: Data
                if let d = p.data, p.data_len > 0 {
                    data = Data(bytes: d, count: p.data_len)
                } else {
                    data = Data()
                }
                let desc = p.description.map { String(cString: $0) } ?? ""
                let ptype = p.picture_type.map { String(cString: $0) } ?? ""
                let mime = p.mime_type.map { String(cString: $0) } ?? ""
                pictures.append(Picture(data: data, description: desc, pictureType: ptype, mimeType: mime))
            }
        }
        return Metadata(propertyMap: map, pictures: pictures)
    }

    /// Returns all values for a single property key, or an empty array if the key is absent.
    public static func getMetadataPropertyValues(from url: URL, propertyName: String) -> [String]? {
        guard url.isFileURL else { return nil }
        let path = filePath(from: url)
        var list = taglib_swift_string_list_t()
        guard taglib_swift_get_property_values(path, propertyName, &list) else {
            return nil
        }
        defer { taglib_swift_free_string_list(&list) }
        if list.count == 0 || list.values == nil {
            return []
        }
        var out: [String] = []
        out.reserveCapacity(Int(list.count))
        for i in 0 ..< list.count {
            if let vp = list.values![Int(i)] {
                out.append(String(cString: vp))
            }
        }
        return out
    }

    /// Returns every embedded picture entry TagLib exposes for the file.
    public static func getPictures(from url: URL) -> [Picture] {
        guard url.isFileURL else { return [] }
        let path = filePath(from: url)
        var pics: UnsafeMutablePointer<taglib_swift_picture_t>?
        var count: size_t = 0
        guard taglib_swift_get_pictures(path, &pics, &count) else {
            return []
        }
        defer {
            if let pics {
                taglib_swift_free_pictures(pics, count)
            }
        }
        guard let pics, count > 0 else { return [] }
        var result: [Picture] = []
        result.reserveCapacity(Int(count))
        for i in 0 ..< count {
            let p = pics[Int(i)]
            let data: Data
            if let d = p.data, p.data_len > 0 {
                data = Data(bytes: d, count: p.data_len)
            } else {
                data = Data()
            }
            let desc = p.description.map { String(cString: $0) } ?? ""
            let ptype = p.picture_type.map { String(cString: $0) } ?? ""
            let mime = p.mime_type.map { String(cString: $0) } ?? ""
            result.append(Picture(data: data, description: desc, pictureType: ptype, mimeType: mime))
        }
        return result
    }

    /// Prefers a picture with type `"Front Cover"`, otherwise returns the first picture.
    public static func getFrontCover(from url: URL) -> Picture? {
        let pictures = getPictures(from: url)
        return pictures.first { $0.pictureType == "Front Cover" } ?? pictures.first
    }

    /// Writes tag properties from a map. Returns whether TagLib reported a successful save.
    @discardableResult
    public static func savePropertyMap(to url: URL, propertyMap: PropertyMap) -> Bool {
        guard url.isFileURL else { return false }
        let path = filePath(from: url)
        var cEntries: [taglib_swift_property_entry_t] = []
        cEntries.reserveCapacity(propertyMap.count)
        var keyPtrs: [UnsafeMutablePointer<CChar>] = []
        var valueRowPtrs: [UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>] = []
        var valueRowLengths: [Int] = []
        defer {
            for k in keyPtrs {
                k.deallocate()
            }
            for i in 0 ..< valueRowPtrs.count {
                let row = valueRowPtrs[i]
                let n = valueRowLengths[i]
                for j in 0 ..< n {
                    row[j]?.deallocate()
                }
                row.deallocate()
            }
        }
        for (key, values) in propertyMap {
            guard let kptr = strdup(key) else { continue }
            keyPtrs.append(kptr)
            let n = values.count
            let row = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: max(n, 1))
            valueRowLengths.append(n)
            valueRowPtrs.append(row)
            for j in 0 ..< n {
                row[j] = strdup(values[j])
            }
            var e = taglib_swift_property_entry_t()
            e.key = kptr
            e.value_count = n
            e.values = row
            cEntries.append(e)
        }
        return cEntries.withUnsafeBufferPointer { buf in
            taglib_swift_save_property_map(path, buf.baseAddress, buf.count)
        }
    }

    /// Replaces embedded pictures for the standard `PICTURE` complex property.
    @discardableResult
    public static func savePictures(to url: URL, pictures: [Picture]) -> Bool {
        guard url.isFileURL else { return false }
        let path = filePath(from: url)
        var cPictures: [taglib_swift_picture_t] = []
        cPictures.reserveCapacity(pictures.count)
        for p in pictures {
            var cp = taglib_swift_picture_t()
            let count = p.data.count
            if count > 0 {
                let buf = UnsafeMutableRawPointer.allocate(byteCount: count, alignment: 1)
                p.data.copyBytes(to: buf.assumingMemoryBound(to: UInt8.self), count: count)
                cp.data = buf.assumingMemoryBound(to: CChar.self)
                cp.data_len = count
            } else {
                cp.data = nil
                cp.data_len = 0
            }
            cp.description = strdup(p.description)
            cp.picture_type = strdup(p.pictureType)
            cp.mime_type = strdup(p.mimeType)
            cPictures.append(cp)
        }
        defer {
            for cp in cPictures {
                if let d = cp.data {
                    UnsafeMutableRawPointer(d).deallocate()
                }
                cp.description?.deallocate()
                cp.picture_type?.deallocate()
                cp.mime_type?.deallocate()
            }
        }
        return cPictures.withUnsafeBufferPointer { buf in
            taglib_swift_save_pictures(path, buf.baseAddress, buf.count)
        }
    }

    /// UTF-8 file system path for TagLib.
    private static func filePath(from url: URL) -> String {
        if #available(macOS 13.0, iOS 16.0, *) {
            let p = url.path(percentEncoded: false)
            if !p.isEmpty { return p }
        }
        return url.path
    }
}
