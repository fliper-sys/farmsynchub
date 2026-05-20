import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/ai_topic.dart';
import '../../domain/models/chat_message.dart';
import 'gemini_service.dart';

class AiProvider extends ChangeNotifier {
  final Map<AiTopic, List<ChatMessage>> _messages = <AiTopic, List<ChatMessage>>{};
  final Map<AiTopic, bool> _loading = <AiTopic, bool>{};
  final Map<AiTopic, DateTime> _cooldownUntil = <AiTopic, DateTime>{};
  final Map<AiTopic, Timer> _cooldownTimers = <AiTopic, Timer>{};

  AiTopic _activeTopic = AiTopic.general;
  String _language = 'English';
  bool _isInitialized = false;

  AiTopic get activeTopic => _activeTopic;
  String get language => _language;
  bool get isInitialized => _isInitialized;
  bool get hasApiKey => GeminiService.instance.hasApiKey;
  String get modelName => 'Gemini Flash';
  int get activeMessageCount => activeMessages.where((ChatMessage message) => !message.isLoading).length;

  List<ChatMessage> messagesFor(AiTopic topic) =>
      List<ChatMessage>.unmodifiable(_messages[topic] ?? const <ChatMessage>[]);

  List<ChatMessage> get activeMessages => messagesFor(_activeTopic);

  bool isLoadingFor(AiTopic topic) => _loading[topic] ?? false;
  bool get isActiveLoading => isLoadingFor(_activeTopic);
  bool get isActiveCoolingDown => cooldownRemainingFor(_activeTopic) > Duration.zero;

  Duration cooldownRemainingFor(AiTopic topic) {
    final DateTime? until = _cooldownUntil[topic];
    if (until == null) {
      return Duration.zero;
    }
    final Duration remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  List<String> get supportedLanguages => const <String>[
        'English',
        'Hausa',
        'Pidgin',
      ];

  List<String> get suggestedQuestions => GeminiService.instance.getSuggestedQuestions(_activeTopic);

  Future<void> init() async {
    if (_isInitialized) {
      return;
    }

    await GeminiService.instance.loadPersistedHistory();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _language = prefs.getString(_languageKey) ?? 'English';
    final String? savedTopic = prefs.getString(_topicKey);
    if (savedTopic != null) {
      _activeTopic = AiTopic.values.firstWhere(
        (AiTopic topic) => topic.name == savedTopic,
        orElse: () => AiTopic.general,
      );
    }

    for (final AiTopic topic in AiTopic.values) {
      _messages[topic] = List<ChatMessage>.from(GeminiService.instance.historyFor(topic));
      _loading[topic] = false;
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setTopic(AiTopic topic) async {
    _activeTopic = topic;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_topicKey, topic.name);
    notifyListeners();
  }

  Future<void> setLanguage(String language) async {
    _language = language;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
    notifyListeners();
  }

  Future<void> sendMessage(String text, {List<int>? imageBytes}) async {
    final String trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return;
    }

    final AiTopic topic = _activeTopic;
    if (isLoadingFor(topic)) {
      return;
    }

    if (!hasApiKey) {
      _addMessage(
        topic,
        ChatMessage.fromAi(
          'AI requests are disabled until a Gemini API key is configured with `--dart-define=GEMINI_API_KEY=your_key`.',
          topic: topic,
          isError: true,
        ),
      );
      notifyListeners();
      return;
    }

    final ChatMessage userMessage = ChatMessage.fromUser(
      trimmedText,
      topic: topic,
      hasImage: imageBytes != null,
    );

    _addMessage(topic, userMessage);
    _loading[topic] = true;
    _addMessage(topic, ChatMessage.loading(topic: topic));
    notifyListeners();

    final ChatMessage response = await GeminiService.instance.sendMessage(
      message: trimmedText,
      topic: topic,
      language: _language,
      imageBytes: imageBytes,
    );

    _removeLoading(topic);
    _addMessage(topic, response);
    _loading[topic] = false;
    if (response.text.toLowerCase().contains('rate-limiting this api key')) {
      _startCooldown(topic, const Duration(seconds: 75));
    }
    notifyListeners();
  }

  Future<void> sendSuggestion(String question) => sendMessage(question);

  Future<void> clearTopic(AiTopic topic) async {
    _messages[topic] = <ChatMessage>[];
    _loading[topic] = false;
    GeminiService.instance.clearHistory(topic);
    notifyListeners();
  }

  Future<void> clearAll() async {
    for (final AiTopic topic in AiTopic.values) {
      _messages[topic] = <ChatMessage>[];
      _loading[topic] = false;
    }
    GeminiService.instance.clearAll();
    notifyListeners();
  }

  void _addMessage(AiTopic topic, ChatMessage message) {
    _messages.putIfAbsent(topic, () => <ChatMessage>[]).add(message);
  }

  void _removeLoading(AiTopic topic) {
    _messages[topic]?.removeWhere((ChatMessage message) => message.isLoading);
  }

  void _startCooldown(AiTopic topic, Duration duration) {
    _cooldownUntil[topic] = DateTime.now().add(duration);
    _cooldownTimers[topic]?.cancel();
    _cooldownTimers[topic] = Timer(duration, () {
      _cooldownUntil.remove(topic);
      _cooldownTimers.remove(topic);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    for (final Timer timer in _cooldownTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}

const String _languageKey = 'ai_language';
const String _topicKey = 'ai_topic';
