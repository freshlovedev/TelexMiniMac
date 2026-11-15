import SwiftUI
import AppKit
import ServiceManagement

private enum Palette {
    static let bg=Color(nsColor:.windowBackgroundColor)
    static let sidebar=Color(nsColor:.underPageBackgroundColor)
    static let card=Color(nsColor:.controlBackgroundColor)
    static let outline=Color(nsColor:.separatorColor)
    static let muted=Color(nsColor:.secondaryLabelColor)
    static let ink=Color(nsColor:.labelColor)
    static let mint=Color(red:0.12,green:0.68,blue:0.55)
    static let blue=Color(red:0.18,green:0.48,blue:0.78)
}

final class SettingsStore: ObservableObject {
    @Published var smartEnglish: Bool { didSet { defaults.set(smartEnglish,forKey:"smartEnglish") } }
    @Published var restoreInvalid: Bool { didSet { defaults.set(restoreInvalid,forKey:"restoreInvalid") } }
    @Published var darkMode: Bool { didSet { defaults.set(darkMode,forKey:"darkMode") } }
    @Published var autoStart: Bool { didSet {
        if #available(macOS 13.0, *) {
            do {
                if autoStart {try SMAppService.mainApp.register()}
                else {try SMAppService.mainApp.unregister()}
            } catch {autoStartError=error.localizedDescription}
        }
    } }
    @Published var autoStartError=""
    @Published var inputMethod:String {didSet {defaults.set(inputMethod,forKey:"inputMethod")}}
    @Published var hotkey:String {didSet {defaults.set(hotkey,forKey:"hotkey")}}
    @Published var languagePriority:String {didSet {defaults.set(languagePriority,forKey:"languagePriority")}}
    @Published var excludedApps:String {didSet {defaults.set(excludedApps,forKey:"excludedApps")}}
    @Published var snippetsEnabled:Bool {didSet {defaults.set(snippetsEnabled,forKey:"snippetsEnabled")}}
    @Published var profilesEnabled:Bool {didSet {defaults.set(profilesEnabled,forKey:"profilesEnabled")}}
    @Published var uiLanguage:String {didSet {defaults.set(uiLanguage,forKey:"uiLanguage")}}
    private let defaults=UserDefaults(suiteName:"com.telexmini.mac") ?? .standard
    init() {
        smartEnglish=defaults.object(forKey:"smartEnglish") as? Bool ?? true
        restoreInvalid=defaults.object(forKey:"restoreInvalid") as? Bool ?? true
        darkMode=defaults.object(forKey:"darkMode") as? Bool ?? true
        if #available(macOS 13.0, *) { autoStart=SMAppService.mainApp.status == .enabled }
        else { autoStart=false }
        inputMethod=defaults.string(forKey:"inputMethod") ?? "Telex"
        hotkey=defaults.string(forKey:"hotkey") ?? "Ctrl + Shift + Space"
        languagePriority=defaults.string(forKey:"languagePriority") ?? "Balanced"
        excludedApps=defaults.string(forKey:"excludedApps") ?? ""
        snippetsEnabled=defaults.bool(forKey:"snippetsEnabled")
        profilesEnabled=defaults.bool(forKey:"profilesEnabled")
        uiLanguage=defaults.string(forKey:"uiLanguage") ?? "vi"
    }
    static var directory: URL {
        let dir=FileManager.default.homeDirectoryForCurrentUser
           .appendingPathComponent("Library/Application Support/TelexMini",isDirectory:true)
        try? FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        return dir
    }
    func signalReload() {
        let file=Self.directory.appendingPathComponent("dictionary-reload.flag")
        try? Date().description.write(to:file,atomically:true,encoding:.utf8)
    }
    func transfer(_ incoming:Bool) {
        let panel=NSOpenPanel()
        panel.canChooseDirectories=true;panel.canChooseFiles=false
        panel.allowsMultipleSelection=false
        let english=defaults.string(forKey:"uiLanguage")=="en"
        panel.prompt=incoming ? (english ? "Import" : "Nhập") : (english ? "Export" : "Xuất")
        guard panel.runModal() == .OK,let folder=panel.url,
              folder.standardizedFileURL != Self.directory.standardizedFileURL else {return}
        for filename in ["EnglishWords.txt","VietnameseOverrides.txt","snippets.tsv","profiles.tsv"] {
            let local=Self.directory.appendingPathComponent(filename)
            let backup=folder.appendingPathComponent(filename)
            let source=incoming ? backup : local
            let target=incoming ? local : backup
            if let data=try? Data(contentsOf:source) {
                // Never remove the old preferences first: atomic replacement
                // leaves existing files intact if reading or writing fails.
                let content=String(data:data,encoding:.utf8) ?? ""
                let valid=filename=="snippets.tsv" ?
                    ProductivityCore.validateSnippets(content) != nil :
                    filename=="profiles.tsv" ?
                    ProductivityCore.validateProfiles(content) != nil : true
                if valid {try? data.write(to:target,options:.atomic)}
            }
        }
        let portable=folder.appendingPathComponent("telexmini-sync.tsv")
        let pref=folder.appendingPathComponent("TelexMini-preferences.json")
        if incoming {
            if let contents=try? String(contentsOf:portable,encoding:.utf8) {
                for line in contents.split(whereSeparator:\.isNewline) {
                    let cells=line.split(separator:"\t",omittingEmptySubsequences:false)
                    guard cells.count==2 else {continue}
                    let key=String(cells[0]),value=String(cells[1])
                    if key=="InputMethod" && ["Telex","VNI"].contains(value) {inputMethod=value}
                    if key=="LanguagePriority" && ["Balanced","Vietnamese","English"].contains(value) {
                        languagePriority=value
                    }
                    if key=="UILanguage" && ["vi","en"].contains(value) {uiLanguage=value}
                    if value=="true" || value=="false" {
                        let enabled=value=="true"
                        if key=="SmartEnglish" {smartEnglish=enabled}
                        if key=="RestoreInvalid" {restoreInvalid=enabled}
                        if key=="SnippetsEnabled" {snippetsEnabled=enabled}
                        if key=="ProfilesEnabled" {profilesEnabled=enabled}
                        if key=="DarkTheme" {darkMode=enabled}
                    }
                }
            }
            if !FileManager.default.fileExists(atPath:portable.path),
               let data=try? Data(contentsOf:pref),
               let json=try? JSONSerialization.jsonObject(with:data) as? [String:String] {
                if let value=json["inputMethod"],["Telex","VNI"].contains(value) {inputMethod=value}
                if let value=json["hotkey"] {hotkey=value}
                if let value=json["languagePriority"],["Balanced","Vietnamese","English"].contains(value) {
                    languagePriority=value
                }
                if let value=json["excludedApps"] {excludedApps=value}
            }
        } else {
            let json=["inputMethod":inputMethod,"hotkey":hotkey,"excludedApps":excludedApps,
                      "languagePriority":languagePriority]
            if let data=try? JSONSerialization.data(withJSONObject:json,options:[.prettyPrinted]) {
                try? data.write(to:pref,options:.atomic)
            }
            let rows=["TelexMini-Sync\t1","InputMethod\t"+inputMethod,
                      "LanguagePriority\t"+languagePriority,
                      "SmartEnglish\t"+String(smartEnglish),
                      "RestoreInvalid\t"+String(restoreInvalid),
                      "SnippetsEnabled\t"+String(snippetsEnabled),
                      "ProfilesEnabled\t"+String(profilesEnabled),
                      "DarkTheme\t"+String(darkMode),
                      "UILanguage\t"+uiLanguage]
            try? (rows.joined(separator:"\n")+"\n")
                .write(to:portable,atomically:true,encoding:.utf8)
        }
        signalReload()
    }
    func edit(_ file:String) {
        let url=Self.directory.appendingPathComponent(file)
        if !FileManager.default.fileExists(atPath:url.path) {
            try? "# Mỗi dòng một từ, không cần dấu cách.\n".write(to:url,atomically:true,encoding:.utf8)
        }
        NSWorkspace.shared.open(url)
    }
}

