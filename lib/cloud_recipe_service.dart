import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class CloudRecipe {
  const CloudRecipe({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.steps,
    required this.tutorialSearchQuery,
  });

  final String title;
  final String subtitle;
  final String time;
  final List<String> steps;
  final String tutorialSearchQuery;
}

class CloudRecipeService {
  CloudRecipeService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const endpoint = String.fromEnvironment('AI_RECIPE_ENDPOINT');
  static const recognitionEndpoint = String.fromEnvironment(
    'AI_RECOGNIZE_ENDPOINT',
  );

  bool get isConfigured => endpoint.isNotEmpty;
  String get resolvedRecognitionEndpoint {
    if (recognitionEndpoint.isNotEmpty) return recognitionEndpoint;
    if (endpoint.isEmpty) return '';
    final recipeUri = Uri.tryParse(endpoint);
    if (recipeUri == null || recipeUri.pathSegments.isEmpty) return '';
    final pathSegments = [...recipeUri.pathSegments]
      ..removeLast()
      ..add('recognize');
    return recipeUri.replace(pathSegments: pathSegments).toString();
  }

  bool get isRecognitionConfigured => resolvedRecognitionEndpoint.isNotEmpty;

  Future<List<String>> recognizeIngredients(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    if (!isRecognitionConfigured) return const [];

    final response = await _client
        .post(
          Uri.parse(resolvedRecognitionEndpoint),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'image': base64Encode(imageBytes),
            'mimeType': mimeType,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Ingredient recognition returned ${response.statusCode}.',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rawIngredients = data['ingredients'];
    if (rawIngredients is! List) {
      throw const FormatException(
        'Ingredient recognition returned an invalid response.',
      );
    }
    return rawIngredients
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(20)
        .toList();
  }

  Future<CloudRecipe?> generate(
    List<String> ingredients, {
    required String dietaryPreference,
    required int servings,
    required int maxMinutes,
    required String language,
  }) async {
    if (!isConfigured) return null;

    final response = await _client
        .post(
          Uri.parse(endpoint),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'ingredients': ingredients,
            'preferences': {
              'diet': dietaryPreference,
              'servings': servings,
              'maxMinutes': maxMinutes,
              'language': language,
            },
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Recipe service returned ${response.statusCode}.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rawSteps = data['steps'];
    if (data['title'] is! String ||
        data['subtitle'] is! String ||
        data['time'] is! String ||
        rawSteps is! List ||
        data['tutorialSearchQuery'] is! String) {
      throw const FormatException('Recipe service returned an invalid recipe.');
    }

    return CloudRecipe(
      title: data['title'] as String,
      subtitle: data['subtitle'] as String,
      time: data['time'] as String,
      steps: rawSteps.whereType<String>().toList(),
      tutorialSearchQuery: data['tutorialSearchQuery'] as String,
    );
  }

  void dispose() => _client.close();
}
