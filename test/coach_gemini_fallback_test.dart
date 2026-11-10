// Gemini through its OpenAI-compatible endpoint, and the fallback model.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openstrap_edge/coach/coach_config.dart';
import 'package:openstrap_edge/coach/coach_engine.dart';

http.Response _ok(String text) => http.Response(
      jsonEncode({
        'choices': [
          {
            'message': {'content': text}
          }
        ]
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Gemini 3+ drops the sampling params; Gemini 2 and others keep them',
      () {
    expect(CoachEngine.geminiRejectsSampling('gemini-3.8-flash'), isTrue);
    expect(CoachEngine.geminiRejectsSampling('google/gemini-3.5-flash-lite'),
        isTrue);
    expect(CoachEngine.geminiRejectsSampling('gemini-2.5-flash'), isFalse);
    expect(CoachEngine.geminiRejectsSampling('gpt-4o-mini'), isFalse);
  });

  test('which failures are worth the fallback', () {
    for (final s in [404, 429, 500, 503]) {
      expect(CoachEngine.fallbackWorthTrying(s), isTrue, reason: '$s');
    }
    for (final s in [null, 400, 401, 403, 413]) {
      expect(CoachEngine.fallbackWorthTrying(s), isFalse, reason: '$s');
    }
  });

  test('a busy model retries once on the fallback, without temperature',
      () async {
    final cfg = CoachConfig();
    await cfg.save(
        baseUrl: kGeminiBaseUrl,
        model: kGeminiDefaultModel,
        fallbackModel: kGeminiFallbackModel);
    final sent = <Map<String, dynamic>>[];
    final c = MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      sent.add(body);
      return body['model'] == kGeminiDefaultModel
          ? http.Response('{"error":{"message":"overloaded"}}', 503)
          : _ok('from the fallback');
    });
    final msg = await CoachEngine.postChat(cfg, {
      'model': cfg.model,
      'messages': [
        {'role': 'user', 'content': 'hi'}
      ],
      'temperature': 0.3,
    }, client: c);
    expect(msg['content'], 'from the fallback');
    expect(sent.map((b) => b['model']),
        [kGeminiDefaultModel, kGeminiFallbackModel]);
    expect(sent.every((b) => !b.containsKey('temperature')), isTrue);
  });

  test('a refused key is not retried on the fallback', () async {
    final cfg = CoachConfig();
    await cfg.save(
        baseUrl: kGeminiBaseUrl,
        model: kGeminiDefaultModel,
        fallbackModel: kGeminiFallbackModel);
    var calls = 0;
    final c = MockClient((_) async {
      calls++;
      return http.Response('{"error":{"message":"bad key"}}', 401);
    });
    await expectLater(
        CoachEngine.postChat(cfg, {
          'model': cfg.model,
          'messages': [
            {'role': 'user', 'content': 'hi'}
          ],
        }, client: c),
        throwsA(isA<CoachException>()));
    expect(calls, 1);
  });

  test('the fallback model is saved and read back', () async {
    final cfg = CoachConfig();
    await cfg.save(fallbackModel: '  gemini-3.5-flash-lite ');
    final again = CoachConfig();
    await again.load();
    expect(again.fallbackModel, 'gemini-3.5-flash-lite');
  });
}
