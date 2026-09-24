// Narrator-kind content models: dialogue scenes, the script inside each, and
// the routes between them.
//
//   story_dialogue  a scene (also carries pos_x/pos_y for the desktop board)
//   story_talk      one line inside a scene, ordered
//   story_edge      "this scene leads to that one", UNIQUE(from_ref, to_ref)
//
// pos_x/pos_y position a scene on the route board — the desktop's and, since
// APK V3, the phone's board view, which writes them when a scene is dragged.

class DialogueModel {
  final int id;
  final int moduleRef;
  final String name;
  final String? description;
  final String? colorCode;

  /// Where the desktop's route board (and the phone's) places the scene.
  final double posX;
  final double posY;

  const DialogueModel({
    required this.id,
    required this.moduleRef,
    required this.name,
    this.description,
    this.colorCode,
    this.posX = 0,
    this.posY = 0,
  });

  factory DialogueModel.fromMap(Map<String, dynamic> m) => DialogueModel(
        id: m['id'] as int,
        moduleRef: m['module_ref'] as int,
        name: m['name'] as String,
        description: m['description'] as String?,
        colorCode: m['color_code'] as String?,
        posX: (m['pos_x'] as num?)?.toDouble() ?? 0,
        posY: (m['pos_y'] as num?)?.toDouble() ?? 0,
      );
}

class TalkModel {
  final int id;
  final int dialogueRef;
  final String? speaker;
  final String? sentence;

  /// 'talk' by default; the schema allows other row kinds (choices, effects)
  /// that the desktop authors. Rows that are not plain talk are shown
  /// read-only here rather than silently rewritten into talk lines.
  final String rowType;
  final int order;

  const TalkModel({
    required this.id,
    required this.dialogueRef,
    this.speaker,
    this.sentence,
    this.rowType = 'talk',
    this.order = 0,
  });

  bool get isPlainTalk => rowType == 'talk';

  factory TalkModel.fromMap(Map<String, dynamic> m) => TalkModel(
        id: m['id'] as int,
        dialogueRef: m['dialogue_ref'] as int,
        speaker: m['speaker'] as String?,
        sentence: m['talk_sentence'] as String?,
        rowType: m['row_type'] as String? ?? 'talk',
        order: m['talk_order'] as int? ?? 0,
      );
}

class StoryEdgeModel {
  final int id;
  final int fromRef;
  final int toRef;
  final String? label;

  /// Resolved in the DAO's join so the list can name the destination without
  /// a lookup per row.
  final String toName;

  const StoryEdgeModel({
    required this.id,
    required this.fromRef,
    required this.toRef,
    this.label,
    required this.toName,
  });

  factory StoryEdgeModel.fromMap(Map<String, dynamic> m) => StoryEdgeModel(
        id: m['id'] as int,
        fromRef: m['from_ref'] as int,
        toRef: m['to_ref'] as int,
        label: m['label'] as String?,
        toName: m['to_name'] as String? ?? '',
      );
}
