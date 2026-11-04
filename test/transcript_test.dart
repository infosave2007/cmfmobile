import 'package:cmf_mobile/core/util/transcript.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('collapseRepeatedSentences', () {
    test('drops a sentence repeated until the token bound', () {
      const text =
          'Привет, это проверка диктовки. Сегодня хорошая погода. '
          'Мне тоже кажется, что она очень красивая. '
          'Мне тоже кажется, что она очень красивая. '
          'Мне тоже кажется, что она очень красивая.';
      expect(
        collapseRepeatedSentences(text),
        'Привет, это проверка диктовки. Сегодня хорошая погода. '
        'Мне тоже кажется, что она очень красивая.',
      );
    });

    test('compares without case, spacing and end punctuation', () {
      expect(
        collapseRepeatedSentences('Hello there.  hello  there! Bye.'),
        'Hello there. Bye.',
      );
    });

    test('keeps a sentence said again later', () {
      expect(
        collapseRepeatedSentences('Yes. No. Yes.'),
        'Yes. No. Yes.',
      );
    });

    test('keeps text without sentence punctuation', () {
      expect(collapseRepeatedSentences('  one two three  '), 'one two three');
      expect(collapseRepeatedSentences(''), '');
    });
  });
}
