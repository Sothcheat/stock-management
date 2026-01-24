import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_model.dart';
import '../auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Stream of the current User? from FirebaseAuth
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// The main profile provider requested by the user
final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(authRepositoryProvider).getUserProfileStream(user.uid);
    },
    loading: () => Stream.value(null),
    error: (e, s) => Stream.value(null),
  );
});

final userStaffIdProvider = FutureProvider<String?>((ref) async {
  final userProfile = ref.watch(currentUserProfileProvider).value;
  if (userProfile == null) return null;

  return ref.read(authRepositoryProvider).getStaffIdByEmail(userProfile.email);
});
