import '../firebase/firebase_bootstrap.dart';
import 'motivation_quote.dart';

class MotivationRepository {
  static Future<List<MotivationQuote>> fetchActiveQuotes() async {
    try {
      final firestore = FirebaseBootstrap.firestoreOrNull;
      if (firestore == null) return [];

      final snapshot = await firestore
          .collection('motivational_quotes')
          .where('active', isEqualTo: true)
          .get()
          .timeout(const Duration(seconds: 6));

      return snapshot.docs
          .map(MotivationQuote.fromFirestore)
          .where((q) => q.text.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
