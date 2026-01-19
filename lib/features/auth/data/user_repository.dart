import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/app_user.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(FirebaseFirestore.instance);
});

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository(this._firestore);

  CollectionReference get _usersRef => _firestore.collection('users');

  // get current user profile
  Stream<AppUser?> getUserStream(String uid) {
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return AppUser.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    });
  }

  // Get all users (for admin/owner)
  Stream<List<AppUser>> getAllUsers() {
    return _usersRef.snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (doc) =>
                AppUser.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    });
  }

  // Create/Update user on sign up/login
  Future<void> createUserIfNotExists(String uid, String email) async {
    final doc = await _usersRef.doc(uid).get();
    if (!doc.exists) {
      await _usersRef.doc(uid).set({
        'email': email,
        'name': email.split('@')[0], // Default name from email
        'photoUrl': '',
        'role': 'employee', // Default role
      });
    }
  }

  Future<void> updateProfile({
    required String uid,
    String? name,
    String? photoUrl,
  }) async {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (photoUrl != null) data['photoUrl'] = photoUrl;

    if (data.isNotEmpty) {
      await _usersRef.doc(uid).update(data);
    }
  }

  Future<void> updateUserRole(String uid, String newRole) async {
    await _usersRef.doc(uid).update({'role': newRole});
  }
}
