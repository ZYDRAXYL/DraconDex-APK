<h1 align="center">DraconDex-APK</h1>

<p align="center">
  <a href="https://github.com/ZYDRAXYL/DraconDex-APP">DraconDex</a> for Android
  and iOS — the Flutter front-end over the shared SQLite vault schema.
</p>

---

## What this is

DraconDex is a world-building manager for novelists: characters, places,
timelines, relationships and Obsidian-style markdown notes with `[[wikilinks]]`,
all in local SQLite. No account, no cloud, no internet required.

This repository is its **mobile front-end**. It was `flutter/` inside the
DraconDex monorepo until 2026-09-10; the project is now seven repositories with
one job each.

| Runs on | Repository |
|---|---|
| Windows desktop | [DraconDex-EXE](https://github.com/ZYDRAXYL/DraconDex-EXE) — Electron + vanilla JS |
| Android / iOS | **this repo** — Flutter + Riverpod |
| Browser / PWA | [DraconDex-PWA](https://github.com/ZYDRAXYL/DraconDex-PWA) — builds both of the above for the web |
| The schema itself | [DraconDex-SDB](https://github.com/ZYDRAXYL/DraconDex-SDB) — one `vault.sql`, generated for each side |
| The hub | [DraconDex-APP](https://github.com/ZYDRAXYL/DraconDex-APP) — docs, the chain contract, shared tooling |

> This side is **behind** the desktop app. There is no `module` table here, so
> the v3 module tree does not exist yet, and Hero / Writer / Scribe / Sage /
> Artisan / wikilinks are not implemented either.
>
> ฝั่งนี้ยังพัฒนาตามหลังเวอร์ชัน Electron อยู่

## This tree builds the PWA too

`flutter/lib/` serves both the mobile apps and the browser, splitting by platform
through conditional exports (`db_factory.dart` exports `_stub` / `_io` / `_web`,
and the same for `file_export`, `temp_file`, `apk_installer`,
`google_auth_platform`). DraconDex-PWA compiles *this* source; it holds no Dart
of its own.

A change that only breaks the web target passes `flutter analyze` and the APK
build — which is exactly why `build-web.yml` runs on every PR.

## Building

Requirements: Flutter SDK 3.44.4+, Android Studio with Android SDK 24+, and a
device with USB debugging on or an emulator.

```bash
cd flutter
flutter pub get
flutter doctor       # the Android toolchain should show no red X
flutter run

flutter build apk --release --split-per-abi   # per-ABI, smaller (recommended)
flutter build apk --release                   # universal
```

APKs land in `flutter/build/app/outputs/flutter-apk/`. You can also build without
a local Flutter setup via the **Build Flutter APK** workflow (Actions → run
workflow → download the `release-apks` artifact).

Install manually with
`adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, or copy
the APK to the device and open it.

## The schema is vendored, not authored here

```
flutter/lib/core/database/vault_schema.g.dart     generated in DraconDex-SDB
flutter/lib/data/services/supabase_schema.dart    generated in DraconDex-SDB
flutter/assets/{images,fonts}/                    masters live in DraconDex-SDB
sdb.lock.json                                     which SDB release they came from
```

```bash
node tools/sdb-check.mjs    # do the vendored files match the pinned release?
node tools/sdb-vendor.mjs   # re-fetch, or --ref sdb-vX.Y.Z to move the pin
```

Do not hand-edit any of them — a schema change starts in DraconDex-SDB, and
`chained-updated` opens the PR that moves the pin here.

## Releases

Tag `flutter-vX.Y.Z`, matching `flutter/pubspec.yaml`'s `version:`.
`build-apk.yml` builds and signs the APKs, publishes the release, and mirrors it
to DraconDex-WEB — which is where the in-app update check reads from.

`v*` without the prefix belongs to DraconDex-EXE. Both apps filter one shared
release list by prefix, so publishing under the wrong one offers a Windows
installer as an Android update.

## Documentation

`docs/` lives in [DraconDex-APP](https://github.com/ZYDRAXYL/DraconDex-APP),
along with this repo's pre-split history. It is written in Thai — that is
intentional.

## License

MIT — see [LICENSE](LICENSE).
