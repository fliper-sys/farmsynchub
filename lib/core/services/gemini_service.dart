import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/ai_topic.dart';
import '../../domain/models/chat_message.dart';

const String _kApiKey = String.fromEnvironment(
  'GEMINI_API_KEY',
  defaultValue: '',
);
const List<String> _kModelNames = <String>[
  'gemini-2.0-flash',
  'gemini-2.0-flash-001',
  'gemini-1.5-flash',
  'gemini-1.5-flash-002',
];
const int _kMaxHistoryTurns = 6;
const Duration _kCacheTtl = Duration(hours: 6);

String _buildSystemPrompt(String language, AiTopic topic) => '''
You are AgriCare AI, the farming assistant inside FarmSync for farmers in Jos South LGA, Plateau State, Nigeria.
Stay focused on farming, livestock, soil, weather, market access, farm records, and rural livelihoods.

Response rules:
- Use $language.
- Keep answers practical and easy to understand.
- Use short paragraphs and short bullet lists when useful.
- Tailor advice to Jos South climate, Plateau State markets, and smallholder farmers.
- If the question is about pests or disease, mention likely cause, symptoms to confirm, and a practical next step.
- If the question is about livestock illness, mention a practical treatment path and advise veterinary help when needed.
- If you are unsure, say so clearly instead of guessing.

Current topic: ${topic.label}
''';

class GeminiService {
  GeminiService._();

  static final GeminiService instance = GeminiService._();

  final Map<AiTopic, List<ChatMessage>> _history = <AiTopic, List<ChatMessage>>{};
  final Map<String, _CachedResponse> _cache = <String, _CachedResponse>{};

  bool get hasApiKey => _kApiKey.isNotEmpty && !_kApiKey.contains('YOUR_GEMINI_API_KEY_HERE');

  String get modelName => _kModelNames.first;

  List<ChatMessage> historyFor(AiTopic topic) =>
      List<ChatMessage>.unmodifiable(_history[topic] ?? const <ChatMessage>[]);

