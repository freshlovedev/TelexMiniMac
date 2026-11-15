import 'package:flutter_test/flutter_test.dart';
import 'package:telexmini_ui/src/release_service.dart';

void main() {
  test('release comparison respects semantic version', () {
    expect(ReleaseService.isNewer('v2.2.0','2.1.0'),true);
    expect(ReleaseService.isNewer('v2.1.0','2.1.0'),false);
    expect(ReleaseService.isNewer('v2.0.9','2.1.0'),false);
    expect(ReleaseService.isNewer('v3.0.0','2.1.0'),true);
    expect(ReleaseService.isNewer('v2.1.1','2.1.0'),true);
    expect(ReleaseService.isNewer('v2.4.1','2.4.1-rc.1'),true);
    expect(ReleaseService.isNewer('v2.4.1-rc.2','2.4.1-rc.1'),true);
    expect(ReleaseService.isNewer('v2.4.1-rc.1','2.4.1'),false);
  });

  test('update source is fixed to the existing TelexMini releases feed', () {
    expect(ReleaseService.endpoint.startsWith('https://api.github.com/repos/'),true);
    expect(ReleaseService.releasesUrl.startsWith('https://github.com/'),true);
  });
}
