import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';
import 'food_analysis_service.dart';

class WorkoutPlanAIService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static String? get apiKey => FoodAnalysisService.apiKey;

  static Future<List<Map<String, String>>> generateWeeklyWorkout({
    required UserProfile profile,
    required String weeklyTrendText,
  }) async {
    final key = apiKey;
    if (key == null || key.isEmpty) {
      throw FoodAnalysisException(
        'Missing API key. Add GEMINI_API_KEY in assets/.env',
      );
    }

    final prompt = '''
Create a safe 7-day workout plan as JSON only.

User:
- Age: ${profile.age}
- Weight: ${profile.weightKg} kg
- Height: ${profile.heightCm} cm
- BMI: ${profile.bmi.toStringAsFixed(1)}
- Goal: ${profile.goal}
- Activity level: ${profile.activityLevel}
- Restrictions: ${profile.dietaryRestrictions.join(', ')}
- Medical notes: ${profile.medicalNotes ?? 'None'}
- Weekly trend: $weeklyTrendText

Return ONLY valid JSON with this exact shape:
{
  "days":[
    {
      "day":"Monday",
      "title":"...",
      "duration":"...",
      "setsPlan":"...",
      "intensity":"...",
      "restPlan":"...",
      "description":"..."
    }
  ]
}

Rules:
- exactly 7 items in "days"
- include at least 1 rest/recovery day
- setsPlan must be specific
- keep each text field concise (under 80 characters where possible)
- no markdown
''';
    List<dynamic> days = [];
    for (var attempt = 0; attempt < 2; attempt++) {
      final body = {
        'contents': [
          {
            'parts': [
              {'text': attempt == 0 ? prompt : '$prompt\nReturn compact minified JSON only.'},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.5,
          'maxOutputTokens': 2200,
          'responseMimeType': 'application/json',
        },
      };

      final response = await http
          .post(
            Uri.parse('$_baseUrl?key=$key'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 35));

      if (response.statusCode != 200) {
        throw FoodAnalysisException(
          'Could not generate AI workout plan. (${response.statusCode})',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        continue;
      }
      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      final text = parts != null && parts.isNotEmpty ? parts[0]['text'] as String? : null;
      if (text == null || text.trim().isEmpty) {
        continue;
      }

      try {
        final raw = _safeJson(text);
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        days = decoded['days'] as List<dynamic>? ?? [];
        if (days.length == 7) {
          break;
        }
      } catch (_) {
        // retry once
      }
    }

    if (days.length != 7) {
      throw FoodAnalysisException('AI plan is incomplete. Please try again.');
    }

    final plan = <Map<String, String>>[];
    for (final day in days) {
      final m = day as Map<String, dynamic>;
      plan.add({
        'day': (m['day'] ?? '').toString(),
        'title': (m['title'] ?? '').toString(),
        'duration': (m['duration'] ?? '').toString(),
        'setsPlan': (m['setsPlan'] ?? '').toString(),
        'intensity': (m['intensity'] ?? '').toString(),
        'restPlan': (m['restPlan'] ?? '').toString(),
        'description': (m['description'] ?? '').toString(),
      });
    }
    return plan;
  }

  static String _safeJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return text.substring(start, end + 1);
    }
    if (start != -1) {
      return _balanceJson(text.substring(start).trim());
    }
    return _balanceJson(text);
  }

  static String _balanceJson(String input) {
    final buffer = StringBuffer(input);
    var openBrace = 0;
    var openBracket = 0;
    for (final rune in input.runes) {
      if (rune == 123) openBrace++; // {
      if (rune == 125) openBrace--; // }
      if (rune == 91) openBracket++; // [
      if (rune == 93) openBracket--; // ]
    }
    while (openBracket > 0) {
      buffer.write(']');
      openBracket--;
    }
    while (openBrace > 0) {
      buffer.write('}');
      openBrace--;
    }
    return buffer.toString();
  }
}

