import 'package:firebase_ai/firebase_ai.dart';

import 'ai_config.dart';

/// A thin service wrapper around the Vertex AI Gemini GenerativeModel.
///
/// This uses the firebase_ai plugin to access Vertex AI with your linked
/// Firebase project credentials. It does not manage chat history; it only
/// exposes helpers for single prompts and streaming.
class AIService {
  final GenerativeModel _model;

  AIService()
      : _model = FirebaseAI.vertexAI().generativeModel(
          model: AIConfig.model,
          systemInstruction: Content.system(AIConfig.systemInstruction),
          generationConfig: GenerationConfig(temperature: 0.7),
        );

  /// Generate a single response for a prompt. Returns Markdown text.
  Future<String> generate(String prompt) async {
    final response = await _model.generateContent([
      Content.text(prompt),
    ]);
    return response.text ?? '';
  }

  /// Stream tokens for a prompt as they arrive.
  Stream<String> generateStream(String prompt) async* {
    await for (final chunk in _model.generateContentStream([
      Content.text(prompt),
    ])) {
      final text = chunk.text;
      if (text != null && text.isNotEmpty) yield text;
    }
  }
}
