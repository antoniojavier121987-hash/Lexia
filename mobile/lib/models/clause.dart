class Clause {
  final int orderIndex;
  final String? title;
  final String originalText;
  final String? plainExplanation;
  final String? riskLevel; // BAJO | MEDIO | ALTO
  final String? riskReason;
  final String? category;

  Clause({
    required this.orderIndex,
    this.title,
    required this.originalText,
    this.plainExplanation,
    this.riskLevel,
    this.riskReason,
    this.category,
  });

  factory Clause.fromJson(Map<String, dynamic> json) {
    return Clause(
      orderIndex: json['order_index'] ?? 0,
      title: json['title'],
      originalText: json['original_text'] ?? '',
      plainExplanation: json['plain_explanation'],
      riskLevel: json['risk_level'],
      riskReason: json['risk_reason'],
      category: json['category'],
    );
  }
}
