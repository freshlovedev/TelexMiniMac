import AppKit
import InputMethodKit

/// System input source; no global keyboard hooks or Accessibility permissions.
@objc(TelexInputController)
final class TelexInputController: IMKInputController {
    private let composer=TelexComposer()
    private var isComposing=false
    private var literalSnippetMode=false
    private var vietnameseEnabled=true
    private var terminalEnglish=false
    private static let terminalAppIds:Set<String> = [
        "com.apple.terminal", "com.googlecode.iterm2",
        "dev.warp.warp-stable", "dev.warp.warp",
        "net.kovidgoyal.kitty", "org.alacritty",
        "com.mitchellh.ghostty"
    ]
    private var shortcut="Ctrl + Shift + Space"
    private var snippetRules=[String:String]()
    private var profileRules=[String:String]()
    private var productivityLastChecked=Date.distantPast
    private var productivitySignature=""
    private var snippetsEnabled=false
    private var profilesEnabled=false
    private var profileMode="Default"
    private var lastReloadCheck=Date.distantPast
    private var lastReloadModification=Date.distantPast

    private func preferences() {
        let defaults=UserDefaults(suiteName:"com.telexmini.mac") ?? .standard
        snippetsEnabled=defaults.bool(forKey:"snippetsEnabled")
        profilesEnabled=defaults.bool(forKey:"profilesEnabled")
        terminalEnglish=defaults.bool(forKey:"terminalEnglish")
        if let sharedMode=defaults.object(forKey:"vietnameseEnabled") as? Bool {
            vietnameseEnabled=sharedMode
        }
        if Date().timeIntervalSince(productivityLastChecked)>2 {
            productivityLastChecked=Date()
            let paths=["snippets.tsv","profiles.tsv"].map {ProductivityCore.folder.appendingPathComponent($0)}
            let signature=paths.map {String((try? $0.resourceValues(forKeys:[.contentModificationDateKey])
                .contentModificationDate?.timeIntervalSince1970) ?? 0)}.joined(separator:"|")
            if signature != productivitySignature {
                productivitySignature=signature
                snippetRules=ProductivityCore.validateSnippets(ProductivityCore.read("snippets.tsv")) ?? [:]
                profileRules=ProductivityCore.validateProfiles(ProductivityCore.read("profiles.tsv")) ?? [:]
            }
        }
        var language=defaults.string(forKey:"languagePriority") ?? "Balanced"
        profileMode="Default"
        if profilesEnabled {
            let app=NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            profileMode=ProductivityCore.profile(for:app,rules:profileRules)
            if profileMode != "Default" {language=profileMode}
        }
        composer.smartEnglish=((defaults.object(forKey:"smartEnglish") as? Bool ?? true) ||
            language == "English") && language != "Vietnamese"
        composer.preferEnglishExact=language == "English"
        composer.restoreInvalid=defaults.object(forKey:"restoreInvalid") as? Bool ?? true
        composer.useVni=defaults.string(forKey:"inputMethod")=="VNI"
        shortcut=defaults.string(forKey:"hotkey") ?? "Ctrl + Shift + Space"
        if Date().timeIntervalSince(lastReloadCheck)>2 {
            lastReloadCheck=Date()
            let flag=FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/TelexMini/dictionary-reload.flag")
            let timestamp=(try? flag.resourceValues(forKeys:[.contentModificationDateKey])
                .contentModificationDate) ?? Date.distantPast
            if timestamp>lastReloadModification && composer.raw.isEmpty {
                lastReloadModification=timestamp
                TelexComposer.reloadLexicon()
            }
        }
    }

