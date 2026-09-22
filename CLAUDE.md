# CLAUDE.md — DraconDex-APK

Guidance for Claude Code working in this repo. Read `chain/README.md` and the
`multi-repository-architecture` skill first if you have not.

## What this is

The **Flutter front-end** for Android and iOS. It was `flutter/` inside the
DraconDex monorepo until the 2026-09-10 split; the directory prefix is unchanged,
because `pubspec.yaml` declares its assets relative to its own package dir.

Riverpod-based, structured under `flutter/lib/{core,data,providers,widgets,features}/`.
It opens the same SQLite vault format as the desktop app, and it **does have** the
v3 module-tree system: `data/dao/module_dao.dart` ("Data access for the v3 module
system"), the nest tree and builder shell under `features/builder/`, and the kind
registry `moduleKindInfo` in `data/models/module_model.dart` — where all 15 kinds
are `contentImplemented: true`.

Eleven of them have a dedicated editor under `features/hub/content/`. The other
four return `null` from `moduleContentFor()` for reasons that are deliberate, not
gaps: `inspector` and `drafter` fall back to the shared notes field, which is what
the desktop app does too (both write `module.description`), and `collector` is a
folder with no content area. Only **`manager` genuinely differs** — it is treated
as a folder here, while the desktop app gives it a four-view container.

**`moduleKindInfo`'s `contentImplemented` flag and `moduleContentFor()` are the
source of truth for what is ported — read them, not prose.** This paragraph used
to say there was no `module` table here at all; that was copied into
`DraconDex-APP/docs/V5.md` and used to route v5 work away from this repo for
several sessions before anyone checked it against the code.

Still genuinely missing on this side: the legacy modules (Hero, Writer, Scribe,
Sage, Artisan, IDE shell) and wikilinks — nothing under `flutter/lib` implements
`[[...]]` parsing or writes the `wiki_link` index.

## This tree also builds the PWA — do not fork it

`flutter/lib/` serves **both** Android/iOS and the browser, splitting by platform
through conditional exports:

```dart
// flutter/lib/core/database/db_factory.dart
export 'db_factory_stub.dart'
  if (dart.library.io) 'db_factory_io.dart'
  if (dart.library.js_interop) 'db_factory_web.dart';
```

The same pattern repeats for `file_export`, `temp_file`, `apk_installer` and
`google_auth_platform`. `ZYDRAXYL/DraconDex-PWA` is a *build target* of this tree
— it fetches this repo at a pinned commit and compiles it for the web. **Never
copy `lib/` into PWA.** Forking it diverges five conditional-import families and
~100 Dart files, and every later fix has to be made twice.

A change that only breaks the web target passes `flutter analyze` and the APK
build. `build-web.yml` exists precisely to catch that — do not skip it.

## The vendored files are not yours to edit

```
flutter/lib/core/database/vault_schema.g.dart      generated in DraconDex-SDB
flutter/lib/data/services/supabase_schema.dart     generated in DraconDex-SDB
flutter/assets/{images,fonts}/                     masters live in DraconDex-SDB
sdb.lock.json                                      which SDB release they came from
```

```bash
node tools/sdb-check.mjs     # do the vendored files match the pinned release?
node tools/sdb-vendor.mjs    # re-fetch, or --ref sdb-vX.Y.Z to move the pin
```

This one check replaces the three the monorepo ran (assets mirror, generated
schema, generated Supabase constants) — all three compared a generated file
against a source that is in another repository now. It also catches what none of
them did: SDB publishing a new artifact for this repo that nobody vendored.

The asset **masters** are deliberately not vendored here. `flutter/assets/` is
already a 6.6 MB committed mirror; carrying both would duplicate ~13 MB of
identical bytes. The manifest verifies the mirror by SHA-256 instead.

## Dev workflow

```bash
cd flutter
flutter pub get
flutter analyze          # this app's main automated check
flutter test
flutter run              # a connected device or emulator

flutter build apk --release --split-per-abi   # per-ABI, recommended
flutter build apk --release                   # universal
```

`flutter/l10n.yaml.disabled` — l10n codegen is deliberately off and
`app_localizations*.dart` are committed by hand. 13 ARB locales here against the
desktop app's 18.

## Versions and releases

`flutter/pubspec.yaml`'s `version:` is the app's real version and what the
`flutter-v*` tag follows. The root `package.json` exists only to hang the chain
tooling's scripts on; its number mirrors the pubspec for reference and is not
what gets built.

**`flutter-v*` is this repo's namespace and `v*` belongs to DraconDex-EXE.**
Never publish under `v*` here. Both apps' update checkers read one shared release
list on DraconDex-WEB and filter by prefix — an Electron tag parses as a valid
version once the leading `v` is stripped, so getting this wrong offers a Windows
installer as an Android update. That is not hypothetical; it is why the prefix
exists.

## Not covered here

`run-dracondex`, `dracondex-module-style` and `dracondex-file-arch` are
Electron-only and are deliberately not mirrored into this repo. A Flutter
equivalent would be a new skill, not a port of those.

## Where the project's docs live

`docs/` stayed in `ZYDRAXYL/DraconDex-APP` — including `PWA.md` (storage,
`sqflite_common_ffi_web`, the `dart:io` splits) and `UPDATE.md` (the release
mirror and the signing keystore). They are in Thai; that is intentional. So does
the pre-split history of every file here.
