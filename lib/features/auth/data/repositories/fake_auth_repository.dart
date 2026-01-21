import '../../domain/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<void> signIn(String email, String password) async {
    // Simulate network lag
    await Future.delayed(const Duration(seconds: 1));

    // Simulate simple check
    if (email == 'test@example.com' && password == 'password') {
      return; // Success
    }
    // You could simulate errors here if needed
    // throw Exception('Invalid credentials');
    return; // Allow any login for now
  }
}
