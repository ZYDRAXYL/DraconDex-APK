// Chronicler-kind content models: a module's timeline of dated events.
//
// `timeline_date` is shared and deduplicated across the whole vault
// (UNIQUE(day,month,years,hour,minute)), so a date is looked up or created
// rather than owned by an event. Fields are plain integers because a Nexus
// may run on an invented calendar — see `calendar_template` — so these are
// deliberately not Dart DateTimes.

class TimelineDateModel {
  final int id;
  final int day;
  final int month;
  final int years;
  final int hour;
  final int minute;

  const TimelineDateModel({
    required this.id,
    required this.day,
    required this.month,
    required this.years,
    this.hour = 0,
    this.minute = 0,
  });

  factory TimelineDateModel.fromMap(Map<String, dynamic> m) => TimelineDateModel(
        id: m['id'] as int,
        day: m['day'] as int,
        month: m['month'] as int,
        years: m['years'] as int,
        hour: m['hour'] as int? ?? 0,
        minute: m['minute'] as int? ?? 0,
      );

  /// Calendar-agnostic label: no month names, no era, nothing that assumes
  /// the Gregorian calendar the events may not be using.
  String get label {
    final d = day.toString().padLeft(2, '0');
    final mo = month.toString().padLeft(2, '0');
    final time = (hour == 0 && minute == 0)
        ? ''
        : ' ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    return '$years-$mo-$d$time';
  }
}

class TimelineEventModel {
  final int id;
  final int timelineId;
  final String? name;
  final String? story;
  final String? colorCode;
  final TimelineDateModel start;
  final TimelineDateModel? end;

  const TimelineEventModel({
    required this.id,
    required this.timelineId,
    this.name,
    this.story,
    this.colorCode,
    required this.start,
    this.end,
  });

  /// Built from the flattened join in ChroniclerDao.getEvents — the start
  /// date columns are aliased s_*, the optional end date e_*.
  factory TimelineEventModel.fromJoin(Map<String, dynamic> m) => TimelineEventModel(
        id: m['id'] as int,
        timelineId: m['timeline_id'] as int,
        name: m['event_name'] as String?,
        story: m['story'] as String?,
        colorCode: m['color_code'] as String?,
        start: TimelineDateModel(
          id: m['s_id'] as int,
          day: m['s_day'] as int,
          month: m['s_month'] as int,
          years: m['s_years'] as int,
          hour: m['s_hour'] as int? ?? 0,
          minute: m['s_minute'] as int? ?? 0,
        ),
        end: m['e_id'] == null
            ? null
            : TimelineDateModel(
                id: m['e_id'] as int,
                day: m['e_day'] as int,
                month: m['e_month'] as int,
                years: m['e_years'] as int,
                hour: m['e_hour'] as int? ?? 0,
                minute: m['e_minute'] as int? ?? 0,
              ),
      );
}
