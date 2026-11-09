import 'dart:convert';

import 'package:farmsynchub/core/services/ai_free_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects common image types from their first bytes', () {
    expect(aiImageMimeType(<int>[0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0]), 'image/png');
    expect(
      aiImageMimeType(<int>[0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50]),
      'image/webp',
    );
    expect(aiImageMimeType(<int>[0x47, 0x49, 0x46, 0x38, 0x39, 0x61]), 'image/gif');
    expect(aiImageMimeType(<int>[0xFF, 0xD8, 0xFF, 0xE0]), 'image/jpeg');
    expect(aiImageMimeType(<int>[]), 'image/jpeg');
  });

  test('text request has system prompt then the conversation', () {
    final Map<String, dynamic> body = FreeAiRoute.buildBody(
      model: 'm',
      systemPrompt: 'be helpful',
      turns: const <AiTurn>[
        AiTurn('user', 'hi'),
        AiTurn('assistant', 'hello'),
        AiTurn('user', 'my maize leaves are yellow'),
      ],
    );
    final List<dynamic> messages = body['messages'] as List<dynamic>;
    expect(body['model'], 'm');
    expect(messages.length, 4);
    expect((messages[0] as Map)['role'], 'system');
    expect((messages[3] as Map)['content'], 'my maize leaves are yellow');
  });

  test('a photo is attached to the last user message as a data URL', () {
    final List<int> png = <int>[0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4];
    final Map<String, dynamic> body = FreeAiRoute.buildBody(
      model: 'vision',
      systemPrompt: 's',
      turns: const <AiTurn>[AiTurn('user', 'what is wrong with this leaf?')],
      imageBytes: png,
    );
    final Map<dynamic, dynamic> last =
        (body['messages'] as List<dynamic>).last as Map<dynamic, dynamic>;
    final List<dynamic> content = last['content'] as List<dynamic>;
    expect((content[0] as Map)['type'], 'text');
    final String url =
        ((content[1] as Map)['image_url'] as Map)['url'] as String;
    expect(url, startsWith('data:image/png;base64,'));
    expect(url, endsWith(base64Encode(png)));
  });

  test('reads the reply from a normal response', () {
    expect(
      FreeAiRoute.parseReply(jsonEncode(<String, dynamic>{
        'choices': <dynamic>[
          <String, dynamic>{
            'message': <String, dynamic>{'content': '  Add nitrogen.  '},
          },
        ],
      })),
      'Add nitrogen.',
    );
  });

  test('reads a reply made of typed parts and tolerates odd responses', () {
    expect(
      FreeAiRoute.parseReply(jsonEncode(<String, dynamic>{
        'choices': <dynamic>[
          <String, dynamic>{
            'message': <String, dynamic>{
              'content': <dynamic>[
                <String, dynamic>{'type': 'text', 'text': 'Use '},
                <String, dynamic>{'type': 'text', 'text': 'mulch.'},
              ],
            },
          },
        ],
      })),
      'Use mulch.',
    );
    expect(FreeAiRoute.parseReply('{}'), '');
    expect(FreeAiRoute.parseReply('[]'), '');
    expect(FreeAiRoute.parseReply('{"choices": []}'), '');
  });

  test('is not configured without a key', () {
    expect(FreeAiRoute.isConfigured, isFalse);
    expect(
      () => FreeAiRoute.instance.generate(
        systemPrompt: 's',
        turns: const <AiTurn>[AiTurn('user', 'hi')],
      ),
      throwsStateError,
    );
  });
}
