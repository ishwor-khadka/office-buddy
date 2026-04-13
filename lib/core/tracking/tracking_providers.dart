import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_bootstrap.dart';
import 'tracking_repository.dart';

final firebaseFirestoreProvider = Provider(
  (ref) => FirebaseBootstrap.firestoreOrNull,
);

final trackingRepositoryProvider = Provider<TrackingRepository?>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  if (firestore == null) return null;
  return TrackingRepository(firestore);
});
