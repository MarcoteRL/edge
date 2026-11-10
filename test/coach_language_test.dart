// The coach, the briefings and the journal answer in the app's language.
import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/coach/coach_engine.dart';

Map<String, dynamic> _body(List<Map<String, dynamic>> messages) =>
    {'model': 'gemini-3.8-flash', 'messages': messages};

void main() {
  test('Spanish: the rule joins the system message, nothing else moves', () {
    final out = CoachEngine.withReplyLanguage(
        _body([
          {'role': 'system', 'content': 'You are a coach.'},
          {'role': 'user', 'content': '¿cómo dormí?'},
        ]),
        'es');
    final msgs = out['messages'] as List;
    expect(msgs, hasLength(2));
    expect(msgs[0]['content'], startsWith('You are a coach.'));
    expect(msgs[0]['content'], contains('Spanish (español)'));
    expect(msgs[0]['content'], contains('JSON keys'));
    expect(msgs[1]['content'], '¿cómo dormí?');
    expect(out['model'], 'gemini-3.8-flash');
  });

  test('English needs no rule; an unknown code is left alone', () {
    final b = _body([
      {'role': 'system', 'content': 'x'}
    ]);
    expect(identical(CoachEngine.withReplyLanguage(b, 'en'), b), isTrue);
    expect(identical(CoachEngine.withReplyLanguage(b, 'xx'), b), isTrue);
  });

  test('no system message: one is added first', () {
    final out = CoachEngine.withReplyLanguage(
        _body([
          {'role': 'user', 'content': 'hola'}
        ]),
        'es');
    final msgs = out['messages'] as List;
    expect(msgs.first['role'], 'system');
    expect(msgs.last['content'], 'hola');
  });

  test('applied twice (the fallback retry) states it once', () {
    final once = CoachEngine.withReplyLanguage(
        _body([
          {'role': 'system', 'content': 'x'}
        ]),
        'es');
    final twice = CoachEngine.withReplyLanguage(once, 'es');
    final c = (twice['messages'] as List).first['content'] as String;
    expect('LANGUAGE:'.allMatches(c).length, 1);
  });

  test('the caller\'s message maps are not mutated', () {
    final sys = {'role': 'system', 'content': 'x'};
    CoachEngine.withReplyLanguage(_body([sys]), 'es');
    expect(sys['content'], 'x');
  });
}
