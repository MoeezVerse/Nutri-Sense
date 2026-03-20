import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/main_shell.dart';
import 'services/food_analysis_service.dart';
import 'services/google_places_service.dart';
import 'services/opencage_geocoder_service.dart';
import 'services/profile_storage.dart';
import 'services/auth_storage.dart';
import 'models/auth_session.dart';
import 'widgets/skeleton_shimmer.dart';
import 'screens/authentication_screen.dart';
import 'screens/further_details_screen.dart';

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
    final ocKey = dotenv.maybeGet('OPENCAGE_API_KEY');
    if (ocKey != null && ocKey.isNotEmpty) {
      OpenCageGeocoderService.apiKey = ocKey;
    }
    final ocBias = dotenv.maybeGet('OPENCAGE_GEOCODE_BIAS');
    if (ocBias != null && ocBias.trim().isNotEmpty) {
      OpenCageGeocoderService.geocodeBias = ocBias.trim();
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

/// Auth + profile gate:
/// - No auth: show Sign In / Sign Up
/// - Auth but no profile: show Further Details
/// - Auth + profile: show main app
class _AppStart extends StatefulWidget {
  const _AppStart();

  @override
  State<_AppStart> createState() => _AppStartState();
}

class _AppStartState extends State<_AppStart> {
  bool _loading = true;
  bool _hasAuth = false;
  bool _hasProfile = false;
  AuthSession? _session;

  @override
  void initState() {
    super.initState();
    _checkAuthAndProfile();
  }

  Future<void> _handleSignedOut() async {
    await AuthStorage.clearSession();
    if (!mounted) return;
    setState(() {
      _hasAuth = false;
      _hasProfile = false;
      _session = null;
    });
  }

  Future<void> _checkAuthAndProfile() async {
    final session = await AuthStorage.loadSession();
    final p = await ProfileStorage.load();
    setState(() {
      _session = session;
      _hasAuth = session != null;
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

    if (_hasAuth) {
      if (_hasProfile) {
        return MainShell(
          onSignedOut: () {
            _handleSignedOut();
          },
        );
      }
      if (_session == null) {
        // Safety: treat missing session as logged out.
        return AuthenticationScreen(onAuthenticated: _checkAuthAndProfile);
      }
      return FurtherDetailsScreen(
        session: _session!,
        onComplete: _checkAuthAndProfile,
      );
    }

    return AuthenticationScreen(
      onAuthenticated: _checkAuthAndProfile,
    );
  }
}