  Future<ChatMessage> sendMessage({
    required String message,
    required AiTopic topic,
    String language = 'English',
    List<int>? imageBytes,
  }) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      return ChatMessage.fromAi(
        'Please type a farming question first.',
        topic: topic,
        isError: true,
      );
    }

    if (!hasApiKey) {
      return ChatMessage.fromAi(
        'Gemini API key is missing. Add `--dart-define=GEMINI_API_KEY=your_key` or update the AI service key.',
        topic: topic,
        isError: true,
      );
    }

    if (imageBytes == null) {
      final cached = _getFromCache(trimmedMessage, topic);
      if (cached != null) {
        return cached;
      }
    }

    final requestBody = _buildRequestBody(
      userMessage: trimmedMessage,
      topic: topic,
      language: language,
      history: _history[topic] ?? const <ChatMessage>[],
      imageBytes: imageBytes,
    );

    try {
      final _GeminiAttemptResult result = await _sendWithFallbackModels(requestBody, topic);
      if (result.response.statusCode != 200) {
        return _handleError(
          topic,
          result.response.statusCode,
          result.response.body,
        );
      }

      final Map<String, dynamic> data = jsonDecode(result.response.body) as Map<String, dynamic>;
      final ChatMessage aiMessage = ChatMessage.fromAi(
        _extractText(data),
        topic: topic,
      );

      _addToHistory(
        topic,
        ChatMessage.fromUser(
          trimmedMessage,
          topic: topic,
          hasImage: imageBytes != null,
        ),
      );
      _addToHistory(topic, aiMessage);

      if (imageBytes == null) {
        _saveToCache(trimmedMessage, topic, aiMessage);
      }

      await _persistHistory(topic);
      return aiMessage;
    } on SocketException {
      return ChatMessage.fromAi(
        'No internet connection. Check your network and try again.',
        topic: topic,
        isError: true,
      );
    } on HttpException {
      return ChatMessage.fromAi(
        'The AI service could not be reached right now. Please try again shortly.',
        topic: topic,
        isError: true,
      );
    } catch (_) {
      return ChatMessage.fromAi(
        'Something went wrong while generating a response. Please try again.',
        topic: topic,
        isError: true,
      );
    }
  }

  List<String> getSuggestedQuestions(AiTopic topic) => _kSuggestedQuestions[topic] ?? const <String>[];

  void clearHistory(AiTopic topic) {
    _history.remove(topic);
    _removePersistedHistory(topic);
  }

  void clearAll() {
    _history.clear();
    _cache.clear();
    _removeAllPersistedHistory();
  }

  Future<void> loadPersistedHistory() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    for (final AiTopic topic in AiTopic.values) {
      final String? raw = prefs.getString('ai_history_${topic.name}');
      if (raw == null) {
        continue;
      }

      try {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        _history[topic] = list
            .map((dynamic item) => ChatMessage.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _history.remove(topic);
      }
    }
  }

  Map<String, dynamic> _buildRequestBody({
    required String userMessage,
    required AiTopic topic,
    required String language,
    required List<ChatMessage> history,
    List<int>? imageBytes,
  }) {
    final List<ChatMessage> trimmedHistory = history.length > _kMaxHistoryTurns * 2
        ? history.sublist(history.length - (_kMaxHistoryTurns * 2))
        : history;
    final List<Map<String, dynamic>> contents = <Map<String, dynamic>>[];

    for (final ChatMessage message in trimmedHistory) {
      contents.add(<String, dynamic>{
        'role': message.isFromUser ? 'user' : 'model',
        'parts': <Map<String, String>>[
          <String, String>{'text': message.text},
        ],
      });
    }

    final List<Map<String, dynamic>> userParts = <Map<String, dynamic>>[
      <String, String>{'text': userMessage},
    ];

    if (imageBytes != null) {
      userParts.add(<String, dynamic>{
        'inline_data': <String, dynamic>{
          'mime_type': 'image/jpeg',
          'data': base64Encode(imageBytes),
        },
      });
    }

    contents.add(<String, dynamic>{
      'role': 'user',
      'parts': userParts,
    });

    return <String, dynamic>{
      'system_instruction': <String, dynamic>{
        'parts': <Map<String, String>>[
          <String, String>{'text': _buildSystemPrompt(language, topic)},
        ],
      },
      'contents': contents,
      'generationConfig': <String, dynamic>{
        'temperature': 0.4,
        'topK': 32,
        'topP': 0.95,
        'maxOutputTokens': 700,
      },
      'safetySettings': <Map<String, String>>[
        <String, String>{
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        <String, String>{
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        <String, String>{
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_ONLY_HIGH',
        },
        <String, String>{
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
      ],
    };
  }

  String _extractText(Map<String, dynamic> data) {
    try {
      final List<dynamic> candidates = data['candidates'] as List<dynamic>;
      if (candidates.isEmpty) {
        return _kFallbackMessage;
      }

      final Map<String, dynamic> content = candidates.first['content'] as Map<String, dynamic>;
      final List<dynamic> parts = content['parts'] as List<dynamic>;
      final StringBuffer buffer = StringBuffer();

      for (final dynamic part in parts) {
        final String? text = (part as Map<String, dynamic>)['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          if (buffer.isNotEmpty) {
            buffer.writeln();
          }
          buffer.write(text.trim());
        }
      }

      return buffer.isEmpty ? _kFallbackMessage : buffer.toString();
    } catch (_) {
      return _kFallbackMessage;
    }
  }

  Future<_GeminiAttemptResult> _sendWithFallbackModels(
    Map<String, dynamic> requestBody,
    AiTopic topic,
  ) async {
    http.Response? lastResponse;

    for (final String model in _kModelNames) {
      final http.Response response = await http
          .post(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/'
              '$model:generateContent?key=$_kApiKey',
            ),
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return _GeminiAttemptResult(model: model, response: response);
      }

      lastResponse = response;
      if (response.statusCode != 404) {
        break;
      }
    }

    return _GeminiAttemptResult(
      model: _kModelNames.first,
      response: lastResponse ??
          http.Response(
            '{"error":{"message":"No Gemini response was returned."}}',
            500,
          ),
    );
  }

  ChatMessage _handleError(AiTopic topic, int statusCode, String responseBody) {
    final String apiMessage = _extractApiErrorMessage(responseBody);
    switch (statusCode) {
      case 400:
        return ChatMessage.fromAi(
          apiMessage.isEmpty
              ? 'That question could not be processed. Please rephrase it and try again.'
              : 'Request could not be processed: $apiMessage',
          topic: topic,
          isError: true,
        );
      case 403:
        return ChatMessage.fromAi(
          apiMessage.isEmpty
              ? 'The Gemini API key was rejected. Please verify the key and API access.'
              : 'Gemini access was rejected: $apiMessage',
          topic: topic,
          isError: true,
        );
      case 404:
        return ChatMessage.fromAi(
          apiMessage.isEmpty
              ? 'The selected Gemini model endpoint was not found. Check the model name or switch to a currently supported model for this API key.'
              : 'Gemini model endpoint was not found: $apiMessage',
          topic: topic,
          isError: true,
        );
      case 429:
        return ChatMessage.fromAi(
          apiMessage.isEmpty
              ? 'Too many AI requests were sent at once. Wait a moment and try again.'
              : 'Too many AI requests were sent: $apiMessage',
          topic: topic,
          isError: true,
        );
      case 500:
      case 503:
        return ChatMessage.fromAi(
          apiMessage.isEmpty
              ? 'The AI server is temporarily unavailable. Please try again in a few minutes.'
              : 'The AI server is temporarily unavailable: $apiMessage',
          topic: topic,
          isError: true,
        );
      default:
        return ChatMessage.fromAi(
          apiMessage.isEmpty
              ? 'Request failed with error $statusCode. Please try again.'
              : 'Request failed with error $statusCode: $apiMessage',
          topic: topic,
          isError: true,
        );
    }
  }

  String _extractApiErrorMessage(String responseBody) {
    try {
      final Map<String, dynamic> decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final Object? error = decoded['error'];
      if (error is Map<String, dynamic>) {
        return (error['message'] as String? ?? '').trim();
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  void _addToHistory(AiTopic topic, ChatMessage message) {
    _history.putIfAbsent(topic, () => <ChatMessage>[]).add(message);
  }

  String _cacheKey(String message, AiTopic topic) => '${topic.name}:${message.toLowerCase()}';

  ChatMessage? _getFromCache(String message, AiTopic topic) {
    final _CachedResponse? cached = _cache[_cacheKey(message.trim(), topic)];
    if (cached == null) {
      return null;
    }

    if (DateTime.now().difference(cached.timestamp) > _kCacheTtl) {
      _cache.remove(_cacheKey(message.trim(), topic));
      return null;
    }

    return cached.message;
  }

  void _saveToCache(String message, AiTopic topic, ChatMessage response) {
    _cache[_cacheKey(message.trim(), topic)] = _CachedResponse(
      message: response,
      timestamp: DateTime.now(),
    );
  }

  Future<void> _persistHistory(AiTopic topic) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<ChatMessage> history = _history[topic] ?? const <ChatMessage>[];
      final List<ChatMessage> toSave = history.length > 10
          ? history.sublist(history.length - 10)
          : history;
      await prefs.setString(
        'ai_history_${topic.name}',
        jsonEncode(toSave.map((ChatMessage message) => message.toJson()).toList()),
      );
    } catch (_) {
      // Persistence failure should not block the chat experience.
    }
  }

  Future<void> _removePersistedHistory(AiTopic topic) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('ai_history_${topic.name}');
    } catch (_) {
      // Ignore cleanup errors.
    }
  }

  Future<void> _removeAllPersistedHistory() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      for (final AiTopic topic in AiTopic.values) {
        await prefs.remove('ai_history_${topic.name}');
      }
    } catch (_) {
      // Ignore cleanup errors.
    }
  }
}