    private func clientText(_ sender: Any?) -> IMKTextInput? {
        return sender as? IMKTextInput
    }
    private var notFound: NSRange { NSRange(location:NSNotFound,length:NSNotFound) }
    private func mark(_ sender: Any?) {
        guard let client=clientText(sender) else { return }
        let length=(composer.text as NSString).length
        client.setMarkedText(composer.text, selectionRange:NSRange(location:length,length:0), replacementRange:notFound)
        isComposing = !composer.text.isEmpty
    }
    private func finish(_ sender: Any?) {
        if isComposing {
            let original=composer.raw
            let final=literalSnippetMode ? original : composer.finish()
            let expanded=ProductivityCore.expand(
                original,rules:snippetRules,enabled:snippetsEnabled,
                clipboardProvider: { NSPasteboard.general.string(forType:.string) })
            clientText(sender)?.insertText(expanded ?? final,replacementRange:notFound)
        }
        composer.reset()
        isComposing=false
        literalSnippetMode=false
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard event.type == .keyDown else { return false }
        preferences()
        if let active=NSWorkspace.shared.frontmostApplication?.bundleIdentifier?.lowercased() {
            let defaults=UserDefaults(suiteName:"com.telexmini.mac") ?? .standard
            let excluded=(defaults.string(forKey:"excludedApps") ?? "")
                .split(separator:",").map {String($0).trimmingCharacters(in:.whitespaces).lowercased()}
            if excluded.contains(active) {finish(sender);return false}
        }
        let modifiers=event.modifierFlags.intersection([.control,.option,.shift,.command])
        let toggle=(shortcut=="Ctrl + Shift + Space" && event.keyCode==49 &&
                    modifiers.contains(.control) && modifiers.contains(.shift)) ||
                   (shortcut=="Ctrl + Option + V" && event.keyCode==9 &&
                    modifiers.contains(.control) && modifiers.contains(.option))
        if toggle {
            finish(sender)
            vietnameseEnabled.toggle()
            (UserDefaults(suiteName:"com.telexmini.mac") ?? .standard)
                .set(vietnameseEnabled,forKey:"vietnameseEnabled")
            return true
        }
        let currentApp=NSWorkspace.shared.frontmostApplication?
            .bundleIdentifier?.lowercased() ?? ""
        let literalMode = !vietnameseEnabled || profileMode=="English" ||
                          (terminalEnglish && Self.terminalAppIds.contains(currentApp))
        if literalMode && !snippetsEnabled {finish(sender);return false}
        // Secure fields are normally handled by the system's Roman input source.
        // Never inspect the receiving application's existing text.
        if event.modifierFlags.intersection([.command,.control,.option]).isEmpty == false {
            finish(sender)
            return false
        }
        guard let key=event.characters, !key.isEmpty else { return false }
        if event.keyCode == 51 { // Backspace: adjust current composition only.
            if isComposing {
                composer.backspace()
                if literalSnippetMode {
                    let raw=composer.raw
                    clientText(sender)?.setMarkedText(raw,
                        selectionRange:NSRange(location:(raw as NSString).length,length:0),
                        replacementRange:notFound)
                    isComposing = !raw.isEmpty
                } else { mark(sender) }
                return true
            }
            return false
        }
        if event.keyCode == 53 { finish(sender); return false }
        if event.keyCode == 36 || event.keyCode == 48 || event.keyCode == 49 ||
           key.unicodeScalars.first?.value ?? 0 < 0x20 {
            finish(sender)
            return false
        }
        if key.count == 1, let char=key.first,
           ((char >= "a" && char <= "z") || (char >= "A" && char <= "Z") ||
            (composer.useVni && char >= "1" && char <= "9")) {
            if composer.raw.count >= 63 { finish(sender); return false }
            if isComposing && literalSnippetMode != literalMode { finish(sender) }
            _ = composer.push(char)
            literalSnippetMode=literalMode
            if literalMode {
                let raw=composer.raw
                clientText(sender)?.setMarkedText(raw,
                    selectionRange:NSRange(location:(raw as NSString).length,length:0),
                    replacementRange:notFound)
                isComposing = true
            } else { mark(sender) }
            return true
        }
        finish(sender)
        return false
    }

    override func commitComposition(_ sender: Any!) { finish(sender) }

    override func activateServer(_ sender: Any!) {
        composer.reset()
        vietnameseEnabled=(UserDefaults(suiteName:"com.telexmini.mac") ?? .standard)
            .object(forKey:"vietnameseEnabled") as? Bool ?? true
        TelexComposer.reloadLexicon()
        preferences()
    }
    override func deactivateServer(_ sender: Any!) {
        finish(sender)
    }
}

@main
enum TelexMiniInputMain {
    static func main() {
        let app=NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let server=IMKServer(name:"TelexMini_Connection",
                             bundleIdentifier:"com.telexmini.mac.input")
        guard server != nil else {
            fputs("TelexMini: failed to initialize IMKServer\n",stderr)
            exit(1)
        }
        app.run()
    }
}
