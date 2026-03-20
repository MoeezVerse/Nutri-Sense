import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/user_profile.dart';
import 'onboarding_screen.dart';

/// Collects additional user profile details after registration.
class FurtherDetailsScreen extends StatelessWidget {
  const FurtherDetailsScreen({
    super.key,
    required this.session,
    required this.onComplete,
  });

  final AuthSession session;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return OnboardingScreen(
      accountEmail: session.email,
      existingProfile: UserProfile(
        name: session.name,
        city: '',
        age: 0,
        weightKg: 0,
        heightCm: 0,
        goal: 'maintain',
        activityLevel: 'moderate',
        dietaryRestrictions: const [],
        medicalNotes: null,
      ),
      onComplete: onComplete,
    );
  }
}

