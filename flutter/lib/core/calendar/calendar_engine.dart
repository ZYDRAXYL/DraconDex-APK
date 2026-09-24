import 'dart:convert';
import 'dart:math' as math;

/// The port of EXE renderer/core/calendar-engine.js: pure date arithmetic
/// over a user-defined unit system, read from a Chronicler's
/// `module_ui.calendarConfig`. Kept byte-for-byte in behaviour with the
/// desktop so a timeline authored there lays out the same here —
/// test/calendar_engine_test.dart carries the desktop's cases.
///
/// `timeline_date` stores five integers (years, month, day, hour, minute),
/// so those five units are STORED and every spec defines them; anything else
/// (a week, a 12-year circle) is DERIVED — display and grouping only, so
/// redefining it never rewrites a row.
///
/// Ordinals are whole minutes since year 1, month 1, day 1, 00:00.

class CalOf {
  final String unit;
  final int count;
  const CalOf(this.unit, this.count);
  Map<String, Object> toJson() => {'unit': unit, 'count': count};
}

class CalUnit {
  final String key;

  /// 'container' or 'cycle'.
  final String mode;
  final List<CalOf> of;
  final bool namingOn;
  final List<String> names;
  final bool lengthsOn;
  final List<int> lengths;
  final bool cycleOn;
  final int period;

  /// cycle slot → (0-based child index → length).
  final Map<int, Map<int, int>> variants;

  const CalUnit(
    this.key, {
    this.mode = 'container',
    this.of = const [],
    this.namingOn = false,
    this.names = const [],
    this.lengthsOn = false,
    this.lengths = const [],
    this.cycleOn = false,
    this.period = 1,
    this.variants = const {},
  });
}

class CalSpec {
  final int weekdayIndex;
  final List<CalUnit> units;
  const CalSpec(this.units, {this.weekdayIndex = 0});

  CalUnit? unit(String key) {
    for (final u in units) {
      if (u.key == key) return u;
    }
    return null;
  }
}

class CalParts {
  final int y, m, d, h, mi;
  const CalParts(this.y, this.m, this.d, [this.h = 0, this.mi = 0]);
  @override
  bool operator ==(Object other) => other is CalParts && other.y == y && other.m == m && other.d == d && other.h == h && other.mi == mi;
  @override
  int get hashCode => Object.hash(y, m, d, h, mi);
  @override
  String toString() => '$y-$m-$d $h:$mi';
}

const calStoredUnits = ['minute', 'hour', 'day', 'month', 'year'];

const _gregorianDefault = {
  'version': 2,
  'anchor': {'weekdayIndex': 0},
  'units': [
    {'key': 'minute', 'mode': 'container', 'of': []},
    {
      'key': 'hour',
      'mode': 'container',
      'of': [
        {'unit': 'minute', 'count': 60}
      ]
    },
    {
      'key': 'day',
      'mode': 'container',
      'of': [
        {'unit': 'hour', 'count': 24}
      ]
    },
    {
      'key': 'week',
      'mode': 'cycle',
      'of': [
        {'unit': 'day', 'count': 7}
      ],
      'naming': {
        'on': true,
        'names': ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
      },
    },
    {
      'key': 'month',
      'mode': 'container',
      'of': [
        {'unit': 'day', 'count': 30},
        {'unit': 'week', 'count': 4}
      ]
    },
    {
      'key': 'year',
      'mode': 'container',
      'of': [
        {'unit': 'month', 'count': 12}
      ],
      'naming': {
        'on': true,
        'names': ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
      },
      'lengths': {
        'on': true,
        'values': [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
      },
      // Slot 3 of 4 (year % 4 == 0): February has 29 days.
      'cycle': {
        'on': true,
        'period': 4,
        'variants': {
          '3': {'1': 29}
        }
      },
    },
  ],
};

/// The international calendar, the default and the base of every template.
final CalSpec calDefaultSpec = _parseUnits(_gregorianDefault, null);

/// A floor-mod: Dart's % is already non-negative for a positive divisor,
/// named for parity with the desktop.
int calFloorMod(int n, int m) => ((n % m) + m) % m;

int? _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.isFinite ? v.floor() : null;
  if (v is String) {
    final d = double.tryParse(v);
    return d == null || !d.isFinite ? null : d.floor();
  }
  if (v is bool) return v ? 1 : 0;
  return null;
}

