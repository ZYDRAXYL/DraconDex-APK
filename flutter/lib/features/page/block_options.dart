import '../../data/dao/page_block_dao.dart';

/// A component's own settings (APP docs/TEMPLATES.md §6.2) — the phone's
/// copy of what each desktop component declares with `options()` (EXE
/// renderer/page/components/*.js). Kept in `config.opts`; a template
/// written before §6 put the same keys at the top of `config`, so those
/// still count. A value that is not valid for its option reads as the
/// default, never an error.
enum OptType { select, toggle, number, text, links, list, image, images, module }

class OptDef {
  final String key;
  final OptType type;

  /// A page string key (page_strings.dart).
  final String label;
  final List<String> choices;

  /// With [choices]: the string key prefix each choice's label has
  /// ('pcBar' + 'Pills'); empty = the choice shown as it is.
  final String choicePrefix;
  final Object? defaultValue;
  final num? min, max;

  /// For image/images: the asset classes the picker offers.
  final Set<String> classes;

  /// For links: each link has a group (a navbox's rows).
  final bool grouped;

  const OptDef(this.key, this.type, this.label,
      {this.choices = const [],
      this.choicePrefix = '',
      this.defaultValue,
      this.min,
      this.max,
      this.classes = const {'image'},
      this.grouped = false});
}

const _media = {'image', 'video', 'model'};

/// Every option the phone can edit, by component — the desktop's own keys
/// and limits, so a block edited on either side reads the same on both.
const Map<String, List<OptDef>> componentOptions = {
  'core.video': [
    OptDef('file', OptType.image, 'pcVideo', classes: {'video'}),
    OptDef('poster', OptType.image, 'pcOptPoster'),
    OptDef('caption', OptType.text, 'pcOptCaption', max: 200),
  ],
  'core.audio': [
    OptDef('files', OptType.images, 'pcAudio', classes: {'audio'}),
    OptDef('title', OptType.text, 'pbHeaderTitle', max: 120),
    OptDef('cover', OptType.image, 'pcOptCover'),
  ],
  'core.pdf': [
    OptDef('file', OptType.image, 'pcPdf', classes: {'pdf'}),
    OptDef('page', OptType.number, 'pcOptStartPage', min: 1, max: 100000, defaultValue: 1),
  ],
  'core.model3d': [OptDef('file', OptType.image, 'pcModel3d', classes: {'model'})],
  'core.media': [
    OptDef('files', OptType.images, 'pcMedia', classes: _media),
    OptDef('cols', OptType.select, 'pbColumns', choices: ['2', '3', '4', '5'], defaultValue: '3'),
  ],
  'core.linkbar': [
    OptDef('links', OptType.links, 'pbLinks'),
    OptDef('bar', OptType.select, 'pcOptBar', choices: ['pills', 'tabs', 'underline', 'buttons'], choicePrefix: 'pcBar', defaultValue: 'pills'),
    OptDef('align', OptType.select, 'pbStyleAlign', choices: ['left', 'center'], choicePrefix: 'align', defaultValue: 'left'),
  ],
  'core.linkcard': [
    OptDef('links', OptType.links, 'pbLinks'),
    OptDef('layout', OptType.select, 'pcOptLayout', choices: ['card', 'compact', 'button'], choicePrefix: 'pcCard', defaultValue: 'card'),
    OptDef('cols', OptType.select, 'pbColumns', choices: ['1', '2', '3'], defaultValue: '2'),
  ],
  'core.hatnote': [
    OptDef('kind', OptType.select, 'pcOptHatKind', choices: ['main', 'about', 'distinguish'], choicePrefix: 'pcHat', defaultValue: 'main'),
    OptDef('links', OptType.links, 'pbLinks'),
  ],
  'core.seealso': [
    OptDef('links', OptType.links, 'pbLinks'),
    OptDef('suggest', OptType.toggle, 'pcOptSuggest', defaultValue: true),
    OptDef('count', OptType.number, 'pcOptCount', min: 1, max: 20, defaultValue: 5),
  ],
  'core.tabs': [
    OptDef('tabs', OptType.list, 'pcOptTabs', max: 8),
    OptDef('look', OptType.select, 'pcOptLook', choices: ['line', 'boxed', 'pills'], choicePrefix: 'pcTabs', defaultValue: 'line'),
    OptDef('start', OptType.number, 'pcOptStartTab', min: 1, max: 8, defaultValue: 1),
  ],
  'core.toggle': [
    OptDef('title', OptType.text, 'pbHeaderTitle', max: 80),
    OptDef('start', OptType.select, 'pcOptStart', choices: ['closed', 'open'], choicePrefix: 'pbColl', defaultValue: 'closed'),
  ],
  'core.navbox': [
    OptDef('title', OptType.text, 'pbHeaderTitle', max: 80),
    OptDef('source', OptType.module, 'pcOptSource'),
    OptDef('links', OptType.links, 'pbLinks', grouped: true),
    OptDef('start', OptType.select, 'pcOptStart', choices: ['open', 'closed'], choicePrefix: 'pbColl', defaultValue: 'open'),
  ],
  'core.children': [
    OptDef('depth', OptType.number, 'pcOptDepth', min: 1, max: 3, defaultValue: 1),
    OptDef('layout', OptType.select, 'pcOptLayout', choices: ['list', 'tree', 'cards'], choicePrefix: 'pcKids', defaultValue: 'list'),
    OptDef('sort', OptType.select, 'pcOptSort', choices: ['order', 'name'], choicePrefix: 'pcSort', defaultValue: 'order'),
  ],
};

