import 'package:cloud_firestore/cloud_firestore.dart';

class MotivationQuote {
  const MotivationQuote({
    required this.id,
    required this.text,
    required this.author,
  });

  final String id;
  final String text;
  final String author;

  factory MotivationQuote.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MotivationQuote(
      id: doc.id,
      text: (data['text'] as String?)?.trim() ?? '',
      author: (data['author'] as String?)?.trim() ?? '',
    );
  }
}
