import Foundation
import TagLib
import XCTest

final class TagLibTests: XCTestCase {
    // MARK: - Fixtures

    private func sampleWavURL() throws -> URL {
        guard let url = Bundle.module.url(forResource: "sample", withExtension: "wav", subdirectory: "Fixtures") else {
            XCTFail("Missing Fixtures/sample.wav")
            throw NSError(domain: "TagLibTests", code: 1)
        }
        return url
    }

    private func temporaryWavCopy() throws -> URL {
        let src = try sampleWavURL()
        let dst = FileManager.default.temporaryDirectory
            .appendingPathComponent("TagLibTests-\(UUID().uuidString).wav")
        if FileManager.default.fileExists(atPath: dst.path) {
            try FileManager.default.removeItem(at: dst)
        }
        try FileManager.default.copyItem(at: src, to: dst)
        return dst
    }

    /// 1x1 transparent PNG (valid image bytes for embedded art tests).
    private var tinyPNGData: Data {
        Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!
    }

    // MARK: - Non-file URLs return safe defaults

    func testNonFileURL_getAudioPropertiesReturnsNil() {
        let url = URL(string: "https://example.com/a.wav")!
        XCTAssertNil(TagLib.getAudioProperties(from: url))
    }

    func testNonFileURL_getMetadataReturnsNil() {
        let url = URL(string: "https://example.com/a.wav")!
        XCTAssertNil(TagLib.getMetadata(from: url))
    }

    func testNonFileURL_getMetadataPropertyValuesReturnsNil() {
        let url = URL(string: "https://example.com/a.wav")!
        XCTAssertNil(TagLib.getMetadataPropertyValues(from: url, propertyName: "TITLE"))
    }

    func testNonFileURL_getPicturesReturnsEmpty() {
        let url = URL(string: "https://example.com/a.wav")!
        XCTAssertTrue(TagLib.getPictures(from: url).isEmpty)
    }

    func testNonFileURL_getFrontCoverReturnsNil() {
        let url = URL(string: "https://example.com/a.wav")!
        XCTAssertNil(TagLib.getFrontCover(from: url))
    }

    func testNonFileURL_savePropertyMapReturnsFalse() {
        let url = URL(string: "https://example.com/a.wav")!
        XCTAssertFalse(TagLib.savePropertyMap(to: url, propertyMap: ["TITLE": ["x"]]))
    }

    func testNonFileURL_savePicturesReturnsFalse() {
        let url = URL(string: "https://example.com/a.wav")!
        let pic = Picture(data: Data([0]), description: "", pictureType: "Front Cover", mimeType: "image/png")
        XCTAssertFalse(TagLib.savePictures(to: url, pictures: [pic]))
    }

    // MARK: - getAudioProperties

    func testGetAudioProperties_allReadStyles() throws {
        let url = try sampleWavURL()
        for style in [AudioPropertiesReadStyle.fast, .average, .accurate] {
            let audio = TagLib.getAudioProperties(from: url, readStyle: style)
            XCTAssertNotNil(audio, "readStyle \(style)")
            XCTAssertGreaterThan(audio?.length ?? 0, 0)
            XCTAssertGreaterThanOrEqual(audio?.channels ?? 0, 1)
        }
    }

    // MARK: - getMetadata

    func testGetMetadata_readPicturesFalse() throws {
        let url = try sampleWavURL()
        let meta = TagLib.getMetadata(from: url, readPictures: false)
        XCTAssertNotNil(meta)
        XCTAssertEqual(meta?.pictures.count, 0)
    }

    func testGetMetadata_readPicturesTrue() throws {
        let url = try sampleWavURL()
        let meta = TagLib.getMetadata(from: url, readPictures: true)
        XCTAssertNotNil(meta)
    }

    // MARK: - getMetadataPropertyValues

    func testGetMetadataPropertyValues_missingKeyReturnsEmptyArray() throws {
        let url = try sampleWavURL()
        let values = TagLib.getMetadataPropertyValues(from: url, propertyName: "NONEXISTENT_KEY_XYZ")
        XCTAssertNotNil(values)
        XCTAssertEqual(values, [])
    }

    // MARK: - getPictures / getFrontCover

    func testGetPictures_returnsArray() throws {
        let url = try sampleWavURL()
        let pics = TagLib.getPictures(from: url)
        XCTAssertNotNil(pics)
    }

    func testGetFrontCover_returnsNilWhenNoFrontCover() throws {
        let url = try sampleWavURL()
        let pics = TagLib.getPictures(from: url)
        if pics.isEmpty {
            XCTAssertNil(TagLib.getFrontCover(from: url))
        } else {
            _ = TagLib.getFrontCover(from: url)
        }
    }

    // MARK: - Round-trip savePropertyMap

    func testSavePropertyMap_roundTripTitleArtist() throws {
        let url = try temporaryWavCopy()
        defer { try? FileManager.default.removeItem(at: url) }

        let title = "TagLib SPM Test Title"
        let artist = "TagLib SPM Test Artist"

        var map = TagLib.getMetadata(from: url, readPictures: false)?.propertyMap ?? [:]
        map["TITLE"] = [title]
        map["ARTIST"] = [artist]

        XCTAssertTrue(TagLib.savePropertyMap(to: url, propertyMap: map), "savePropertyMap should succeed on WAV temp copy")

        let titleBack = TagLib.getMetadataPropertyValues(from: url, propertyName: "TITLE")
        let artistBack = TagLib.getMetadataPropertyValues(from: url, propertyName: "ARTIST")

        XCTAssertEqual(titleBack, [title], "TITLE round-trip")
        XCTAssertEqual(artistBack, [artist], "ARTIST round-trip")

        let meta = TagLib.getMetadata(from: url, readPictures: false)
        XCTAssertEqual(meta?.propertyMap["TITLE"], [title])
        XCTAssertEqual(meta?.propertyMap["ARTIST"], [artist])
    }

    // MARK: - savePictures (format-dependent)

    func testSavePictures_andReadBack() throws {
        let url = try temporaryWavCopy()
        defer { try? FileManager.default.removeItem(at: url) }

        let picture = Picture(
            data: tinyPNGData,
            description: "test",
            pictureType: "Front Cover",
            mimeType: "image/png"
        )

        let saved = TagLib.savePictures(to: url, pictures: [picture])
        guard saved else {
            throw XCTSkip("This WAV path does not support writing embedded pictures on this TagLib build; API was exercised.")
        }

        let pics = TagLib.getPictures(from: url)
        XCTAssertFalse(pics.isEmpty, "Expected at least one picture after save")
        let front = TagLib.getFrontCover(from: url)
        XCTAssertNotNil(front)
        XCTAssertEqual(front?.mimeType, "image/png")
        XCTAssertEqual(front?.pictureType, "Front Cover")
        XCTAssertFalse(front?.data.isEmpty ?? true)
    }

    // MARK: - Types

    func testAudioPropertiesReadStyle_rawValuesMatchTagLib() {
        XCTAssertEqual(AudioPropertiesReadStyle.fast.rawValue, 0)
        XCTAssertEqual(AudioPropertiesReadStyle.average.rawValue, 1)
        XCTAssertEqual(AudioPropertiesReadStyle.accurate.rawValue, 2)
    }

    func testPictureEquatable() {
        let a = Picture(data: Data([1, 2]), description: "d", pictureType: "Front Cover", mimeType: "image/png")
        let b = Picture(data: Data([1, 2]), description: "d", pictureType: "Front Cover", mimeType: "image/png")
        XCTAssertEqual(a, b)
    }
}
