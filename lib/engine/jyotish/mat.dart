import 'tajika_common.dart' show Bi;

/// मत (mat): one position in a dispute between classical texts.
///
/// Where the tradition's books disagree, the app does not quietly pick a side
/// and it does not drop the item. It keeps every position, with who holds it,
/// the reason they give, and what the chart says when that position is
/// followed. One of them is marked as the one the app computes by default, and
/// the reason for that choice is stated beside it.
///
/// The type is shared on purpose: the yogas, the varshphal (sahams, Tajika
/// yogas, dashas), the panchang, the ghat chakra, the upagrahas and the
/// Sudarshan chakra all raise the same kind of disagreement and all carry it
/// the same way, so one card can show any of them.
///
/// Honesty rule for whoever fills one in: [holder] names the text or tradition
/// only as far as it was actually seen. Where a position could not be traced
/// to a text, say "a widely printed convention" instead of borrowing a
/// citation.
class Mat {
  const Mat({
    required this.position,
    required this.holder,
    required this.reasoning,
    required this.result,
    this.isDefault = false,
    this.value,
    this.holds,
  });

  /// The rule itself, in words or as a formula ("Jupiter − Sun + Lagna").
  final Bi position;

  /// The text or tradition that holds it.
  final Bi holder;

  /// Why they hold it: the argument, not just the claim.
  final Bi reasoning;

  /// What the chart (or the date) comes to under this position: the computed
  /// longitude, window, yes or no. Always a real computation, never a note.
  final Bi result;

  /// True for the position the app computes by default.
  final bool isDefault;

  /// The same result as a number (a longitude in degrees, a count), when it is
  /// one. Lets a test, or a screen, see that two positions really differ.
  final double? value;

  /// For a yoga or a rule: whether it holds under this position.
  final bool? holds;

  bool get isComplete =>
      position.isComplete &&
      holder.isComplete &&
      reasoning.isComplete &&
      result.isComplete;
}

/// मतभेद (matbhed): a disagreement, carried as the positions in it.
///
/// It is shown as "दो मत" / "Two views" (or three when a third reading exists),
/// with each position's computation side by side.
class Matbhed {
  const Matbhed({
    required this.key,
    required this.topic,
    required this.views,
    required this.defaultReason,
    this.whyTheyDiffer,
  });

  /// A stable identifier, for tests and for pinning a card to a screen.
  final String key;

  /// What the disagreement is about ("Mitra saham", "Ravi Yoga").
  final Bi topic;

  /// Two or three positions; exactly one is the default.
  final List<Mat> views;

  /// Why the app computes the default one.
  final Bi defaultReason;

  /// Why the books differ, when there is a reason to give beyond the
  /// positions themselves.
  final Bi? whyTheyDiffer;

  /// "Two views" / "दो मत", or "Three views" / "तीन मत".
  Bi get title => views.length == 3
      ? const Bi('Three views', 'तीन मत')
      : const Bi('Two views', 'दो मत');

  Mat get defaultView => views.firstWhere((Mat m) => m.isDefault);

  List<Mat> get others =>
      views.where((Mat m) => !m.isDefault).toList(growable: false);

  /// True when the positions come to different results. Where every position
  /// has a number, the numbers decide. Where they say whether a yoga or rule
  /// holds, a different answer is a difference, and so is a different account
  /// of how it holds; positions that all find nothing do not differ. Otherwise
  /// the wording of the result decides.
  bool get differs {
    if (views.every((Mat m) => m.value != null)) {
      final double first = views.first.value!;
      return views.any((Mat m) => (m.value! - first).abs() > 1e-6);
    }
    if (views.every((Mat m) => m.holds != null)) {
      if (views.any((Mat m) => m.holds != views.first.holds)) return true;
      if (views.every((Mat m) => m.holds == false)) return false;
    }
    return views.any((Mat m) => m.result.en != views.first.result.en);
  }

  /// Everything a finding that carries two views must have: at least two
  /// positions, exactly one marked as the default, and every line present in
  /// both languages.
  bool get isComplete =>
      views.length >= 2 &&
      views.where((Mat m) => m.isDefault).length == 1 &&
      views.every((Mat m) => m.isComplete) &&
      topic.isComplete &&
      defaultReason.isComplete &&
      (whyTheyDiffer?.isComplete ?? true);
}

/// Something the app still does not compute, with the reason in plain words.
/// It is shown rather than hidden, so a reader knows it exists.
class LeftOut {
  const LeftOut({required this.key, required this.name, required this.reason});

  final String key;
  final Bi name;
  final Bi reason;

  bool get isComplete => name.isComplete && reason.isComplete;
}
