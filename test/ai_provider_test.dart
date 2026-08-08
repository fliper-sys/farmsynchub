import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farmsynchub/core/services/ai_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('Ask AI can accept a farming question and store the reply thread', () async {
    final AiProvider provider = AiProvider();

    const String question = 'What should I do if my tomato leaves are turning yellow?';
    await provider.sendMessage(question);

    final List<dynamic> messages = provider.activeMessages;

    expect(messages, hasLength(2));
    expect(messages.first.text, question);
    expect(messages.first.isFromUser, isTrue);
    expect(messages.last.isFromAi, isTrue);
    expect(messages.last.isLoading, isFalse);
    expect(messages.last.text, isNotEmpty);
  });

  test('Photo diagnosis attaches image bytes to the request and records hasImage', () async {
    final AiProvider provider = AiProvider();

    const String diagnosisPrompt =
        'Please inspect this image carefully. Provide a likely diagnosis, '
        'specific signs I should look for to confirm, and a practical list '
        'of next steps for my farm.';
    await provider.sendMessage(diagnosisPrompt, imageBytes: <int>[1, 2, 3, 4]);

    final List<dynamic> messages = provider.activeMessages;

    expect(messages, hasLength(2));
    expect(messages.first.isFromUser, isTrue);
    expect(messages.first.hasImage, isTrue);
    expect(messages.last.isFromAi, isTrue);
    expect(messages.last.isLoading, isFalse);
    expect(messages.last.text, isNotEmpty);
  });
}
