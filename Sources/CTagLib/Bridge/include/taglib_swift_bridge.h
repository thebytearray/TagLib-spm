#ifndef TAGLIB_SWIFT_BRIDGE_H
#define TAGLIB_SWIFT_BRIDGE_H

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int32_t length_ms;
    int32_t bitrate;
    int32_t sample_rate;
    int32_t channels;
} taglib_swift_audio_properties_t;

typedef struct {
    char *data;
    size_t data_len;
    char *description;
    char *picture_type;
    char *mime_type;
} taglib_swift_picture_t;

typedef struct {
    char *key;
    char **values;
    size_t value_count;
} taglib_swift_property_entry_t;

typedef struct {
    taglib_swift_property_entry_t *entries;
    size_t entry_count;
    taglib_swift_picture_t *pictures;
    size_t picture_count;
} taglib_swift_metadata_t;

typedef struct {
    char **values;
    size_t count;
} taglib_swift_string_list_t;

bool taglib_swift_get_audio_properties(const char *path_utf8, int read_style,
                                       taglib_swift_audio_properties_t *out);

bool taglib_swift_get_metadata(const char *path_utf8, bool read_pictures,
                               taglib_swift_metadata_t **out_metadata);

void taglib_swift_free_metadata(taglib_swift_metadata_t *metadata);

bool taglib_swift_get_property_values(const char *path_utf8, const char *property_name_utf8,
                                      taglib_swift_string_list_t *out);

void taglib_swift_free_string_list(taglib_swift_string_list_t *list);

bool taglib_swift_get_pictures(const char *path_utf8, taglib_swift_picture_t **out_pictures,
                               size_t *out_count);

void taglib_swift_free_pictures(taglib_swift_picture_t *pictures, size_t count);

bool taglib_swift_save_property_map(const char *path_utf8,
                                    const taglib_swift_property_entry_t *entries, size_t entry_count);

bool taglib_swift_save_pictures(const char *path_utf8, const taglib_swift_picture_t *pictures,
                                size_t count);

#ifdef __cplusplus
}
#endif

#endif
