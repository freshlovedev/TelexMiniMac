import SwiftUI
import AppKit
import ServiceManagement

private enum Palette {
    static let bg=Color(red:0.055,green:0.084,blue:0.14)
    static let sidebar=Color(red:0.07,green:0.115,blue:0.18)
    static let card=Color(red:0.103,green:0.16,blue:0.235)
    static let outline=Color(red:0.20,green:0.29,blue:0.36)
    static let muted=Color(red:0.62,green:0.71,blue:0.79)
    static let mint=Color(red:0.27,green:0.89,blue:0.72)
    static let blue=Color(red:0.24,green:0.67,blue:0.93)
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
        panel.prompt=incoming ? "Nhập" : "Xuất"
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
            .foregroundStyle(selected ? Palette.mint : Color.white.opacity(0.78))
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
                    hero
                    HStack(spacing:16) { statusCard; privacyCard }
                    VStack(alignment:.leading,spacing:8) {
                        Text("CÁ NHÂN HÓA").font(.system(size:11,weight:.bold))
                            .tracking(2).foregroundStyle(Palette.muted)
                        VStack(spacing:0) {
                            PreferenceRow(icon:"character.cursor.ibeam",title:"Nhận diện tiếng Anh",
                                          description:"Bảo vệ từ tiếng Anh ngay khi nhập",
                                          checked:$prefs.smartEnglish)
                            Divider().overlay(Palette.outline)
                            PreferenceRow(icon:"arrow.uturn.backward",title:"Khôi phục từ không hợp lệ",
                                          description:"Tự khôi phục phím gốc ở cuối từ",
                                          checked:$prefs.restoreInvalid)
                        }
                        .padding(.horizontal,20)
                        .background(Palette.card,in:RoundedRectangle(cornerRadius:18))
                    }
                    VStack(alignment:.leading,spacing:12) {
                        Text(tr("CÀI ĐẶT NÂNG CAO","ADVANCED SETTINGS")).font(.system(size:11,weight:.bold))
                            .tracking(2).foregroundStyle(Palette.muted)
                        HStack {
                            Text(tr("Kiểu gõ","Typing method"))
                            Spacer()
                            Picker("Kiểu gõ",selection:$prefs.inputMethod) {
                                Text("Telex").tag("Telex");Text("VNI").tag("VNI")
                            }.labelsHidden().frame(width:145)
                        }
                        HStack {
                            Text(tr("Ưu tiên ngôn ngữ","Language priority"))
                            Spacer()
                            Picker("Ưu tiên",selection:$prefs.languagePriority) {
                                Text("Cân bằng").tag("Balanced")
                                Text("Tiếng Việt").tag("Vietnamese")
                                Text("Tiếng Anh").tag("English")
                            }.labelsHidden().frame(width:165)
                        }
                        HStack {
                            Text(tr("Ngôn ngữ giao diện","Interface language"))
                            Spacer()
                            Picker("UI",selection:$prefs.uiLanguage) {
                                Text("Tiếng Việt").tag("vi")
                                Text("English").tag("en")
                            }.labelsHidden().frame(width:165)
                        }
                        HStack {
                            Text(tr("Phím chuyển V/E","V/E shortcut"))
                            Spacer()
                            Picker("Phím tắt",selection:$prefs.hotkey) {
                                Text("Ctrl + Shift + Space").tag("Ctrl + Shift + Space")
                                Text("Ctrl + Option + V").tag("Ctrl + Option + V")
                            }.labelsHidden().frame(width:235)
                        }
                        Toggle(tr("Tự khởi động cùng macOS","Start with macOS"),isOn:$prefs.autoStart).tint(Palette.mint)
                        Toggle(tr("Gõ tắt tại ranh giới từ (tự chọn bật)","Expand snippets at word boundaries (opt-in)"),isOn:$prefs.snippetsEnabled).tint(Palette.mint)
                        Toggle(tr("Cấu hình riêng theo ứng dụng","Per-app profiles"),isOn:$prefs.profilesEnabled).tint(Palette.mint)
                        HStack {
                            Button(tr("Quản lý gõ tắt","Manage snippets")) {openEditor("snippets.tsv")}
                            Button(tr("Profile ứng dụng","Application profiles")) {openEditor("profiles.tsv")}
                            Button(tr("Ký tự nhanh","Symbols")) {showSymbols=true}
                        }.buttonStyle(.bordered)
                        HStack {
                            TextField("Nhập từ muốn xem gợi ý...",text:$spellingInput)
                                .textFieldStyle(.roundedBorder)
                            Button(tr("Gợi ý chính tả","Spelling suggestions")) {
                                spellingSuggestions=SpellAdvisor.suggest(spellingInput)
                            }
                        }.buttonStyle(.bordered)
                        Text(spellingSuggestions.isEmpty ? "Gợi ý offline theo yêu cầu, không tự sửa chữ." :
                            "Gợi ý: "+spellingSuggestions.joined(separator:" · "))
                            .font(.caption).foregroundStyle(Palette.muted)
                        if !prefs.autoStartError.isEmpty {
                            Text(prefs.autoStartError).foregroundStyle(.orange).font(.caption)
                        }
                        Text("Ứng dụng bỏ qua (bundle ID, phân tách bằng dấu phẩy)")
                            .font(.system(size:11)).foregroundStyle(Palette.muted)
                        TextField("com.apple.Terminal, com.microsoft.VSCode",text:$prefs.excludedApps)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Button(tr("Xuất cấu hình","Export settings")) {prefs.transfer(false)}
                            Button(tr("Nhập cấu hình","Import settings")) {prefs.transfer(true)}
                            Button(tr("Kiểm tra bản mới","Check releases")) {
                                NSWorkspace.shared.open(URL(string:
                                    "https://github.com/muahacodon321-boop/TelexMiniMac/releases")!)
                            }
                        }.buttonStyle(.bordered)
                    }.padding(18).background(Palette.card,in:RoundedRectangle(cornerRadius:18))
                    VStack(alignment:.leading,spacing:9) {
                        Label("THỬ GÕ NGAY",systemImage:"keyboard")
                            .font(.system(size:11,weight:.bold)).tracking(1.2)
                            .foregroundStyle(Palette.muted)
                        TextField("Nhập thử tiếng Việt hoặc tiếng Anh…",text:$preview)
                            .textFieldStyle(.plain).font(.system(size:14))
                            .padding(14)
                            .background(Palette.card,in:RoundedRectangle(cornerRadius:12))
                        Text("Chọn nguồn nhập TelexMini trong macOS để thử chuyển đổi dấu.")
                            .font(.system(size:11)).foregroundStyle(Palette.muted)
                    }
                    HStack {
                        Text("Native macOS · Apple Silicon · Offline first")
                        Spacer()
                        Text("TelexMini 1.0 Preview")
                    }
                    .font(.system(size:10,weight:.medium)).foregroundStyle(Palette.muted)
                }
                .padding(28)
            }
            .background(Palette.bg)
        }
        .frame(minWidth:930,minHeight:640)
        .preferredColorScheme(.dark)
        .alert("Dữ liệu chưa hợp lệ",isPresented:Binding(
            get:{!validationError.isEmpty},set:{if !$0 {validationError=""}})) {
            Button("OK") {validationError=""}
        } message: {Text(validationError)}
        .sheet(isPresented:$showSymbols) {
            VStack(alignment:.leading,spacing:14) {
                Text("Ký tự nhanh").font(.title2.bold())
                Text("Chọn ký tự để sao chép, sau đó Command+V để chèn.")
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
                Text(file=="EnglishWords.txt" ? "Từ điển tiếng Anh" :
                     file=="VietnameseOverrides.txt" ? "Ưu tiên Telex" :
                     file=="snippets.tsv" ? "Gõ tắt" : "Cấu hình ứng dụng")
                    .font(.title2.bold())
                Text(file=="snippets.tsv" ? "Mỗi dòng: phím tắt a-z, Tab, nội dung thay thế. Ví dụ dc<Tab>được." :
                     file=="profiles.tsv" ? "Mỗi dòng: bundle-id<Tab>English/Vietnamese/Balanced." :
                     "Mỗi dòng một từ gồm a-z. Không ghi nhận nội dung đang gõ.")
                    .font(.caption).foregroundStyle(.secondary)
                TextEditor(text:$editingText).font(.system(.body,design:.monospaced))
                    .frame(minHeight:340)
                HStack {
                    Button("Hủy") {editingFile=nil}
                    Spacer()
                    Button("Lưu") {
                        let url=SettingsStore.directory.appendingPathComponent(file)
                        if file=="snippets.tsv" {
                            guard ProductivityCore.validateSnippets(editingText) != nil else {
                                validationError="Gõ tắt phải có phím a-z (2–48 ký tự), Tab, rồi nội dung."
                                return
                            }
                            try? ProductivityCore.save(editingText,to:file)
                        } else if file=="profiles.tsv" {
                            guard ProductivityCore.validateProfiles(editingText) != nil else {
                                validationError="Profile phải là bundle ID, Tab, English/Vietnamese/Balanced."
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
            Text("WORKSPACE").font(.system(size:10,weight:.bold))
                .tracking(1.4).foregroundStyle(Palette.muted)
            VStack(spacing:5) {
                SidebarButton(icon:"square.grid.2x2.fill",label:tr("Tổng quan","Overview"),action:{ section="dashboard" },selected:true)
                SidebarButton(icon:"text.badge.plus",label:tr("Từ điển tiếng Anh","English dictionary"),action:{ openEditor("EnglishWords.txt") })
                SidebarButton(icon:"character.book.closed",label:tr("Ưu tiên Telex","Telex overrides"),action:{ openEditor("VietnameseOverrides.txt") })
                SidebarButton(icon:"arrow.clockwise",label:tr("Nạp lại từ điển","Reload dictionaries"),action:{
                    // Input-source process loads preferences/dictionary on its next activation.
                    prefs.signalReload()
                })
            }
            Spacer()
            VStack(alignment:.leading,spacing:12) {
                Image(systemName:"lock.shield.fill").font(.system(size:20)).foregroundStyle(Palette.mint)
                Text("PRIVATE BY DESIGN").font(.system(size:10,weight:.bold))
                    .tracking(1.3).foregroundStyle(Palette.muted)
                Text("Không gửi phím đã gõ lên mạng. Không lưu mật khẩu hay lịch sử gõ.")
                    .font(.system(size:11)).foregroundStyle(.white.opacity(0.75))
                    .lineSpacing(5)
            }
            .padding(16).frame(maxWidth:.infinity,alignment:.leading)
            .background(Palette.card,in:RoundedRectangle(cornerRadius:14))
            Text("BUILT FOR macOS").font(.system(size:10,weight:.medium))
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
                Text("OVERVIEW / BẢNG ĐIỀU KHIỂN")
                    .font(.system(size:10,weight:.bold)).tracking(1.8)
                    .foregroundStyle(Palette.mint)
                Text(tr("Gõ theo cách của bạn.","Type your way."))
                    .font(.system(size:27,weight:.bold,design:.rounded))
                Text(tr("Hai ngôn ngữ. Một trải nghiệm liền mạch.","Two languages, one seamless experience."))
                    .font(.system(size:13)).foregroundStyle(Palette.muted)
            }
            Spacer()
            Label("LOCAL & SECURE",systemImage:"checkmark.shield.fill")
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
                Text("SMART BILINGUAL TYPING").font(.system(size:11,weight:.bold))
                    .tracking(1.9).foregroundStyle(.white.opacity(0.8))
                Text("Tiếng Việt tự nhiên.\nEnglish liền mạch.")
                    .font(.system(size:24,weight:.bold,design:.rounded))
                    .lineSpacing(5).fixedSize(horizontal:false,vertical:true)
                Text("Telex tức thời · Từ điển offline · Không gián đoạn")
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
                Text("TỪ ĐIỂN OFFLINE").font(.system(size:10,weight:.bold))
                    .foregroundStyle(Palette.muted)
                Text(wordCount+" từ").font(.system(size:20,weight:.bold))
                Text("Có thể mở rộng").font(.system(size:11))
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
                Text("MẬT KHẨU").font(.system(size:10,weight:.bold))
                    .foregroundStyle(Palette.muted)
                Text("Hệ thống bảo vệ").font(.system(size:17,weight:.bold))
                Text("Không xử lý Secure Input").font(.system(size:11))
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
