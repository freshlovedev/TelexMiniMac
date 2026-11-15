#include <ibus.h>
#include "c_api.h"
#include <string.h>
#include <glib/gstdio.h>

typedef struct _TelexMiniIBus {
    IBusEngine parent;
    tm_composer *composer;
    gboolean secure;
    gboolean enabled;
    gboolean vni;
    gboolean reload_pending;
    gchar *config_dir;
    GFileMonitor *monitor;
} TelexMiniIBus;
typedef struct _TelexMiniIBusClass { IBusEngineClass parent_class; } TelexMiniIBusClass;
G_DEFINE_TYPE(TelexMiniIBus, telexmini_ibus, IBUS_TYPE_ENGINE)

// Use precisely the same XDG directory and INI schema as Flutter.
static gchar *configuration_dir(void) {
    const gchar *override = g_getenv("TELEXMINI_CONFIG_DIR");
    if (override && *override) return g_strdup(override);
    return g_build_filename(g_get_user_config_dir(), "telexmini", NULL);
}
static gboolean config_bool(GKeyFile *file, const char *key, gboolean fallback) {
    GError *error = NULL;
    gboolean value = g_key_file_get_boolean(file, "TelexMini", key, &error);
    if (error) { g_error_free(error); return fallback; }
    return value;
}
static void apply_preferences(TelexMiniIBus *self) {
    if (!self->composer) return;
    g_autofree gchar *file_path = g_build_filename(self->config_dir, "preferences.ini", NULL);
    g_autoptr(GKeyFile) file = g_key_file_new();
    g_key_file_load_from_file(file, file_path, G_KEY_FILE_NONE, NULL);
    g_autofree gchar *method = g_key_file_get_string(file, "TelexMini", "InputMethod", NULL);
    g_autofree gchar *priority = g_key_file_get_string(file, "TelexMini", "LanguagePriority", NULL);
    self->enabled = config_bool(file, "VietnameseEnabled", TRUE);
    self->vni = g_strcmp0(method, "VNI") == 0;
    const gboolean smart = config_bool(file, "SmartEnglish", TRUE);
    const gboolean restore = config_bool(file, "RestoreInvalid", TRUE);
    const gboolean english_first = g_strcmp0(priority, "English") == 0;
    tm_configure(self->composer, smart, english_first, self->vni, restore);
}
static void on_file_changed(GFileMonitor *monitor, GFile *file, GFile *other,
                            GFileMonitorEvent event, gpointer data) {
    (void)monitor; (void)other; (void)event;
    TelexMiniIBus *self = (TelexMiniIBus*)data;
    g_autofree gchar *name = g_file_get_basename(file);
    if (g_strcmp0(name, "preferences.ini") == 0 ||
        g_strcmp0(name, "dictionary-reload.flag") == 0 ||
        g_strcmp0(name, "EnglishWords.txt") == 0 ||
        g_strcmp0(name, "VietnameseOverrides.txt") == 0) {
        self->reload_pending = TRUE;
    }
}

