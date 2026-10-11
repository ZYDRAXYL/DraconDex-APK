import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// The Glass style's low-spec check (APP Plan.md Procress 23 part 3): the
/// first frames drawn after Glass turns on say whether this device can
/// afford the blur. Too slow, and the panes keep their tint and drop the
/// blur — the decision is the caller's to persist (settings `glass_blur`).
///
/// The rule: over the first [sample] frames, the median frame — the slower
/// of its build and raster — is over [budget], one 60 Hz frame. A median,
/// so the one-off frames around turning Glass on (the whole app rebuilding,
/// a page transition) cannot decide it alone; 60 Hz, because a device that
/// cannot hold that while drawing the blur is what "low spec" means here,
/// whatever its screen's own refresh rate.
class GlassFrameProbe {
  GlassFrameProbe({this.sample = 60, this.budget = const Duration(microseconds: 16667)});

  final int sample;
  final Duration budget;
  final List<Duration> _costs = [];

  /// Null while measuring; then true (too slow) or false, and fixed.
  bool? get verdict => _verdict;
  bool? _verdict;

  /// Adds the cost of each frame drawn; returns [verdict].
  bool? add(Iterable<Duration> frameCosts) {
    if (_verdict != null) return _verdict;
    for (final c in frameCosts) {
      _costs.add(c);
      if (_costs.length == sample) {
        final sorted = [..._costs]..sort();
        return _verdict = sorted[sample ~/ 2] > budget;
      }
    }
    return null;
  }

  /// What one frame cost: build and raster run in parallel on their own
  /// threads, so the slower of the two is what limits the frame rate.
  static Duration costOf(FrameTiming t) => t.buildDuration > t.rasterDuration ? t.buildDuration : t.rasterDuration;
}

/// Runs a [GlassFrameProbe] on the frames the engine reports while [active]
/// (Glass on, blurring, not yet measured) and hands the verdict to
/// [onVerdict] once. Draws nothing of its own.
class GlassFrameWatch extends StatefulWidget {
  const GlassFrameWatch({super.key, required this.active, required this.onVerdict, required this.child});

  final bool active;
  final void Function(bool tooSlow) onVerdict;
  final Widget child;

  @override
  State<GlassFrameWatch> createState() => _GlassFrameWatchState();
}

class _GlassFrameWatchState extends State<GlassFrameWatch> {
  GlassFrameProbe? _probe;

  @override
  void initState() {
    super.initState();
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(GlassFrameWatch old) {
    super.didUpdateWidget(old);
    if (widget.active && _probe == null) _start();
    if (!widget.active && _probe != null) _stop();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  // A fresh probe each time it starts: frames from an earlier stretch of
  // Glass (turned off half-way) say nothing about this one.
  void _start() {
    _probe = GlassFrameProbe();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _stop() {
    if (_probe == null) return;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _probe = null;
  }

  void _onTimings(List<FrameTiming> timings) {
    final verdict = _probe?.add(timings.map(GlassFrameProbe.costOf));
    if (verdict == null) return;
    _stop();
    widget.onVerdict(verdict);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
