/// Cleans a speech-to-text result of the decoder's loop artifact.
///
/// Whisper, once it runs out of speech (silence, noise, a clip padded to a
/// window), tends to emit one plausible sentence and then repeat it until
/// the token bound. Nobody said a sentence six times in a row, so the
/// repeats are dropped: every sentence that reads the same as the one kept
/// before it (ignoring case, spacing and trailing punctuation) goes.
String collapseRepeatedSentences(String text) {
  final pieces = text.trim().split(_sentenceEnd);
  final kept = <String>[];
  String? previous;
  for (final piece in pieces) {
    final sentence = piece.trim();
    if (sentence.isEmpty) continue;
    final key = sentence
        .toLowerCase()
        .replaceAll(_trailingPunctuation, '')
        .replaceAll(_spaces, ' ');
    if (key == previous) continue;
    previous = key;
    kept.add(sentence);
  }
  return kept.join(' ');
}

final _sentenceEnd = RegExp(r'(?<=[.!?…。！？])\s+');
final _trailingPunctuation = RegExp(r'[\s.!?…。！？,;:]+$');
final _spaces = RegExp(r'\s+');