bool _truthy(Object? v) => v != null && v != false && v != 0 && v != '';

CalUnit _parseUnit(Map u) {
  final of = [
    for (final o in (u['of'] is List ? u['of'] as List : const []))
      if (o is Map && o['unit'] is String && (_int(o['count']) ?? 0) > 0) CalOf(o['unit'] as String, _int(o['count'])!),
  ];
  final naming = u['naming'] is Map ? u['naming'] as Map : null;
  final lengths = u['lengths'] is Map ? u['lengths'] as Map : null;
  final cycle = u['cycle'] is Map ? u['cycle'] as Map : null;
  final variants = <int, Map<int, int>>{};
  if (cycle != null && cycle['variants'] is Map) {
    for (final MapEntry(:key, :value) in (cycle['variants'] as Map).entries) {
      final pos = _int(key);
      if (pos == null || value is! Map) continue;
      final inner = <int, int>{};
      for (final e in value.entries) {
        final i = _int(e.key), n = _int(e.value);
        if (i != null && n != null && n > 0) inner[i] = n;
      }
      variants[pos] = inner;
    }
  }
  return CalUnit(
    u['key'] as String,
    mode: u['mode'] == 'cycle' ? 'cycle' : 'container',
    of: of,
    namingOn: naming != null && _truthy(naming['on']),
    names: [for (final n in (naming?['names'] is List ? naming!['names'] as List : const [])) '${n ?? ''}'],
    lengthsOn: lengths != null && _truthy(lengths['on']),
    lengths: [for (final v in (lengths?['values'] is List ? lengths!['values'] as List : const [])) math.max(1, _int(v) ?? 1)],
    cycleOn: cycle != null && _truthy(cycle['on']),
    period: math.max(1, _int(cycle?['period']) ?? 1),
    variants: variants,
  );
}

/// A stored `calendarConfig` (a JSON string or an already-decoded map) as a
/// spec. Repairs anything missing and upgrades the v1 blob
/// ({daysPerWeek, daysPerMonth, monthsPerYear, dayNames, monthNames}) —
/// the parse is the migration, nothing on disk is rewritten.
CalSpec calSpecNormalize(Object? raw) {
  if (raw is String) {
    try {
      raw = jsonDecode(raw);
    } catch (_) {
      raw = null;
    }
  }
  if (raw is! Map) return calDefaultSpec;

  const v1Keys = ['daysPerWeek', 'daysPerMonth', 'monthsPerYear', 'dayNames', 'monthNames'];
  if (raw['units'] is! List && v1Keys.any(raw.containsKey)) {
    int pos(Object? v, int d) => math.max(1, (_int(v) ?? 0) == 0 ? d : _int(v)!);
    final base = calDefaultSpec;
    List<String> names(Object? v) => [for (final n in (v is List ? v : const [])) if (_truthy(n)) '$n'];
    final dayNames = names(raw['dayNames']), monthNames = names(raw['monthNames']);
    return CalSpec([
      for (final u in base.units)
        switch (u.key) {
          'week' => CalUnit('week', mode: 'cycle', of: [CalOf('day', pos(raw['daysPerWeek'], 7))], namingOn: dayNames.isNotEmpty, names: dayNames),
          'month' => CalUnit('month', of: [CalOf('day', pos(raw['daysPerMonth'], 30))]),
          // A v1 calendar had uniform months and no leap rule.
          'year' => CalUnit('year', of: [CalOf('month', pos(raw['monthsPerYear'], 12))], namingOn: monthNames.isNotEmpty, names: monthNames),
          _ => u,
        },
    ]);
  }
  if (raw['units'] is! List) return calDefaultSpec;
  return _parseUnits(raw, calDefaultSpec);
}

/// A spec missing a stored unit takes [base]'s definition of it; the
/// built-in default has all five, so it is parsed with no base.
CalSpec _parseUnits(Map raw, CalSpec? base) {
  final anchor = raw['anchor'] is Map ? _int((raw['anchor'] as Map)['weekdayIndex']) : null;
  final units = [
    for (final u in raw['units'] as List)
      if (u is Map && u['key'] is String && (u['key'] as String).isNotEmpty) _parseUnit(u),
  ];
  final have = {for (final u in units) u.key};
  for (final k in calStoredUnits) {
    if (!have.contains(k) && base != null) units.add(base.unit(k)!);
  }
  return CalSpec(units, weekdayIndex: anchor ?? 0);
}

