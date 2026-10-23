/// The names of the parts an answer is made of. A substantial answer has the
/// six of the timing template, in this order; a shorter one keeps the ones
/// that apply, and every answer that is not a refusal ends with [close].
abstract final class SectionKey {
  /// What is running now.
  static const String now = 'now';

  /// What it tends to bring, read from this chart.
  static const String effect = 'effect';

  /// What helps.
  static const String remedy = 'remedy';

  /// The next better stretch, compared with now, with its dates.
  static const String better = 'better';

  /// How it comes about, and what the shastra says.
  static const String how = 'how';

  /// The closing line: said according to the shastra, not a certainty.
  static const String close = 'close';

  /// The single part of a refusal or of a "not yet".
  static const String plain = 'plain';

  /// The answer in two or three plain lines, for someone who does not know
  /// what a dasha is. Shown first; the rest is there for whoever wants it.
  static const String short = 'short';

  /// The yogas answer's own parts.
  static const String leading = 'leading';
  static const String others = 'others';
  static const String care = 'care';
  static const String running = 'running';
}

/// One headed part of an answer: a heading and a few short paragraphs, so it
/// can be read aloud to someone sitting in front of you.
class AnswerSection {
  const AnswerSection({
    required this.key,
    required this.heading,
    required this.paragraphs,
    this.optional = const <int>{},
  });

  final String key;
  final String heading;
  final List<String> paragraphs;

  /// Indices of paragraphs that are detail: they are shown on screen, but are
  /// the first to be left out when the answer is too long to be read aloud.
  final Set<int> optional;
}

/// An answer composed from the computed chart.
///
/// Nothing here is generated text: each answer is written by hand in both
/// languages and filled from the engine, so it can be read out loud, it works
/// offline, and it cannot invent a planet. The optional language model, when
/// it arrives, sits on top of exactly this material.
class Answer {
  const Answer({
    required this.title,
    required this.sections,
    required this.basis,
    this.short,
    this.isRefusal = false,
    this.isFallback = false,
  });

  final String title;
  final List<AnswerSection> sections;

  /// The answer in plain words, without a single term of the shastra. Kept
  /// apart from [sections] so the full explanation stays exactly as it was.
  final AnswerSection? short;

  /// Everything a reader sees: [short] first, then [sections].
  List<AnswerSection> get allSections => <AnswerSection>[?short, ...sections];

  /// The chart factors the answer was read from.
  final List<String> basis;
  final bool isRefusal;
  final bool isFallback;

  /// True for an answer that explains something from the chart, as opposed to
  /// a refusal or a "not yet". These always end with the closing line.
  bool get isSubstantive => !isRefusal && !isFallback;

  AnswerSection? section(String key) {
    for (final AnswerSection s in sections) {
      if (s.key == key) return s;
    }
    return null;
  }

  /// The closing line, or an empty string when the answer has none.
  String get closing => section(SectionKey.close)?.paragraphs.join(' ') ?? '';

  /// The whole answer as plain text, headings included.
  String get body => allSections
      .map(
        (AnswerSection s) => <String>[
          if (s.heading.isNotEmpty) s.heading,
          ...s.paragraphs,
        ].join('\n\n'),
      )
      .join('\n\n');

  /// The answer as it is read aloud: the title, then every part with its
  /// heading as a sentence of its own, without the paragraphs marked as detail
  /// (those stay on screen). The closing line is always kept.
  String get spoken => spokenChunks().join(' ');

  /// The gist, for an answer that is spoken without being asked to be: the
  /// plain answer when there is one, else every part's heading and its first
  /// paragraph; and the closing line. The screen carries the rest, and the
  /// speaker button reads all of it.
  String get gist => spokenChunks(brief: true).join(' ');

  /// The spoken answer cut into pieces a speech engine will take, each at the
  /// end of a paragraph and none longer than [limit] characters unless a single
  /// sentence is.
  List<String> spokenChunks({int limit = 3500, bool brief = false}) {
    String sentence(String s) {
      final String t = s.trim();
      if (t.isEmpty) return t;
      const String enders = '.।!?:';
      return enders.contains(t[t.length - 1]) ? t : '$t.';
    }

    final List<String> pieces = <String>[sentence(title)];
    final bool shortOnly = brief && short != null;
    for (final AnswerSection s in allSections) {
      if (shortOnly && s.key != SectionKey.short && s.key != SectionKey.close) {
        continue;
      }
      if (s.heading.isNotEmpty) pieces.add(sentence(s.heading));
      for (int i = 0; i < s.paragraphs.length; i++) {
        if (s.optional.contains(i)) continue;
        if (brief && !shortOnly && i > 0 && s.key != SectionKey.close) {
          continue;
        }
        pieces.add(s.paragraphs[i]);
      }
    }
    final List<String> chunks = <String>[];
    String current = '';
    void flush() {
      if (current.isNotEmpty) chunks.add(current);
      current = '';
    }

    for (final String piece in pieces) {
      final List<String> parts = piece.length <= limit
          ? <String>[piece]
          : _splitSentences(piece, limit);
      for (final String part in parts) {
        if (current.isNotEmpty && current.length + part.length + 1 > limit) {
          flush();
        }
        current = current.isEmpty ? part : '$current $part';
      }
    }
    flush();
    return chunks;
  }
}

/// Cuts one long paragraph at sentence ends into pieces of at most [limit].
List<String> _splitSentences(String text, int limit) {
  final List<String> out = <String>[];
  final RegExp end = RegExp(r'(?<=[.।!?]) ');
  String current = '';
  for (final String sentence in text.split(end)) {
    if (current.isNotEmpty && current.length + sentence.length + 1 > limit) {
      out.add(current);
      current = '';
    }
    current = current.isEmpty ? sentence : '$current $sentence';
  }
  if (current.isNotEmpty) out.add(current);
  return out;
}
