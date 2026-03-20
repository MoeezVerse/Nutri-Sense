import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';
import 'food_analysis_service.dart';

/// Sends chat messages to Gemini with user profile context for personalized nutrition advice.
class NutritionChatService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static String? get apiKey => FoodAnalysisService.apiKey;

  /// [history] alternating user/assistant messages: [ { role: 'user', text: '...' }, { role: 'assistant', text: '...' }, ... ]
  static Future<String> sendMessage({
    required String userMessage,
    required List<Map<String, String>> history,
    UserProfile? profile,
  }) async {
    final key = apiKey;
    if (key == null || key.isEmpty) {
      throw FoodAnalysisException('Missing API key. Add GEMINI_API_KEY to your .env file.');
    }

    final profileContext = profile != null
        ? '''
User profile (use this to personalize all advice):
- Name: ${profile.name}
- Age: ${profile.age}, Weight: ${profile.weightKg} kg, Height: ${profile.heightCm} cm, BMI: ${profile.bmi.toStringAsFixed(1)}
- Goal: ${profile.goal}
- Activity level: ${profile.activityLevel}
- Dietary restrictions: ${profile.dietaryRestrictions.isEmpty ? 'None' : profile.dietaryRestrictions.join(', ')}
${profile.medicalNotes != null && profile.medicalNotes!.isNotEmpty ? '- Medical notes: ${profile.medicalNotes}' : ''}
'''
        : 'No user profile available. Ask the user for their goals and any restrictions if relevant.';

    final systemInstruction = '''
You are a friendly personal nutritionist assistant inside the Nutri-Sense app. Give clear, practical advice about diet, meals, calories, and healthy eating. Use the user's profile to personalize suggestions. Keep responses concise (2-4 short paragraphs max). Do not use markdown or bullet points unless needed for lists. Be supportive and professional.

$profileContext
''';

    final contents = <Map<String, dynamic>>[];
    for (final msg in history) {
      final role = msg['role'] == 'assistant' ? 'model' : 'user';
      contents.add({
        'role': role,
        'parts': [
          {'text': msg['text'] ?? ''},
        ],
      });
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage},
      ],
    });

    final body = {
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction},
        ],
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1024,
      },
    };

    final url = '$_baseUrl?key=$key';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      if (response.statusCode == 429) {
        throw FoodAnalysisException('Rate limit exceeded. Try again in a moment.');
      }
      throw FoodAnalysisException('Could not get response. Try again.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw FoodAnalysisException('No response from assistant.');
    }
    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw FoodAnalysisException('Empty response.');
    }
    final text = parts[0]['text'] as String?;
    return text?.trim() ?? '';
  }
}