/// How many of its canonical child a unit holds; only of[0] drives arithmetic.
int calCanonicalCount(CalSpec spec, String key) {
  final u = spec.unit(key);
  return u == null || u.of.isEmpty ? 0 : u.of.first.count;
}

int calYearCyclePos(CalSpec spec, int year) {
  final y = spec.unit('year');
  final period = y != null && y.cycleOn ? y.period : 1;
  return calFloorMod(year - 1, period);
}

/// Cycle variant, then the year's flat overrides, then the month default.
int calMonthLength(CalSpec spec, int year, int monthIndex) {
  final yu = spec.unit('year');
  if (yu != null && yu.cycleOn) {
    final n = yu.variants[calYearCyclePos(spec, year)]?[monthIndex];
    if (n != null && n > 0) return n;
  }
  if (yu != null && yu.lengthsOn && monthIndex >= 0 && monthIndex < yu.lengths.length) return yu.lengths[monthIndex];
  final c = calCanonicalCount(spec, 'month');
  return c > 0 ? c : 30;
}

int calMonthsInYear(CalSpec spec) {
  final c = calCanonicalCount(spec, 'year');
  return c > 0 ? c : 12;
}

int calDaysInYear(CalSpec spec, int year) {
  var total = 0;
  for (var i = 0; i < calMonthsInYear(spec); i++) {
    total += calMonthLength(spec, year, i);
  }
  return total;
}

int _cycleTotal(CalSpec spec, int period) {
  var t = 0;
  for (var i = 0; i < period; i++) {
    t += calDaysInYear(spec, 1 + i);
  }
  return t;
}

/// Days from the epoch to the start of [year]; never a loop over the year.
int calDaysBeforeYear(CalSpec spec, int year) {
  final yu = spec.unit('year');
  final before = year - 1;
  if (yu == null || !yu.cycleOn) return before * calDaysInYear(spec, 1);
  final full = (before / yu.period).floor();
  final rem = before - full * yu.period;
  var days = full * _cycleTotal(spec, yu.period);
  for (var i = 0; i < rem; i++) {
    days += calDaysInYear(spec, 1 + i);
  }
  return days;
}

int calDayIndex(CalSpec spec, int year, int month, int day) {
  var days = calDaysBeforeYear(spec, year);
  for (var i = 0; i < math.max<int>(1, month) - 1; i++) {
    days += calMonthLength(spec, year, i);
  }
  return days + math.max<int>(1, day) - 1;
}

int _hpd(CalSpec s) => calCanonicalCount(s, 'day') > 0 ? calCanonicalCount(s, 'day') : 24;
int _mph(CalSpec s) => calCanonicalCount(s, 'hour') > 0 ? calCanonicalCount(s, 'hour') : 60;

/// Null only for a missing month or day — year 0 is an ordinary year.
int? calToOrdinal(CalSpec spec, CalParts p) {
  if (p.m == 0 || p.d == 0) return null;
  final hpd = _hpd(spec), mph = _mph(spec);
  final h = p.h.clamp(0, hpd - 1), mi = p.mi.clamp(0, mph - 1);
  return (calDayIndex(spec, p.y, p.m, p.d) * hpd + h) * mph + mi;
}

CalParts calFromOrdinal(CalSpec spec, int ordinal) {
  final hpd = _hpd(spec), mph = _mph(spec), perDay = hpd * mph;
  final dayIndex = (ordinal / perDay).floor();
  final within = ordinal - dayIndex * perDay;
  final p = calPartsFromDayIndex(spec, dayIndex);
  final h = within ~/ mph;
  return CalParts(p.y, p.m, p.d, h, within - h * mph);
}

