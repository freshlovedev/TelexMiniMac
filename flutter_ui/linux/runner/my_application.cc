#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include <string.h>
#include <errno.h>
#include <glib/gstdio.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* telexmini_channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static gchar* telexmini_data_directory() {
  gchar* directory = g_build_filename(g_get_user_config_dir(), "telexmini", NULL);
  g_mkdir_with_parents(directory, 0700);
  return directory;
}

static gchar* telexmini_settings_path() {
  g_autofree gchar* directory = telexmini_data_directory();
  return g_build_filename(directory, "preferences.ini", NULL);
}

static GKeyFile* telexmini_load_settings() {
  GKeyFile* key_file = g_key_file_new();
  g_autofree gchar* path = telexmini_settings_path();
  g_key_file_load_from_file(key_file, path, G_KEY_FILE_KEEP_COMMENTS, NULL);
  return key_file;
}

static gboolean telexmini_save_settings(GKeyFile* key_file) {
  gsize length = 0;
  g_autofree gchar* contents = g_key_file_to_data(key_file, &length, NULL);
  g_autofree gchar* path = telexmini_settings_path();
  return g_file_set_contents(path, contents, length, NULL);
}

static gboolean telexmini_get_bool(GKeyFile* key_file, const gchar* key,
                                    gboolean fallback) {
  GError* error = NULL;
  const gboolean value = g_key_file_get_boolean(key_file, "TelexMini", key, &error);
  if (error != NULL) {
    g_error_free(error);
    return fallback;
  }
  return value;
}

static void telexmini_set_bool_from_args(GKeyFile* key_file, FlValue* args,
                                         const gchar* argument,
                                         const gchar* setting) {
  FlValue* value = fl_value_lookup_string(args, argument);
  if (value != NULL && fl_value_get_type(value) == FL_VALUE_TYPE_BOOL) {
    g_key_file_set_boolean(key_file, "TelexMini", setting, fl_value_get_bool(value));
  }
}

static void telexmini_set_string_from_args(GKeyFile* key_file, FlValue* args,
                                           const gchar* argument,
                                           const gchar* setting) {
  FlValue* value = fl_value_lookup_string(args, argument);
  if (value != NULL && fl_value_get_type(value) == FL_VALUE_TYPE_STRING) {
    g_key_file_set_string(key_file, "TelexMini", setting, fl_value_get_string(value));
  }
}

static gboolean telexmini_write_file(const gchar* name, const gchar* contents,
                                      gssize length) {
  g_autofree gchar* directory = telexmini_data_directory();
  g_autofree gchar* path = g_build_filename(directory, name, NULL);
  return g_file_set_contents(path, contents, length, NULL);
}

// User-owned login item; never changes the desktop input-source selection.
static gboolean telexmini_set_autostart(gboolean enabled) {
  g_autofree gchar* dir = g_build_filename(
      g_get_user_config_dir(), "autostart", NULL);
  g_autofree gchar* file = g_build_filename(
      dir, "telexmini-input-service.desktop", NULL);
  if (!enabled) {
    if (g_remove(file) != 0 && errno != ENOENT) return FALSE;
    return TRUE;
  }
  g_autofree gchar* source = g_build_filename(
      g_get_home_dir(), ".local", "libexec", "telexmini-ibus", NULL);
  if (!g_file_test(source, G_FILE_TEST_IS_EXECUTABLE)) return FALSE;
  if (g_mkdir_with_parents(dir, 0700) != 0) return FALSE;
  g_autofree gchar* desktop = g_strdup_printf(
      "[Desktop Entry]\nType=Application\nName=TelexMini input service\n"
      "Exec=%s\nNoDisplay=true\nX-GNOME-Autostart-enabled=true\n"
      "OnlyShowIn=GNOME;\n", source);
  return g_file_set_contents(file, desktop, -1, NULL);
}

