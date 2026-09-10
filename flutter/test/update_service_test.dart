import 'package:flutter_test/flutter_test.dart';
import 'package:dracondex/data/services/update_service.dart';

void main() {
  group('UpdateService.parseRelease', () {
    test('parses a real-shaped payload', () {
      final info = UpdateService.parseRelease({
        'tag_name': 'flutter-v2.2.0',
        'html_url': 'https://github.com/ZYDRAXYL/DraconDex-WEB/releases/tag/flutter-v2.2.0',
        'body': 'Release notes here',
      });
      expect(info, isNotNull);
      expect(info!.version, '2.2.0');
      expect(info.url, 'https://github.com/ZYDRAXYL/DraconDex-WEB/releases/tag/flutter-v2.2.0');
      expect(info.notes, 'Release notes here');
    });

    test('strips the flutter-v prefix regardless of case', () {
      final info = UpdateService.parseRelease({'tag_name': 'FLUTTER-V3.0', 'html_url': '', 'body': ''});
      expect(info!.version, '3.0');
    });

    test('rejects a malformed tag', () {
      expect(UpdateService.parseRelease({'tag_name': 'not-a-version', 'html_url': '', 'body': ''}), isNull);
      expect(UpdateService.parseRelease({'tag_name': '', 'html_url': '', 'body': ''}), isNull);
      expect(UpdateService.parseRelease({'tag_name': 'flutter-v', 'html_url': '', 'body': ''}), isNull);
    });

    test('rejects a bare v* tag — that is the Electron app\'s own release namespace', () {
      // A plain "vX.Y.Z" tag belongs to electron/src/db/update.js's release
      // train, not this app's. Accepting it here would let this app offer a
      // desktop installer as an "update" for the phone app.
      expect(UpdateService.parseRelease({
        'tag_name': 'v4.10.1',
        'html_url': 'https://github.com/ZYDRAXYL/DraconDex-WEB/releases/tag/v4.10.1',
        'body': '',
      }), isNull);
    });

    test('falls back to the releases prefix when html_url points outside the repo', () {
      final info = UpdateService.parseRelease({
        'tag_name': 'flutter-v1.0.0',
        'html_url': 'https://github.com/evil/repo/releases/tag/flutter-v1.0.0',
        'body': '',
      });
      expect(info!.url, UpdateService.releaseUrlPrefix);
    });

    test('rejects a lookalike host smuggled past a naive prefix check', () {
      final info = UpdateService.parseRelease({
        'tag_name': 'flutter-v1.0.0',
        'html_url': 'https://github.com.evil.example/ZYDRAXYL/DraconDex-WEB/releases/tag/flutter-v1.0.0',
        'body': '',
      });
      expect(info!.url, UpdateService.releaseUrlPrefix);
    });

    test('truncates release notes to 4000 characters', () {
      final info = UpdateService.parseRelease({
        'tag_name': 'flutter-v1.0.0',
        'html_url': '',
        'body': 'x' * 5000,
      });
      expect(info!.notes.length, 4000);
    });

    test('captures download assets, dropping ones missing a name or pointing off-repo', () {
      const base = 'https://github.com/ZYDRAXYL/DraconDex-WEB/releases/download/flutter-v2.4.0';
      final info = UpdateService.parseRelease({
        'tag_name': 'flutter-v2.4.0',
        'html_url': '',
        'body': '',
        'assets': [
          {'name': 'DraconDex-2.4.0-release.apk', 'browser_download_url': '$base/DraconDex-2.4.0-release.apk'},
          {'name': 'checksums-sha256.txt', 'browser_download_url': '$base/checksums-sha256.txt'},
          // Off-repo: these get fetched, and the APK is handed to Android's
          // package installer, so an unexpected host is dropped outright.
          {'name': 'evil.apk', 'browser_download_url': 'https://example.com/evil.apk'},
          {'name': 'evil2.apk', 'browser_download_url': 'https://github.com.evil.example/ZYDRAXYL/DraconDex-WEB/releases/download/x/evil2.apk'},
          {'name': 'evil3.apk', 'browser_download_url': 'https://github.com/evil/repo/releases/download/x/evil3.apk'},
          {'name': '', 'browser_download_url': '$base/x'},
          {'browser_download_url': '$base/y'},
        ],
      });
      expect(info!.assets.length, 2);
      expect(info.assets.first.name, 'DraconDex-2.4.0-release.apk');
      expect(UpdateService.apkAsset(info)!.downloadUrl, '$base/DraconDex-2.4.0-release.apk');
      expect(UpdateService.checksumsAsset(info)!.downloadUrl, '$base/checksums-sha256.txt');
    });
  });

  group('UpdateService.pickOwnRelease', () {
    Map<String, dynamic> published(String tag, {bool draft = false, bool prerelease = false}) => {
          'tag_name': tag,
          'draft': draft,
          'prerelease': prerelease,
          'body': '',
          'html_url': 'https://github.com/ZYDRAXYL/DraconDex-WEB/releases/tag/$tag',
        };

    test('skips a more-recent electron v* release and finds the flutter one', () {
      final list = [published('v4.10.1'), published('flutter-v2.4.0'), published('v4.9.0')];
      final r = UpdateService.pickOwnRelease(list);
      expect(r!.version, '2.4.0');
    });

    test('skips draft and prerelease entries', () {
      final list = [
        published('flutter-v3.0.0', draft: true),
        published('flutter-v2.9.0', prerelease: true),
        published('flutter-v2.8.0'),
      ];
      expect(UpdateService.pickOwnRelease(list)!.version, '2.8.0');
    });

    test('returns null when only foreign or malformed releases exist', () {
      expect(UpdateService.pickOwnRelease([published('v4.10.1')]), isNull);
      expect(UpdateService.pickOwnRelease([published('not-a-version')]), isNull);
      expect(UpdateService.pickOwnRelease([]), isNull);
    });

    // The bug this ranking replaced, reproduced from the real feed. GET
    // /releases is ordered by created_at, and a release's created_at is the
    // date of the COMMIT its tag points at — not the date it was published.
    // flutter-v2.10.0 and flutter-v2.10.1 were both cut on older commits, so
    // GitHub listed them BELOW flutter-v2.9.0, and "first match wins" answered
    // 2.9.0. Every 2.9 install was told it was on the latest version while
    // 2.10.1 was already out.
    test('ranks by version, not by the order GitHub returns', () {
      final list = [
        published('v4.12.0'),
        published('v4.11.0'),
        published('flutter-v2.9.0'),
        published('flutter-v2.8.1'),
        published('flutter-v2.8.0'),
        published('flutter-v2.10.1'),
        published('flutter-v2.10.0'),
        published('flutter-v2.7.0'),
      ];
      expect(UpdateService.pickOwnRelease(list)!.version, '2.10.1');
    });

    test('compares version parts numerically, not as text', () {
      // 2.9.0 sorts after 2.10.0 as a string, and comes first in the list.
      final list = [published('flutter-v2.9.0'), published('flutter-v2.10.0')];
      expect(UpdateService.pickOwnRelease(list)!.version, '2.10.0');
    });
  });

  // ZYDRAXYL/DraconDex-APP is private: api.github.com answers 404 to every
  // install, and _fetchLatest() turns any non-200 into "no update", so
  // pointing the feed back at it silently disables the update check for
  // everyone. Releases are mirrored to the public ZYDRAXYL/DraconDex-WEB.
  group('UpdateService release feed', () {
    test('is pinned to the public release mirror, not the private app repo', () {
      expect(UpdateService.releaseUrlPrefix, 'https://github.com/ZYDRAXYL/DraconDex-WEB/releases');
      expect(UpdateService.assetUrlPrefix, 'https://github.com/ZYDRAXYL/DraconDex-WEB/releases/download/');
    });

    test('rejects an asset served from the private app repo', () {
      final info = UpdateService.parseRelease({
        'tag_name': 'flutter-v2.10.1',
        'html_url': '',
        'body': '',
        'assets': [
          {
            'name': 'DraconDex-2.10.1-release.apk',
            'browser_download_url':
                'https://github.com/ZYDRAXYL/DraconDex-APP/releases/download/flutter-v2.10.1/DraconDex-2.10.1-release.apk',
          },
        ],
      });
      expect(info!.assets, isEmpty);
    });
  });

  group('UpdateService checksum assets', () {
    UpdateInfo release(List<Map<String, String>> assets) => UpdateService.parseRelease({
          'tag_name': 'flutter-v2.8.0',
          'html_url': '',
          'body': '',
          'assets': [
            for (final a in assets) {'name': a['name'], 'browser_download_url': a['url']},
          ],
        })!;

    const base = 'https://github.com/ZYDRAXYL/DraconDex-WEB/releases/download/flutter-v2.8.0';

    test('finds the checksums file among the release assets', () {
      final info = release([
        {'name': 'DraconDex-2.8.0-release.apk', 'url': '$base/DraconDex-2.8.0-release.apk'},
        {'name': 'checksums-sha256.txt', 'url': '$base/checksums-sha256.txt'},
      ]);
      expect(UpdateService.checksumsAsset(info)!.downloadUrl, '$base/checksums-sha256.txt');
    });

    test('is null for a release published before checksums were attached', () {
      final info = release([
        {'name': 'DraconDex-2.8.0-release.apk', 'url': '$base/DraconDex-2.8.0-release.apk'},
      ]);
      expect(UpdateService.checksumsAsset(info), isNull);
    });
  });

  group('UpdateService.expectedSha256', () {
    // Verbatim `sha256sum *` output shape from the "Collect release assets"
    // step in .github/workflows/build-apk.yml (two spaces, text mode).
    const real = '677a2c2e53e194b677f057a13d3aa186d955664092acb48cd8c8fbeb6faa7b7d  DraconDex-2.8.0-arm64-v8a-release.apk\n'
        '3db9152a63492aa4b7d6048db8caaec88c2135dba87b70236cc4e8b16b8b8815  DraconDex-2.8.0-armeabi-v7a-release.apk\n'
        '8b50fd53b4a23b2122915357dac110ce196b63fde2146f7201aed3e194a5db6f  DraconDex-2.8.0-release.apk\n'
        '46fc8d0a41e2bb0ea3467fefd86604ee0fcb0cc2ceae056f5556ca6c37ef12f1  DraconDex-2.8.0-x86_64-release.apk\n';

    test('picks the universal APK line, not a per-ABI one that shares a prefix', () {
      expect(
        UpdateService.expectedSha256(real, 'DraconDex-2.8.0-release.apk'),
        '8b50fd53b4a23b2122915357dac110ce196b63fde2146f7201aed3e194a5db6f',
      );
    });

    test('accepts binary-mode output and uppercase digests', () {
      expect(
        UpdateService.expectedSha256('${'A' * 64} *app.apk', 'app.apk'),
        'a' * 64,
      );
    });

    test('is null when the file is not listed or the text is not a checksums file', () {
      expect(UpdateService.expectedSha256(real, 'DraconDex-9.9.9-release.apk'), isNull);
      expect(UpdateService.expectedSha256('404: Not Found', 'DraconDex-2.8.0-release.apk'), isNull);
      expect(UpdateService.expectedSha256('', 'app.apk'), isNull);
    });

    test('ignores a short (non-sha256) digest rather than trusting it', () {
      expect(UpdateService.expectedSha256('deadbeef  app.apk', 'app.apk'), isNull);
    });
  });

  group('UpdateService.isNewerVersion', () {
    test('detects a newer patch/minor/major version', () {
      expect(UpdateService.isNewerVersion('2.2.1', '2.2.0'), isTrue);
      expect(UpdateService.isNewerVersion('2.3.0', '2.2.0'), isTrue);
      expect(UpdateService.isNewerVersion('3.0.0', '2.2.0'), isTrue);
    });

    test('is false for an equal or older version', () {
      expect(UpdateService.isNewerVersion('2.2.0', '2.2.0'), isFalse);
      expect(UpdateService.isNewerVersion('2.1.0', '2.2.0'), isFalse);
    });

    test('ignores Flutter build-number suffixes on the local version', () {
      // pubspec versions look like "2.2.0+2" — the +build part must not be
      // compared as if it were a fourth version segment.
      expect(UpdateService.isNewerVersion('2.2.0', '2.2.0+7'), isFalse);
      expect(UpdateService.isNewerVersion('2.3.0', '2.2.0+7'), isTrue);
    });

    test('ignores a -n prerelease suffix on the remote tag', () {
      expect(UpdateService.isNewerVersion('2.2.0-1', '2.1.0'), isTrue);
      expect(UpdateService.isNewerVersion('2.2.0-1', '2.2.0'), isFalse);
    });

    test('pads missing segments with zero', () {
      expect(UpdateService.isNewerVersion('2.2', '2.2.0'), isFalse);
      expect(UpdateService.isNewerVersion('2.2.1', '2.2'), isTrue);
    });
  });
}
