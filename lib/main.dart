import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'screens/login_screen.dart';
import 'screens/campaign_list_screen.dart';
import 'screens/game_screen.dart';
import 'screens/character_screen.dart';
import 'screens/vision_archive_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const ImmersiveStoriesApp());
}

class ImmersiveStoriesApp extends StatelessWidget {
  const ImmersiveStoriesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Immersive Stories',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B1A1A),
          secondary: Color(0xFFB8860B),
          surface: Color(0xFF1A1A2E),
          background: Color(0xFF0D0D1A),
          onPrimary: Colors.white,
          onSurface: Color(0xFFD4C5A9),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A2E),
          foregroundColor: Color(0xFFD4C5A9),
          elevation: 2,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF16213E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF8B1A1A)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF4A4A6A)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF8B1A1A), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF9A8A74)),
          hintStyle: const TextStyle(color: Color(0xFF6A5A4A)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B1A1A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFD4C5A9)),
          bodyMedium: TextStyle(color: Color(0xFFB8A89A)),
          titleLarge: TextStyle(color: Color(0xFFE8D5B7), fontWeight: FontWeight.bold),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/campaigns': (context) => const CampaignListScreen(),
        '/game': (context) => const GameScreen(),
        '/character':      (context) => const CharacterScreen(),
        '/vision_archive': (context) => const VisionArchiveScreen(),
      },
    );
  }
}