List<OptDef> optionsOf(PageBlock b) => componentOptions[b.component] ?? const [];

final _fileRef = RegExp(r'^file_\d+$');

/// [v] if it is a valid value for [d], else null — the desktop's pbOptValid.
Object? optValid(OptDef d, Object? v) {
  if (v == null) return null;
  switch (d.type) {
    case OptType.select:
      return d.choices.contains('$v') ? '$v' : null;
    case OptType.toggle:
      return v is bool ? v : null;
    case OptType.number:
      final n = v is num ? v : num.tryParse('$v');
      if (n == null || !n.isFinite) return null;
      return n.clamp(d.min ?? double.negativeInfinity, d.max ?? double.infinity);
    case OptType.text:
      if (v is! String) return null;
      final max = (d.max ?? 200).toInt();
      return v.length > max ? v.substring(0, max) : v;
    case OptType.links:
      return v is List ? v : null;
    case OptType.list:
      return v is List ? [for (final s in v.take((d.max ?? 12).toInt())) (s ?? '').toString()] : null;
    case OptType.image:
      return v is String && _fileRef.hasMatch(v) ? v : null;
    case OptType.images:
      return v is List ? [for (final r in v) if (r is String && _fileRef.hasMatch(r)) r].take(60).toList() : null;
    case OptType.module:
      final n = v is int ? v : int.tryParse('$v');
      return n != null && n > 0 ? n : null;
  }
}

/// One option's value for a block: config.opts, the older top-level key,
/// then the declared default — the desktop's pbOpt.
Object? optValue(PageBlock b, String key) {
  final opts = b.config['opts'];
  final raw = opts is Map && opts[key] != null ? opts[key] : b.config[key];
  final d = optionsOf(b).where((o) => o.key == key).firstOrNull;
  if (d == null) return raw;
  return optValid(d, raw) ?? d.defaultValue;
}

/// `config` with one option set; null or '' removes it (pbOptSet).
Map<String, Object?> configWithOpt(Map<String, Object?> config, String key, Object? value) {
  final opts = {...?(config['opts'] as Map?)?.cast<String, Object?>()};
  if (value == null || value == '') {
    opts.remove(key);
  } else {
    opts[key] = value;
  }
  final out = {...config};
  if (opts.isEmpty) {
    out.remove('opts');
  } else {
    out['opts'] = opts;
  }
  return out;
}
