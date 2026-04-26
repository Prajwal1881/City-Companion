class Message {
  final String text;
  final DateTime timestamp;
  final bool isMe;

  Message({
    required this.text,
    required this.timestamp,
    required this.isMe,
  });

  factory Message.fromJson(Map<String, dynamic> json, String currentUserId) {
    final rawTs = (json['sent_at'] ?? json['created_at'])?.toString();
    return Message(
      text: json['content'] ?? '',
      timestamp: rawTs != null
          ? (DateTime.tryParse(rawTs) ?? DateTime.now())
          : DateTime.now(),
      isMe: json['sender_id']?.toString() == currentUserId,
    );
  }
}
