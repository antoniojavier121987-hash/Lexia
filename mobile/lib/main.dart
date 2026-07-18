import 'package:flutter/material.dart';
import 'config.dart';
import 'services/auth_storage.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const LexiaApp());
}

class LexiaApp extends StatelessWidget {
  const LexiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LEXIA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppConfig.primaryColor,
        colorScheme: ColorScheme.fromSeed(seedColor: AppConfig.primaryColor),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      home: const _StartupGate(),
    );
  }
}

/// Decide si mostrar el login o el historial, según si ya hay una sesión guardada.
class _StartupGate extends StatelessWidget {
  const _StartupGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthStorage.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return (snapshot.data ?? false) ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
