#include "taglib_swift_bridge.h"

#include "fileref.h"
#include "tbytevector.h"
#include "tpropertymap.h"
#include "tstringlist.h"
#include "tvariant.h"

#include <cstring>
#include <cstdlib>

using namespace TagLib;

namespace {

char *dup_utf8(const String &s) {
    return strdup(s.toCString(true));
}

char *dup_bytes(const ByteVector &bv, size_t *out_len) {
    *out_len = bv.size();
    if (bv.isEmpty()) {
        return nullptr;
    }
    auto *p = static_cast<char *>(std::malloc(bv.size()));
    if (!p) {
        return nullptr;
    }
    std::memcpy(p, bv.data(), bv.size());
    return p;
}

bool build_metadata(const FileRef &f, bool read_pictures, taglib_swift_metadata_t **out) {
    auto *meta = static_cast<taglib_swift_metadata_t *>(std::calloc(1, sizeof(taglib_swift_metadata_t)));
    if (!meta) {
        return false;
    }

    const PropertyMap pm = f.properties();
    meta->entry_count = pm.size();
    if (meta->entry_count > 0) {
        meta->entries = static_cast<taglib_swift_property_entry_t *>(
            std::calloc(meta->entry_count, sizeof(taglib_swift_property_entry_t)));
        if (!meta->entries) {
            std::free(meta);
            return false;
        }
        size_t i = 0;
        for (const auto &pair : pm) {
            taglib_swift_property_entry_t &e = meta->entries[i];
            e.key = dup_utf8(pair.first);
            const StringList &sl = pair.second;
            e.value_count = sl.size();
            if (e.value_count > 0) {
                e.values = static_cast<char **>(std::calloc(e.value_count, sizeof(char *)));
                if (!e.values) {
                    taglib_swift_free_metadata(meta);
                    return false;
                }
                for (size_t j = 0; j < e.value_count; ++j) {
                    e.values[j] = dup_utf8(sl[j]);
                }
            } else {
                e.values = nullptr;
            }
            ++i;
        }
    }

    if (read_pictures) {
        const List<VariantMap> pics = f.complexProperties("PICTURE");
        size_t non_empty = 0;
        for (const auto &picture : pics) {
            if (!picture["data"].toByteVector().isEmpty()) {
                ++non_empty;
            }
        }
        meta->picture_count = non_empty;
        if (non_empty > 0) {
            meta->pictures = static_cast<taglib_swift_picture_t *>(
                std::calloc(non_empty, sizeof(taglib_swift_picture_t)));
            if (!meta->pictures) {
                taglib_swift_free_metadata(meta);
                return false;
            }
            size_t pi = 0;
            for (const auto &picture : pics) {
                const ByteVector pictureData = picture["data"].toByteVector();
                if (pictureData.isEmpty()) {
                    continue;
                }
                taglib_swift_picture_t &p = meta->pictures[pi];
                p.data = dup_bytes(pictureData, &p.data_len);
                p.description = dup_utf8(picture["description"].toString());
                p.picture_type = dup_utf8(picture["pictureType"].toString());
                p.mime_type = dup_utf8(picture["mimeType"].toString());
                ++pi;
            }
        }
    }

    *out = meta;
    return true;
}

} // namespace

void taglib_swift_free_string_list(taglib_swift_string_list_t *list) {
    if (!list) {
        return;
    }
    for (size_t i = 0; i < list->count; ++i) {
        std::free(list->values[i]);
    }
    std::free(list->values);
    list->values = nullptr;
    list->count = 0;
}

void taglib_swift_free_pictures(taglib_swift_picture_t *pictures, size_t count) {
    if (!pictures) {
        return;
    }
    for (size_t i = 0; i < count; ++i) {
        std::free(pictures[i].data);
        std::free(pictures[i].description);
        std::free(pictures[i].picture_type);
        std::free(pictures[i].mime_type);
    }
    std::free(pictures);
}

void taglib_swift_free_metadata(taglib_swift_metadata_t *metadata) {
    if (!metadata) {
        return;
    }
    for (size_t i = 0; i < metadata->entry_count; ++i) {
        std::free(metadata->entries[i].key);
        for (size_t j = 0; j < metadata->entries[i].value_count; ++j) {
            std::free(metadata->entries[i].values[j]);
        }
        std::free(metadata->entries[i].values);
    }
    std::free(metadata->entries);
    taglib_swift_free_pictures(metadata->pictures, metadata->picture_count);
    std::free(metadata);
}

bool taglib_swift_get_audio_properties(const char *path_utf8, const int read_style,
                                       taglib_swift_audio_properties_t *out) {
    if (!path_utf8 || !out) {
        return false;
    }
    const auto style = static_cast<AudioProperties::ReadStyle>(read_style);
    const FileRef f(path_utf8, true, style);
    if (f.isNull()) {
        return false;
    }
    const AudioProperties *ap = f.audioProperties();
    if (ap) {
        out->length_ms = static_cast<int32_t>(ap->lengthInMilliseconds());
        out->bitrate = static_cast<int32_t>(ap->bitrate());
        out->sample_rate = static_cast<int32_t>(ap->sampleRate());
        out->channels = static_cast<int32_t>(ap->channels());
    } else {
        out->length_ms = 0;
        out->bitrate = 0;
        out->sample_rate = 0;
        out->channels = 0;
    }
    return true;
}

