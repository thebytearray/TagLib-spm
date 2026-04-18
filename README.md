# TagLibSPM

**Repository:** [github.com/thebytearray/TagLib-spm](https://github.com/thebytearray/TagLib-spm)

Swift Package Manager library that exposes [TagLib](https://taglib.org/) on **iOS 15+** and **macOS 12+** for reading and writing audio metadata (tags, embedded pictures, and basic audio properties) on local files.

TagLib is shipped as a **prebuilt `TagLib.xcframework`** attached to each GitHub release. The root `Package.swift` declares a `.binaryTarget` pointing at that zip, so SPM consumers don't need to clone submodules or compile any C++ — they just download the xcframework.

---

## Table of contents

1. [Requirements](#requirements)
2. [Adding the package to your app](#adding-the-package-to-your-app)
3. [Examples](#examples-reading-and-editing-metadata)
4. [Public Swift API](#public-swift-api)
5. [File URLs and threading](#file-urls-and-threading)
6. [Repository layout](#repository-layout)
7. [Cutting a release](#cutting-a-release)
8. [Building the xcframework locally (contributors only)](#building-the-xcframework-locally-contributors-only)
9. [License](#license)

---

## Requirements

- Consumers: **Xcode** with Swift 5.9 or newer. **No submodules needed.**
- Contributors building the xcframework: additionally Git with submodule support.
- `zlib` is linked into the xcframework at build time; consumers get it via load commands in the dylib.

---

## Adding the package to your app

**Package URL:** `https://github.com/thebytearray/TagLib-spm`

In Xcode: **File → Add Package Dependencies…**, paste the URL, choose a version, and add the **`TagLib`** product to your target.

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

Types: `AudioPropertiesReadStyle` (`fast`, `average`, `accurate`), `AudioProperties`, `Metadata`, `Picture`, `PropertyMap` (`[String: [String]]`). Property keys match TagLib's map (e.g. `TITLE`, `ARTIST`). Picture types follow ID3v2 (e.g. `"Front Cover"`).

---

## File URLs and threading

- Use normal file **`URL`**s (and security-scoped access on iOS when needed).
- TagLib does **blocking I/O**; call from a **background** queue or `Task.detached`, not the main thread.

---

## Repository layout

- `Package.swift` — consumer-facing manifest; a single `.binaryTarget` pointing at the xcframework zip published on the tagged GitHub release. `let release` / `let checksum` are rewritten by the release workflow on each tag.
- `BuildPackage/Package.swift` — source manifest. Compiles TagLib from the `vendor/taglib` submodule into `TagLib.framework` via `xcodebuild archive`. Only used for building the xcframework and running tests locally or in CI.
- `Sources/` — Swift wrapper (`TagLib`), C++ bridge (`CTagLib`), and SPM-specific config headers for `TagLibCore`.
- `vendor/taglib` — upstream TagLib C++ sources as a git submodule (only needed by contributors).
- `Scripts/create-xcframework.sh` — archives `TagLibSPM` from `BuildPackage/` for macOS, iOS, and iOS Simulator, bundles them into `TagLib.xcframework`, `ditto`-zips it, and writes `TagLib.xcframework.zip.sha256`.
- `.github/workflows/release.yml` — runs the script, patches `let release` / `let checksum` in the root `Package.swift`, commits, tags, pushes, and uploads the zip to the GitHub release.
- `.github/workflows/ci.yml` — builds and tests against the source manifest in `BuildPackage/` on every push / PR.

---

## Cutting a release

Trigger `.github/workflows/release.yml` via **Actions → Release → Run workflow**, providing a new tag such as `v1.0.1`. The workflow:

1. Checks out the branch with submodules.
2. Runs `swift test` against `BuildPackage/`.
3. Builds `TagLib.xcframework`, zips it with `ditto`, and records its SHA-256.
4. Rewrites `let release` and `let checksum` in the root `Package.swift`.
5. Commits, tags, pushes, and publishes the zip as a release asset.

After the tag is pushed, the root `Package.swift` at that tag references the just-uploaded zip.

---

## Building the xcframework locally (contributors only)

```bash
git clone --recurse-submodules https://github.com/thebytearray/TagLib-spm.git
cd TagLib-spm
# If you already cloned without submodules:
git submodule update --init --recursive

mkdir -p vendor/taglib/taglib/spm_public_headers
# Opening BuildPackage/Package.swift in Xcode once makes the `TagLibSPM` scheme available.
./Scripts/create-xcframework.sh /path/to/out
```

Outputs inside `/path/to/out`:

- `TagLib.xcframework`
- `TagLib.xcframework.zip`
- `TagLib.xcframework.zip.sha256`

To run tests locally:

```bash
cd BuildPackage
swift test
```

API docs (DocC), from `BuildPackage/`:

```bash
swift package --disable-sandbox preview-documentation --target TagLib
# or
swift package generate-documentation --target TagLib
```

---

## License

Packaging and Swift/C code in this repository are under **LGPL 2.1**; see [`LICENSE`](LICENSE). TagLib in `vendor/taglib` follows upstream licensing (LGPL / MPL); see that tree's `COPYING` files and [taglib.org](https://taglib.org/).
