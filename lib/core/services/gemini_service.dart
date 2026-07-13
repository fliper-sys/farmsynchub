import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/currency_utils.dart';
import '../../domain/models/ai_topic.dart';
import '../../domain/models/crop.dart';
import '../../domain/models/farm.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/livestock.dart';
import '../../domain/models/transaction.dart';

const String _kFirebaseAiModelName = String.fromEnvironment(
  'FIREBASE_AI_MODEL',
  defaultValue: 'gemini-1.5-flash',
);
const int _kMaxHistoryTurns = 6;
const Duration _kCacheTtl = Duration(hours: 6);

String _buildSystemPrompt(String language, AiTopic topic) => '''
You are Farmsync AI, the farming assistant inside FarmSync for farmers in Nigeria.
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
  DateTime? _rateLimitedUntil;

  bool get hasApiKey => Firebase.apps.isNotEmpty;

  String get modelName => _kFirebaseAiModelName;

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

    final DateTime? rateLimitedUntil = _rateLimitedUntil;
    if (rateLimitedUntil != null && DateTime.now().isBefore(rateLimitedUntil)) {
      return _offlineRateLimitResponse(
        topic: topic,
        message: trimmedMessage,
        imageBytes: imageBytes,
        retryAt: rateLimitedUntil,
      );
    }

    if (imageBytes == null) {
      final cached = _getFromCache(trimmedMessage, topic);
      if (cached != null) {
        return cached;
      }
    }

    if (!hasApiKey) {
      final ChatMessage offlineMessage = _offlineUnavailableResponse(
        topic: topic,
        message: trimmedMessage,
        imageBytes: imageBytes,
        reason: 'FarmSync AI is not configured yet.',
      );

      _addToHistory(
        topic,
        ChatMessage.fromUser(
          trimmedMessage,
          topic: topic,
          hasImage: imageBytes != null,
        ),
      );
      _addToHistory(topic, offlineMessage);
      return offlineMessage;
    }

    try {
      final GenerateContentResponse response = await _sendWithFirebaseAi(
        topic: topic,
        language: language,
        userMessage: trimmedMessage,
        history: _history[topic] ?? const <ChatMessage>[],
        imageBytes: imageBytes,
      );

      final String responseText = response.text?.trim() ?? '';
      final ChatMessage aiMessage = ChatMessage.fromAi(
        responseText.isEmpty ? _kFallbackMessage : responseText,
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
    } on InvalidApiKey catch (_) {
      return _handleFirebaseAiFailure(
        topic: topic,
        message: trimmedMessage,
        imageBytes: imageBytes,
        reason: 'FarmSync AI is not configured correctly right now.',
      );
    } on UnsupportedUserLocation catch (_) {
      return _handleFirebaseAiFailure(
        topic: topic,
        message: trimmedMessage,
        imageBytes: imageBytes,
        reason: 'FarmSync AI is unavailable in this location.',
      );
    } on FirebaseAIException catch (error) {
      final String errorText = error.toString().toLowerCase();
      if (errorText.contains('quota') || errorText.contains('resource_exhausted')) {
        _rateLimitedUntil = DateTime.now().add(const Duration(minutes: 10));
        final ChatMessage offlineMessage = _offlineRateLimitResponse(
          topic: topic,
          message: trimmedMessage,
          imageBytes: imageBytes,
          retryAt: _rateLimitedUntil ?? DateTime.now().add(const Duration(minutes: 10)),
        );
        _addToHistory(
          topic,
          ChatMessage.fromUser(
            trimmedMessage,
            topic: topic,
            hasImage: imageBytes != null,
          ),
        );
        _addToHistory(topic, offlineMessage);
        await _persistHistory(topic);
        return offlineMessage;
      }
      return _handleFirebaseAiFailure(
        topic: topic,
        message: trimmedMessage,
        imageBytes: imageBytes,
        reason: errorText.contains('not enabled') || errorText.contains('firebasevertexai.googleapis.com')
            ? 'Firebase AI is not enabled for this project: $error'
            : 'Firebase AI could not complete the request: $error',
      );
    } on FirebaseAISdkException catch (_) {
      return _handleFirebaseAiFailure(
        topic: topic,
        message: trimmedMessage,
        imageBytes: imageBytes,
        reason: 'FarmSync AI could not read the response just now.',
      );
    } on SocketException catch (_) {
      return _handleFirebaseAiFailure(
        topic: topic,
        message: trimmedMessage,
        imageBytes: imageBytes,
        reason: 'Network error while contacting FarmSync AI.',
      );
    } on HttpException catch (_) {
      return _handleFirebaseAiFailure(
        topic: topic,
        message: trimmedMessage,
        imageBytes: imageBytes,
        reason: 'FarmSync AI could not reach the service right now.',
      );
    } catch (_) {
      return _handleFirebaseAiFailure(
        topic: topic,
        message: trimmedMessage,
        imageBytes: imageBytes,
        reason: 'FarmSync AI could not complete this request right now.',
      );
    }
  }

  Future<String> generateFarmInsight({
    required Farm farm,
    required List<Crop> crops,
    required List<Livestock> livestock,
    required List<Transaction> transactions,
  }) async {
    try {
      final FirebaseAI firebaseAi = FirebaseAI.googleAI(
        auth: FirebaseAuth.instance,
        appCheck: FirebaseAppCheck.instance,
      );

      final GenerativeModel model = firebaseAi.generativeModel(
        model: _kFirebaseAiModelName,
        systemInstruction: Content.system(_buildFarmInsightSystemPrompt()),
        generationConfig: GenerationConfig(
          temperature: 0.35,
          topK: 32,
          topP: 0.9,
          maxOutputTokens: 900,
        ),
        safetySettings: <SafetySetting>[
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium, null),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium, null),
          SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.high, null),
          SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium, null),
        ],
      );

      final GenerateContentResponse response = await model.generateContent(
        <Content>[
          Content.text(
            _buildFarmInsightPrompt(
              farm: farm,
              crops: crops,
              livestock: livestock,
              transactions: transactions,
            ),
          ),
        ],
      );

      final String insight = response.text?.trim() ?? '';
      if (insight.isNotEmpty) {
        return insight;
      }
    } catch (_) {
      // Fall through to a local briefing if Firebase AI is unavailable.
    }

    return _buildLocalFarmInsight(
      farm: farm,
      crops: crops,
      livestock: livestock,
      transactions: transactions,
    );
  }

  Future<String> generateFinanceRecap({
    required List<Transaction> transactions,
    required List<Farm> farms,
    String language = 'English',
  }) async {
    try {
      final FirebaseAI firebaseAi = FirebaseAI.googleAI(
        auth: FirebaseAuth.instance,
        appCheck: FirebaseAppCheck.instance,
      );

      final GenerativeModel model = firebaseAi.generativeModel(
        model: _kFirebaseAiModelName,
        systemInstruction: Content.system(_buildFinanceRecapSystemPrompt(language)),
        generationConfig: GenerationConfig(
          temperature: 0.35,
          topK: 32,
          topP: 0.9,
          maxOutputTokens: 900,
        ),
        safetySettings: <SafetySetting>[
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium, null),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium, null),
          SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.high, null),
          SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium, null),
        ],
      );

      final GenerateContentResponse response = await model.generateContent(
        <Content>[
          Content.text(
            _buildFinanceRecapPrompt(
              transactions: transactions,
              farms: farms,
            ),
          ),
        ],
      );

      final String recap = response.text?.trim() ?? '';
      if (recap.isNotEmpty) {
        return recap;
      }
    } catch (_) {
      // Fall through to a local briefing if Firebase AI is unavailable.
    }

    return _buildLocalFinanceRecap(
      transactions: transactions,
      farms: farms,
    );
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

  Future<GenerateContentResponse> _sendWithFirebaseAi({
    required AiTopic topic,
    required String language,
    required String userMessage,
    required List<ChatMessage> history,
    List<int>? imageBytes,
  }) async {
    final FirebaseAI firebaseAi = FirebaseAI.googleAI(
      auth: FirebaseAuth.instance,
      appCheck: FirebaseAppCheck.instance,
    );

    final GenerativeModel model = firebaseAi.generativeModel(
      model: _kFirebaseAiModelName,
      systemInstruction: Content.system(_buildSystemPrompt(language, topic)),
      generationConfig: GenerationConfig(
        temperature: 0.4,
        topK: 32,
        topP: 0.95,
        maxOutputTokens: 700,
      ),
      safetySettings: <SafetySetting>[
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium, null),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium, null),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.high, null),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium, null),
      ],
    );

    final List<Content> prompt = _buildFirebasePrompt(
      userMessage: userMessage,
      history: history,
      imageBytes: imageBytes,
    );
    final GenerateContentResponse response = await model.generateContent(prompt);
    return response;
  }

  ChatMessage _handleFirebaseAiFailure({
    required AiTopic topic,
    required String message,
    required List<int>? imageBytes,
    required String reason,
  }) {
    final ChatMessage offlineMessage = _offlineUnavailableResponse(
      topic: topic,
      message: message,
      imageBytes: imageBytes,
      reason: reason,
    );

    _addToHistory(
      topic,
      ChatMessage.fromUser(
        message,
        topic: topic,
        hasImage: imageBytes != null,
      ),
    );
    _addToHistory(topic, offlineMessage);
    unawaited(_persistHistory(topic));
    return offlineMessage;
  }

  List<Content> _buildFirebasePrompt({
    required String userMessage,
    required List<ChatMessage> history,
    List<int>? imageBytes,
  }) {
    final List<Content> prompt = <Content>[];
    final List<ChatMessage> trimmedHistory = history.length > _kMaxHistoryTurns * 2
        ? history.sublist(history.length - (_kMaxHistoryTurns * 2))
        : history;

    for (final ChatMessage message in trimmedHistory) {
      prompt.add(
        Content(
          message.isFromUser ? 'user' : 'model',
          <Part>[
            TextPart(message.text),
          ],
        ),
      );
    }

    final List<Part> userParts = <Part>[
      TextPart(userMessage),
    ];
    if (imageBytes != null) {
      userParts.add(
        InlineDataPart(
          'image/jpeg',
          Uint8List.fromList(imageBytes),
        ),
      );
    }

    prompt.add(Content('user', userParts));
    return prompt;
  }

  ChatMessage _offlineRateLimitResponse({
    required AiTopic topic,
    required String message,
    required List<int>? imageBytes,
    required DateTime retryAt,
  }) {
    final int waitMinutes = retryAt.difference(DateTime.now()).inMinutes + 1;
    final String advice = _localFarmAdvice(topic, message);
    final String imageNote = imageBytes == null
        ? ''
        : '\n\nImage note: FarmSync AI is rate-limited, so I cannot inspect the photo right now. Save the photo and retry after the cooldown.';

    return ChatMessage.fromAi(
      'FarmSync AI is rate-limiting this request, so I switched to offline farm guidance for now. Try the live AI again in about $waitMinutes minutes.\n\n$advice$imageNote',
      topic: topic,
    );
  }

  ChatMessage _offlineUnavailableResponse({
    required AiTopic topic,
    required String message,
    required List<int>? imageBytes,
    required String reason,
  }) {
    final String advice = _localFarmAdvice(topic, message);
    final String imageNote = imageBytes == null
        ? ''
        : '\n\nImage note: I cannot inspect the photo while offline. Keep the image attached or upload it again when internet or quota is available.';

    return ChatMessage.fromAi(
      '$reason I switched to offline FarmSync guidance until FarmSync AI is available again.\n\n$advice$imageNote',
      topic: topic,
    );
  }

  String _localFarmAdvice(AiTopic topic, String message) {
    final String lower = message.toLowerCase();
    final List<String>? exactAnswers = _offlineAnswersFor(topic, message);
    if (exactAnswers != null && exactAnswers.isNotEmpty) {
      final int historyCount = _history[topic]?.length ?? 0;
      return exactAnswers[historyCount % exactAnswers.length];
    }

    switch (topic) {
      case AiTopic.cropManagement:
        return 'Crop action plan:\n- Check crop stage, soil moisture, and leaf color before applying inputs.\n- Record the field, date, product used, quantity, and labour cost in crop records.\n- If leaves are yellowing, compare watering, nutrient deficiency, and pest signs before treatment.\n- For urgent field problems, take clear photos and ask an extension officer or retry Firebase AI later.';
      case AiTopic.animalHealth:
        return 'Animal care action plan:\n- Separate weak or sick animals and check feed, water, temperature, stool, coughing, and wounds.\n- Record symptoms, treatment, vaccination status, and mortality risk in livestock records.\n- Keep housing dry and clean, and call a vet quickly for sudden deaths, severe diarrhoea, or breathing trouble.\n- Update stock counts after births, sales, deaths, or transfers.';
      case AiTopic.diseaseAndPest:
        return 'Pest and disease action plan:\n- Inspect both sides of leaves, stems, fruit, and nearby healthy plants.\n- Do not spray blindly; identify whether signs look like insects, fungus, bacteria, nutrient stress, or water stress.\n- Remove badly affected plant parts where safe, improve spacing/airflow, and document the affected bed.\n- Retry live AI with a clear close-up photo when quota is available.';
      case AiTopic.soilAndWater:
        return 'Soil and water action plan:\n- Use a simple soil squeeze test before irrigation.\n- Mulch exposed beds, avoid waterlogging, and record rainfall or irrigation dates.\n- If soil stays wet after rain, improve drains and avoid walking heavy paths through beds.\n- Match watering to crop stage; young crops need steadier moisture than mature crops.';
      case AiTopic.marketAndFinance:
        return 'Market and finance action plan:\n- Record every sale with buyer, product, quantity, unit price, transport, and receipt number.\n- Compare at least three buyer prices before large sales.\n- Track input costs immediately so profit is not guessed after harvest.\n- If prices are low, compare storage loss risk against waiting for a better market day.';
      case AiTopic.weatherAndClimate:
        return 'Weather planning action plan:\n- Move spraying, harvesting, drying, and transport away from heavy rain periods.\n- Check drainage before storms and cover feed, fertiliser, documents, and harvested produce.\n- During hot dry days, irrigate early morning or evening and watch young plants first.\n- Keep a daily task list for weather-sensitive farm work.';
      case AiTopic.general:
        if (lower.contains('goat') || lower.contains('chicken') || lower.contains('cattle') || lower.contains('animal')) {
          return _localFarmAdvice(AiTopic.animalHealth, message);
        }
        if (lower.contains('sale') || lower.contains('price') || lower.contains('profit') || lower.contains('money')) {
          return _localFarmAdvice(AiTopic.marketAndFinance, message);
        }
        return 'Farm action plan:\n- Write the issue as a record: farm, crop/animal, date, symptoms, cost, and next action.\n- Start with observation before treatment: moisture, weather, pests, health signs, and recent input use.\n- Add a reminder so the issue is checked again tomorrow.\n- Retry Firebase AI later for a more specific live answer.';
    }
  }

  List<String>? _offlineAnswersFor(AiTopic topic, String message) {
    final String normalizedMessage = _normalizeQuestion(message);
    final Map<String, List<String>> answers = _kOfflineAnswerBank[topic] ?? const <String, List<String>>{};

    for (final MapEntry<String, List<String>> entry in answers.entries) {
      final String normalizedQuestion = _normalizeQuestion(entry.key);
      if (normalizedMessage == normalizedQuestion ||
          normalizedMessage.contains(normalizedQuestion) ||
          normalizedQuestion.contains(normalizedMessage)) {
        return entry.value;
      }
    }
    return null;
  }

  String _normalizeQuestion(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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

String _buildFarmInsightSystemPrompt() => '''
You are FarmSync Hub\u2122 Insight AI.
Write for a working farm owner who needs a clear, practical briefing.
Focus on the supplied farm data only.
Use short sections with bold headings, concise paragraphs, and bullet lists.
Prioritize:
- current state of the farm,
- likely operational risks,
- record keeping gaps,
- financial pressure or opportunity,
- the next 3 to 7 actions to take.
Avoid vague advice. Be specific, practical, and respectful.
''';

String _buildFinanceRecapSystemPrompt(String language) => '''
You are FarmSync Hub\u2122 Finance AI.
Write in $language.
Produce a short, executive-style financial recap for a farm owner.
Focus on cash flow, sales, expenses, procurement, record quality, and next actions.
Use concise headings, bullets, and practical recommendations.
When data is limited, clearly say so and still give useful next steps.
''';

String _buildFarmInsightPrompt({
  required Farm farm,
  required List<Crop> crops,
  required List<Livestock> livestock,
  required List<Transaction> transactions,
}) {
  final double income = transactions
      .where((Transaction item) => item.type == TransactionType.income)
      .fold<double>(0, (double sum, Transaction item) => sum + item.amount);
  final double expenses = transactions
      .where((Transaction item) => item.type == TransactionType.expense)
      .fold<double>(0, (double sum, Transaction item) => sum + item.amount);
  final double balance = income - expenses;

  final Map<String, dynamic> payload = <String, dynamic>{
    'farm': <String, dynamic>{
      'name': farm.name,
      'ward': farm.ward,
      'sizeHa': farm.sizeHa,
      'farmType': farm.farmType.name,
      'farmerCategory': farm.farmerCategory.name,
      'soilType': farm.soilType.name,
      'waterSource': farm.waterSource.name,
      'ownerName': farm.ownerName,
      'ownerEmail': farm.ownerEmail,
      'notes': farm.notes,
      'workspaceNotes': farm.workspaceNotes,
      'temperatureCelsius': farm.temperatureCelsius,
      'humidityPercent': farm.humidityPercent,
      'soilMoisturePercent': farm.soilMoisturePercent,
      'precipitationMm': farm.precipitationMm,
      'documents': farm.documents.length,
      'members': farm.workspaceMembers.length,
      'tasks': farm.workspaceTasks.length,
      'openTasks': farm.openWorkspaceTaskCount,
      'activities': farm.activityLog.length,
    },
    'financials': <String, dynamic>{
      'income': income,
      'expenses': expenses,
      'balance': balance,
      'transactionCount': transactions.length,
    },
    'crops': crops.take(8).map((Crop crop) => <String, dynamic>{
      'name': crop.name,
      'variety': crop.variety,
      'areaHa': crop.areaHa,
      'stage': crop.currentStage.name,
      'status': crop.status.name,
      'daysToHarvest': crop.daysToHarvest,
      'inputCost': crop.totalInputCost,
      'openTasks': crop.openTaskCount,
    }).toList(),
    'livestock': livestock.take(8).map((Livestock item) => <String, dynamic>{
      'species': item.species.name,
      'breed': item.breed,
      'count': item.count,
      'purpose': item.purpose.name,
      'healthScore': item.healthScore,
      'vaccinationStatus': item.vaccinationStatus,
      'growthStage': item.growthStage.name,
      'estimatedValue': item.estimatedValue,
      'openTasks': item.openTaskCount,
    }).toList(),
    'recentTransactions': transactions
        .take(8)
        .map((Transaction item) => <String, dynamic>{
              'date': item.transactionDate.toIso8601String(),
              'type': item.type.name,
              'category': item.category.name,
              'amount': item.amount,
              'description': item.description,
              'productName': item.productName,
              'counterpartyName': item.counterpartyName,
              'recordKind': item.recordKind.name,
            })
        .toList(),
    'instructions': <String>[
      'Produce a clear briefing with sections titled: Situation snapshot, Strengths, Risks, Next 7 days, Finance, Records, and Closing advice.',
      'Give concrete actions the farm owner can try next.',
      'Mention where records or follow-up are missing.',
      'If information is limited, say so and still give useful next steps.',
    ],
  };

  return jsonEncode(payload);
}

String _buildLocalFarmInsight({
  required Farm farm,
  required List<Crop> crops,
  required List<Livestock> livestock,
  required List<Transaction> transactions,
}) {
  final double income = transactions
      .where((Transaction item) => item.type == TransactionType.income)
      .fold<double>(0, (double sum, Transaction item) => sum + item.amount);
  final double expenses = transactions
      .where((Transaction item) => item.type == TransactionType.expense)
      .fold<double>(0, (double sum, Transaction item) => sum + item.amount);
  final double balance = income - expenses;
  final List<String> strengths = <String>[
    if (farm.workspaceMembers.isNotEmpty) '${farm.workspaceMembers.length} workspace members are linked.',
    if (crops.isNotEmpty) '${crops.length} crop records are available for review.',
    if (livestock.isNotEmpty) '${livestock.length} livestock groups are being tracked.',
    if (farm.documents.isNotEmpty) '${farm.documents.length} documents are stored with the farm.',
  ];
  final List<String> risks = <String>[
    if (farm.soilMoisturePercent < 30) 'Soil moisture looks low; irrigation or mulching may need attention.',
    if (farm.soilMoisturePercent > 80) 'Soil moisture is high; drainage or root stress should be checked.',
    if (farm.openWorkspaceTaskCount > 0) '${farm.openWorkspaceTaskCount} open tasks need follow-up.',
    if (expenses > income) 'Expenses are currently above income, so cost control matters this week.',
  ];
  final List<String> nextSteps = <String>[
    'Walk the field or pens and verify the latest crop, livestock, and finance entries.',
    'Update any missing records for documents, tasks, or activities today.',
    'Review the highest-cost crop or livestock item and decide the next input or treatment.',
    'Check drainage, water supply, and storage conditions before the next weather change.',
  ];

  return '''
