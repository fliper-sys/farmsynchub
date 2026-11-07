import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Free, OpenAI-compatible AI route used as a backup when Firebase AI Logic
/// and the direct Gemini key are unavailable (missing key, quota, App Check).
///
/// It speaks the widely supported `/chat/completions` format, so it works with
/// OpenRouter's free models (default), Groq, or any other compatible service.
/// Configure it at build time:
///
///   --dart-define=AI_FREE_API_KEY=your-key
///   --dart-define=AI_FREE_MODEL=openrouter/free              (optional)
///   --dart-define=AI_FREE_VISION_MODEL=<a vision model id>    (optional)
///   --dart-define=AI_FREE_BASE_URL=https://openrouter.ai/api/v1 (optional)
///
/// See docs/AI_SETUP.md. Nothing here is hardcoded to a secret.
const String _kApiKey = String.fromEnvironment('AI_FREE_API_KEY');
const String _kBaseUrl = String.fromEnvironment(
  'AI_FREE_BASE_URL',
  defaultValue: 'https://openrouter.ai/api/v1',
);
const String _kModel = String.fromEnvironment(
  'AI_FREE_MODEL',
  defaultValue: 'openrouter/free',
);
const String _kVisionModel = String.fromEnvironment('AI_FREE_VISION_MODEL');

/// One message of a conversation sent to the free route.
@immutable
class AiTurn {
  /// Creates a turn. [role] is `user` or `assistant`.
  const AiTurn(this.role, this.text);

  /// `user` or `assistant`.
  final String role;

  /// The message text.
  final String text;
}

/// Best-guess image type from the file's first bytes (defaults to JPEG).
String aiImageMimeType(List<int> bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  if (bytes.length >= 6 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46) {
    return 'image/gif';
  }
  return 'image/jpeg';
}

/// Client for the free OpenAI-compatible route.
class FreeAiRoute {
  FreeAiRoute({http.Client? client}) : _client = client;

  /// The app-wide instance.
  static final FreeAiRoute instance = FreeAiRoute();

  final http.Client? _client;

  /// True when a key was supplied at build time.
  static bool get isConfigured => _kApiKey.isNotEmpty;

  /// Model for text questions.
  static String get model => _kModel;

  /// Model used when a photo is attached (falls back to [model]).
  static String get visionModel =>
      _kVisionModel.isNotEmpty ? _kVisionModel : _kModel;

  /// The JSON body for a chat-completions request. Public for testing.
  @visibleForTesting
  static Map<String, dynamic> buildBody({
    required String model,
    required String systemPrompt,
    required List<AiTurn> turns,
    List<int>? imageBytes,
    double temperature = 0.4,
    int maxTokens = 1500,
  }) {
    final List<Map<String, dynamic>> messages = <Map<String, dynamic>>[
      <String, dynamic>{'role': 'system', 'content': systemPrompt},
    ];

    for (int i = 0; i < turns.length; i++) {
      final AiTurn turn = turns[i];
      final bool isLast = i == turns.length - 1;
      if (isLast && turn.role == 'user' && imageBytes != null) {
        messages.add(<String, dynamic>{
          'role': 'user',
          'content': <Map<String, dynamic>>[
            <String, dynamic>{'type': 'text', 'text': turn.text},
            <String, dynamic>{
              'type': 'image_url',
              'image_url': <String, String>{
                'url':
                    'data:${aiImageMimeType(imageBytes)};base64,${base64Encode(imageBytes)}',
              },
            },
          ],
        });
      } else {
        messages.add(<String, dynamic>{
          'role': turn.role,
          'content': turn.text,
        });
      }
    }

    return <String, dynamic>{
      'model': model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
    };
  }

  /// Pulls the reply text out of a chat-completions response body, or an
  /// empty string when there is none. Public for testing.
  @visibleForTesting
  static String parseReply(String responseBody) {
    final Object? decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      return '';
    }
    final Object? choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      return '';
    }
    final Object? first = choices.first;
    if (first is! Map<String, dynamic>) {
      return '';
    }
    final Object? message = first['message'];
    if (message is! Map<String, dynamic>) {
      return '';
    }
    final Object? content = message['content'];
    if (content is String) {
      return content.trim();
    }
    // Some providers return a list of typed parts.
    if (content is List) {
      return content
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> part) => part['text'])
          .whereType<String>()
          .join()
          .trim();
    }
    return '';
  }

  /// Asks the free route. Throws when it is not configured or fails.
  /// Retries once on rate limits and temporary server errors.
  Future<String> generate({
    required String systemPrompt,
    required List<AiTurn> turns,
    List<int>? imageBytes,
    double temperature = 0.4,
    int maxTokens = 1500,
  }) async {
    if (!isConfigured) {
      throw StateError(
          'No AI_FREE_API_KEY configured (pass --dart-define=AI_FREE_API_KEY=...).');
    }

    final Uri uri = Uri.parse('$_kBaseUrl/chat/completions');
    final String body = jsonEncode(buildBody(
      model: imageBytes != null ? visionModel : model,
      systemPrompt: systemPrompt,
      turns: turns,
      imageBytes: imageBytes,
      temperature: temperature,
      maxTokens: maxTokens,
    ));

    final http.Client client = _client ?? http.Client();
    try {
      for (int attempt = 0; attempt < 2; attempt++) {
        final http.Response response = await client
            .post(
              uri,
              headers: <String, String>{
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_kApiKey',
              },
              body: body,
            )
            .timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          return parseReply(utf8.decode(response.bodyBytes));
        }

        final bool retryable = response.statusCode == 429 ||
            response.statusCode == 502 ||
            response.statusCode == 503;
        if (retryable && attempt == 0) {
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        throw http.ClientException(
          'Free AI route returned ${response.statusCode}: '
          '${response.body.length > 300 ? response.body.substring(0, 300) : response.body}',
          uri,
        );
      }
      return '';
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }
}
