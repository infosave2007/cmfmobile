/// A model reply split into its reasoning and its answer.
///
/// Reasoning models write their thinking before the answer and close it
/// with `</think>`. Qwen3-style templates open the block with `<think>` in
/// the output; others (LFM2.5 2.6B) put the opening tag in the prompt, so
/// the reply starts straight with the thinking and the only marker in the
/// text is the closing tag. Shown raw, either way the user read the model
/// talking to itself and a literal `</think>` in the middle of the reply.
class ReplyParts {
  const ReplyParts({
    required this.answer,
    this.reasoning,
    this.thinking = false,
  });

  /// What the model says to the user. May be empty while it still thinks,
  /// or when it ran out of tokens before answering.
  final String answer;

  /// The model's reasoning, or null when the reply has none (or an empty
  /// block, as templates emit when thinking is switched off).
  final String? reasoning;

  /// The reasoning block is open and not closed yet: still thinking.
  final bool thinking;
}

const _open = '<think>';
const _close = '</think>';

/// Splits [text] into reasoning and answer (see [ReplyParts]). A reply
/// without the tags comes back unchanged as the answer.
ReplyParts splitReasoning(String text) {
  final closeAt = text.indexOf(_close);
  if (closeAt >= 0) {
    final head = text.substring(0, closeAt);
    final openAt = head.indexOf(_open);
    // With an opening tag, text before it is answer and the block is
    // reasoning. Without one (the template opened it), everything up to
    // the closing tag is reasoning.
    final lead = openAt >= 0 ? head.substring(0, openAt) : '';
    final reasoning = openAt >= 0
        ? head.substring(openAt + _open.length)
        : head;
    // A second block later in the reply (rare, but some models re-think
    // mid-answer) is folded into the same reasoning.
    final rest = splitReasoning(text.substring(closeAt + _close.length));
    final parts = [
      reasoning.trim(),
      if (rest.reasoning != null) rest.reasoning!,
    ].where((p) => p.isNotEmpty).toList();
    return ReplyParts(
      answer: (lead + rest.answer.trimLeft()).trimLeft(),
      reasoning: parts.isEmpty ? null : parts.join('\n\n'),
      thinking: rest.thinking,
    );
  }
  final openAt = text.indexOf(_open);
  if (openAt >= 0 && text.substring(0, openAt).trim().isEmpty) {
    final reasoning = text.substring(openAt + _open.length).trim();
    return ReplyParts(
      answer: '',
      reasoning: reasoning.isEmpty ? null : reasoning,
      thinking: true,
    );
  }
  return ReplyParts(answer: text);
}

/// The answer alone: what goes back to the model as conversation history
/// and what Copy puts on the clipboard.
String replyAnswer(String text) => splitReasoning(text).answer;
