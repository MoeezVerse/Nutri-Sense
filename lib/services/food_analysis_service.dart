import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Calls Google Gemini vision API to analyze a food image and return
/// dish name, nutrition (calories, protein, carbs, fat, fiber), and how to make it.
/// Set the API key from main after loading .env: FoodAnalysisService.apiKey = dotenv.maybeGet('GEMINI_API_KEY');
class FoodAnalysisService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static String? apiKey;

  /// Analyze a food image file. Returns a map with: label, calories, protein, carbs, fat, fiber, howToMake.
  /// Throws on network/API errors or if API key is missing.
  static Future<Map<String, dynamic>> analyzeFoodFromFile(File imageFile) async {
    final key = FoodAnalysisService.apiKey;
    if (key == null || key.isEmpty) {
      throw FoodAnalysisException('Missing API key. Create a .env file in the project root with: GEMINI_API_KEY=your_key\nGet a free key at https://aistudio.google.com/apikey');
    }
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    return _callGemini(key, base64Image);
  }

  static Future<Map<String, dynamic>> _callGemini(String apiKey, String base64Image) async {
    const prompt = r'''
Look at this food/meal image. Identify the dish and provide:

1. Dish name (short, e.g. Grilled chicken with rice)
2. Estimated nutrition per typical serving: calories, protein (g), carbs (g), fat (g), fiber (g) - numbers only.
3. How to make it: 1 or 2 short sentences only. Do not use double-quote characters inside the text.

Reply with ONLY a valid JSON object, no other text. Use exactly these keys:
"dishName", "calories", "protein", "carbs", "fat", "fiber", "howToMake"
Keep howToMake brief so the JSON is not cut off.
''';

    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Image,
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 2048,
        'responseMimeType': 'application/json',
      },
    };

    final url = '$_baseUrl?key=$apiKey';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final err = response.body;
      if (response.statusCode == 400 || response.statusCode == 404) {
        throw FoodAnalysisException('API error: ${response.statusCode}. Check your API key and model.');
      }
      if (response.statusCode == 429) {
        throw FoodAnalysisException('Rate limit exceeded. Try again in a moment.');
      }
      throw FoodAnalysisException('Request failed: ${response.statusCode} $err');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw FoodAnalysisException('No result from AI. Try another image.');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw FoodAnalysisException('Empty response from AI.');
    }

    final text = parts[0]['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw FoodAnalysisException('No analysis text from AI.');
    }

    return _parseResponse(text.trim());
  }

  static Map<String, dynamic> _parseResponse(String text) {
    String jsonStr = text;
    final start = text.indexOf('{');
    var end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      jsonStr = text.substring(start, end + 1);
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      data = _parseResponseFallback(text);
    }

    final dishName = data['dishName'] as String? ?? data['label'] as String? ?? 'Unknown dish';
    final calories = _num(data['calories'], 250);
    final protein = _num(data['protein'], 12);
    final carbs = _num(data['carbs'], 30);
    final fat = _num(data['fat'], 10);
    final fiber = _num(data['fiber'], 3);
    var howToMake = data['howToMake'] as String? ?? '';
    if (howToMake.isNotEmpty) {
      howToMake = howToMake.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    return {
      'label': dishName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'howToMake': howToMake,
    };
  }

  /// When JSON is truncated or malformed, try to extract fields manually.
  static Map<String, dynamic> _parseResponseFallback(String text) {
    final data = <String, dynamic>{
      'dishName': 'Unknown dish',
      'calories': 250,
      'protein': 12,
      'carbs': 30,
      'fat': 10,
      'fiber': 3,
      'howToMake': '',
    };

    final dishNameMatch = RegExp(r'"dishName"\s*:\s*"((?:[^"\\]|\\.)*)"', dotAll: true).firstMatch(text);
    if (dishNameMatch != null) {
      data['dishName'] = dishNameMatch.group(1)?.replaceAll(r'\"', '"') ?? data['dishName'];
    }

    final numKeys = ['calories', 'protein', 'carbs', 'fat', 'fiber'];
    for (final key in numKeys) {
      final m = RegExp('"$key"\\s*:\\s*(-?\\d+)').firstMatch(text);
      if (m != null) {
        data[key] = int.tryParse(m.group(1) ?? '') ?? data[key];
      }
    }

    final howMatch = RegExp(r'"howToMake"\s*:\s*"([\s\S]*?)(?:"\s*[,}]|$)', dotAll: true).firstMatch(text);
    if (howMatch == null) {
      final howStart = text.indexOf('"howToMake"');
      if (howStart != -1) {
        final valueStart = text.indexOf('"', howStart + 12) + 1;
        if (valueStart > 0) {
          var s = text.substring(valueStart).replaceAll(RegExp(r'\s+'), ' ').trim();
          if (s.length > 500) s = s.substring(0, 500);
          data['howToMake'] = s;
        }
      }
    } else {
      var s = howMatch.group(1) ?? '';
      s = s.replaceAll(r'\"', '"').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (s.length > 500) s = s.substring(0, 500);
      data['howToMake'] = s;
    }

    return data;
  }

  static int _num(dynamic v, int fallback) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }
}

class FoodAnalysisException implements Exception {
  final String message;
  FoodAnalysisException(this.message);
  @override
  String toString() => message;
}
