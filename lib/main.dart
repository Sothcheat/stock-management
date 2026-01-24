import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // If you haven't run flutterfire configure, this will throw
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint("Firebase init error: $e");
    // Fallback? Or just let it crash/log if essential
  }

  runApp(const ProviderScope(child: StockManagementApp()));
}

class StockManagementApp extends ConsumerWidget {
  const StockManagementApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Force system chrome to light mode style
    // This ensures status bar and nav bar look correct even if OS is dark
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return MaterialApp.router(
      title: 'Stock Management',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.lightTheme, // Force light theme even for dark mode
      themeMode: ThemeMode.light, // Explicitly set to light
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
