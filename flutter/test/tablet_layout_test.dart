import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dracondex/core/layout/breakpoints.dart';
import 'package:dracondex/features/builder/hub_location.dart';

void main() {
  group('ddxLayoutForSize', () {
    test('a phone held either way stays on the phone shell', () {
      // iPhone-class portrait, and the same device rotated: wide enough for a
      // rail on paper, far too short for one in practice.
      expect(ddxLayoutForSize(const Size(393, 852)), DdxLayoutClass.phone);
      expect(ddxLayoutForSize(const Size(852, 393)), DdxLayoutClass.phone);
    });

    test('tablets get the rail, and get the panel too once wide enough', () {
      // iPad mini and iPad 11" in portrait…
      expect(ddxLayoutForSize(const Size(744, 1133)), DdxLayoutClass.tablet);
      expect(ddxLayoutForSize(const Size(834, 1194)), DdxLayoutClass.tablet);
      // …and in landscape.
      expect(ddxLayoutForSize(const Size(1194, 834)), DdxLayoutClass.wide);
      expect(ddxLayoutForSize(const Size(1366, 1024)), DdxLayoutClass.wide);
    });

    test('an iPad in half Split View is a phone-shaped column', () {
      expect(ddxLayoutForSize(const Size(507, 1194)), DdxLayoutClass.phone);
      // Two thirds of the same screen is not.
      expect(ddxLayoutForSize(const Size(704, 1194)), DdxLayoutClass.tablet);
    });

    test('exactly on the boundary counts as tablet', () {
      expect(
        ddxLayoutForSize(const Size(kTabletMinWidth, kTabletMinHeight)),
        DdxLayoutClass.tablet,
      );
      expect(
        ddxLayoutForSize(const Size(kTabletMinWidth - 1, kTabletMinHeight)),
        DdxLayoutClass.phone,
      );
    });

    test('hasRail is every shell but the phone', () {
      expect(DdxLayoutClass.phone.hasRail, isFalse);
      expect(DdxLayoutClass.tablet.hasRail, isTrue);
      expect(DdxLayoutClass.wide.hasRail, isTrue);
    });

    test('grid tiles grow with the shell', () {
      expect(
        gridTileExtentFor(DdxLayoutClass.tablet),
        greaterThan(gridTileExtentFor(DdxLayoutClass.phone)),
      );
      expect(
        gridTileExtentFor(DdxLayoutClass.wide),
        greaterThan(gridTileExtentFor(DdxLayoutClass.tablet)),
      );
    });
  });

  group('HubLocation.parse', () {
    test('reads a Nexus root and a module out of the path', () {
      final root = HubLocation.parse('/hub/3');
      expect(root.nexusId, 3);
      expect(root.moduleId, isNull);

      final module = HubLocation.parse('/hub/3/module/12');
      expect(module.nexusId, 3);
      expect(module.moduleId, 12);
    });

    test('anything that is not a hub route highlights nothing', () {
      for (final path in ['/', '/settings', '/colors', '/hub', '/hub/abc', '']) {
        expect(HubLocation.parse(path).nexusId, isNull, reason: path);
        expect(HubLocation.parse(path).isHome, isTrue, reason: path);
      }
    });

    test('a trailing or doubled slash still resolves', () {
      expect(HubLocation.parse('/hub/7/').nexusId, 7);
      expect(HubLocation.parse('//hub//7//module//9').moduleId, 9);
    });
  });
}