Situation snapshot
- Farm: ${farm.name} in ${farm.ward}
- Type: ${farm.farmType.name}
- Area: ${farm.sizeHa.toStringAsFixed(2)} ha
- Financial balance: ${CurrencyUtils.formatCurrency(balance)}

Strengths
${strengths.isEmpty ? '- The farm has enough data to continue but no strong positive signal is obvious yet.' : strengths.map((String item) => '- $item').join('\n')}

Risks
${risks.isEmpty ? '- No immediate risk is obvious from the stored data.' : risks.map((String item) => '- $item').join('\n')}

Next 7 days
${nextSteps.map((String item) => '- $item').join('\n')}

Finance
- Income: ${CurrencyUtils.formatCurrency(income)}
- Expenses: ${CurrencyUtils.formatCurrency(expenses)}
- Balance: ${CurrencyUtils.formatCurrency(balance)}
- Transactions recorded: ${transactions.length}

Records
- Crop records: ${crops.length}
- Livestock records: ${livestock.length}
- Documents: ${farm.documents.length}
- Activity logs: ${farm.activityLog.length}
  ''';
}

String _buildFinanceRecapPrompt({
  required List<Transaction> transactions,
  required List<Farm> farms,
}) {
  final double income = transactions
      .where((Transaction item) => item.type == TransactionType.income)
      .fold<double>(0, (double sum, Transaction item) => sum + item.amount);
  final double expenses = transactions
      .where((Transaction item) => item.type == TransactionType.expense)
      .fold<double>(0, (double sum, Transaction item) => sum + item.amount);
  final double balance = income - expenses;

  final Map<String, double> categoryTotals = <String, double>{};
  for (final Transaction transaction in transactions) {
    final String key = transaction.category.name;
    categoryTotals[key] = (categoryTotals[key] ?? 0) + transaction.amount;
  }

  final List<Transaction> sortedTransactions = transactions.toList(growable: false)
    ..sort((Transaction a, Transaction b) => b.transactionDate.compareTo(a.transactionDate));

  final Map<String, dynamic> payload = <String, dynamic>{
    'farms': farms.take(8).map((Farm farm) => <String, dynamic>{
          'name': farm.name,
          'ward': farm.ward,
          'sizeHa': farm.sizeHa,
          'farmType': farm.farmType.name,
          'soilType': farm.soilType.name,
          'waterSource': farm.waterSource.name,
        }).toList(),
    'summary': <String, dynamic>{
      'income': income,
      'expenses': expenses,
      'balance': balance,
      'transactionCount': transactions.length,
      'salesCount': transactions.where((Transaction item) => item.recordKind == TransactionRecordKind.sale).length,
      'procurementCount': transactions.where((Transaction item) => item.recordKind == TransactionRecordKind.procurement).length,
    },
    'categoryTotals': categoryTotals.entries
        .map((MapEntry<String, double> entry) => <String, dynamic>{
              'category': entry.key,
              'amount': entry.value,
            })
        .toList(),
    'recentTransactions': sortedTransactions.take(10).map((Transaction item) => <String, dynamic>{
          'date': item.transactionDate.toIso8601String(),
          'type': item.type.name,
          'category': item.category.name,
          'recordKind': item.recordKind.name,
          'description': item.description,
          'productName': item.productName,
          'counterpartyName': item.counterpartyName,
          'amount': item.amount,
          'quantity': item.quantity,
          'unit': item.unit,
          'unitPrice': item.unitPrice,
          'receiptNumber': item.receiptNumber,
        }).toList(),
    'instructions': <String>[
      'Return a compact recap with sections titled: Snapshot, What improved, What needs attention, Previous review focus, and Next suggestions.',
      'Make the advice practical and short enough to read quickly.',
      'Highlight any cash flow pressure, missing records, or repeated patterns.',
      'Suggest concrete next actions for the next 3 to 7 days.',
    ],
  };

  return jsonEncode(payload);
}

String _buildLocalFinanceRecap({
  required List<Transaction> transactions,
  required List<Farm> farms,
}) {
  final double income = transactions
      .where((Transaction item) => item.type == TransactionType.income)
      .fold<double>(0, (double sum, Transaction item) => sum + item.amount);
  final double expenses = transactions
      .where((Transaction item) => item.type == TransactionType.expense)
      .fold<double>(0, (double sum, Transaction item) => sum + item.amount);
  final double balance = income - expenses;
  final int salesCount = transactions.where((Transaction item) => item.recordKind == TransactionRecordKind.sale).length;
  final int procurementCount = transactions.where((Transaction item) => item.recordKind == TransactionRecordKind.procurement).length;

  final List<String> strengths = <String>[
    if (salesCount > 0) '$salesCount sales records are available for review.',
    if (procurementCount > 0) '$procurementCount procurement records are available for review.',
    if (farms.isNotEmpty) '${farms.length} farms are linked to the finance workspace.',
    if (balance >= 0) 'The current balance is positive.',
  ];

  final List<String> attention = <String>[
    if (transactions.isEmpty) 'No finance records are stored yet, so the recap is based on setup data only.',
    if (expenses > income) 'Expenses are higher than income, so tighten spending and review pricing.',
    if (farms.isEmpty) 'No farms are linked yet, so it is harder to compare finance by farm.',
  ];

  final List<String> nextSuggestions = <String>[
    'Review the last 7 days of sales and procurement for missing notes or duplicate entries.',
    'Compare top expense categories against sales to spot margin pressure.',
    'Open the sales desk to check whether customer-linked receipts are being recorded consistently.',
    'Export the finance PDF before the next review meeting so the numbers stay current.',
  ];

  return '''
