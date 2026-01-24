import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system.dart';
import '../../auth/data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final input = _emailController.text.trim();
      final password = _passwordController.text.trim();
      String emailToUse = input;

      // Case B: Staff ID (No '@' symbol)
      if (!input.contains('@')) {
        final fetchedEmail = await ref
            .read(authRepositoryProvider)
            .getEmailFromStaffId(input);

        if (fetchedEmail == null) {
          throw FirebaseAuthException(
            code: 'invalid-staff-id',
            message: 'Invalid Staff ID. Please checking your registry.',
          );
        }
        emailToUse = fetchedEmail;
      }

      // Proceed with Email (either direct or resolved)
      await ref
          .read(authRepositoryProvider)
          .signInWithEmailAndPassword(emailToUse, password);
    } catch (e) {
      if (mounted) {
        String message = 'Login failed';
        if (e is FirebaseAuthException) {
          message = e.message ?? message;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: SoftColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SoftColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Icon
                    Icon(
                      Icons.inventory_2_rounded,
                      size: 80,
                      color: SoftColors.brandPrimary,
                    ),
                    const SizedBox(height: 32),

                    // Welcome Text
                    Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: SoftColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Login to manage your inventory',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: SoftColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Soft Card Container for Form
                    SoftCard(
                      child: Column(
                        children: [
                          ModernInput(
                            controller: _emailController,
                            hintText: 'Email Address or Staff ID',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) => value == null || value.isEmpty
                                ? 'Please enter email'
                                : null,
                          ),
                          const SizedBox(height: 20),
                          ModernInput(
                            controller: _passwordController,
                            hintText: 'Password',
                            prefixIcon: Icons.lock_outline,
                            obscureText: true,
                            validator: (value) => value == null || value.isEmpty
                                ? 'Please enter password'
                                : null,
                          ),
                          const SizedBox(height: 32),
                          SoftButton(
                            label: 'Sign In',
                            onTap: _login,
                            isLoading: _isLoading,
                            icon: Icons.login_rounded,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