static gboolean telexmini_valid_word(const gchar* word) {
  if (word == NULL || *word == '\0' || strlen(word) > 64) return FALSE;
  for (const gchar* p = word; *p != '\0'; ++p) {
    if (*p < 'a' || *p > 'z') return FALSE;
  }
  return TRUE;
}

static FlMethodResponse* telexmini_handle_call(const gchar* method, FlValue* args) {
  if (g_strcmp0(method, "getStatus") == 0) {
    g_autoptr(GKeyFile) key_file = telexmini_load_settings();
    g_autoptr(FlValue) status = fl_value_new_map();
    fl_value_set_string_take(status, "vietnameseEnabled",
      fl_value_new_bool(telexmini_get_bool(key_file, "VietnameseEnabled", TRUE)));
    fl_value_set_string_take(status, "automaticMode", fl_value_new_bool(TRUE));
    fl_value_set_string_take(status, "autoStart",
      fl_value_new_bool(telexmini_get_bool(key_file, "AutoStart", FALSE)));
    g_autofree gchar* priority = g_key_file_get_string(key_file, "TelexMini", "LanguagePriority", NULL);
    fl_value_set_string_take(status, "languagePriority",
      fl_value_new_string(priority && (g_strcmp0(priority,"English")==0 ||
            g_strcmp0(priority,"Vietnamese")==0) ? priority : "Balanced"));
    return FL_METHOD_RESPONSE(fl_method_success_response_new(status));
  }

  if (g_strcmp0(method, "setMode") == 0) {
    if (args == NULL || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "BAD_ARGUMENT", "Expected a mode map.", NULL));
    }
    FlValue* enabled = fl_value_lookup_string(args, "vietnameseEnabled");
    if (enabled == NULL || fl_value_get_type(enabled) != FL_VALUE_TYPE_BOOL) {
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "BAD_ARGUMENT", "Missing Vietnamese mode state.", NULL));
    }
    g_autoptr(GKeyFile) key_file = telexmini_load_settings();
    g_key_file_set_boolean(key_file, "TelexMini", "VietnameseEnabled",
                           fl_value_get_bool(enabled));
    if (!telexmini_save_settings(key_file)) {
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "LOCAL_STORAGE", "Could not save preferences.", NULL));
    }
    return FL_METHOD_RESPONSE(fl_method_success_response_new(NULL));
  }

  if (g_strcmp0(method, "applyPreferences") == 0) {
    if (args == NULL || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "BAD_ARGUMENT", "Expected a preferences map.", NULL));
    }
    g_autoptr(GKeyFile) key_file = telexmini_load_settings();
    telexmini_set_bool_from_args(key_file, args, "vietnameseEnabled", "VietnameseEnabled");
    telexmini_set_bool_from_args(key_file, args, "smartEnglish", "SmartEnglish");
    telexmini_set_bool_from_args(key_file, args, "restoreInvalid", "RestoreInvalid");
    telexmini_set_bool_from_args(key_file, args, "terminalEnglish", "AutoEnglish");
    telexmini_set_bool_from_args(key_file, args, "snippetsEnabled", "SnippetsEnabled");
    telexmini_set_bool_from_args(key_file, args, "profilesEnabled", "ProfilesEnabled");
    FlValue* startup = fl_value_lookup_string(args, "autoStart");
    if (startup != NULL && fl_value_get_type(startup) == FL_VALUE_TYPE_BOOL) {
      const gboolean enabled = fl_value_get_bool(startup);
      if (!telexmini_set_autostart(enabled)) {
        return FL_METHOD_RESPONSE(fl_method_error_response_new(
          "LOCAL_STORAGE", "Could not update user autostart. Install TelexMini first.", NULL));
      }
      g_key_file_set_boolean(key_file, "TelexMini", "AutoStart", enabled);
    }
    telexmini_set_string_from_args(key_file, args, "inputMethod", "InputMethod");
    telexmini_set_string_from_args(key_file, args, "languagePriority", "LanguagePriority");
    telexmini_set_string_from_args(key_file, args, "hotkey", "Hotkey");
    telexmini_set_string_from_args(key_file, args, "excludedApps", "ExcludedApps");
    FlValue* dark = fl_value_lookup_string(args, "darkMode");
    if (dark != NULL && fl_value_get_type(dark) == FL_VALUE_TYPE_BOOL)
      g_key_file_set_boolean(key_file, "TelexMini", "DarkTheme", fl_value_get_bool(dark));
    FlValue* english_ui = fl_value_lookup_string(args, "englishUI");
    if (english_ui != NULL && fl_value_get_type(english_ui) == FL_VALUE_TYPE_BOOL)
      g_key_file_set_string(key_file, "TelexMini", "UILanguage", fl_value_get_bool(english_ui) ? "en" : "vi");
    // Snippets belong to saveSnippets only. A preferences snapshot may
    // contain obsolete values and must never overwrite the native store.
    if (!telexmini_save_settings(key_file)) {
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "LOCAL_STORAGE", "Could not save preferences.", NULL));
    }
    telexmini_write_file("dictionary-reload.flag", "reload\n", -1);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(NULL));
  }

  if (g_strcmp0(method, "closeUi") == 0) {
    g_idle_add_full(G_PRIORITY_DEFAULT_IDLE, [](gpointer)->gboolean {
      GApplication* app = g_application_get_default();
      if (app) g_application_quit(app);
      return G_SOURCE_REMOVE;
    }, NULL, NULL);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(NULL));
  }

  if (g_strcmp0(method, "listProcesses") == 0) {
    g_autoptr(FlValue) processes = fl_value_new_list();
    g_autoptr(GHashTable) unique = g_hash_table_new_full(
      g_str_hash, g_str_equal, g_free, NULL);
    GDir* directory = g_dir_open("/proc", 0, NULL);
    if (directory) {
      const gchar* entry;
      while ((entry = g_dir_read_name(directory)) != NULL &&
             g_hash_table_size(unique) < 1000) {
        if (!g_ascii_isdigit(entry[0])) continue;
        gboolean numeric = TRUE;
        for (const gchar* p=entry; *p; ++p) {
          if (!g_ascii_isdigit(*p)) { numeric = FALSE; break; }
        }
        if (!numeric) continue;
        g_autofree gchar* path = g_build_filename("/proc", entry, "comm", NULL);
        g_autofree gchar* comm = NULL;
        if (!g_file_get_contents(path, &comm, NULL, NULL) || !comm) continue;
        g_strstrip(comm);
        if (!*comm || strlen(comm) > 255 || g_hash_table_contains(unique, comm))
          continue;
        g_hash_table_add(unique, g_strdup(comm));
        fl_value_append_take(processes, fl_value_new_string(comm));
      }
      g_dir_close(directory);
    }
    return FL_METHOD_RESPONSE(fl_method_success_response_new(processes));
  }

  if (g_strcmp0(method, "loadSnippets") == 0 ||
      g_strcmp0(method, "loadProfiles") == 0) {
    const gchar* filename = g_strcmp0(method, "loadSnippets") == 0
      ? "snippets.tsv" : "profiles.tsv";
    g_autofree gchar* directory = telexmini_data_directory();
    g_autofree gchar* path = g_build_filename(directory, filename, NULL);
    gchar* text = NULL;
    gsize size = 0;
    if (!g_file_get_contents(path, &text, &size, NULL))
      return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_string("")));
    if (size > 65536) {
      g_free(text);
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "LOCAL_STORAGE", "Stored text exceeds limit.", NULL));
    }
    g_autoptr(FlValue) value = fl_value_new_string(text);
    g_free(text);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(value));
  }

  if (g_strcmp0(method, "saveSnippets") == 0 ||
      g_strcmp0(method, "saveProfiles") == 0) {
    if (args == NULL || fl_value_get_type(args) != FL_VALUE_TYPE_MAP)
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "BAD_ARGUMENT", "Expected text map.", NULL));
    FlValue* value = fl_value_lookup_string(args, "text");
    if (value == NULL || fl_value_get_type(value) != FL_VALUE_TYPE_STRING)
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "BAD_ARGUMENT", "Expected text string.", NULL));
    const gchar* contents = fl_value_get_string(value);
    if (strlen(contents) > 65536) return FL_METHOD_RESPONSE(fl_method_error_response_new(
      "BAD_ARGUMENT", "Text limit exceeded.", NULL));
    const gboolean snippets = g_strcmp0(method, "saveSnippets") == 0;
    g_auto(GStrv) lines = g_strsplit(contents, "\n", -1);
    g_autoptr(GHashTable) seen = g_hash_table_new_full(
        g_str_hash, g_str_equal, g_free, NULL);
    for (gsize i = 0; lines[i] != NULL; i++) {
      if (!*lines[i]) continue;
      gchar* line = lines[i];
      gchar* tab = strchr(line, '\t');
      if (!tab || strchr(tab+1, '\t'))
        return FL_METHOD_RESPONSE(fl_method_error_response_new(
          "BAD_ARGUMENT", "Each line must contain one tab.", NULL));
      gchar* key = g_strndup(line, tab-line);
      const gchar* replacement = tab+1;
      gboolean valid = strlen(replacement)>0 &&
         strlen(replacement)<=(snippets ? 1024 : 24) &&
         strlen(key)>=(snippets ? 2 : 1) &&
         strlen(key)<=(snippets ? 48 : 255);
      for(const gchar* p=key; *p && valid; p++) {
        valid = (*p>='a' && *p<='z') ||
          (!snippets && ((*p>='A' && *p<='Z') ||
          (*p>='0' && *p<='9') || *p=='-' || *p=='_' || *p=='.'));
      }
      if (!snippets && !(g_strcmp0(replacement,"English")==0 ||
            g_strcmp0(replacement,"Vietnamese")==0 ||
            g_strcmp0(replacement,"Balanced")==0)) valid=FALSE;
      if(g_hash_table_contains(seen,key))valid=FALSE;
      if(valid)g_hash_table_add(seen,key); else g_free(key);
      if(!valid || g_hash_table_size(seen)>(snippets ? 256 : 200))
        return FL_METHOD_RESPONSE(fl_method_error_response_new(
          "BAD_ARGUMENT", "Invalid or duplicated row.", NULL));
    }
    if(!telexmini_write_file(snippets?"snippets.tsv":"profiles.tsv",contents,-1))
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "LOCAL_STORAGE", "Could not save text.", NULL));
    telexmini_write_file("dictionary-reload.flag", "reload\n", -1);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(NULL));
  }

  if (g_strcmp0(method, "loadDictionary") == 0) {
    if (args == NULL || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "BAD_ARGUMENT", "Expected a dictionary language map.", NULL));
    }
    FlValue* language = fl_value_lookup_string(args, "vietnamese");
    if (language == NULL || fl_value_get_type(language) != FL_VALUE_TYPE_BOOL) {
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "BAD_ARGUMENT", "Missing dictionary language.", NULL));
    }
    g_autofree gchar* directory = telexmini_data_directory();
    const gchar* name = fl_value_get_bool(language)
      ? "VietnameseOverrides.txt" : "EnglishWords.txt";
    g_autofree gchar* path = g_build_filename(directory, name, NULL);
    gchar* contents = NULL;
    gsize length = 0;
    if (!g_file_get_contents(path, &contents, &length, NULL)) {
      return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_list()));
    }
    gchar** lines = g_strsplit(contents, "\\n", -1);
    GPtrArray* valid = g_ptr_array_new_with_free_func(g_free);
    for (gsize i = 0; lines[i] != NULL; ++i) {
      if (telexmini_valid_word(lines[i])) g_ptr_array_add(valid, g_strdup(lines[i]));
    }
    g_ptr_array_add(valid, NULL);
    g_autoptr(FlValue) list = fl_value_new_list_from_strv(
      (const gchar* const*)valid->pdata);
    g_ptr_array_unref(valid);
    g_strfreev(lines);
    g_free(contents);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(list));
  }

  if (g_strcmp0(method, "saveDictionary") == 0) {
    if (args == NULL || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "BAD_ARGUMENT", "Expected a dictionary map.", NULL));
    }
    FlValue* language = fl_value_lookup_string(args, "vietnamese");
    FlValue* words = fl_value_lookup_string(args, "words");
    if (language == NULL || fl_value_get_type(language) != FL_VALUE_TYPE_BOOL ||
        words == NULL || fl_value_get_type(words) != FL_VALUE_TYPE_LIST) {
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "BAD_ARGUMENT", "Expected dictionary language and words.", NULL));
    }
    GString* contents = g_string_new(NULL);
    for (size_t i = 0; i < fl_value_get_length(words); ++i) {
      FlValue* item = fl_value_get_list_value(words, i);
      if (fl_value_get_type(item) != FL_VALUE_TYPE_STRING) continue;
      const gchar* word = fl_value_get_string(item);
      if (telexmini_valid_word(word)) {
        g_string_append(contents, word);
        g_string_append_c(contents, '\n');
      }
    }
    const gchar* name = fl_value_get_bool(language)
      ? "VietnameseOverrides.txt" : "EnglishWords.txt";
    const gboolean saved = telexmini_write_file(name, contents->str, contents->len);
    g_string_free(contents, TRUE);
    if (!saved) {
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "LOCAL_STORAGE", "Could not save dictionary.", NULL));
    }
    telexmini_write_file("dictionary-reload.flag", "reload\n", -1);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(NULL));
  }

  if (g_strcmp0(method, "reloadEngine") == 0) {
    telexmini_write_file("dictionary-reload.flag", "reload\n", -1);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(NULL));
  }

  return FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
}