Snapshot
- Income: ${CurrencyUtils.formatCurrency(income)}
- Expenses: ${CurrencyUtils.formatCurrency(expenses)}
- Balance: ${CurrencyUtils.formatCurrency(balance)}
- Sales records: $salesCount
- Procurement records: $procurementCount

What improved
${strengths.isEmpty ? '- The dataset is small, so no strong improvement signal is visible yet.' : strengths.map((String item) => '- $item').join('\n')}

What needs attention
${attention.isEmpty ? '- No urgent finance issue is obvious from the available data.' : attention.map((String item) => '- $item').join('\n')}

Previous review focus
- Recheck the most recent receipt and expense entries for accuracy.
- Confirm all customer-linked sales have the right product, quantity, and price.

Next suggestions
${nextSuggestions.map((String item) => '- $item').join('\n')}
''';
}

class _CachedResponse {
  const _CachedResponse({
    required this.message,
    required this.timestamp,
  });

  final ChatMessage message;
  final DateTime timestamp;
}

const String _kFallbackMessage =
    'I could not generate a response for that question. Please rephrase it or ask a nearby agricultural extension office for help.';

const Map<AiTopic, Map<String, List<String>>> _kOfflineAnswerBank = <AiTopic, Map<String, List<String>>>{
  AiTopic.cropManagement: <String, List<String>>{
    'When is the best time to plant Irish potatoes in Jos?': <String>[
      'Offline guide: In Jos South, Irish potatoes usually do well when planting is timed with cool, moist conditions. For rain-fed fields, target the early rainy season once rains are steady and the soil is workable. For dry-season production, use irrigation and avoid the hottest periods.\n\nPractical steps:\n- Use clean seed tubers.\n- Plant on ridges or well-drained beds.\n- Avoid waterlogged areas because potatoes rot easily.\n- Record planting date and expected harvest window in crop records.',
      'Offline guide: Plant potatoes when the soil is moist but not soaked. In Plateau conditions, many farmers use the rainy season for easier moisture management, while dry-season farmers depend on irrigation.\n\nQuick checklist:\n- Prepare loose, well-drained soil.\n- Use disease-free seed.\n- Hill up soil as plants grow.\n- Watch for late blight during cool wet periods.',
    ],
    'My tomato leaves are turning yellow. What could be wrong?': <String>[
      'Offline diagnosis: Yellow tomato leaves can come from too much water, too little nitrogen, old lower leaves, root stress, or disease. Check whether yellowing starts from old leaves, whether soil is waterlogged, and whether there are spots or wilting.\n\nNext action:\n- Check soil moisture first.\n- Remove badly diseased leaves.\n- Apply balanced nutrition only if moisture is stable.\n- Take a clear photo and retry live AI when quota returns.',
      'Offline guide: Start with observation before treatment. If lower leaves yellow evenly, nutrient shortage is possible. If yellowing comes with brown spots, suspect disease. If plants wilt in wet soil, root problems may be involved.\n\nRecord this in crop notes: field, date, affected area, recent fertilizer, watering pattern, and photo.',
    ],
    'How much NPK fertilizer do I need for 1 hectare of maize?': <String>[
      'Offline guide: Fertilizer rate depends on soil fertility and NPK grade, so avoid guessing if soil test is available. As a practical smallholder step, split fertilizer application instead of applying everything once.\n\nPlan:\n- Apply basal fertilizer after establishment if soil moisture is good.\n- Top dress when maize is actively growing.\n- Do not apply fertilizer to dry soil.\n- Track quantity and cost in finance records.',
      'Offline caution: Without soil test and exact NPK grade, I cannot give a safe precise rate. Use local extension recommendations for your ward and maize variety.\n\nGood practice:\n- Place fertilizer away from seed to avoid burning.\n- Weed before top dressing.\n- Apply before light rain or irrigate after application.\n- Compare plant color one week later.',
    ],
    'How do I control late blight on potatoes?': <String>[
      'Offline guide: Late blight spreads fast in cool, wet weather. Look for dark water-soaked leaf patches, white growth under leaves, and rapid plant collapse.\n\nActions:\n- Remove badly infected leaves carefully.\n- Improve airflow and avoid overhead watering.\n- Use recommended fungicide from a trusted agro dealer.\n- Do not delay if weather is wet; scout every 2-3 days.',
      'Offline emergency plan: Separate affected sections, avoid moving through wet plants, and record where symptoms started. If infection is spreading, speak with extension staff or a reliable input provider for the right fungicide and dosage.\n\nPrevention: clean seed, crop rotation, drainage, and early scouting.',
    ],
    'What spacing is best for onions?': <String>[
      'Offline guide: Onion spacing depends on variety and bulb size target. A common approach is close spacing for smaller bulbs and wider spacing for bigger bulbs.\n\nPractical rule:\n- Keep rows straight for easy weeding.\n- Avoid overcrowding because airflow reduces disease pressure.\n- Thin weak plants early.\n- Record bed size, plant population, and harvest yield.',
      'Offline tip: For onions, consistent spacing matters as much as the exact number. Leave enough room for hand weeding and bulb expansion. If disease pressure is high, give plants more airflow rather than crowding them.',
    ],
  },
  AiTopic.animalHealth: <String, List<String>>{
    'What vaccines should my goats get this season?': <String>[
      'Offline guide: Goat vaccine schedules depend on local disease risk, age, and veterinary advice. In many smallholder systems, farmers plan around PPR and other locally advised vaccines.\n\nAction:\n- Call a local vet/extension worker for the exact vaccine list.\n- Record vaccine name, date, batch, provider, and next due date.\n- Keep sick animals separate before vaccination.',
      'Offline checklist: Do not vaccinate weak, feverish, or heavily stressed goats without vet guidance. Keep vaccines cold, use clean needles, and mark treated groups in livestock records. Add a reminder for the next dose.',
    ],
    'My chickens are dying suddenly. What could cause it?': <String>[
      'Offline urgent guide: Sudden chicken deaths can be serious. Possible causes include Newcastle disease, poisoning, heat stress, contaminated feed/water, or severe infection.\n\nDo now:\n- Isolate sick birds.\n- Remove dead birds safely.\n- Check feed, water, and housing ventilation.\n- Call a vet quickly if deaths continue.',
      'Offline triage: Look for twisted neck, green diarrhoea, coughing, swollen face, blood in droppings, or sudden weakness. Do not sell or move birds while deaths continue. Record mortality count and time in livestock records.',
    ],
    'How do I deworm my goats properly?': <String>[
      'Offline guide: Deworming should match animal weight and local parasite risk. Under-dosing encourages resistance; over-dosing can harm animals.\n\nSteps:\n- Estimate or weigh goats.\n- Use the correct product and dose label.\n- Treat the group consistently.\n- Keep housing dry and rotate grazing where possible.',
      'Offline reminder: Deworming alone is not enough. Improve sanitation, avoid overcrowding, and watch for pale eyelids, bottle jaw, diarrhoea, poor weight gain, or rough coat. Record date and product used.',
    ],
    'What feed ratio is good for broilers at week 6?': <String>[
      'Offline guide: Week 6 broilers usually need a finisher ration with good protein-energy balance and constant clean water. Exact ratio depends on feed brand/formulation.\n\nPractical actions:\n- Use reputable finisher feed.\n- Avoid sudden feed changes.\n- Keep feeders clean and dry.\n- Track feed bags used and weight gain.',
      'Offline tip: At week 6, performance depends heavily on water, ventilation, stocking density, and feed quality. If growth is poor, check heat stress, disease, feeder access, and whether feed is stale or mouldy.',
    ],
    'What are danger signs during farrowing?': <String>[
      'Offline guide: Danger signs include prolonged straining without piglet delivery, heavy bleeding, foul discharge, fever, weakness, or piglets stuck for too long.\n\nAction:\n- Keep the area clean and quiet.\n- Do not pull aggressively.\n- Call a vet if labour is prolonged or sow is distressed.\n- Record birth count, stillbirths, and sow condition.',
      'Offline checklist: Prepare clean bedding, disinfect hands/tools, keep piglets warm, and ensure each piglet gets colostrum. Watch the sow after farrowing for fever, poor appetite, or swollen udder.',
    ],
  },
  AiTopic.diseaseAndPest: <String, List<String>>{
    'There are holes in my cabbage leaves. What pest is this?': <String>[
      'Offline diagnosis: Holes in cabbage leaves are often caused by caterpillars, diamondback moth larvae, grasshoppers, or beetles. Check the underside of leaves for larvae and eggs.\n\nAction:\n- Hand-pick if infestation is light.\n- Remove badly damaged leaves.\n- Use recommended control only after confirming pest.\n- Scout early morning or evening.',
      'Offline guide: Look at the hole pattern. Small many holes may suggest tiny larvae; large ragged holes may suggest bigger caterpillars or grasshoppers. Record affected beds and retry live AI with a close photo later.',
    ],
    'My maize leaves have a white powder. What does it mean?': <String>[
      'Offline diagnosis: White powder can be fungal growth, dust, or residue from sprays. If it rubs off and spreads on leaves, suspect powdery mildew or another fungal issue.\n\nAction:\n- Improve spacing and airflow.\n- Avoid overhead irrigation.\n- Check if nearby plants show the same sign.\n- Ask extension support if spreading fast.',
      'Offline check: Confirm whether the white material is powder, insect residue, or chemical deposit. Take a photo, note weather conditions, and avoid applying more chemicals until you know the cause.',
    ],
    'My goat is coughing and has nose discharge.': <String>[
      'Offline animal health guide: Coughing with nasal discharge may be respiratory infection, dust irritation, pneumonia risk, or parasites. Separate the goat and check temperature, appetite, breathing, and discharge color.\n\nCall a vet if breathing is fast, discharge is thick, or the animal is weak.',
      'Offline action: Move the goat to a dry, clean, well-ventilated pen. Reduce dust, provide clean water, and record symptoms. Do not mix it with healthy animals until the cause is clear.',
    ],
    'Caterpillars are eating my potato plants. What can I spray?': <String>[
      'Offline guide: First confirm caterpillars are present and active. Check leaf undersides and field edges.\n\nActions:\n- Hand-pick in small plots.\n- Remove heavily damaged leaves.\n- Ask an agro dealer/extension worker for a potato-safe product and correct pre-harvest interval.\n- Avoid spraying during wind or before rain.',
      'Offline caution: Do not spray blindly. Identify the pest, crop stage, and harvest timing first. Use protective clothing, follow label dosage, and record product, date, and cost in crop/finance records.',
    ],
    'My tomato fruits have brown patches inside. What is it?': <String>[
      'Offline diagnosis: Brown patches inside tomato fruit can come from blossom end rot, disease, sunscald, or nutrient/water stress. If patches are at the blossom end, calcium uptake and irregular watering may be involved.\n\nAction: keep moisture steady and remove badly affected fruits.',
      'Offline guide: Cut a few fruits and compare. Record whether the patch is at the bottom, side, or inside only. Check watering pattern, heat stress, and variety. Retry live AI with fruit photos when quota returns.',
    ],
  },
  AiTopic.soilAndWater: <String, List<String>>{
    'How do I know if my soil pH is good for potatoes?': <String>[
      'Offline guide: The best way is a soil test. Potatoes generally prefer slightly acidic soil, but exact target and amendments should follow local test results.\n\nAction:\n- Test soil before planting.\n- Avoid fresh lime unless advised.\n- Improve organic matter and drainage.\n- Record pH result in farm notes.',
      'Offline tip: Poor potato growth can come from pH, low fertility, disease, or waterlogging. If you cannot test immediately, compare crop performance across beds and avoid fields with known scab or drainage problems.',
    ],
    'How do I make compost from farm waste?': <String>[
      'Offline guide: Mix dry materials, green materials, manure, and a little soil. Keep the pile moist like a squeezed sponge, not soaked.\n\nSteps:\n- Layer dry stalks/leaves with green waste/manure.\n- Turn every 1-2 weeks.\n- Cover during heavy rain.\n- Use when dark, crumbly, and earthy-smelling.',
      'Offline warning: Do not add diseased plant material, plastics, chemicals, or fresh uncomposted waste directly around young crops. Good compost improves water holding and soil life.',
    ],
    'My field stays waterlogged after rain. What should I do?': <String>[
      'Offline guide: Waterlogging reduces roots and encourages disease.\n\nActions:\n- Open shallow drains to move excess water away.\n- Use raised beds or ridges.\n- Avoid walking or tilling when soil is wet.\n- Add organic matter over time to improve structure.',
      'Offline plan: Map where water stands longest after rain. Plant water-sensitive crops on higher beds and keep livestock/feed away from muddy zones. Record drainage work as a farm task.',
    ],
    'How often should I irrigate dry season vegetables?': <String>[
      'Offline guide: Frequency depends on crop stage, soil, mulch, heat, and wind. Young vegetables need steady moisture; mature crops may tolerate slightly longer intervals.\n\nUse this test: squeeze soil from root depth. If it crumbles dry, irrigate. If it forms a wet sticky ball, wait.',
      'Offline tip: Irrigate early morning or evening to reduce loss. Mulch beds, group crops by water need, and record irrigation dates so you can learn the pattern for your farm.',
    ],
    'How can I improve sandy soil on the Jos Plateau?': <String>[
      'Offline guide: Sandy soil loses water and nutrients quickly.\n\nActions:\n- Add compost or well-rotted manure.\n- Mulch exposed soil.\n- Split fertilizer into smaller doses.\n- Plant cover crops where possible.\n- Avoid burning residues.',
      'Offline plan: Improve sandy soil gradually. Keep living roots or mulch on the soil, add organic matter every season, and avoid heavy watering that washes nutrients below roots.',
    ],
  },
  AiTopic.marketAndFinance: <String, List<String>>{
    'How do I calculate farm profit for this season?': <String>[
      'Offline formula: Profit = total sales income - total costs.\n\nTrack:\n- Seed, fertilizer, feed, medicine, labour, transport, rent, packaging.\n- Sales by buyer, product, quantity, and price.\n- Losses/spoilage.\nUse the finance screen to register expenses and receipts.',
      'Offline guide: Do not calculate from memory. Enter each input as it happens, then enter each sale with receipt. Compare profit per crop or animal group, not only whole-farm profit.',
    ],
    'When is the best time to sell tomatoes for better prices?': <String>[
      'Offline guide: Best timing depends on supply, spoilage risk, transport, and buyer demand. Prices often fall when many farmers harvest at once.\n\nAction:\n- Compare 3 buyers.\n- Estimate spoilage if you wait.\n- Sell lower-grade fruits first.\n- Record buyer price history.',
      'Offline tip: If tomatoes are ripe and storage is weak, waiting can lose more than a higher price gains. Sort fruits, sell ripe stock quickly, and hold only firm healthy fruits if market signals are improving.',
    ],
    'How do I access a small farm loan in Plateau State?': <String>[
      'Offline guide: Prepare records before applying. Lenders want identity, farm activity, expected income, costs, and repayment plan.\n\nChecklist:\n- Farm profile.\n- Crop/livestock records.\n- Sales history.\n- Input costs.\n- Simple cashflow plan.',
      'Offline caution: Compare interest, fees, repayment timing, collateral, and penalties. Avoid loans where repayment is due before harvest or sales income is likely.',
    ],
    'What is the best way to store onions after harvest?': <String>[
      'Offline guide: Cure onions properly before storage. Keep them dry, shaded, and ventilated.\n\nSteps:\n- Harvest when tops fall and bulbs mature.\n- Cure under shade with airflow.\n- Remove damaged bulbs.\n- Store off the floor in breathable bags/crates.',
      'Offline warning: Moisture is the enemy. Do not store wet onions in sealed bags. Check regularly and remove rotting bulbs before they spread losses.',
    ],
    'Help me make a simple poultry startup budget.': <String>[
      'Offline budget headings:\n- Chicks or point-of-lay birds.\n- Feed by growth stage.\n- Vaccines/medicine.\n- Housing, drinkers, feeders, bedding.\n- Labour, transport, electricity/heat.\n- Emergency reserve.\n- Expected sales and mortality allowance.',
      'Offline guide: Start with flock size, then calculate cost per bird and expected sale income. Include losses and feed price changes. Use finance records from day one so profit is clear.',
    ],
  },
  AiTopic.weatherAndClimate: <String, List<String>>{
    'When do rains usually start in Jos South?': <String>[
      'Offline guide: Rain onset varies by year, so use current local forecasts before planting. Farmers often prepare before steady rains and plant when rainfall becomes reliable, not after one isolated shower.\n\nAction: keep seed and ridges ready, but wait for consistent moisture.',
      'Offline planning: Watch for two or more meaningful rains and soil moisture at planting depth. Keep early seed protected from dry spells and record first effective rain in farm notes.',
    ],
    'What crops suit dry season farming in Jos?': <String>[
      'Offline guide: Dry-season options depend on irrigation. Vegetables such as tomato, pepper, cabbage, onion, leafy greens, and irrigated potatoes may work where water is reliable.\n\nCheck: water source, market demand, pest pressure, and labour.',
      'Offline caution: Choose crops by water availability, not only price. Start with a manageable area, mulch heavily, and track irrigation cost in finance records.',
    ],
    'How do I protect crops from harmattan winds?': <String>[
      'Offline guide: Harmattan can dry leaves and soil quickly.\n\nActions:\n- Mulch beds.\n- Use windbreaks where possible.\n- Irrigate early or evening.\n- Protect seedlings with light shade.\n- Avoid spraying during strong wind.',
      'Offline tip: Young crops suffer most. Group sensitive seedlings near wind protection, reduce exposed soil, and inspect leaf scorch or wilting daily.',
    ],
    'Help me plan a planting calendar for Jos South.': <String>[
      'Offline planning steps:\n- List crops and maturity days.\n- Mark expected rain start, dry spells, and harvest targets.\n- Match crops to field drainage and water source.\n- Add reminders for nursery, transplanting, fertilizer, scouting, and harvest.',
      'Offline guide: Build the calendar backwards from market or household need. Add buffer days for rain delays, labour shortages, and input purchase time. Keep it updated in crop records.',
    ],
  },
  AiTopic.general: <String, List<String>>{
    'How can FarmSync help me manage my farm?': <String>[
      'Offline answer: Use FarmSync to connect farm profiles, crop records, livestock groups, reminders, input costs, sales, receipts, and learning notes in one place. Start by creating a farm, then link crops, animals, finance, and tasks to it.',
      'Offline answer: FarmSync works best when you record small actions daily: planting, treatment, feeding, irrigation, expenses, sales, and reminders. Those records make profit, planning, and advisory support easier.',
    ],
    'What should I record every day?': <String>[
      'Offline answer: Record weather, tasks done, crop or animal changes, input used, labour, expenses, sales, and issues noticed. Add photos when possible.',
      'Offline answer: A good daily farm note includes date, farm section, crop/animal, what changed, what was spent, who worked, and next action.',
    ],
    'How do I prepare for the next farming season?': <String>[
      'Offline answer: Review last season profit, input use, pest problems, labour gaps, and market timing. Then prepare seed, soil, finance, water source, and a task calendar before planting.',
      'Offline answer: Start with records: what worked, what failed, and what cost too much. Use that to choose crops, set budget, plan irrigation, and schedule reminders.',
    ],
  },
};

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
