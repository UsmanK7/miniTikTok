import 'package:cloud_firestore/cloud_firestore.dart';

class VideoModel {
  final String id;
  final String videoUrl;
  final String caption;
  final String userId;
  final DateTime createdAt;
  final List<String> likes;
  final List<String> saves;

  VideoModel({
    required this.id,
    required this.videoUrl,
    required this.caption,
    required this.userId,
    required this.createdAt,
    required this.likes,
    required this.saves,
  });

  factory VideoModel.fromMap(Map<String, dynamic> map, String id) {
    // Handle both Timestamp and int formats for createdAt
    dynamic createdAtValue = map['createdAt'];
    DateTime createdAt;

    if (createdAtValue is Timestamp) {
      createdAt = createdAtValue.toDate();
    } else if (createdAtValue is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtValue);
    } else {
      // Fallback to current time if format is unexpected
      createdAt = DateTime.now();
    }

    return VideoModel(
      id: id,
      videoUrl: map['videoUrl'] ?? '',
      caption: map['caption'] ?? '',
      userId: map['userId'] ?? '',
      createdAt: createdAt,
      likes: List<String>.from(map['likes'] ?? []),
      saves: List<String>.from(map['saves'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'videoUrl': videoUrl,
      'caption': caption,
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(), // Always use server timestamp
      'likes': likes,
      'saves': saves,
    };
  }
}