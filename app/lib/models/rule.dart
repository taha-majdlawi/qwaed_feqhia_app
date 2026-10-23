import '../core/arabic.dart';

/// موضع ورود قاعدة داخل حلقة.
class RuleOccurrence {
  const RuleOccurrence({
    required this.episodeId,
    required this.episodeNumber,
    required this.paragraphIndex,
    required this.start,
    required this.context,
  });

  final String episodeId;
  final int episodeNumber;
  final int paragraphIndex;

  /// موضعها بالثواني داخل الحلقة.
  final double start;

  /// نص الفقرة التي وردت فيها، لعرضه كسياق.
  final String context;
}

/// قاعدة فقهية (أو عبارة مقتبسة) وردت بين «» في نصوص السلسلة،
/// مع كل مواضع ورودها.
class FiqhRule {
  FiqhRule({required this.text, required this.occurrences});

  /// أشهر صيغة وردت بها القاعدة (كما في النص، بتشكيلها).
  final String text;
  final List<RuleOccurrence> occurrences;

  int get count => occurrences.length;

  /// أرقام الحلقات التي وردت فيها، مرتّبة وبلا تكرار.
  List<int> get episodeNumbers {
    final numbers = occurrences.map((o) => o.episodeNumber).toSet().toList()
      ..sort();
    return numbers;
  }

  String get normalized => normalizeArabic(text);
}
