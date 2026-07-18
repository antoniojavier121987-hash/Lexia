import 'clause.dart';

class Contract {
  final int id;
  final String originalFilename;
  final String? contractType;
  final String? summaryGeneral;
  final String? summaryExecutive;
  final double? riskScore;
  final String? riskLevel;
  final Map<String, dynamic>? riskBreakdown;
  final String status; // subido | procesando | analizado | error
  final DateTime createdAt;
  final List<Clause> clauses;

  Contract({
    required this.id,
    required this.originalFilename,
    this.contractType,
    this.summaryGeneral,
    this.summaryExecutive,
    this.riskScore,
    this.riskLevel,
    this.riskBreakdown,
    required this.status,
    required this.createdAt,
    this.clauses = const [],
  });

  factory Contract.fromJson(Map<String, dynamic> json) {
    return Contract(
      id: json['id'],
      originalFilename: json['original_filename'] ?? '',
      contractType: json['contract_type'],
      summaryGeneral: json['summary_general'],
      summaryExecutive: json['summary_executive'],
      riskScore: (json['risk_score'] as num?)?.toDouble(),
      riskLevel: json['risk_level'],
      riskBreakdown: json['risk_breakdown'] != null
          ? Map<String, dynamic>.from(json['risk_breakdown'])
          : null,
      status: json['status'] ?? 'subido',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      clauses: json['clauses'] != null
          ? (json['clauses'] as List).map((c) => Clause.fromJson(c)).toList()
          : [],
    );
  }
}
