// lib/models/chat_message.dart
import 'dart:io';

/// Represents the sender of the message.
enum MessageSender { user, model }

/// A class to represent a single message in the chat.
/// A message can contain text, a local media file (image/video), or both.
class ChatMessage {
  final String id;
  final String? text;
  final File? mediaFile;
  final MessageSender sender;
  final DateTime timestamp;

  /// Whether this message represents an error (e.g., model/service failure).
  final bool isError;

  ChatMessage({
    String? id,
    this.text,
    this.mediaFile,
    required this.sender,
    DateTime? timestamp,
    this.isError = false,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now(),
        assert(
          text != null || mediaFile != null,
          'A message must have either text or a media file.',
        );
}
