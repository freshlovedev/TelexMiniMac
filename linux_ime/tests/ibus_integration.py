#!/usr/bin/env python3
"""Integration QA against the logged-in user's *existing* IBus daemon.

This only creates its own input context; it never changes the global
input method or reads any user document. Requires a running telexmini-ibus
development service, not root.
"""
import atexit
import os
import sys
import time
from pathlib import Path

import gi

gi.require_version("IBus", "1.0")
from gi.repository import GLib, IBus


def flush_events(limit=30):
    ctx = GLib.MainContext.default()
    for _ in range(limit):
        while ctx.pending():
            ctx.iteration(False)
        time.sleep(0.006)


class Recorder:
    def __init__(self):
        self.commits = []
        self.preedits = []
        self.errors = []

    def on_commit(self, context, text):
        self.commits.append(text.get_text())

    def on_preedit(self, context, text, cursor, visible):
        self.preedits.append((text.get_text(), bool(visible)))


def main():
    IBus.init()
    bus = IBus.Bus()
    if not bus.is_connected():
        print("ERROR: IBus is disconnected")
        return 2

    context = bus.create_input_context("telexmini-isolated-qa")
    if context is None:
        print("ERROR: could not create isolated input context")
        return 2

    events = Recorder()
    context.connect("commit-text", events.on_commit)
    context.connect("update-preedit-text", events.on_preedit)
    context.set_capabilities(IBus.Capabilite.PREEDIT_TEXT | IBus.Capabilite.FOCUS | IBus.Capabilite.SYNC_PROCESS_KEY)
    original = bus.get_global_engine()
    original_name = original.get_name() if original else "xkb:us::eng"
    global_engine = bus.get_use_global_engine()
    def restore():
        context.focus_out()
        if global_engine:
            bus.set_global_engine(original_name)
    atexit.register(restore)
    context.focus_in()
    flush_events()
    qa_engine = os.environ.get("TELEXMINI_IBUS_QA_NAME", "telexmini")
    if global_engine:
        bus.set_global_engine(qa_engine)
    else:
        context.set_engine(qa_engine)
    flush_events()
    engine = context.get_engine()
    active = bus.get_global_engine()
    print("GLOBAL=" + (active.get_name() if active else "NONE"), flush=True)
    print("ENGINE=" + (engine.get_name() if engine else "NONE"), flush=True)
    if engine is None or engine.get_name() != qa_engine:
        restore()
        atexit.unregister(restore)
        return 2
    cases = [
        ("w", "ư"),
        ("now", "nơ"),
        ("tieengs", "tiếng"),
        ("boons", "bốn"),
        ("uow", "ươ"),
        ("boost", "boost"),
        ("windows", "windows"),
        ("been", "bên"),
        ("chayj", "chạy"),
    ]
    fails = 0
    for raw, expected in cases:
        context.focus_in()
        flush_events()
        events.commits.clear()
        events.preedits.clear()
        accepted = []
        for c in raw:
            accepted.append(context.process_key_event(ord(c), 0, 0))
            flush_events()
        # The actual word must be committed before the unconsumed space.
        space_accepted = context.process_key_event(IBus.space, 0, 0)
        flush_events()
        result = "".join(events.commits)
        preedit_before = next((text for text, visible in reversed(events.preedits) if visible), "")
        passed = result == expected and all(accepted) and not space_accepted
        if not passed:
            fails += 1
            print(f"FAIL {raw!r}: commit={result!r}, expected={expected!r}, "
                  f"accepted={accepted}, space_eaten={space_accepted}, preedit={preedit_before!r}")
        context.focus_out()
        flush_events()
    # These tests use a private config folder passed only to the QA process.
    # They never change the user's existing Flutter preferences/dictionaries.
    qa_config = os.environ.get("TELEXMINI_QA_CONFIG_DIR")
    extra_cases = 0
    if qa_config:
        directory = Path(qa_config)
        directory.mkdir(parents=True, exist_ok=True)
        preferences = directory / "preferences.ini"
        overrides = directory / "VietnameseOverrides.txt"

        def write_preferences(enabled=True, method="Telex", priority="Balanced",
                              snippets=False):
            text = (
                "[TelexMini]\n"
                f"VietnameseEnabled={'true' if enabled else 'false'}\n"
                f"InputMethod={method}\n"
                "SmartEnglish=true\n"
                "RestoreInvalid=true\n"
                f"LanguagePriority={priority}\n"
                f"SnippetsEnabled={'true' if snippets else 'false'}\n"
            )
            temporary = preferences.with_suffix(".ini.tmp")
            temporary.write_text(text, encoding="utf-8")
            os.replace(temporary, preferences)
            time.sleep(0.22)
            flush_events(10)

        def try_word(raw, expected, label):
            nonlocal fails, extra_cases
            extra_cases += 1
            context.focus_in()
            flush_events()
            events.commits.clear()
            accepted = [context.process_key_event(ord(c), 0, 0) for c in raw]
            flush_events()
            space_eaten = context.process_key_event(IBus.space, 0, 0)
            flush_events()
            actual = "".join(events.commits)
            if actual != expected or not all(accepted) or space_eaten:
                fails += 1
                print(f"FAIL {label}: got {actual!r}, expected {expected!r}, "
                      f"accepted={accepted}, space_eaten={space_eaten}")
            context.focus_out()
            flush_events()

        write_preferences(enabled=False)
        context.focus_in()
        flush_events()
        extra_cases += 1
        disabled_pass_through = not context.process_key_event(ord("w"), 0, 0)
        if not disabled_pass_through:
            fails += 1
            print("FAIL disabled Vietnamese mode did not pass a key through")
        context.focus_out()

        write_preferences(enabled=True, method="VNI")
        try_word("bo6n1", "bốn", "VNI toggle")
        write_preferences(enabled=True, method="Telex")
        overrides.write_text("boost\n", encoding="utf-8")
        (directory / "dictionary-reload.flag").write_text("reload override\n", encoding="utf-8")
        time.sleep(0.22)
        try_word("boost", "bốt", "Vietnamese override reload")
        overrides.write_text("", encoding="utf-8")
        (directory / "dictionary-reload.flag").write_text("reload cleared\n", encoding="utf-8")
        time.sleep(0.22)
        try_word("boost", "boost", "English dictionary restore")

        # Expand raw shortcuts despite Telex conversion or English mode.
        snippet_path = directory / "snippets.tsv"
        snippet_path.write_text("dc\tĐịa chỉ:\ndd\tDấu d:\n", encoding="utf-8")
        write_preferences(enabled=True, snippets=True)
        try_word("dc", "Địa chỉ:", "Vietnamese snippet")
        try_word("dd", "Dấu d:", "Telex-collision snippet")
        write_preferences(enabled=False, snippets=True)
        try_word("dc", "Địa chỉ:", "English mode snippet")
        try_word("dd", "Dấu d:", "English mode Telex-collision snippet")
        try_word("boost", "boost", "Literal English with snippets enabled")
        write_preferences(enabled=True, priority="Vietnamese")
        try_word("boost", "bốt", "Vietnamese-first mode")
        write_preferences(enabled=True, priority="English")
        try_word("been", "been", "English-first mode")
        write_preferences(enabled=True)
        try_word("been", "bên", "Balanced mode restored")
        print(f"IBUS_HOT_RELOAD_QA cases={extra_cases} current_failures={fails}", flush=True)

    # Password input scopes should pass all physical keys through unchanged.
    context.set_capabilities(IBus.Capabilite.PREEDIT_TEXT | IBus.Capabilite.FOCUS)
    if hasattr(context, "set_content_type"):
        context.set_content_type(IBus.InputPurpose.PASSWORD, IBus.InputHints.PRIVATE)
        context.focus_in()
        flush_events()
        password_consumed = context.process_key_event(ord("w"), 0, 0)
        flush_events()
        if password_consumed:
            fails += 1
            print("FAIL password scope unexpectedly consumed key")
        context.focus_out()
    print(f"IBUS_PROTOCOL_QA cases={len(cases)} failures={fails}", flush=True)
    # Release the active composition and restore the keyboard while the bus
    # and GI event loop are still alive, not during Python interpreter teardown.
    restore()
    atexit.unregister(restore)
    return 0 if fails == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
