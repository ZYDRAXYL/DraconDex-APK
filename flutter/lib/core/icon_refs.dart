import 'package:flutter/material.dart';

/// An icon reference as both apps store it (EXE core/pickers.js iconRefHtml):
/// `svg:<name>` names an icon of the desktop's catalogue (core/icon-catalog.js
/// ICON_CATS), `sym:<glyph>` is a symbol or emoji, `img:…` a picture. Here:
/// the Material icon for a catalogue name, the glyph for a symbol, and null
/// for anything else — the caller then draws its plain dot, never a guess.
/// Procress 28 part 3 (the relation view draws an element's own icon).
IconData? iconForRef(String? ref) {
  if (ref == null || ref.isEmpty || ref.startsWith('sym:') || ref.startsWith('img:')) return null;
  return _catalog[ref.startsWith('svg:') ? ref.substring(4) : ref];
}

/// The glyph of a `sym:` reference, or null.
String? glyphForRef(String? ref) => ref != null && ref.startsWith('sym:') && ref.length > 4 ? ref.substring(4) : null;

const _catalog = <String, IconData>{
  // people
  'person': Icons.person_outline, 'hero': Icons.sports_esports_outlined, 'director': Icons.movie_outlined,
  'navigator': Icons.explore_outlined, 'narrator': Icons.forum_outlined, 'manager': Icons.task_alt,
  'writer': Icons.edit_note, 'scribe': Icons.sticky_note_2_outlined, 'sage': Icons.insights_outlined,
  'artisan': Icons.construction_outlined, 'sageTab': Icons.insights_outlined,
  // places
  'globe': Icons.public, 'map': Icons.map_outlined, 'home': Icons.home_outlined, 'wanderer': Icons.route_outlined,
  'pin': Icons.place_outlined, 'layer': Icons.layers_outlined, 'collector': Icons.folder_outlined,
  // things
  'sword': Icons.colorize_outlined, 'book': Icons.menu_book_outlined, 'item': Icons.category_outlined,
  'story': Icons.auto_stories_outlined, 'document': Icons.description_outlined, 'series': Icons.library_books_outlined,
  'projects': Icons.work_outline, 'folder': Icons.folder_outlined, 'dice': Icons.casino_outlined,
  'sketcher': Icons.draw_outlined, 'colors': Icons.palette_outlined, 'classifier': Icons.view_list_outlined,
  'exhibitor': Icons.hub_outlined,
  // time
  'timeline': Icons.timeline, 'chart': Icons.bar_chart, 'list': Icons.list, 'table': Icons.table_chart_outlined,
  'fields': Icons.tune, 'func': Icons.functions, 'view': Icons.visibility_outlined,
  // magic
  'star': Icons.star_outline, 'relation': Icons.share_outlined, 'hashtag': Icons.tag, 'eye': Icons.visibility_outlined,
  'dragonSearch': Icons.manage_search, 'info': Icons.info_outline,
  // arrows
  'chevronUp': Icons.expand_less, 'chevronDown': Icons.expand_more, 'chevronLeft': Icons.chevron_left,
  'chevronRight': Icons.chevron_right, 'return': Icons.undo, 'import': Icons.download_outlined,
  'export': Icons.upload_outlined, 'move': Icons.open_with,
  // ui
  'check': Icons.check, 'plus': Icons.add, 'minus': Icons.remove, 'close': Icons.close, 'edit': Icons.edit_outlined,
  'delete': Icons.delete_outline, 'copy': Icons.content_copy, 'search': Icons.search, 'settings': Icons.settings_outlined,
  'options': Icons.more_horiz, 'eyeOff': Icons.visibility_off_outlined, 'panelLeft': Icons.view_sidebar_outlined,
  'panelRight': Icons.view_sidebar_outlined,
};
