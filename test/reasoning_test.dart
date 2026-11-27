import 'package:cmf_mobile/core/util/reasoning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a reply without tags is all answer', () {
    final p = splitReasoning('Hello there.');
    expect(p.answer, 'Hello there.');
    expect(p.reasoning, isNull);
    expect(p.thinking, isFalse);
  });

  test('Qwen3-style block with both tags', () {
    final p = splitReasoning('<think>\nLet me count.\n</think>\n\nTwo.');
    expect(p.reasoning, 'Let me count.');
    expect(p.answer, 'Two.');
    expect(p.thinking, isFalse);
  });

  test('LFM2.5-style: no opening tag, only the closing one', () {
    // Seen on an iPhone with lfm2.5-2.6b-q4tp: the template opens the block
    // in the prompt, so the reply starts with the thinking itself.
    final p = splitReasoning(
      'Let me draft. Final check: two sentences? Yes. Ready.</think>A local AI model is a model that runs on your device.',
    );
    expect(
      p.reasoning,
      'Let me draft. Final check: two sentences? Yes. Ready.',
    );
    expect(p.answer, 'A local AI model is a model that runs on your device.');
    expect(replyAnswer('x</think> y'), 'y');
  });

  test('an open block while streaming is still thinking', () {
    final p = splitReasoning('<think>\nHmm, the user wants');
    expect(p.thinking, isTrue);
    expect(p.answer, isEmpty);
    expect(p.reasoning, 'Hmm, the user wants');
    expect(splitReasoning('<think>').reasoning, isNull);
    expect(splitReasoning('<think>').thinking, isTrue);
  });

  test('an empty block (thinking switched off) leaves no reasoning', () {
    final p = splitReasoning('<think>\n\n</think>\n\nParis.');
    expect(p.reasoning, isNull);
    expect(p.answer, 'Paris.');
  });

  test('a reply that is all reasoning keeps it and has no answer', () {
    final p = splitReasoning('<think>long thought</think>');
    expect(p.reasoning, 'long thought');
    expect(p.answer, isEmpty);
    expect(p.thinking, isFalse);
  });

  test('a second block later in the reply is folded into the reasoning', () {
    final p = splitReasoning('<think>a</think>First. <think>b</think>Second.');
    expect(p.reasoning, 'a\n\nb');
    expect(p.answer, 'First. Second.');
  });

  test('text that merely mentions <think> mid-sentence stays an answer', () {
    final p = splitReasoning('Use the <think> tag to open reasoning.');
    expect(p.reasoning, isNull);
    expect(p.answer, 'Use the <think> tag to open reasoning.');
  });
}
