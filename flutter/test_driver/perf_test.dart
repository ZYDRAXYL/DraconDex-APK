// Procress 19 part 1 — the host side of the device numbers: sends the stress
// vault to test_driver/perf_app.dart, walks the screens Procress 19 names
// (open a Nexus · Nest · Classifier table / detail / grid · one write ·
// import), and traces each step on the engine timeline so the frame times
// are the device's, not a guess from the host.
//
//   flutter drive --profile --driver=test_driver/perf_test.dart --target=test_driver/perf_app.dart
//
// Prints a table and writes build/perf/apk-device.json. "open" is wall time
// from the route change to the first frame showing the page's content, seen
// from the host, so it carries one driver round trip (a few ms) on top.
// Asserts nothing: these are baselines (part 1), not budgets (part 8).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  late FlutterDriver d;
  final rows = <Map<String, Object?>>[];
  late Map<String, Object?> ids;

  setUpAll(() async {
    d = await FlutterDriver.connect();
    await d.waitUntilFirstFrameRasterized();
  });

  tearDownAll(() async {
    final out = File('build/perf/apk-device.json')..createSync(recursive: true);
    out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'import': ids, 'steps': rows}));
    String f(Object? v) => v is num ? v.toStringAsFixed(1) : '${v ?? ''}';
    // ignore: avoid_print
    print([
      '',
      '${'step'.padRight(34)} ${'wall ms'.padLeft(8)} ${'frames'.padLeft(6)} '
          '${'build avg/p90/worst'.padLeft(22)} ${'raster avg/p90/worst'.padLeft(22)} >16ms',
      for (final r in rows)
        '${(r['step'] as String).padRight(34)} ${f(r['wall']).padLeft(8)} ${f(r['frames']).padLeft(6)} '
            '${'${f(r['buildAvg'])}/${f(r['buildP90'])}/${f(r['buildWorst'])}'.padLeft(22)} '
            '${'${f(r['rasterAvg'])}/${f(r['rasterP90'])}/${f(r['rasterWorst'])}'.padLeft(22)} '
            '${r['missedBuild']}+${r['missedRaster']}',
      '',
    ].join('\n'));
    await d.close();
  });

  /// Runs [body] under a timeline trace and keeps the frame summary.
  Future<void> step(String name, Future<void> Function() body) async {
    final sw = Stopwatch();
    final tl = await d.traceAction(() async {
      sw.start();
      await body();
      sw.stop();
      // let the frames the step started finish inside the trace
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    // a step that drew nothing (a page at rest) has no frames to summarize
    final drew = tl.events?.any((e) => e.name == 'Frame' || e.name == 'GPURasterizer::Draw') ?? false;
    final s = drew ? TimelineSummary.summarize(tl).summaryJson : const <String, Object?>{'frame_count': 0};
    rows.add({
      'step': name,
      'wall': sw.elapsedMicroseconds / 1000,
      'frames': s['frame_count'],
      'buildAvg': s['average_frame_build_time_millis'],
      'buildP90': s['90th_percentile_frame_build_time_millis'],
      'buildWorst': s['worst_frame_build_time_millis'],
      'rasterAvg': s['average_frame_rasterizer_time_millis'],
      'rasterP90': s['90th_percentile_frame_rasterizer_time_millis'],
      'rasterWorst': s['worst_frame_rasterizer_time_millis'],
      'missedBuild': s['missed_frame_build_budget_count'],
      'missedRaster': s['missed_frame_rasterizer_budget_count'],
    });
  }

  Future<void> open(String name, String location, String waitText) => step(name, () async {
        await d.requestData('go:$location');
        await d.waitFor(find.text(waitText), timeout: const Duration(seconds: 30));
      });

  Future<void> fling(String name, String onText, double dy) => step(name, () async {
        // one fling, then its momentum: a second drag from [onText] would
        // look for a row the first one already scrolled away
        await d.scroll(find.text(onText), 0, dy, const Duration(milliseconds: 300),
            timeout: const Duration(seconds: 20));
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      });

  test('stress vault on the device', () async {
    final text = File('test/fixtures/stress-v2.json').readAsStringSync();
    const size = 60000;
    for (var i = 0; i < text.length; i += size) {
      await d.requestData('chunk:${text.substring(i, i + size > text.length ? text.length : i + size)}');
    }
    late String reply;
    await step('import snapshot (schema+decode+apply)', () async {
      reply = await d.requestData('import', timeout: const Duration(minutes: 2));
    });
    ids = jsonDecode(reply) as Map<String, Object?>;
    final n = ids['nexus'], cls = ids['classifier'], folder = ids['folder'];

    await open('open Nexus (21 top-level rows)', '/hub/$n', 'Folder 0');
    await fling('Nest: scroll top level', 'Folder 2', -1200);
    await open('open Folder 0 (25 children)', '/hub/$n/module/$folder', 'Doc 0');

    await open('Classifier 3,000: table', '/hub/$n/module/$cls', 'Object 0');
    // frames drawn while nothing happens: ~0 on a page at rest
    await step('Classifier table: idle 1 s', () => Future<void>.delayed(const Duration(seconds: 1)));
    await fling('Classifier table: scroll', 'Object 1', -3000);
    await step('one value write (patched in place)', () async {
      for (var i = 0; i < 5; i++) {
        await d.requestData('set');
      }
    });

    for (final preset in const ['listDetail', 'grid']) {
      // off the Classifier page, so the next open builds it from scratch
      await d.requestData('go:/hub/$n/module/$folder');
      await d.waitFor(find.text('Doc 0'), timeout: const Duration(seconds: 30));
      await d.requestData('preset:$preset');
      await open('Classifier 3,000: $preset', '/hub/$n/module/$cls', 'Object 0');
      await fling('Classifier $preset: scroll', 'Object 1', -3000);
    }
    await d.requestData('preset:table');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