class _CachedResponse {
  const _CachedResponse({
    required this.message,
    required this.timestamp,
  });

  final ChatMessage message;
  final DateTime timestamp;
}

class _GeminiAttemptResult {
  const _GeminiAttemptResult({
    required this.model,
    required this.response,
  });

  final String model;
  final http.Response response;
}

const String _kFallbackMessage =
    'I could not generate a response for that question. Please rephrase it or ask a nearby agricultural extension office for help.';

const Map<AiTopic, List<String>> _kSuggestedQuestions = <AiTopic, List<String>>{
  AiTopic.cropManagement: <String>[
    'When is the best time to plant Irish potatoes in Jos?',
    'My tomato leaves are turning yellow. What could be wrong?',
    'How much NPK fertilizer do I need for 1 hectare of maize?',
    'How do I control late blight on potatoes?',
    'What spacing is best for onions?',
  ],
  AiTopic.animalHealth: <String>[
    'What vaccines should my goats get this season?',
    'My chickens are dying suddenly. What could cause it?',
    'How do I deworm my goats properly?',
    'What feed ratio is good for broilers at week 6?',
    'What are danger signs during farrowing?',
  ],
  AiTopic.diseaseAndPest: <String>[
    'There are holes in my cabbage leaves. What pest is this?',
    'My maize leaves have a white powder. What does it mean?',
    'My goat is coughing and has nose discharge.',
    'Caterpillars are eating my potato plants. What can I spray?',
    'My tomato fruits have brown patches inside. What is it?',
  ],
  AiTopic.soilAndWater: <String>[
    'How do I know if my soil pH is good for potatoes?',
    'How do I make compost from farm waste?',
    'My field stays waterlogged after rain. What should I do?',
    'How often should I irrigate dry season vegetables?',
    'How can I improve sandy soil on the Jos Plateau?',
  ],
  AiTopic.marketAndFinance: <String>[
    'How do I calculate farm profit for this season?',
    'When is the best time to sell tomatoes for better prices?',
    'How do I access a small farm loan in Plateau State?',
    'What is the best way to store onions after harvest?',
    'Help me make a simple poultry startup budget.',
  ],
  AiTopic.weatherAndClimate: <String>[
    'When do rains usually start in Jos South?',
    'What crops suit dry season farming in Jos?',
    'How do I protect crops from harmattan winds?',
    'Help me plan a planting calendar for Jos South.',
    'Will this weather affect my maize this week?',
  ],
  AiTopic.general: <String>[
    'What records should I keep every week on my farm?',
    'Best crops for a new farmer in Jos South?',
    'How do I start a small poultry farm with 50,000 naira?',
    'What government farm support programs can I look for?',
    'How do I get improved seeds for planting?',
  ],
};
