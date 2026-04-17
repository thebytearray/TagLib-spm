# TagLibSPM

**Repository:** [github.com/thebytearray/TagLib-spm](https://github.com/thebytearray/TagLib-spm)

Swift Package Manager library that exposes [TagLib](https://taglib.org/) on **iOS 15+** and **macOS 12+**. It ships a small C bridge (`CTagLib`) and a Swift module **`TagLib`** for reading and writing audio metadata (tags, embedded pictures, and basic audio properties) on local files.

Upstream TagLib is included as a **git submodule** under `vendor/taglib`.

---

## Table of contents

1. [Requirements](#requirements)
2. [Getting the code](#getting-the-code)
3. [Adding the package to your app](#adding-the-package-to-your-app)
4. [Examples](#examples-reading-and-editing-metadata)
5. [Public Swift API](#public-swift-api)
6. [File URLs and threading](#file-urls-and-threading)
7. [Developing this package](#developing-this-package)
8. [License](#license)

---

## Requirements

- **Xcode** with Swift 5.9 or newer.
- **Git** with submodule support.
- **zlib** on Apple platforms (linked as `z`).

---

## Getting the code

```bash
git clone --recurse-submodules https://github.com/thebytearray/TagLib-spm.git
cd TagLib-spm
```

If you already cloned without submodules: `git submodule update --init --recursive`.

---

## Adding the package to your app

**Package URL:** `https://github.com/thebytearray/TagLib-spm`

In Xcode: **File → Add Package Dependencies…**, paste the URL, add the **`TagLib`** product to your target.

In another `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/thebytearray/TagLib-spm.git", from: "1.0.0"),
],
.target(
    name: "YourTarget",
    dependencies: [.product(name: "TagLib", package: "TagLib-spm")]
)
```

```swift
import TagLib
```

---

## Examples: reading and editing metadata

Use **`URL`** file URLs and call TagLib off the main thread (see [File URLs and threading](#file-urls-and-threading)).

### Read title, artist, and album

```swift
import TagLib

func printCommonTags(fileURL: URL) {
    guard let meta = TagLib.getMetadata(from: fileURL, readPictures: false) else {
        print("Could not read file or unsupported format")
        return
    }
    let map = meta.propertyMap
    let title = map["TITLE"]?.first
    let artist = map["ARTIST"]?.first
    let album = map["ALBUM"]?.first
    print("Title:", title ?? "(none)", "Artist:", artist ?? "(none)", "Album:", album ?? "(none)")
}
```

TagLib uses **uppercase** keys such as `TITLE`, `ARTIST`, `ALBUM`. Values are **arrays** (formats may allow multiple values per key).

### Read a single property

```swift
let titles = TagLib.getMetadataPropertyValues(from: fileURL, propertyName: "TITLE")
// Missing keys return [].
```

### Change title and artist, then save

```swift
func applyTitleAndArtist(fileURL: URL, title: String, artist: String) -> Bool {
    var map = TagLib.getMetadata(from: fileURL, readPictures: false)?.propertyMap ?? [:]
    map["TITLE"] = [title]
    map["ARTIST"] = [artist]
    return TagLib.savePropertyMap(to: fileURL, propertyMap: map)
}
```

Saving replaces the **property map** for that file type. Start from `getMetadata` and merge changes so you do not wipe other tags.

### Merge edits (recommended)

```swift
func updateTags(fileURL: URL, edits: [String: [String]]) -> Bool {
    guard var map = TagLib.getMetadata(from: fileURL, readPictures: false)?.propertyMap else {
        return false
    }
    for (key, values) in edits {
        map[key] = values
    }
    return TagLib.savePropertyMap(to: fileURL, propertyMap: map)
}
```

### Embedded cover art

```swift
if let cover = TagLib.getFrontCover(from: fileURL) {
    let imageData = cover.data
    let mime = cover.mimeType
}
```

```swift
func setFrontCoverJPEG(fileURL: URL, jpegData: Data) -> Bool {
    let picture = Picture(
        data: jpegData,
        description: "",
        pictureType: "Front Cover",
        mimeType: "image/jpeg"
    )
    return TagLib.savePictures(to: fileURL, pictures: [picture])
}
```

### Audio properties (no tags)

```swift
if let audio = TagLib.getAudioProperties(from: fileURL, readStyle: .average) {
    let seconds = audio.length / 1000
    print("Duration ~ \(seconds)s, \(audio.bitrate) kbps, \(audio.sampleRate) Hz, \(audio.channels) ch")
}
```

---

## Public Swift API

Entry points are static methods on the `TagLib` enum. **`URL`** must be a **file URL** (`url.isFileURL == true`).

| Method | Purpose |
|--------|---------|
| `getAudioProperties(from:readStyle:)` | Bitrate, duration, sample rate, channels. |
| `getMetadata(from:readPictures:)` | Property map and optional pictures. |
| `getMetadataPropertyValues(from:propertyName:)` | Values for one key; `[]` if missing. |
| `getPictures(from:)` | All embedded pictures. |
| `getFrontCover(from:)` | `"Front Cover"` or first picture. |
| `savePropertyMap(to:propertyMap:)` | Writes tags from `[String: [String]]`. |
| `savePictures(to:pictures:)` | Writes embedded pictures. |

Types: `AudioPropertiesReadStyle` (`fast`, `average`, `accurate`), `AudioProperties`, `Metadata`, `Picture`, `PropertyMap` (`[String: [String]]`). Property keys match TagLib’s map (e.g. `TITLE`, `ARTIST`). Picture types follow ID3v2 (e.g. `"Front Cover"`).

---

## File URLs and threading

- Use normal file **`URL`**s (and security-scoped access on iOS when needed).
- TagLib does **blocking I/O**; call from a **background** queue or `Task.detached`, not the main thread.

---

## Developing this package

After submodules are initialized, if **`swift build`** fails with a public-headers error for the core target, create the empty path SwiftPM expects:

```bash
mkdir -p vendor/taglib/taglib/spm_public_headers
swift build
swift test
```

API docs (DocC): `swift package --disable-sandbox preview-documentation --target TagLib`, or `swift package generate-documentation --target TagLib`.

The **`TagLib`** product is built as a **dynamic** library so Xcode can produce **`TagLib.framework`** slices for an **XCFramework**. GitHub **Actions → Release** builds `TagLib.xcframework`, zips it, and attaches **`TagLib.xcframework.zip`** to the release. Locally: `./Scripts/create-xcframework.sh <output-dir>`.

---

## License

Packaging and Swift/C code in this repository are under **LGPL 2.1**; see [`LICENSE`](LICENSE). TagLib in `vendor/taglib` follows upstream licensing (LGPL / MPL); see that tree’s `COPYING` files and [taglib.org](https://taglib.org/).
