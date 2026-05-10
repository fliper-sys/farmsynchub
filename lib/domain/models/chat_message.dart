// ─────────────────────────────────────────────────────────────────────────────
// lib/models/chat_message.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'ai_topic.dart';

enum MessageSender { user, ai }

class ChatMessage {
  final String id;
  final String text;
  final MessageSender sender;
  final AiTopic? topic;
  final DateTime timestamp;
  final bool isError;
  final bool hasImage;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    this.topic,
    required this.timestamp,
    this.isError = false,
    this.hasImage = false,
  });

  bool get isFromUser => sender == MessageSender.user;
  bool get isFromAi   => sender == MessageSender.ai;

  /// Create a user message.
  factory ChatMessage.fromUser(String text, {AiTopic? topic, bool hasImage = false}) {
    return ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      sender: MessageSender.user,
      topic: topic,
      timestamp: DateTime.now(),
      hasImage: hasImage,
    );
  }

  /// Create an AI response message.
  factory ChatMessage.fromAi(String text, {AiTopic? topic, bool isError = false}) {
    return ChatMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}_ai',
      text: text,
      sender: MessageSender.ai,
      topic: topic,
      timestamp: DateTime.now(),
      isError: isError,
    );
  }

  /// Loading placeholder message while waiting for Gemini response.
  factory ChatMessage.loading({AiTopic? topic}) {
    return ChatMessage(
      id: 'loading',
      text: '',
      sender: MessageSender.ai,
      topic: topic,
      timestamp: DateTime.now(),
    );
  }

  bool get isLoading => id == 'loading';

  // ── SERIALISATION ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id':        id,
    'text':      text,
    'sender':    sender.name,
    'topic':     topic?.name,
    'timestamp': timestamp.toIso8601String(),
    'isError':   isError,
    'hasImage':  hasImage,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id:        json['id'] as String,
    text:      json['text'] as String,
    sender:    MessageSender.values.firstWhere(
                 (s) => s.name == json['sender'],
                 orElse: () => MessageSender.ai,
               ),
    topic:     json['topic'] != null
                 ? AiTopic.values.firstWhere(
                     (t) => t.name == json['topic'],
                     orElse: () => AiTopic.general,
                   )
                 : null,
    timestamp: DateTime.parse(json['timestamp'] as String),
    isError:   (json['isError'] as bool?) ?? false,
    hasImage:  (json['hasImage'] as bool?) ?? false,
  );

  ChatMessage copyWith({String? text, bool? isError}) => ChatMessage(
    id:        id,
    text:      text ?? this.text,
    sender:    sender,
    topic:     topic,
    timestamp: timestamp,
    isError:   isError ?? this.isError,
    hasImage:  hasImage,
  );
}
