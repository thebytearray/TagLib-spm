# TagLibSPM

**Repository:** [github.com/thebytearray/TagLib-spm](https://github.com/thebytearray/TagLib-spm)

Swift Package Manager library that exposes [TagLib](https://taglib.org/) on **iOS 15+** and **macOS 12+**. It ships a small C bridge (`CTagLib`) and a Swift module named **`TagLib`** for reading and writing audio metadata (tags, embedded pictures, and basic audio properties) on local files.

This package tracks the **official** TagLib sources as a **git submodule** rather than vendoring a copy inside the tree. You get upstream bug fixes and releases by updating the submodule pointer.

---

## Table of contents

1. [Requirements](#requirements)
2. [Getting the code](#getting-the-code)
3. [Adding the package to your app](#adding-the-package-to-your-app)
4. [Examples: reading and editing metadata](#examples-reading-and-editing-metadata)
5. [Public Swift API](#public-swift-api)
6. [File URLs and threading](#file-urls-and-threading)
7. [How the package is built](#how-the-package-is-built)
8. [Building and testing](#building-and-testing)
9. [Swift API documentation (DocC)](#swift-api-documentation-docc)
10. [GitHub releases (manual)](#github-releases-manual)
11. [Troubleshooting](#troubleshooting)
12. [License](#license)

---

## Requirements

- **Xcode** with Swift 5.9 or newer (SwiftPM as shipped with Xcode).
- **Git** with submodule support.
- **zlib** on Apple platforms (system library, linked as `z`).

---

## Getting the code

TagLib lives under **`vendor/taglib`** and points at [github.com/taglib/taglib](https://github.com/taglib/taglib). TagLib in turn depends on **utfcpp** as a nested submodule under `vendor/taglib/3rdparty/utfcpp`.

**Clone with submodules (recommended):**

```bash
git clone --recurse-submodules https://github.com/thebytearray/TagLib-spm.git
cd TagLib-spm
```

**If you already cloned without submodules:**

```bash
git submodule update --init --recursive
```

Run the same `git submodule update --init --recursive` after pulling changes whenever this repository updates the `vendor/taglib` pointer or when TagLib adds new nested dependencies.

To see which upstream TagLib commit is pinned:

```bash
git submodule status
cd vendor/taglib && git describe --tags
```

---

## Adding the package to your app

Use the public package URL:

**`https://github.com/thebytearray/TagLib-spm`**

### Xcode

1. Open your project.
2. **File** → **Add Package Dependencies…**
3. Paste: `https://github.com/thebytearray/TagLib-spm`
4. Choose a **version rule** (for example, a tagged release) or a branch.
5. Add the **`TagLib`** product to your app target.

### SwiftPM manifest

Add a dependency in your `Package.swift` (adjust the version rule to match published tags):

```swift
dependencies: [
    .package(url: "https://github.com/thebytearray/TagLib-spm.git", from: "1.0.0"),
],
```

Then add **`TagLib`** to the target that needs it. The package name SwiftPM uses for the dependency matches the repository name:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "TagLib", package: "TagLib-spm"),
    ]
)
```

Import in Swift:

```swift
import TagLib
```

---

## Examples: reading and editing metadata

All calls use **`URL`** file URLs. Run them off the main thread (see [File URLs and threading](#file-urls-and-threading)).

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

TagLib uses **uppercase** keys such as `TITLE`, `ARTIST`, `ALBUM`, `GENRE`, `DATE`. Values are **arrays** because some formats allow multiple values per key.

### Read a single property without loading the full map

```swift
let titles = TagLib.getMetadataPropertyValues(from: fileURL, propertyName: "TITLE")
// Missing keys return an empty array `[]`, not `nil`.
```

### Change title and artist, then save

Build a new map from what you read, change entries, then write:

```swift
func applyTitleAndArtist(fileURL: URL, title: String, artist: String) -> Bool {
    var map = TagLib.getMetadata(from: fileURL, readPictures: false)?.propertyMap ?? [:]
    map["TITLE"] = [title]
    map["ARTIST"] = [artist]
    return TagLib.savePropertyMap(to: fileURL, propertyMap: map)
}
```

**Note:** Saving replaces the **property map** TagLib uses for that file type. Starting from an empty map would wipe tags. Always **merge** with existing `getMetadata` when you only want to change a few fields.

### Merge edits safely (recommended pattern)

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

// Example:
// _ = updateTags(fileURL: url, edits: ["TITLE": ["My Song"], "ARTIST": ["Jane"]])
```

### Embedded cover art

**Read** the front cover (prefers ID3 type `"Front Cover"`):

```swift
if let cover = TagLib.getFrontCover(from: fileURL) {
    let imageData = cover.data
    let mime = cover.mimeType // e.g. "image/jpeg"
    // Use imageData with UIImage / NSImage / SwiftUI Image
}
```

**Write** new pictures (replaces the `PICTURE` complex property for formats that support it):

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

You can pass multiple `Picture` values if the format supports more than one image.

### Audio-only info (no tags)

```swift
if let audio = TagLib.getAudioProperties(from: fileURL, readStyle: .average) {
    let seconds = audio.length / 1000
    print("Duration ~ \(seconds)s, \(audio.bitrate) kbps, \(audio.sampleRate) Hz, \(audio.channels) ch")
}
```

---

## Public Swift API

All entry points are static methods on the `TagLib` enum. They take **`URL`** values that must be **file URLs** (`url.isFileURL == true`). Paths are passed to TagLib as UTF-8 file system paths.

| Method | Purpose |
|--------|---------|
| `getAudioProperties(from:readStyle:)` | Bitrate, duration, sample rate, channel count. |
| `getMetadata(from:readPictures:)` | Property map (string keys to string lists) and optional embedded pictures. |
| `getMetadataPropertyValues(from:propertyName:)` | Values for one property key. Returns an empty array if the key is missing (does not crash). |
| `getPictures(from:)` | All embedded pictures (for example, ID3 `APIC`). |
| `getFrontCover(from:)` | Picture with type `"Front Cover"`, or the first picture if none match. |
| `savePropertyMap(to:propertyMap:)` | Writes tags from a `[String: [String]]` map. Returns whether TagLib reported success. |
| `savePictures(to:pictures:)` | Writes embedded pictures for the `PICTURE` complex property. |

Supporting types:

- **`AudioPropertiesReadStyle`**: `fast`, `average`, `accurate` (trade speed vs accuracy when reading audio properties).
- **`AudioProperties`**: `length` (milliseconds), `bitrate`, `sampleRate`, `channels`.
- **`Metadata`**: `propertyMap` and `pictures`.
- **`Picture`**: `data`, `description`, `pictureType`, `mimeType`.
- **`PropertyMap`**: typealias for `[String: [String]]`.

Property names are the same strings TagLib uses in its property map (for example, `TITLE`, `ARTIST`). Picture types follow ID3v2 conventions (for example, `"Front Cover"`).

---

## File URLs and threading

- Use **`URL`** objects created from file paths or from security-scoped bookmarks as your app already does for file access.
- On iOS, complete any **security-scoped resource** access before calling into TagLib if the file is outside your sandbox.
- TagLib performs **blocking disk I/O**. Call these APIs from a **background queue** or `Task.detached` so you do not block the main thread.

---

## How the package is built

SwiftPM targets:

| Target | Role |
|--------|------|
| **TagLibCore** | Compiles upstream C++ sources under `vendor/taglib/taglib`.
| **CTagLib** | C bridge (`Sources/CTagLib/Bridge`) and a C header for Swift. Links `TagLibCore` and `z`.
| **TagLib** | Swift wrapper. Depends on `CTagLib`.

Apple-specific compile flags and `config.h` / `taglib_config.h` live under **`Sources/CTagLib/_spm_config`**. SwiftPM also needs an **empty** directory **`vendor/taglib/taglib/spm_public_headers`** so the **TagLibCore** target can set a valid `publicHeadersPath` without exposing C++ headers to Swift. That path is not part of upstream TagLib, so create it after cloning submodules if `swift build` reports an invalid public headers path:

```bash
mkdir -p vendor/taglib/taglib/spm_public_headers
```

---

## Building and testing

From the repository root:

```bash
mkdir -p vendor/taglib/taglib/spm_public_headers   # once per clone if missing
swift build
swift test
```

Continuous integration (see `.github/workflows/ci.yml`) runs `swift build`, `swift test`, and an **iOS Simulator** cross-compile to verify the C++ and Swift stack link for iOS. You can also run that workflow **manually** from the repository **Actions** tab (**Run workflow**).

---

## GitHub releases (manual)

This repository does **not** auto-publish on every push. To ship a release with SwiftPM **release** build artifacts attached to **GitHub Releases**:

1. **Create and push a tag** on the commit you want to release (example: `v1.0.0`):

   ```bash
   git tag -a v1.0.0 -m "Release 1.0.0"
   git push origin v1.0.0
   ```

2. In GitHub, open **Actions** → workflow **Release** → **Run workflow**.

3. Enter the **same tag** (e.g. `v1.0.0`) and run.

The workflow checks out that tag (with submodules), runs `swift build -c release` for **macOS** and **iOS Simulator**, then packages each `.build/*/release` directory into a tarball and uploads them to a **GitHub Release** for that tag (with auto-generated release notes). The tag must already exist on the remote so the workflow can check it out.

**Note:** Most apps depend on this package as source via SwiftPM; the tarballs are convenience artifacts (SwiftPM build outputs, not `.xcframework` bundles). If you need XCFrameworks, build them in Xcode or a custom script from the same tag.

---

## Swift API documentation (DocC)

This package depends on Apple’s **[Swift-DocC plugin](https://github.com/swiftlang/swift-docc-plugin)** so you can browse API docs the same way many Swift packages do.

**Live preview in the browser** (local HTTP server, one target at a time). From the repository root, after submodules are initialized:

```bash
swift package --disable-sandbox preview-documentation --target TagLib
```

DocC prints a URL (typically `http://localhost:XXXX/`). Open it to navigate symbol documentation generated from Swift doc comments. Stop the server with **Control+C**.

`--disable-sandbox` is required on macOS so the plugin can run the preview server outside SwiftPM’s default sandbox.

**Generate a documentation archive** (no server; path printed when it finishes):

```bash
swift package generate-documentation --target TagLib
```

To write a static site under `./docs` (for example to host on GitHub Pages), allow SwiftPM to write that folder:

```bash
swift package --allow-writing-to-directory ./docs \
  generate-documentation --target TagLib --output-path ./docs \
  --transform-for-static-hosting --hosting-base-path TagLib-spm
```

Adjust `--hosting-base-path` to match your site’s public path if you publish the archive.

---

## Troubleshooting

**`utf8.h` is missing or TagLib fails to compile.**

- Run `git submodule update --init --recursive` so `vendor/taglib/3rdparty/utfcpp` is present.

**Empty or missing `vendor/taglib`.**

- Run `git submodule update --init --recursive` from the repository root.

**Submodule shows as modified after opening the project.**

- If you changed files inside `vendor/taglib`, reset or commit that submodule in line with your workflow. Do not commit secrets.

---

## License

This repository (Swift module, C bridge, tests, and packaging outside `vendor/`) is licensed under the **GNU Lesser General Public License v2.1** in the same way as upstream TagLib. The full license text is in **[`LICENSE`](LICENSE)** (verbatim copy of [`vendor/taglib/COPYING.LGPL`](vendor/taglib/COPYING.LGPL)).

The **TagLib** C++ library in **`vendor/taglib`** remains under LGPL 2.1 and MPL 1.1 as shipped upstream. See [`vendor/taglib/COPYING.LGPL`](vendor/taglib/COPYING.LGPL), [`vendor/taglib/COPYING.MPL`](vendor/taglib/COPYING.MPL), and [taglib.org](https://taglib.org/).

If you link this package into an application, you must meet the LGPL requirements for your distribution (for example object files or relinking for the LGPL-covered library, depending on how you ship). This is not legal advice; consult your counsel for commercial or App Store use.
