import 'package:dracondex/core/calendar/calendar_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// The desktop's cases (EXE test/calendar-engine.test.mjs), so a timeline
/// authored on either side lands on the same instants on the other.
Map<String, Object> _spec(List<Map<String, Object>> extra, {int anchor = 0, Map<String, Object>? year}) => {
      'version': 2,
      'anchor': {'weekdayIndex': anchor},
      'units': [
        {'key': 'minute', 'mode': 'container', 'of': []},
        {
          'key': 'hour',
          'of': [
            {'unit': 'minute', 'count': 60}
          ]
        },
        {
          'key': 'day',
          'of': [
            {'unit': 'hour', 'count': 24}
          ]
        },
        {
          'key': 'week',
          'mode': 'cycle',
          'of': [
            {'unit': 'day', 'count': 7}
          ]
        },
        {
          'key': 'month',
          'of': [
            {'unit': 'day', 'count': 30}
          ]
        },
        year ??
            {
              'key': 'year',
              'of': [
                {'unit': 'month', 'count': 12}
              ]
            },
        ...extra,
      ],
    };

void main() {
  final greg = calDefaultSpec;
  final fictional = calSpecNormalize({
    'version': 2,
    'units': [
      {'key': 'minute', 'of': []},
      {
        'key': 'hour',
        'of': [
          {'unit': 'minute', 'count': 60}
        ]
      },
      {
        'key': 'day',
        'of': [
          {'unit': 'hour', 'count': 20}
        ]
      },
      {
        'key': 'week',
        'mode': 'cycle',
        'of': [
          {'unit': 'day', 'count': 10}
        ]
      },
      {
        'key': 'month',
        'of': [
          {'unit': 'day', 'count': 40}
        ]
      },
      {
        'key': 'year',
        'of': [
          {'unit': 'month', 'count': 15}
        ]
      },
    ],
  });

  test('the default reproduces Gregorian month lengths and leap years', () {
    expect(calMonthLength(greg, 2001, 1), 28);
    expect(calMonthLength(greg, 2004, 1), 29);
    expect(calMonthLength(greg, 2000, 1), 29);
    expect(calMonthLength(greg, 2003, 1), 28);
    expect(calDaysInYear(greg, 2001), 365);
    expect(calDaysInYear(greg, 2004), 366);
    expect([2001, 2002, 2003, 2004].fold(0, (n, y) => n + calDaysInYear(greg, y)), 365 * 4 + 1);
  });

  test('ordinals round-trip, including across a leap boundary', () {
    for (final p in const [
      CalParts(1, 1, 1),
      CalParts(2004, 2, 29, 13, 45),
      CalParts(2004, 3, 1),
      CalParts(2005, 1, 1, 23, 59),
      CalParts(1482, 7, 3, 9, 30),
    ]) {
      expect(calFromOrdinal(greg, calToOrdinal(greg, p)!), p);
    }
  });

  test('the leap day sits one day after Feb 28 and one before Mar 1', () {
    const perDay = 24 * 60;
    final feb28 = calToOrdinal(greg, const CalParts(2004, 2, 28))!;
    final feb29 = calToOrdinal(greg, const CalParts(2004, 2, 29))!;
    final mar01 = calToOrdinal(greg, const CalParts(2004, 3, 1))!;
    expect(feb29 - feb28, perDay);
    expect(mar01 - feb29, perDay);
    expect(calToOrdinal(greg, const CalParts(2003, 3, 1))! - calToOrdinal(greg, const CalParts(2003, 2, 28))!, perDay);
  });

  test('dates past a real month length stay distinct and ordered', () {
    final a = calToOrdinal(fictional, const CalParts(1200, 1, 35))!;
    final b = calToOrdinal(fictional, const CalParts(1200, 2, 4))!;
    expect(a < b, isTrue);
    expect(calToOrdinal(fictional, const CalParts(1200, 2, 1))! - calToOrdinal(fictional, const CalParts(1200, 1, 40))!, 20 * 60);
  });

  test('a 15-month year rolls over at month 15', () {
    expect(calToOrdinal(fictional, const CalParts(1201, 1, 1))! - calToOrdinal(fictional, const CalParts(1200, 15, 40))!, 20 * 60);
    expect(calDaysInYear(fictional, 1200), 15 * 40);
    final m13 = calFromOrdinal(fictional, calToOrdinal(fictional, const CalParts(1200, 13, 1))!);
    expect((m13.y, m13.m), (1200, 13));
  });

  test('small and non-positive years are ordinary years', () {
    final y47 = calToOrdinal(greg, const CalParts(47, 6, 1))!;
    expect(y47 < calToOrdinal(greg, const CalParts(1947, 6, 1))!, isTrue);
    expect(calFromOrdinal(greg, y47), const CalParts(47, 6, 1));
    for (final y in [0, -1, -100]) {
      expect(calFromOrdinal(greg, calToOrdinal(greg, CalParts(y, 3, 2))!), CalParts(y, 3, 2));
    }
    final order = [for (final y in [-100, -1, 0, 1, 47]) calToOrdinal(greg, CalParts(y, 1, 1))!];
    expect(order, [...order]..sort());
    expect(calToOrdinal(greg, const CalParts(5, 0, 0)), isNull);
  });

  test('a cycle does not reset at its parent boundary', () {
    final spec = calSpecNormalize(_spec([]));
    int slotOfFirst(int m) => calCycleSlot(spec, 'week', calDayIndex(spec, 1, m, 1));
    expect([1, 2, 3, 4].map(slotOfFirst), [0, 2, 4, 6]);
    final base = calDayIndex(spec, 1, 1, 7);
    expect(calCycleSlot(spec, 'week', base), 6);
    expect(calCycleSlot(spec, 'week', base + 1), 0);
    expect(calCycleSlot(spec, 'week', -1), 6);
  });

  test('the weekday anchor shifts the whole cycle', () {
    expect(calCycleSlot(calSpecNormalize(_spec([])), 'week', 0), 0);
    expect(calCycleSlot(calSpecNormalize(_spec([], anchor: 3)), 'week', 0), 3);
  });

  test('flat overrides beat the month default, and cycle variants beat both', () {
    final spec = calSpecNormalize(_spec([], year: {
      'key': 'year',
      'of': [
        {'unit': 'month', 'count': 3}
      ],
      'lengths': {
        'on': true,
        'values': [31, 28, 30]
      },
      'cycle': {
        'on': true,
        'period': 3,
        'variants': {
          2: {1: 99}
        }
      },
    }));
    expect(calMonthLength(spec, 1, 0), 31);
    expect(calMonthLength(spec, 1, 1), 28);
    expect(calMonthLength(spec, 3, 1), 99);
    expect(calDaysInYear(spec, 1), 31 + 28 + 30);
    expect(calDaysInYear(spec, 3), 31 + 99 + 30);
    expect(calToOrdinal(spec, const CalParts(3, 3, 1))! - calToOrdinal(spec, const CalParts(3, 2, 99))!, 24 * 60);
  });

  test('a large year does not walk year by year', () {
    final sw = Stopwatch()..start();
    expect(calFromOrdinal(greg, calToOrdinal(greg, const CalParts(400000, 6, 15, 12, 30))!), const CalParts(400000, 6, 15, 12, 30));
    expect(sw.elapsedMilliseconds < 500, isTrue);
  });

  test('the v1 blob upgrades without changing what it described', () {
    final spec = calSpecNormalize({
      'daysPerWeek': 5,
      'daysPerMonth': 20,
      'monthsPerYear': 8,
      'dayNames': ['A', 'B', 'C', 'D', 'E'],
      'monthNames': ['Frost', 'Thaw'],
    });
    expect(calDaysInYear(spec, 1), 160);
    expect(calDaysInYear(spec, 4), 160);
    expect(calMonthLength(spec, 1, 0), 20);
    expect(calCanonicalCount(spec, 'week'), 5);
    expect(calWeekdayNames(spec), ['A', 'B', 'C', 'D', 'E']);
    expect(calMonthLabel(spec, 1), 'Thaw');
    expect(calMonthLabel(spec, 2), '3');
    expect(spec.unit('year')!.lengthsOn, isFalse);
    expect(spec.unit('year')!.cycleOn, isFalse);
  });

  test('a malformed config falls back to the default', () {
    for (final bad in [null, 42, 'nonsense', '{}', <String, Object>{}, {'units': 'no'}]) {
      expect(calDaysInYear(calSpecNormalize(bad), 2001), 365, reason: '$bad');
    }
    final partial = calSpecNormalize({
      'version': 2,
      'units': [
        {
          'key': 'year',
          'of': [
            {'unit': 'month', 'count': 4}
          ]
        }
      ]
    });
    expect(calToOrdinal(partial, const CalParts(2, 2, 2)), isNotNull);
    // Read straight from module_ui, where it is a JSON string.
    expect(calMonthsInYear(calSpecNormalize('{"monthsPerYear": 10}')), 10);
  });

  test('a unit above year is derived, not stored', () {
    final spec = calSpecNormalize(_spec([
      {
        'key': 'circle',
        'of': [
          {'unit': 'year', 'count': 12}
        ]
      }
    ]));
    expect(calDerivedUnitValue(spec, 'circle', 1), (index: 0, instance: 1));
    expect(calDerivedUnitValue(spec, 'circle', 12), (index: 11, instance: 1));
    expect(calDerivedUnitValue(spec, 'circle', 13), (index: 0, instance: 2));
    final wider = calSpecNormalize(_spec([
      {
        'key': 'circle',
        'of': [
          {'unit': 'year', 'count': 60}
        ]
      }
    ]));
    expect(calToOrdinal(wider, const CalParts(13, 1, 1)), calToOrdinal(spec, const CalParts(13, 1, 1)));
  });

  test('ruler ticks step in the calendar\'s own units', () {
    final from = calToOrdinal(greg, const CalParts(1000, 1, 1))!;
    final to = calToOrdinal(greg, const CalParts(1000, 6, 1))!;
    final monthly = calRulerTicks(greg, from, to);
    expect(monthly.length, inInclusiveRange(5, 7));
    expect(monthly.first.label, 'January');
    final yearly = calRulerTicks(greg, from, calToOrdinal(greg, const CalParts(1050, 1, 1))!);
    expect(yearly.first.label, '1000');
    final fFrom = calToOrdinal(fictional, const CalParts(5, 1, 1))!;
    final fTo = calToOrdinal(fictional, const CalParts(5, 15, 40))!;
    final f = calRulerTicks(fictional, fFrom, fTo);
    expect(f.every((t) => t.ordinal >= fFrom && t.ordinal <= fTo), isTrue);
    expect(f.any((t) => int.parse(t.label) > 12), isTrue);
    expect(calRulerTicks(greg, 100, 100), isEmpty);
  });

  test('a very long span is labelled across its whole width', () {
    final from = calToOrdinal(greg, const CalParts(0, 1, 1))!;
    final to = calToOrdinal(greg, const CalParts(1200, 1, 1))!;
    final ticks = calRulerTicks(greg, from, to);
    expect(ticks.length, inInclusiveRange(2, 20));
    expect((ticks.last.ordinal - from) / (to - from) > 0.8, isTrue);
    final step = int.parse(ticks[1].label) - int.parse(ticks[0].label);
    expect(ticks.every((t) => int.parse(t.label) % step == 0), isTrue);
  });

  test('floor-mod keeps negatives on the cycle', () {
    expect(calFloorMod(-1, 7), 6);
    expect(calFloorMod(-7, 7), 0);
    expect(calFloorMod(8, 7), 1);
  });
}
