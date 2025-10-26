import 'dart:async';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

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
        ) {
    debugPrint('[AIService] Initialized with model: ${AIConfig.model}');
  }

  /// Generate a single response for a prompt. Returns Markdown text.
  Future<String> generate(String prompt) async {
    debugPrint('[AIService] generate() start  promptLen=${prompt.length}');
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _model
          .generateContent([
            Content.text(prompt),
          ])
          .timeout(const Duration(seconds: 25));
      final text = response.text ?? '';
      stopwatch.stop();
      debugPrint('[AIService] generate() success in ${stopwatch.elapsedMilliseconds}ms  mdLen=${text.length}');
      return text;
    } on TimeoutException catch (e, st) {
      debugPrint('[AIService] generate() timeout after ${stopwatch.elapsedMilliseconds}ms: $e\n$st');
      rethrow;
    } catch (e, st) {
      stopwatch.stop();
      debugPrint('[AIService] generate() error after ${stopwatch.elapsedMilliseconds}ms: $e\n$st');
      rethrow;
    }
  }

  /// Stream tokens for a prompt as they arrive.
  Stream<String> generateStream(String prompt) async* {
    debugPrint('[AIService] generateStream() start  promptLen=${prompt.length}');
    await for (final chunk in _model.generateContentStream([
      Content.text(prompt),
    ])) {
      final text = chunk.text;
      if (text != null && text.isNotEmpty) yield text;
    }
    debugPrint('[AIService] generateStream() end');
  }
}