struct PreferenceRow: View {
    let icon:String
    let title:String
    let description:String
    @Binding var checked:Bool
    var body: some View {
        HStack(spacing:14) {
            Image(systemName:icon).font(.system(size:17,weight:.semibold))
                .foregroundStyle(Palette.mint)
                .frame(width:42,height:42)
                .background(Palette.mint.opacity(0.1),in:RoundedRectangle(cornerRadius:12))
            VStack(alignment:.leading,spacing:5) {
                Text(title).font(.system(size:13,weight:.semibold))
                Text(description).font(.system(size:11)).foregroundStyle(Palette.muted)
            }
            Spacer()
            Toggle("",isOn:$checked).toggleStyle(.switch).tint(Palette.mint).labelsHidden()
        }
        .padding(.vertical,10)
    }
}

struct SidebarButton:View {
    let icon:String
    let label:String
    let action:()->Void
    var selected=false
    var body:some View {
        Button(action:action) {
            HStack(spacing:14) {
                Image(systemName:icon).font(.system(size:15,weight:.medium)).frame(width:19)
                Text(label).font(.system(size:12,weight:.semibold))
                Spacer()
            }
            .foregroundStyle(selected ? Palette.mint : Palette.ink.opacity(0.82))
            .padding(.horizontal,16).frame(height:42)
            .background(selected ? Palette.mint.opacity(0.12) : .clear,
                        in:RoundedRectangle(cornerRadius:11))
        }.buttonStyle(.plain)
    }
}