static void update(TelexMiniIBus *self) {
    const char *text = tm_text(self->composer);
    if (!text) text = "";
    ibus_engine_update_preedit_text_with_mode(IBUS_ENGINE(self),
        ibus_text_new_from_string(text), (guint)g_utf8_strlen(text, -1),
        *text != '\0', IBUS_ENGINE_PREEDIT_CLEAR);
}
static void clear(TelexMiniIBus *self) {
    tm_reset(self->composer);
    update(self);
}
static void commit(TelexMiniIBus *self) {
    const char *current = tm_text(self->composer);
    if (current && *current) {
        const char *result = tm_finish(self->composer);
        if (result && *result)
            ibus_engine_commit_text(IBUS_ENGINE(self), ibus_text_new_from_string(result));
    }
    clear(self);
}
static gboolean on_key(IBusEngine *engine, guint keyval, guint keycode, guint state) {
    TelexMiniIBus *self = (TelexMiniIBus*)engine;
    (void)keycode;
    if (!self->composer || (state & IBUS_RELEASE_MASK)) return FALSE;
    // Event-driven hot reload: only touch the filesystem if Flutter actually
    // changed preferences or a dictionary. Do not lose the pending composition.
    if (self->reload_pending) {
        if (!self->secure) commit(self);
        else clear(self);
        tm_reload(self->composer);
        apply_preferences(self);
        self->reload_pending = FALSE;
    }
    if (self->secure || !self->enabled) return FALSE;
    if (state & (IBUS_CONTROL_MASK | IBUS_MOD1_MASK | IBUS_SUPER_MASK)) {
        commit(self);
        return FALSE;
    }
    const char *now = tm_text(self->composer);
    const gboolean composing = now && *now;
    if (keyval == IBUS_BackSpace && composing) {
        tm_backspace(self->composer);
        update(self);
        return TRUE;
    }
    if (keyval == IBUS_Escape && composing) {
        clear(self);
        return TRUE;
    }
    if ((keyval >= 'a' && keyval <= 'z') ||
        (keyval >= 'A' && keyval <= 'Z') ||
        (self->vni && keyval >= '1' && keyval <= '9')) {
        if (strlen(tm_raw(self->composer)) >= 63) commit(self);
        tm_push(self->composer, keyval);
        update(self);
        return TRUE;
    }
    if (composing) commit(self);
    // Delimiters are not consumed; the target inserts exactly one delimiter.
    return FALSE;
}
static void on_reset(IBusEngine *engine) {
    TelexMiniIBus *self = (TelexMiniIBus*)engine;
    if (self->composer) clear(self);
}
static void on_focus_out(IBusEngine *engine) {
    TelexMiniIBus *self = (TelexMiniIBus*)engine;
    if (self->composer) {
        if (self->secure) clear(self);
        else commit(self);
    }
}
static void on_content_type(IBusEngine *engine, guint purpose, guint hints) {
    TelexMiniIBus *self = (TelexMiniIBus*)engine;
    const gboolean secret = purpose == IBUS_INPUT_PURPOSE_PASSWORD ||
        (hints & IBUS_INPUT_HINT_PRIVATE) != 0;
    if (secret && self->composer) clear(self);
    self->secure = secret;
}
static void on_finalize(GObject *object) {
    TelexMiniIBus *self = (TelexMiniIBus*)object;
    g_clear_object(&self->monitor);
    g_clear_pointer(&self->config_dir, g_free);
    tm_destroy(self->composer);
    self->composer = NULL;
    G_OBJECT_CLASS(telexmini_ibus_parent_class)->finalize(object);
}
static void telexmini_ibus_class_init(TelexMiniIBusClass *cls) {
    IBusEngineClass *engine = IBUS_ENGINE_CLASS(cls);
    engine->process_key_event = on_key;
    engine->reset = on_reset;
    engine->focus_out = on_focus_out;
    engine->set_content_type = on_content_type;
    G_OBJECT_CLASS(cls)->finalize = on_finalize;
}
static void telexmini_ibus_init(TelexMiniIBus *self) {
    self->config_dir = configuration_dir();
    g_mkdir_with_parents(self->config_dir, 0700);
    g_autofree gchar *english = g_build_filename(self->config_dir, "EnglishWords.txt", NULL);
    g_autofree gchar *vietnamese = g_build_filename(self->config_dir, "VietnameseOverrides.txt", NULL);
    const char *override_seed = g_getenv("TELEXMINI_LEXICON_PATH");
    const char *seed = override_seed && *override_seed ? override_seed : TELEXMINI_SEED_PATH;
    self->composer = tm_create(seed, english, vietnamese);
    apply_preferences(self);
    g_autoptr(GFile) directory = g_file_new_for_path(self->config_dir);
    self->monitor = g_file_monitor_directory(directory, G_FILE_MONITOR_NONE, NULL, NULL);
    if (self->monitor) {
        g_signal_connect_object(self->monitor, "changed",
                                G_CALLBACK(on_file_changed), self, 0);
    }
}

static void disconnected(IBusBus *bus, gpointer data) {
    (void)bus; (void)data;
    ibus_quit();
}
int main(int argc, char **argv) {
    ibus_init();
    IBusBus *bus = ibus_bus_new();
    if (!ibus_bus_is_connected(bus)) {
        g_printerr("TelexMini IBus: daemon is not connected\n");
        g_object_unref(bus);
        return 1;
    }
    g_signal_connect(bus, "disconnected", G_CALLBACK(disconnected), NULL);
    IBusFactory *factory = ibus_factory_new(ibus_bus_get_connection(bus));
    ibus_factory_add_engine(factory, "telexmini", telexmini_ibus_get_type());
    if (!ibus_bus_request_name(bus, "org.freedesktop.IBus.TelexMini", 0)) {
        g_printerr("TelexMini IBus: could not own service name\n");
        g_object_unref(factory);
        g_object_unref(bus);
        return 1;
    }
    if (!(argc > 1 && strcmp(argv[1], "--ibus") == 0)) {
        // IBus starts engines by executing the component's registered path.
        // An absolute path works for developer builds without installing globally.
        g_autofree char *exe = g_file_read_link("/proc/self/exe", NULL);
        g_autofree char *quoted = exe ? g_shell_quote(exe) : NULL;
        g_autofree char *command = quoted ? g_strconcat(quoted, " --ibus", NULL) : NULL;
        if (!command) {
            g_printerr("TelexMini IBus: executable path unavailable\n");
            g_object_unref(factory);
            g_object_unref(bus);
            return 1;
        }
        IBusComponent *component = ibus_component_new(
            "org.freedesktop.IBus.TelexMini", "TelexMini Vietnamese",
            "2.4.0", "Pre-release", "TelexMini", "",
            command, "telexmini");
        ibus_component_add_engine(component, ibus_engine_desc_new(
            "telexmini", "TelexMini Vietnamese", "Vietnamese Telex/VNI",
            "vi", "Proprietary preview", "TelexMini", "input-keyboard", "us"));
        if (!ibus_bus_register_component(bus, component)) {
            g_printerr("TelexMini IBus: component registration failed\n");
            g_object_unref(component);
            g_object_unref(factory);
            g_object_unref(bus);
            return 1;
        }
        g_object_unref(component);
    }
    ibus_main();
    g_object_unref(factory);
    g_object_unref(bus);
    return 0;
}
