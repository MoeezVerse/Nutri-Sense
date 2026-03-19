import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/main_shell.dart';
import 'services/food_analysis_service.dart';
import 'services/google_places_service.dart';
import 'screens/onboarding_screen.dart';
import 'services/profile_storage.dart';
import 'widgets/skeleton_shimmer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: 'assets/.env');
    final key = dotenv.maybeGet('GEMINI_API_KEY');
    if (key != null && key.isNotEmpty) {
      FoodAnalysisService.apiKey = key;
    }
    final placesKey = dotenv.maybeGet('GOOGLE_PLACES_API_KEY');
    if (placesKey != null && placesKey.isNotEmpty) {
      GooglePlacesService.apiKey = placesKey;
    }
  } catch (_) {
    // .env missing or invalid; app still runs, scan will show "add API key" message
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF1A1D29),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const NutriSenseApp());
}

class NutriSenseApp extends StatelessWidget {
  const NutriSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF22C55E);
    const surface = Color(0xFFF4F7FB);
    const onSurface = Color(0xFF0F172A);
    const darkHeader = Color(0xFF111827);
    return MaterialApp(
      title: 'Nutri-Sense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: primary).copyWith(
          primary: primary,
          secondary: const Color(0xFF14B8A6),
          surface: Colors.white,
          onSurface: onSurface,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: darkHeader,
          foregroundColor: Colors.white,
        ),
        scaffoldBackgroundColor: surface,
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE5EAF0)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD7DEE8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD7DEE8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
          labelStyle: const TextStyle(color: Color(0xFF6B7280)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: onSurface,
            side: const BorderSide(color: Color(0xFFD1D9E3)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: darkHeader,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const _AppStart(),
    );
  }
}

/// Shows onboarding if no profile, otherwise main app with bottom nav.
class _AppStart extends StatefulWidget {
  const _AppStart();

  @override
  State<_AppStart> createState() => _AppStartState();
}

class _AppStartState extends State<_AppStart> {
  bool _loading = true;
  bool _hasProfile = false;

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    final p = await ProfileStorage.load();
    setState(() {
      _hasProfile = p != null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: SizedBox(
            width: 220,
            child: SkeletonShimmer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SkeletonBox(height: 18, width: 120, radius: 999),
                  SizedBox(height: 14),
                  SkeletonBox(height: 12, width: 210),
                  SizedBox(height: 10),
                  SkeletonBox(height: 12, width: 180),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (_hasProfile) {
      return MainShell(
        onSignedOut: () => setState(() => _hasProfile = false),
      );
    }
    return OnboardingScreen(
      onComplete: () => setState(() => _hasProfile = true),
    );
  }
}