struct SettingsView:View {
    @StateObject private var prefs=SettingsStore()
    @State private var preview=""
    @State private var section="dashboard"
    @State private var editingFile:String?=nil
    @State private var editingText=""
    @State private var validationError=""
    @State private var showSymbols=false
    @State private var spellingInput=""
    @State private var spellingSuggestions=[String]()
    private var wordCount:String { "1.670+" }
    private func tr(_ vi:String,_ en:String)->String {
        prefs.uiLanguage=="en" ? en : vi
    }
    var body:some View {
        HStack(spacing:0) {
            sidebar
            ScrollView {
                VStack(alignment:.leading,spacing:22) {
                    header
                    if section=="dashboard" {
                        hero
                        HStack(spacing:16) { statusCard; privacyCard }
                        VStack(alignment:.leading,spacing:8) {
                            Text(tr("THIẾT LẬP NHANH","QUICK SETUP")).font(.system(size:11,weight:.bold))
                                .tracking(1.5).foregroundStyle(Palette.muted)
                            settingsCard {
                                PreferenceRow(icon:"character.cursor.ibeam",title:tr("Nhận diện tiếng Anh","Recognize English"),
                                    description:tr("Bảo vệ từ tiếng Anh khi đang gõ tiếng Việt","Protect English words while typing Vietnamese"),
                                    checked:$prefs.smartEnglish)
                                Divider()
                                PreferenceRow(icon:"arrow.uturn.backward",title:tr("Khôi phục từ không hợp lệ","Restore invalid words"),
                                    description:tr("Khôi phục phím gốc khi chuỗi không hợp lệ","Restore original keys when a sequence is invalid"),
                                    checked:$prefs.restoreInvalid)
                            }
                        }
                        VStack(alignment:.leading,spacing:9) {
                            Label(tr("THỬ GÕ NGAY","TRY TYPING"),systemImage:"keyboard")
                                .font(.system(size:11,weight:.bold)).tracking(1.2).foregroundStyle(Palette.muted)
                            TextField(tr("Nhập thử tiếng Việt hoặc tiếng Anh…","Try Vietnamese or English…"),text:$preview)
                                .textFieldStyle(.plain).font(.system(size:14)).padding(14)
                                .background(Palette.card,in:RoundedRectangle(cornerRadius:12))
                            Text(tr("Chọn nguồn nhập TelexMini trong macOS để thử chuyển đổi dấu.",
                                    "Select TelexMini in macOS Input Sources to test accent conversion."))
                                .font(.system(size:11)).foregroundStyle(Palette.muted)
                        }
                    } else if section=="typing" {
                        Text(tr("PHƯƠNG THỨC NHẬP","INPUT METHOD")).font(.system(size:11,weight:.bold))
                            .tracking(1.5).foregroundStyle(Palette.muted)
                        settingsCard {
                            settingRow(tr("Kiểu gõ","Typing method"),tr("Chọn Telex hoặc VNI","Choose Telex or VNI")) {
                                Picker("",selection:$prefs.inputMethod) {
                                    Text("Telex").tag("Telex");Text("VNI").tag("VNI")
                                }.labelsHidden().frame(width:145)
                            }
                            Divider()
                            settingRow(tr("Ưu tiên ngôn ngữ","Language priority"),
                                tr("Quyết định cách xử lý chuỗi Anh–Việt mơ hồ","Resolve ambiguous English/Vietnamese sequences")) {
                                Picker("",selection:$prefs.languagePriority) {
                                    Text(tr("Cân bằng","Balanced")).tag("Balanced")
                                    Text(tr("Tiếng Việt","Vietnamese first")).tag("Vietnamese")
                                    Text(tr("Tiếng Anh","English first")).tag("English")
                                }.labelsHidden().frame(width:165)
                            }
                            Divider()
                            settingRow(tr("Phím chuyển V/E","V/E shortcut"),tr("Chuyển chế độ nhập","Switch input mode")) {
                                Picker("",selection:$prefs.hotkey) {
                                    Text("Ctrl + Shift + Space").tag("Ctrl + Shift + Space")
                                    Text("Ctrl + Option + V").tag("Ctrl + Option + V")
                                }.labelsHidden().frame(width:235)
                            }
                            Divider()
                            PreferenceRow(icon:"character.cursor.ibeam",title:tr("Nhận diện tiếng Anh","Recognize English"),
                                description:tr("Bảo vệ từ tiếng Anh khi đang gõ tiếng Việt","Protect English words while typing Vietnamese"),
                                checked:$prefs.smartEnglish)
                            Divider()
                            PreferenceRow(icon:"arrow.uturn.backward",title:tr("Khôi phục từ không hợp lệ","Restore invalid words"),
                                description:tr("Khôi phục phím gốc khi chuỗi không hợp lệ","Restore original keys when a sequence is invalid"),
                                checked:$prefs.restoreInvalid)
                        }
                    } else if section=="dictionaries" {
                        Text(tr("TỪ ĐIỂN CÁ NHÂN","PERSONAL DICTIONARIES")).font(.system(size:11,weight:.bold))
                            .tracking(1.5).foregroundStyle(Palette.muted)
                        dictionaryCard("text.book.closed",tr("Từ điển tiếng Anh","English dictionary"),
                            tr("Bảo vệ tên riêng, thuật ngữ và từ chuyên ngành","Protect names, technical terms and specialist vocabulary")) {
                                openEditor("EnglishWords.txt")
                            }
                        dictionaryCard("character.book.closed",tr("Ưu tiên Telex","Vietnamese priority"),
                            tr("Các chuỗi phím cần được xử lý như tiếng Việt","Key sequences that should be treated as Vietnamese")) {
                                openEditor("VietnameseOverrides.txt")
                            }
                        Button {prefs.signalReload()} label:{Label(tr("Nạp lại từ điển","Reload dictionaries"),systemImage:"arrow.clockwise")}
                            .buttonStyle(.bordered)
                    } else if section=="productivity" {
                        Text(tr("CÔNG CỤ NĂNG SUẤT","PRODUCTIVITY TOOLS")).font(.system(size:11,weight:.bold))
                            .tracking(1.5).foregroundStyle(Palette.muted)
                        settingsCard {
                            PreferenceRow(icon:"text.badge.plus",title:tr("Gõ tắt","Text snippets"),
                                description:tr("Mở rộng phím tắt tại ranh giới từ","Expand shortcuts at word boundaries"),
                                checked:$prefs.snippetsEnabled)
                            Divider()
                            PreferenceRow(icon:"macwindow",title:tr("Profile theo ứng dụng","Per-app profiles"),
                                description:tr("Chọn ưu tiên ngôn ngữ cho từng ứng dụng","Set language priority per app"),
                                checked:$prefs.profilesEnabled)
                        }
                        HStack {
                            Button(tr("Quản lý gõ tắt","Manage snippets")){openEditor("snippets.tsv")}
                            Button(tr("Profile ứng dụng","Application profiles")){openEditor("profiles.tsv")}
                            Button(tr("Ký tự nhanh","Quick symbols")){showSymbols=true}
                        }.buttonStyle(.bordered)
                        settingsCard {
                            TextField(tr("Nhập từ cần kiểm tra","Enter a word to check"),text:$spellingInput)
                                .textFieldStyle(.roundedBorder)
                            Button(tr("Gợi ý chính tả","Spelling suggestions")) {
                                spellingSuggestions=SpellAdvisor.suggest(spellingInput)
                            }.buttonStyle(.bordered)
                            Text(spellingSuggestions.isEmpty ? tr("Gợi ý chỉ xuất hiện khi bạn yêu cầu.","Suggestions appear only when requested.") :
                                tr("Gợi ý: ","Suggestions: ")+spellingSuggestions.joined(separator:" · "))
                                .font(.caption).foregroundStyle(Palette.muted)
                        }
                    } else if section=="system" {
                        Text(tr("HỆ THỐNG & GIAO DIỆN","SYSTEM & APPEARANCE")).font(.system(size:11,weight:.bold))
                            .tracking(1.5).foregroundStyle(Palette.muted)
                        settingsCard {
                            settingRow(tr("Ngôn ngữ giao diện","Interface language"),
                                tr("Áp dụng cho toàn bộ cửa sổ cài đặt","Applies to all settings screens")) {
                                Picker("",selection:$prefs.uiLanguage) {
                                    Text("Tiếng Việt").tag("vi");Text("English").tag("en")
                                }.labelsHidden().frame(width:145)
                            }
                            Divider()
                            PreferenceRow(icon:"moon.stars",title:tr("Giao diện tối","Dark appearance"),
                                description:tr("Tắt để dùng giao diện sáng","Turn off to use light appearance"),
                                checked:$prefs.darkMode)
                            Divider()
                            PreferenceRow(icon:"power",title:tr("Tự khởi động cùng macOS","Start with macOS"),
                                description:tr("Đăng ký trong Login Items","Register in Login Items"),
                                checked:$prefs.autoStart)
                            if !prefs.autoStartError.isEmpty {
                                Text(prefs.autoStartError).font(.caption).foregroundStyle(.orange)
                            }
                        }
                        settingsCard {
                            Text(tr("ỨNG DỤNG BỎ QUA","EXCLUDED APPLICATIONS"))
                                .font(.system(size:10,weight:.bold)).foregroundStyle(Palette.muted)
                            Text(tr("Nhập bundle ID, phân tách bằng dấu phẩy.","Enter bundle IDs separated by commas."))
                                .font(.caption).foregroundStyle(Palette.muted)
                            TextField("com.apple.Terminal, com.microsoft.VSCode",text:$prefs.excludedApps)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Button(tr("Xuất cấu hình","Export settings")){prefs.transfer(false)}
                            Button(tr("Nhập cấu hình","Import settings")){prefs.transfer(true)}
                            Button(tr("Kiểm tra bản phát hành","Check releases")) {
                                NSWorkspace.shared.open(URL(string:"https://github.com/muahacodon321-boop/TelexMiniMac/releases")!)
                            }
                        }.buttonStyle(.bordered)
                    } else {
                        Text(tr("VỀ TELEXMINI","ABOUT TELEXMINI")).font(.system(size:11,weight:.bold))
                            .tracking(1.5).foregroundStyle(Palette.muted)
                        privacyCard
                        settingsCard {
                            Text("TelexMini 1.0 Preview").font(.system(size:18,weight:.bold))
                            Text(tr("Bộ gõ song ngữ Việt–Anh cho macOS. Hoạt động offline và không lưu lịch sử gõ.",
                                    "Vietnamese–English input for macOS. Works offline and does not store typing history."))
                                .font(.system(size:12)).foregroundStyle(Palette.muted)
                            Text(tr("Nguồn nhập cần được bật trong Cài đặt hệ thống → Bàn phím → Nguồn nhập.",
                                    "Enable the input source in System Settings → Keyboard → Input Sources."))
                                .font(.system(size:11)).foregroundStyle(Palette.muted)
                        }
                    }
                }
                .padding(28)
            }
            .background(Palette.bg)
        }
        .frame(minWidth:1020,minHeight:700)
        .preferredColorScheme(prefs.darkMode ? .dark : .light)
        .animation(.easeInOut(duration:0.16),value:section)
        .alert(tr("Dữ liệu chưa hợp lệ","Invalid data"),isPresented:Binding(
            get:{!validationError.isEmpty},set:{if !$0 {validationError=""}})) {
            Button("OK") {validationError=""}
        } message: {Text(validationError)}
        .sheet(isPresented:$showSymbols) {
            VStack(alignment:.leading,spacing:14) {
                Text(tr("Ký tự nhanh","Quick symbols")).font(.title2.bold())
                Text(tr("Chọn ký tự để sao chép, sau đó Command+V để chèn.",
                        "Select a symbol to copy, then press Command+V to insert."))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:7),spacing:8) {
                    ForEach(ProductivityCore.symbols,id:\.self) { value in
                        Button(value) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(value,forType:.string)
                            showSymbols=false
                        }.frame(maxWidth:.infinity,minHeight:36)
                            .buttonStyle(.bordered)
                    }
                }
            }.padding(24).frame(width:500)
        }
        .sheet(isPresented:Binding(get:{editingFile != nil},set:{if !$0 {editingFile=nil}})) {
            let file=editingFile ?? "EnglishWords.txt"
            VStack(alignment:.leading,spacing:12) {
                Text(file=="EnglishWords.txt" ? tr("Từ điển tiếng Anh","English dictionary") :
                     file=="VietnameseOverrides.txt" ? tr("Ưu tiên Telex","Vietnamese priority") :
                     file=="snippets.tsv" ? tr("Gõ tắt","Text snippets") : tr("Cấu hình ứng dụng","Application profiles"))
                    .font(.title2.bold())
                Text(file=="snippets.tsv" ? tr("Mỗi dòng: phím tắt a-z, Tab, nội dung thay thế. Ví dụ dc<Tab>được.",
                        "One rule per line: a-z shortcut, Tab, replacement. Example dc<Tab>được.") :
                     file=="profiles.tsv" ? tr("Mỗi dòng: bundle-id<Tab>English/Vietnamese/Balanced.",
                        "One rule per line: bundle ID, Tab, English/Vietnamese/Balanced.") :
                     tr("Mỗi dòng một từ gồm a-z. Không ghi nhận nội dung đang gõ.",
                        "One a-z word per line. Typed content is never logged."))
                    .font(.caption).foregroundStyle(.secondary)
                TextEditor(text:$editingText).font(.system(.body,design:.monospaced))
                    .frame(minHeight:340)
                HStack {
                    Button(tr("Hủy","Cancel")) {editingFile=nil}
                    Spacer()
                    Button(tr("Lưu","Save")) {
                        let url=SettingsStore.directory.appendingPathComponent(file)
                        if file=="snippets.tsv" {
                            guard ProductivityCore.validateSnippets(editingText) != nil else {
                                validationError=tr("Gõ tắt phải có phím a-z (2–48 ký tự), Tab, rồi nội dung.",
                                    "A snippet needs a 2–48 character a-z key, a Tab, and replacement text.")
                                return
                            }
                            try? ProductivityCore.save(editingText,to:file)
                        } else if file=="profiles.tsv" {
                            guard ProductivityCore.validateProfiles(editingText) != nil else {
                                validationError=tr("Profile phải là bundle ID, Tab, English/Vietnamese/Balanced.",
                                    "A profile needs a bundle ID, Tab, and English/Vietnamese/Balanced.")
                                return
                            }
                            try? ProductivityCore.save(editingText,to:file)
                        } else {
                            let cleaned=editingText.split(whereSeparator: \.isNewline)
                                .map {String($0).trimmingCharacters(in:.whitespaces).lowercased()}
                                .filter {!$0.isEmpty && $0.count<=64 &&
                                         $0.utf8.allSatisfy({$0>=97 && $0<=122})}
                            try? (cleaned.joined(separator:"\n")+"\n").write(to:url,
                                atomically:true,encoding:.utf8)
                        }
                        prefs.signalReload();editingFile=nil
                    }.keyboardShortcut(.defaultAction)
                }
            }.padding(24).frame(width:530)
        }
    }
    private func openEditor(_ file:String) {
        editingText=(try? String(contentsOf:SettingsStore.directory.appendingPathComponent(file),
                                 encoding:.utf8)) ?? ""
        editingFile=file
    }
    private func settingsCard<Content:View>(@ViewBuilder _ content:()->Content)->some View {
        VStack(alignment:.leading,spacing:13,content:content)
            .padding(18).frame(maxWidth:.infinity,alignment:.leading)
            .background(Palette.card,in:RoundedRectangle(cornerRadius:16))
            .overlay(RoundedRectangle(cornerRadius:16).stroke(Palette.outline.opacity(0.75),lineWidth:1))
    }
    private func settingRow<Content:View>(_ title:String,_ subtitle:String,@ViewBuilder control:()->Content)->some View {
        HStack(spacing:14) {
            VStack(alignment:.leading,spacing:4) {
                Text(title).font(.system(size:12,weight:.semibold)).foregroundStyle(Palette.ink)
                Text(subtitle).font(.system(size:10)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength:12)
            control()
        }.padding(.vertical,4)
    }
    private func dictionaryCard(_ icon:String,_ title:String,_ subtitle:String,_ action:@escaping()->Void)->some View {
        Button(action:action) {
            HStack(spacing:14) {
                Image(systemName:icon).font(.system(size:21)).foregroundStyle(Palette.mint)
                    .frame(width:48,height:48).background(Palette.mint.opacity(0.12),in:RoundedRectangle(cornerRadius:14))
                VStack(alignment:.leading,spacing:5) {
                    Text(title).font(.system(size:13,weight:.semibold)).foregroundStyle(Palette.ink)
                    Text(subtitle).font(.system(size:11)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Label(tr("Chỉnh sửa","Edit"),systemImage:"pencil").font(.system(size:11,weight:.semibold))
                    .foregroundStyle(Palette.mint)
            }.padding(17).background(Palette.card,in:RoundedRectangle(cornerRadius:15))
                .overlay(RoundedRectangle(cornerRadius:15).stroke(Palette.outline.opacity(0.7),lineWidth:1))
        }.buttonStyle(.plain)
    }
    private var sidebar:some View {
        VStack(alignment:.leading,spacing:20) {
            HStack(spacing:11) {
                Image(systemName:"character.bubble.fill")
                    .font(.system(size:24,weight:.semibold))
                    .foregroundStyle(Palette.mint)
                    .frame(width:42,height:42)
                    .background(Palette.mint.opacity(0.1),in:RoundedRectangle(cornerRadius:13))
                VStack(alignment:.leading,spacing:1) {
                    Text("telexmini").font(.system(size:20,weight:.bold,design:.rounded))
                    Text("SMART INPUT SYSTEM").font(.system(size:8,weight:.bold))
                        .tracking(1.4).foregroundStyle(Palette.muted)
                }
            }
            .padding(.top,16)
            Rectangle().fill(Palette.outline).frame(height:1)
            Text(tr("KHÔNG GIAN LÀM VIỆC","WORKSPACE")).font(.system(size:10,weight:.bold))
                .tracking(1.4).foregroundStyle(Palette.muted)
            VStack(spacing:5) {
                SidebarButton(icon:"square.grid.2x2.fill",label:tr("Tổng quan","Overview"),action:{section="dashboard"},selected:section=="dashboard")
                SidebarButton(icon:"keyboard",label:tr("Cài đặt gõ","Typing"),action:{section="typing"},selected:section=="typing")
                SidebarButton(icon:"character.book.closed",label:tr("Từ điển","Dictionaries"),action:{section="dictionaries"},selected:section=="dictionaries")
                SidebarButton(icon:"bolt.fill",label:tr("Năng suất","Productivity"),action:{section="productivity"},selected:section=="productivity")
                SidebarButton(icon:"slider.horizontal.3",label:tr("Hệ thống","System"),action:{section="system"},selected:section=="system")
                SidebarButton(icon:"info.circle",label:tr("Giới thiệu","About"),action:{section="about"},selected:section=="about")
            }
            Spacer()
            VStack(alignment:.leading,spacing:12) {
                Image(systemName:"lock.shield.fill").font(.system(size:20)).foregroundStyle(Palette.mint)
                Text(tr("RIÊNG TƯ THEO THIẾT KẾ","PRIVATE BY DESIGN")).font(.system(size:10,weight:.bold))
                    .tracking(1.3).foregroundStyle(Palette.muted)
                Text(tr("Không gửi nội dung đã gõ lên mạng. Không lưu mật khẩu hay lịch sử gõ.",
                        "Typed content is never sent online. Passwords and typing history are not stored."))
                    .font(.system(size:11)).foregroundStyle(Palette.muted)
                    .lineSpacing(5)
            }
            .padding(16).frame(maxWidth:.infinity,alignment:.leading)
            .background(Palette.card,in:RoundedRectangle(cornerRadius:14))
            Text(tr("DÀNH CHO macOS","BUILT FOR macOS")).font(.system(size:10,weight:.medium))
                .tracking(1.4).foregroundStyle(Palette.muted)
                .padding(.bottom,9)
        }
        .padding(.horizontal,19)
        .frame(width:235)
        .background(Palette.sidebar)
    }
    private var header:some View {
        HStack {
            VStack(alignment:.leading,spacing:5) {
                Text(tr("TELEXMINI / BẢNG ĐIỀU KHIỂN","TELEXMINI / CONTROL CENTER"))
                    .font(.system(size:10,weight:.bold)).tracking(1.8)
                    .foregroundStyle(Palette.mint)
                Text(section=="dashboard" ? tr("Gõ theo cách của bạn.","Type your way.") :
                     section=="typing" ? tr("Cài đặt gõ","Typing") :
                     section=="dictionaries" ? tr("Từ điển","Dictionaries") :
                     section=="productivity" ? tr("Năng suất","Productivity") :
                     section=="system" ? tr("Hệ thống","System") : tr("Giới thiệu","About"))
                    .font(.system(size:27,weight:.bold,design:.rounded))
                Text(tr("Hai ngôn ngữ. Một trải nghiệm liền mạch.","Two languages, one seamless experience."))
                    .font(.system(size:13)).foregroundStyle(Palette.muted)
            }
            Spacer()
            Label(tr("CỤC BỘ & AN TOÀN","LOCAL & SECURE"),systemImage:"checkmark.shield.fill")
                .font(.system(size:11,weight:.bold))
                .foregroundStyle(Palette.mint)
                .padding(.horizontal,13).padding(.vertical,10)
                .background(Palette.mint.opacity(0.08),
                            in:Capsule())
        }
    }
    private var hero:some View {
        HStack(alignment:.center) {
            VStack(alignment:.leading,spacing:12) {
                Text(tr("GÕ SONG NGỮ THÔNG MINH","SMART BILINGUAL TYPING")).font(.system(size:11,weight:.bold))
                    .tracking(1.9).foregroundStyle(.white.opacity(0.8))
                Text(tr("Tiếng Việt tự nhiên.\nEnglish liền mạch.","Natural Vietnamese.\nSeamless English."))
                    .font(.system(size:24,weight:.bold,design:.rounded))
                    .lineSpacing(5).fixedSize(horizontal:false,vertical:true)
                Text(tr("Telex tức thời · Từ điển offline · Không gián đoạn",
                        "Instant Telex · Offline dictionary · No interruptions"))
                    .font(.system(size:12)).foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            Image(systemName:"keyboard")
                .font(.system(size:76,weight:.ultraLight))
                .foregroundStyle(.white.opacity(0.9))
                .padding(24)
                .background(.white.opacity(0.08),
                            in:RoundedRectangle(cornerRadius:24))
        }
        .padding(27)
        .frame(maxWidth:.infinity,alignment:.leading)
        .background(LinearGradient(colors:[
            Color(red:0.04,green:0.55,blue:0.49),
            Color(red:0.09,green:0.34,blue:0.53),
            Color(red:0.11,green:0.22,blue:0.43)
        ],startPoint:.topLeading,endPoint:.bottomTrailing),
        in:RoundedRectangle(cornerRadius:22))
    }
    private var statusCard:some View {
        HStack(alignment:.center,spacing:14) {
            Image(systemName:"globe.asia.australia.fill").font(.system(size:24))
                .foregroundStyle(Palette.mint)
            VStack(alignment:.leading,spacing:7) {
                Text(tr("TỪ ĐIỂN OFFLINE","OFFLINE DICTIONARY")).font(.system(size:10,weight:.bold))
                    .foregroundStyle(Palette.muted)
                Text(wordCount+" "+tr("từ","words")).font(.system(size:20,weight:.bold))
                Text(tr("Có thể mở rộng","Customizable")).font(.system(size:11))
                    .foregroundStyle(Palette.muted)
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth:.infinity,alignment:.leading)
        .background(Palette.card,in:RoundedRectangle(cornerRadius:17))
    }
    private var privacyCard:some View {
        HStack(alignment:.center,spacing:14) {
            Image(systemName:"lock.shield.fill").font(.system(size:26))
                .foregroundStyle(Palette.mint)
            VStack(alignment:.leading,spacing:7) {
                Text(tr("MẬT KHẨU","PASSWORDS")).font(.system(size:10,weight:.bold))
                    .foregroundStyle(Palette.muted)
                Text(tr("Hệ thống bảo vệ","Protected by default")).font(.system(size:17,weight:.bold))
                Text(tr("Không xử lý Secure Input","Secure Input is never processed")).font(.system(size:11))
                    .foregroundStyle(Palette.muted)
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth:.infinity,alignment:.leading)
        .background(Palette.card,in:RoundedRectangle(cornerRadius:17))
    }
}

@main
struct TelexMiniSettingsApp: App {
    var body: some Scene {
        WindowGroup("TelexMini") { SettingsView() }
            .windowResizability(.contentMinSize)
    }
}
