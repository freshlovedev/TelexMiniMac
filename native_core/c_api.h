#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
// UTF-8, non-throwing C ABI shared by macOS InputMethodKit and Linux IME adapters.
// All returned UTF-8 strings are borrowed until the next call on this instance.
typedef struct tm_composer tm_composer;
uint32_t tm_api_version(void);
tm_composer* tm_create(const char* seed, const char* english, const char* vietnamese);
void tm_destroy(tm_composer* instance);
int tm_configure(tm_composer* instance, int smart_english, int english_first, int vni, int restore_invalid);
int tm_reload(tm_composer* instance);
void tm_reset(tm_composer* instance);
void tm_backspace(tm_composer* instance);
const char* tm_push(tm_composer* instance, uint32_t unicode_scalar);
const char* tm_text(tm_composer* instance);
const char* tm_raw(tm_composer* instance);
const char* tm_finish(tm_composer* instance);
uint32_t tm_dictionary_size(tm_composer* instance);
#ifdef __cplusplus
}
#endif
