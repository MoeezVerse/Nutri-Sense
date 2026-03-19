import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/models/user_profile.dart';
import 'package:project/services/food_analysis_service.dart';
import 'package:project/services/workout_plan_ai_service.dart';

void main() {
  test('AI workout plan generates 7 days', () async {
    await dotenv.load(fileName: 'assets/.env');
    final key = dotenv.maybeGet('GEMINI_API_KEY');
    expect(key, isNotNull, reason: 'GEMINI_API_KEY missing in assets/.env');
    expect(key!.isNotEmpty, isTrue, reason: 'GEMINI_API_KEY empty in assets/.env');
    FoodAnalysisService.apiKey = key;

    const profile = UserProfile(
      name: 'Smoke Test',
      city: 'Lahore',
      age: 28,
      weightKg: 75,
      heightCm: 175,
      goal: 'maintain',
      activityLevel: 'moderate',
      dietaryRestrictions: [],
      medicalNotes: null,
    );

    final days = await WorkoutPlanAIService.generateWeeklyWorkout(
      profile: profile,
      weeklyTrendText: 'No trend yet',
    );

    expect(days.length, 7);
    expect(days.first['title']?.isNotEmpty ?? false, isTrue);
    expect(days.first['setsPlan']?.isNotEmpty ?? false, isTrue);
  });
}

