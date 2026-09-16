// Scribe-kind content models: chat-style session notes. `chat_session` groups
// messages per module; `chat_message` holds each line. Electron's
// src/renderer/mod/chatscribe.js writes the same two tables.

class ChatSessionModel {
  final int id;
  final int moduleRef;
  final String name;
  final int order;
  final String updatedAt;

  const ChatSessionModel({
    required this.id,
    required this.moduleRef,
    required this.name,
    this.order = 0,
    this.updatedAt = '',
  });

  factory ChatSessionModel.fromMap(Map<String, dynamic> m) => ChatSessionModel(
        id: m['id'] as int,
        moduleRef: m['module_ref'] as int,
        name: m['name'] as String,
        order: m['session_order'] as int? ?? 0,
        updatedAt: m['update_at'] as String? ?? '',
      );
}

class ChatMessageModel {
  final int id;
  final int sessionRef;
  final String message;
  final int? colorId;
  final String? colorCode;

  /// 'r' or 'l' — which side of the transcript the bubble sits on. The column
  /// defaults to 'r'; anything else is treated as left so a malformed row
  /// still renders instead of throwing.
  final String side;
  final String createdAt;

  const ChatMessageModel({
    required this.id,
    required this.sessionRef,
    required this.message,
    this.colorId,
    this.colorCode,
    this.side = 'r',
    this.createdAt = '',
  });

  bool get isRight => side != 'l';

  factory ChatMessageModel.fromMap(Map<String, dynamic> m) => ChatMessageModel(
        id: m['id'] as int,
        sessionRef: m['session_ref'] as int,
        message: m['message'] as String,
        colorId: m['color'] as int?,
        colorCode: m['color_code'] as String?,
        side: m['side'] as String? ?? 'r',
        createdAt: m['create_at'] as String? ?? '',
      );
}