static void telexmini_method_call_cb(FlMethodChannel* channel,
                                     FlMethodCall* method_call,
                                     gpointer user_data) {
  g_autoptr(FlMethodResponse) response =
    telexmini_handle_call(fl_method_call_get_name(method_call),
                          fl_method_call_get_args(method_call));
  g_autoptr(GError) error = NULL;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("TelexMini method channel response failed: %s", error->message);
  }
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) use_header_bar = FALSE;
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "TelexMini");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "TelexMini");
  }

  gtk_window_set_default_size(window, 1280, 820);
  gtk_window_set_icon_name(window, "telexmini");

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  // Flutter 3.47+ defaults to Impeller on Linux. VMware SVGA3D/other virtual
  // GPUs can render badly corrupted text and incomplete frames with Impeller.
  // Skia still uses accelerated OpenGL on supported physical GPUs. Users
  // can explicitly opt back into Impeller after validating their GPU.
  if (g_strcmp0(g_getenv("TELEXMINI_ENABLE_IMPELLER"), "1") != 0) {
    fl_dart_project_set_enable_impeller(project, FALSE);
  }
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);
  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, "#F6F9FC");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb), self);
  gtk_widget_realize(GTK_WIDGET(view));
  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->telexmini_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "com.telexmini/control",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->telexmini_channel, telexmini_method_call_cb, self, NULL);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);
  g_autoptr(GError) error = NULL;
  if (!g_application_register(application, NULL, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }
  g_application_activate(application);
  *exit_status = 0;
  return TRUE;
}

static void my_application_startup(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

static void my_application_shutdown(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_object(&self->telexmini_channel);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  self->telexmini_channel = NULL;
}

MyApplication* my_application_new() {
  g_set_prgname(APPLICATION_ID);
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, NULL));
}