bool taglib_swift_get_metadata(const char *path_utf8, const bool read_pictures,
                               taglib_swift_metadata_t **out_metadata) {
    if (!path_utf8 || !out_metadata) {
        return false;
    }
    const FileRef f(path_utf8, false, AudioProperties::Average);
    if (f.isNull()) {
        return false;
    }
    taglib_swift_metadata_t *meta = nullptr;
    if (!build_metadata(f, read_pictures, &meta)) {
        return false;
    }
    *out_metadata = meta;
    return true;
}

bool taglib_swift_get_property_values(const char *path_utf8, const char *property_name_utf8,
                                      taglib_swift_string_list_t *out) {
    if (!path_utf8 || !property_name_utf8 || !out) {
        return false;
    }
    out->values = nullptr;
    out->count = 0;
    const FileRef f(path_utf8, false, AudioProperties::Average);
    if (f.isNull()) {
        return false;
    }
    const PropertyMap propertyMap = f.properties();
    const String key(property_name_utf8, String::UTF8);
    const auto it = propertyMap.find(key);
    if (it == propertyMap.end()) {
        return true;
    }
    const StringList &valueList = it->second;
    out->count = valueList.size();
    if (out->count == 0) {
        return true;
    }
    out->values = static_cast<char **>(std::calloc(out->count, sizeof(char *)));
    if (!out->values) {
        return false;
    }
    for (size_t i = 0; i < out->count; ++i) {
        out->values[i] = dup_utf8(valueList[i]);
    }
    return true;
}

bool taglib_swift_get_pictures(const char *path_utf8, taglib_swift_picture_t **out_pictures,
                               size_t *out_count) {
    if (!path_utf8 || !out_pictures || !out_count) {
        return false;
    }
    *out_pictures = nullptr;
    *out_count = 0;
    const FileRef f(path_utf8, false, AudioProperties::Average);
    if (f.isNull()) {
        return true;
    }
    const List<VariantMap> pics = f.complexProperties("PICTURE");
    if (pics.isEmpty()) {
        return true;
    }
    auto *arr = static_cast<taglib_swift_picture_t *>(
        std::calloc(pics.size(), sizeof(taglib_swift_picture_t)));
    if (!arr) {
        return false;
    }
    size_t n = 0;
    for (const auto &picture : pics) {
        const ByteVector pictureData = picture["data"].toByteVector();
        if (pictureData.isEmpty()) {
            continue;
        }
        arr[n].data = dup_bytes(pictureData, &arr[n].data_len);
        arr[n].description = dup_utf8(picture["description"].toString());
        arr[n].picture_type = dup_utf8(picture["pictureType"].toString());
        arr[n].mime_type = dup_utf8(picture["mimeType"].toString());
        ++n;
    }
    *out_pictures = arr;
    *out_count = n;
    return true;
}

bool taglib_swift_save_property_map(const char *path_utf8,
                                    const taglib_swift_property_entry_t *entries, const size_t entry_count) {
    if (!path_utf8 || (!entries && entry_count > 0)) {
        return false;
    }
    FileRef f(path_utf8, false, AudioProperties::Average);
    if (f.isNull()) {
        return false;
    }
    PropertyMap pm;
    for (size_t i = 0; i < entry_count; ++i) {
        if (!entries[i].key) {
            continue;
        }
        StringList sl;
        for (size_t j = 0; j < entries[i].value_count; ++j) {
            if (entries[i].values[j]) {
                sl.append(String(entries[i].values[j], String::UTF8));
            }
        }
        pm[String(entries[i].key, String::UTF8)] = sl;
    }
    f.setProperties(pm);
    return f.save();
}

bool taglib_swift_save_pictures(const char *path_utf8, const taglib_swift_picture_t *pictures,
                                const size_t count) {
    if (!path_utf8 || (!pictures && count > 0)) {
        return false;
    }
    FileRef f(path_utf8, false, AudioProperties::Average);
    if (f.isNull()) {
        return false;
    }
    List<VariantMap> pictureList;
    for (size_t i = 0; i < count; ++i) {
        VariantMap picture;
        if (pictures[i].data && pictures[i].data_len > 0) {
            picture["data"] = ByteVector(pictures[i].data, static_cast<unsigned int>(pictures[i].data_len));
        } else {
            continue;
        }
        picture["description"] =
            pictures[i].description ? String(pictures[i].description, String::UTF8) : String();
        picture["pictureType"] =
            pictures[i].picture_type ? String(pictures[i].picture_type, String::UTF8) : String();
        picture["mimeType"] = pictures[i].mime_type ? String(pictures[i].mime_type, String::UTF8) : String();
        pictureList.append(picture);
    }
    f.setComplexProperties("PICTURE", pictureList);
    return f.save();
}