CalParts calPartsFromDayIndex(CalSpec spec, int dayIndex) {
  final yu = spec.unit('year');
  var year = 1, remaining = dayIndex;
  if (yu != null && yu.cycleOn) {
    final total = _cycleTotal(spec, yu.period);
    if (total > 0) {
      final full = (remaining / total).floor();
      year += full * yu.period;
      remaining -= full * total;
    }
  } else {
    final perYear = calDaysInYear(spec, 1);
    if (perYear > 0) {
      final whole = (remaining / perYear).floor();
      year += whole;
      remaining -= whole * perYear;
    }
  }
  while (remaining < 0) {
    year -= 1;
    remaining += calDaysInYear(spec, year);
  }
  for (;;) {
    final inYear = calDaysInYear(spec, year);
    if (remaining < inYear) break;
    remaining -= inYear;
    year += 1;
  }
  var month = 1;
  for (var i = 0; i < calMonthsInYear(spec); i++) {
    final len = calMonthLength(spec, year, i);
    if (remaining < len) {
      month = i + 1;
      break;
    }
    remaining -= len;
    month = i + 2;
  }
  return CalParts(year, month, remaining + 1);
}

/// Which slot of a cycle unit (a week) a day falls on. It does not reset at
/// the month boundary — that is the point of a cycle.
int calCycleSlot(CalSpec spec, String unitKey, int dayIndex) {
  final u = spec.unit(unitKey);
  final len = calCanonicalCount(spec, unitKey);
  if (u == null || u.mode != 'cycle' || len <= 0) return 0;
  return calFloorMod(dayIndex + spec.weekdayIndex, len);
}

/// A unit placed above year (a 12-year circle): 0-based index within it and
/// which instance, 1-based.
({int index, int instance})? calDerivedUnitValue(CalSpec spec, String unitKey, int year) {
  final count = calCanonicalCount(spec, unitKey);
  if (count <= 0) return null;
  return (index: calFloorMod(year - 1, count), instance: ((year - 1) / count).floor() + 1);
}

/// A unit's naming names its CHILDREN: a year names its months.
String? calChildName(CalSpec spec, String unitKey, int childIndex) {
  final u = spec.unit(unitKey);
  if (u == null || !u.namingOn || childIndex < 0 || childIndex >= u.names.length) return null;
  final n = u.names[childIndex];
  return n.isEmpty ? null : n;
}

String calMonthLabel(CalSpec spec, int monthIndex) => calChildName(spec, 'year', monthIndex) ?? '${monthIndex + 1}';

/// The weekday names a month grid heads its columns with, or none when the
/// week is unnamed or not a cycle.
List<String> calWeekdayNames(CalSpec spec) {
  final len = calCanonicalCount(spec, 'week');
  final w = spec.unit('week');
  if (w == null || w.mode != 'cycle' || len <= 0) return const [];
  return [for (var i = 0; i < len; i++) calChildName(spec, 'week', i) ?? '${i + 1}'];
}

const _strides = [1, 2, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000];

int calPickStride(int count, int target) {
  for (final s in _strides) {
    if (count / s <= target) return s;
  }
  return math.pow(10, (math.log(math.max(1, count / target)) / math.ln10).ceil()).toInt();
}

/// Axis ticks in the calendar's own units: by month over a short span, by a
/// round stride of years over a long one.
List<({int ordinal, String label})> calRulerTicks(CalSpec spec, int minOrd, int maxOrd, {int cap = 240}) {
  if (!(maxOrd > minOrd)) return const [];
  final perDay = _hpd(spec) * _mph(spec);
  final spanDays = (maxOrd - minOrd) / perDay;
  final dpy = math.max(1, calDaysInYear(spec, 1));
  final months = calMonthsInYear(spec);
  final byYear = spanDays > dpy * 4;
  final start = calFromOrdinal(spec, minOrd);
  final target = math.min(12, cap);
  final unitSpan = byYear ? spanDays / dpy : spanDays / (dpy / months);
  final stride = calPickStride(math.max(1, unitSpan.ceil()), target);
  final out = <({int ordinal, String label})>[];
  var year = start.y, month = byYear ? 1 : start.m;
  if (byYear) year = (year / stride).ceil() * stride;
  for (var guard = 0; guard < cap; guard++) {
    final ord = calToOrdinal(spec, CalParts(year, month, 1));
    if (ord == null || ord > maxOrd) break;
    if (ord >= minOrd) out.add((ordinal: ord, label: byYear ? '$year' : calMonthLabel(spec, month - 1)));
    if (byYear) {
      year += stride;
    } else {
      month += stride;
      while (month > months) {
        month -= months;
        year += 1;
      }
    }
  }
  return out;
}
