/// A string in both languages. Every sentence of a reading is one of these,
/// so a screen never has to choose between a sentence that exists and one
/// that does not.
class Bi {
  const Bi(this.en, this.hi);

  final String en;
  final String hi;

  String of(bool hindi) => hindi ? hi : en;

  bool get isComplete => en.trim().isNotEmpty && hi.trim().isNotEmpty;

  @override
  String toString() => en;
}
