import 'dart:convert';
import 'dart:io';

class ReleaseInfo {
  const ReleaseInfo(this.tag, this.url, this.newer);
  final String tag;
  final String url;
  final bool newer;
}

/// Opt-in check only. Does not download or execute arbitrary binaries.
class ReleaseService {
  static const currentVersion = '2.4.1-rc.1';
  static const releasesUrl = 'https://github.com/freshlovedev/TelexMiniMac/releases';
  static const endpoint = 'https://api.github.com/repos/freshlovedev/TelexMiniMac/releases/latest';

  static List<int> _parts(String value) {
    final clean = value.trim().replaceFirst(RegExp(r'^[vV]'), '').split(RegExp(r'[-+]')).first;
    return clean.split('.').map((part) => int.tryParse(part) ?? 0).toList();
  }

  static bool isNewer(String latest, String installed) {
    final a = _parts(latest), b = _parts(installed);
    for(var i=0;i<3;i++) {
      final x=i<a.length?a[i]:0, y=i<b.length?b[i]:0;
      if(x!=y)return x>y;
    }
    // A stable release outranks a prerelease with the same core version.
    final candidate = latest.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
    final current = installed.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
    final candidatePre = candidate.contains('-') ? candidate.split('-').skip(1).join('-') : '';
    final currentPre = current.contains('-') ? current.split('-').skip(1).join('-') : '';
    if(candidatePre.isEmpty) return currentPre.isNotEmpty;
    if(currentPre.isEmpty) return false;
    final candidateTokens = candidatePre.split('.');
    final currentTokens = currentPre.split('.');
    for(var i=0;i<candidateTokens.length && i<currentTokens.length;i++) {
      final a= int.tryParse(candidateTokens[i]);
      final b= int.tryParse(currentTokens[i]);
      if(a!=null && b!=null && a!=b) return a>b;
      if(a!=null && b==null) return false;
      if(a==null && b!=null) return true;
      if(a==null && b==null) {
        final compare=candidateTokens[i].compareTo(currentTokens[i]);
        if(compare!=0) return compare>0;
      }
    }
    return candidateTokens.length>currentTokens.length;
  }

  static Future<ReleaseInfo> check() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds:6);
    client.userAgent = 'TelexMini-Windows/$currentVersion';
    try {
      final req = await client.getUrl(Uri.parse(endpoint));
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response = await req.close().timeout(const Duration(seconds:8));
      if(response.statusCode != HttpStatus.ok) {
        throw HttpException('Release API returned HTTP ${response.statusCode}');
      }
      final raw = await utf8.decoder.bind(response).join();
      final json = jsonDecode(raw);
      if(json is! Map || json['tag_name'] is! String) throw const FormatException('Invalid release response');
      final tag=json['tag_name'] as String;
      final candidate=json['html_url'];
      final url=candidate is String && candidate.startsWith(releasesUrl)
          ? candidate : releasesUrl;
      return ReleaseInfo(tag,url,isNewer(tag,currentVersion));
    } finally {
      client.close(force:true);
    }
  }

  static Future<void> openReleases([String url = releasesUrl]) async {
    if(!Platform.isWindows || !url.startsWith(releasesUrl)) {
      throw const FormatException('Unsupported releases URL');
    }
    await Process.start('explorer.exe',[url],mode:ProcessStartMode.detached);
  }
}
