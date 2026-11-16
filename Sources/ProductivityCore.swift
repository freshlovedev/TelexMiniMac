import Foundation

/// Offline, opt-in features. The parser never records typed words or opens
/// network connections; only user-authored rules are persisted.
enum ProductivityCore {
    static var folder:URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/TelexMini",isDirectory:true)
    }
    static let symbols=["→","←","↑","↓","✓","✕","•","…","°","₫","©","®","™",
                        "±","≠","≤","≥","∞","€","£","¥","—","–","♥","★","😊","👍","❤️"]
    static func read(_ file:String)->String {
        (try? String(contentsOf:folder.appendingPathComponent(file),encoding:.utf8)) ?? ""
    }
    static func validateSnippets(_ source:String)->[String:String]? {
        var result=[String:String]()
        for line in source.split(whereSeparator:\.isNewline) {
            if line.hasPrefix("#") {continue}
            let pieces=line.split(separator:"\t",omittingEmptySubsequences:false)
            guard pieces.count==2 else {return nil}
            let key=String(pieces[0]).trimmingCharacters(in:.whitespaces)
            let value=String(pieces[1])
            guard (2...48).contains(key.count),(1...1024).contains(value.count),
                  key.unicodeScalars.allSatisfy({($0.value>=65 && $0.value<=90) ||
                                                ($0.value>=97 && $0.value<=122)}) else {return nil}
            result[key.lowercased()]=value
            if result.count>256 {return nil}
        }
        return result
    }
    static func validateProfiles(_ source:String)->[String:String]? {
        var result=[String:String]()
        for line in source.split(whereSeparator:\.isNewline) {
            if line.hasPrefix("#") {continue}
            let pieces=line.split(separator:"\t",omittingEmptySubsequences:false)
            guard pieces.count==2 else{return nil}
            let name=String(pieces[0]).trimmingCharacters(in:.whitespaces).lowercased()
            let mode=String(pieces[1]).trimmingCharacters(in:.whitespaces)
            guard !name.isEmpty,name.count<=160,
                  ["English","Vietnamese","Balanced"].contains(mode),
                  name.unicodeScalars.allSatisfy({CharacterSet(charactersIn:"abcdefghijklmnopqrstuvwxyz0123456789-_.").contains($0)}) else {return nil}
            result[name]=mode
            if result.count>200{return nil}
        }
        return result
    }
    static func profile(for app:String?,rules:[String:String])->String {
        guard var app=app?.lowercased() else {return "Default"}
        if app.hasSuffix(".exe"){app=String(app.dropLast(4))}
        return rules[app] ?? "Default"
    }
    static func expand(_ word:String,rules:[String:String],enabled:Bool,
                       clipboardProvider:(()->String?)?=nil)->String? {
        guard enabled,let value=rules[word.lowercased()] else {return nil}
        // IMK has no guaranteed permission-free caret repositioning API after
        // text is committed. Never insert a literal {cursor} marker.
        guard !value.contains("{cursor}") else {return nil}
        let now=Date()
        let day=DateFormatter(),clock=DateFormatter(),dateTime=DateFormatter()
        for formatter in [day,clock,dateTime] {
            formatter.locale=Locale(identifier:"en_US_POSIX")
        }
        day.dateFormat="yyyy-MM-dd"
        clock.dateFormat="HH:mm"
        dateTime.dateFormat="yyyy-MM-dd HH:mm"
        var expanded=value.replacingOccurrences(of:"{date}",with:day.string(from:now))
                          .replacingOccurrences(of:"{time}",with:clock.string(from:now))
                          .replacingOccurrences(of:"{datetime}",with:dateTime.string(from:now))
        // Clipboard is read ONLY when the user triggers a rule with this macro.
        if expanded.contains("{clipboard}") {
            guard let clipboard=clipboardProvider?() else {return nil}
            let singleLine=String(clipboard.prefix(1024))
                .replacingOccurrences(of:"[\\r\\n\\t]",with:" ",
                                      options:.regularExpression)
            expanded=expanded.replacingOccurrences(of:"{clipboard}",with:singleLine)
        }
        return expanded.replacingOccurrences(of:"\\r\\n",with:"\n")
                       .replacingOccurrences(of:"\\n",with:"\n")
                       .replacingOccurrences(of:"\\t",with:"\t")
    }
    static func save(_ text:String,to filename:String)throws {
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        try text.write(to:folder.appendingPathComponent(filename),atomically:true,encoding:.utf8)
    }
}
